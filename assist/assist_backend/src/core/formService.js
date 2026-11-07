import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { SERVICES } from '../data/services.js';
import { findUser, maskName, publicHelper, HELPERS } from '../data/users.js';
import { seedForms, formToService, sampleRows, profileKeyOf, FIELD_TYPES } from '../data/forms.js';
import { badRequest, notFound, conflict, tooMany, forbidden } from './errors.js';
import { createRateLimiter } from './rateLimit.js';

const STATUSES = new Set(['draft', 'open', 'closed']);
const MAX_TEXT = { textarea: 500, address: 120 };

/** 承辦人員（可以看表單後台、接線上求助）：1999 客服與里長 */
export const isStaff = (u) => u?.role === 'helper' && ['official', 'village_chief'].includes(u.helperType);

/**
 * 靜態 QR Code 表單：表單定義、收件、半路求助。
 *
 *   長輩掃 QR → 自己填 ──送出──► 回覆（後台即時看到）
 *                  │
 *                  └─ 不會填 ─► 線上客服接手／旁邊的人掃碼／信任的人
 *                               └─ 已填的答案帶進陪辦 session，陪辦完成一樣寫進回覆
 */
export function createFormService({ config, assist, audit, notify = () => {}, now = () => Date.now() }) {
  const forms = new Map();
  const rows = new Map(); // formId -> 真實回覆（新到舊）
  const samples = new Map(); // formId -> 示意回覆
  const drafts = new Map(); // `${elderId}:${serviceId}` -> { answers, expiresAt }
  const tickets = new Map();
  const ticketLimiter = createRateLimiter({ max: 5, windowMs: 10 * 60 * 1000, now });
  const file = config.dataDir ? path.join(config.dataDir, 'forms.json') : null;

  // ───────────────────────── 載入與保存

  function load() {
    let saved = null;
    if (file && fs.existsSync(file)) {
      try {
        saved = JSON.parse(fs.readFileSync(file, 'utf8'));
      } catch (e) {
        console.error('[forms] 讀取失敗，改用預設表單', e.message);
      }
    }
    const seeds = seedForms(now);
    for (const f of saved?.forms ?? seeds) forms.set(f.id, f);
    // 預設表單被刪掉以外，永遠補回來（QR Code 已經印出去了）
    for (const f of seeds) if (!forms.has(f.id) && !(saved?.deleted ?? []).includes(f.id)) forms.set(f.id, f);
    for (const [id, list] of Object.entries(saved?.rows ?? {})) rows.set(id, list);
    for (const f of seeds) samples.set(f.id, sampleRows(f, now));
    deleted = new Set(saved?.deleted ?? []);
    for (const f of forms.values()) register(f);
  }
  let deleted = new Set();

  let saveTimer = null;
  function save() {
    if (!file) return;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      try {
        fs.mkdirSync(path.dirname(file), { recursive: true });
        const tmp = `${file}.tmp`;
        fs.writeFileSync(
          tmp,
          JSON.stringify({ forms: [...forms.values()], rows: Object.fromEntries(rows), deleted: [...deleted] }),
        );
        fs.renameSync(tmp, file);
      } catch (e) {
        console.error('[forms] 保存失敗', e.message);
      }
    }, 300);
    saveTimer.unref?.();
  }

  /** 已發布的表單同時登記成陪辦業務，讓陪辦人員可以直接帶長輩填 */
  function register(f) {
    const i = SERVICES.findIndex((s) => s.id === `form-${f.id}`);
    if (f.status === 'draft') {
      if (i >= 0) SERVICES.splice(i, 1);
      return;
    }
    const svc = formToService(f);
    svc.open = f.status === 'open' && f.allowAssist !== false;
    if (i >= 0) SERVICES[i] = svc;
    else SERVICES.push(svc);
  }

  // ───────────────────────── 視圖

  const allRows = (id) => [...(rows.get(id) ?? []), ...(samples.get(id) ?? [])];

  function publicForm(f) {
    return {
      id: f.id,
      title: f.title,
      dept: f.dept,
      desc: f.desc,
      deadline: f.deadline,
      allowAssist: f.allowAssist !== false,
      once: Boolean(f.once),
      doneMsg: f.doneMsg,
      status: f.status,
      serviceId: `form-${f.id}`,
      fields: f.fields.map((x) => ({ ...x, profile: profileKeyOf(x) })),
    };
  }

  function summary(f) {
    const list = allRows(f.id);
    const dayAgo = now() - 86400000;
    return {
      ...publicForm(f),
      createdAt: f.createdAt,
      updated: f.updated,
      responses: list.length,
      realResponses: (rows.get(f.id) ?? []).length,
      today: list.filter((r) => r._t > dayAgo).length,
      assisted: list.filter((r) => r._via === 'assist').length,
      waitingHelp: [...tickets.values()].filter((t) => t.formId === f.id && t.status === 'waiting').length,
    };
  }

  function requireForm(id, { open = false } = {}) {
    const f = forms.get(id);
    if (!f || f.status === 'draft') throw notFound('找不到這份表單', 'FORM_NOT_FOUND');
    if (open && f.status !== 'open') throw conflict('這份表單已經停止收件了', 'FORM_CLOSED');
    if (open && f.deadline && new Date(`${f.deadline}T23:59:59+08:00`).getTime() < now()) {
      throw conflict('這份表單已經過了截止日期', 'FORM_CLOSED');
    }
    return f;
  }

  // ───────────────────────── 承辦人員：管理表單

  function cleanForm(body, old) {
    const s = (v, max) => String(v ?? '').slice(0, max);
    if (!Array.isArray(body.fields) || body.fields.length > 40) throw badRequest('題目格式錯誤', 'INVALID_FORM');
    const ids = new Set();
    const fields = body.fields.map((x) => {
      if (!FIELD_TYPES.has(x?.type)) throw badRequest('不支援的題型', 'INVALID_FORM');
      const id = s(x.id, 40) || crypto.randomUUID().slice(0, 7);
      if (ids.has(id) || !/^[\w-]+$/.test(id)) throw badRequest('題目代號重複或格式錯誤', 'INVALID_FORM');
      ids.add(id);
      return {
        id,
        type: x.type,
        label: s(x.label, 120),
        hint: s(x.hint, 200),
        required: x.required !== false,
        options: (Array.isArray(x.options) ? x.options : []).slice(0, 20).map((o) => s(o, 60)),
        ...(x.profile !== undefined ? { profile: PROFILE_OK(x.profile) } : {}),
      };
    });
    return {
      id: old?.id,
      title: s(body.title, 80),
      dept: s(body.dept, 60) || '臺北市政府',
      desc: s(body.desc, 400),
      fields,
      deadline: /^\d{4}-\d{2}-\d{2}$/.test(body.deadline ?? '') ? body.deadline : '',
      allowAssist: body.allowAssist !== false,
      once: Boolean(body.once),
      doneMsg: s(body.doneMsg, 200) || '已經幫你送出了，謝謝你。',
      status: STATUSES.has(body.status) ? body.status : 'draft',
      createdAt: old?.createdAt ?? now(),
      updated: now(),
    };
  }
  const PROFILE_OK = (p) => (['realName', 'birthday', 'idNo', 'phone', 'residentAddress'].includes(p) ? p : null);

  function listForms(staff) {
    requireStaff(staff);
    return [...forms.values()].sort((a, b) => b.updated - a.updated).map((f) => ({ ...summary(f), status: f.status }));
  }

  function getFormForStaff(staff, id) {
    requireStaff(staff);
    const f = forms.get(id);
    if (!f) throw notFound('找不到這份表單');
    return { ...summary(f), status: f.status };
  }

  function putForm(staff, id, body = {}) {
    requireStaff(staff);
    if (!/^[\w-]{3,40}$/.test(id)) throw badRequest('表單代號格式錯誤', 'INVALID_FORM');
    const old = forms.get(id);
    const f = cleanForm(body, old ?? { id });
    f.id = id;
    forms.set(id, f);
    deleted.delete(id);
    register(f);
    if (!old || old.status !== f.status) {
      audit.append({
        type: 'form.updated',
        actor: { role: 'helper', id: staff.id },
        helperId: staff.id,
        summary: `${f.status === 'open' ? '發布' : f.status === 'closed' ? '停止收件' : '儲存草稿'}「${f.title}」`,
      });
    }
    save();
    return { ...summary(f), status: f.status };
  }

  function deleteForm(staff, id) {
    requireStaff(staff);
    if (!forms.delete(id)) throw notFound('找不到這份表單');
    rows.delete(id);
    samples.delete(id);
    deleted.add(id);
    const i = SERVICES.findIndex((s) => s.id === `form-${id}`);
    if (i >= 0) SERVICES[i].open = false;
    save();
    return { ok: true };
  }

  function listRows(staff, id) {
    requireStaff(staff);
    if (!forms.has(id)) throw notFound('找不到這份表單');
    return allRows(id);
  }

  function requireStaff(u) {
    if (!isStaff(u)) throw forbidden('只有承辦人員可以使用表單後台', 'NOT_STAFF');
  }

  // ───────────────────────── 長輩：自己填

  /** 長輩打開表單：附上自己實名帳號裡可帶入的資料（只回給長輩本人） */
  function openForElder(elder, id) {
    const f = requireForm(id);
    const prefill = {};
    for (const x of f.fields) {
      const pk = profileKeyOf(x);
      if (pk && elder.profile[pk]) prefill[x.id] = elder.profile[pk];
    }
    const mine = (rows.get(id) ?? []).find((r) => r._elder === elder.id);
    return {
      ...publicForm(f),
      prefill,
      submitted: mine ? { receiptNo: mine._receipt, at: mine._t } : null,
    };
  }

  function cleanAnswers(f, answers, { partial = false } = {}) {
    if (answers === null || typeof answers !== 'object' || Array.isArray(answers)) {
      throw badRequest('答案格式錯誤', 'INVALID_ANSWERS');
    }
    const out = {};
    const missing = [];
    for (const x of f.fields) {
      let v = answers[x.id];
      if (Array.isArray(v)) v = v.map(String).join('、');
      v = v == null ? '' : String(v).trim();
      // eslint-disable-next-line no-control-regex
      v = v.replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, '').slice(0, MAX_TEXT[x.type] ?? 100);
      if (x.type === 'file') v = v ? '（照片稍後補件）' : '';
      if (v && (x.type === 'radio' || x.type === 'select') && !x.options.includes(v)) {
        throw badRequest(`「${x.label}」沒有這個選項`, 'INVALID_OPTION');
      }
      if (v && x.type === 'checkbox' && v.split('、').some((p) => !x.options.includes(p))) {
        throw badRequest(`「${x.label}」沒有這個選項`, 'INVALID_OPTION');
      }
      if (v && x.type === 'consent') v = '我同意';
      if (v && x.type === 'number' && !/^\d{1,6}$/.test(v)) throw badRequest(`「${x.label}」請填數字`, 'INVALID_VALUE');
      if (v && x.type === 'date' && !/^\d{4}-\d{2}-\d{2}$/.test(v)) throw badRequest(`「${x.label}」日期格式錯誤`, 'INVALID_VALUE');
      if (v) out[x.id] = v;
      else if (x.required && x.type !== 'file') missing.push(x.label);
    }
    if (!partial && missing.length) throw badRequest(`還有題目沒回答：${missing.join('、')}`, 'INCOMPLETE');
    return out;
  }

  function receiptNo() {
    const t = new Date(now());
    const ymd = `${t.getFullYear()}${String(t.getMonth() + 1).padStart(2, '0')}${String(t.getDate()).padStart(2, '0')}`;
    return `F${ymd}-${crypto.randomInt(0, 100000).toString().padStart(5, '0')}`;
  }

  function addRow(f, row) {
    const list = rows.get(f.id) ?? [];
    list.unshift(row);
    rows.set(f.id, list);
    save();
    for (const h of HELPERS) if (isStaff(h)) notify(h.id, 'form:response', { formId: f.id, row, form: summary(f) });
  }

  function submitByElder(elder, id, { answers } = {}) {
    const f = requireForm(id, { open: true });
    if (f.once && (rows.get(id) ?? []).some((r) => r._elder === elder.id)) {
      throw conflict('你已經填過這份表單了', 'ALREADY_SUBMITTED');
    }
    const clean = cleanAnswers(f, answers);
    const row = { _id: crypto.randomUUID(), _t: now(), _by: '本人（台北通）', _via: 'self', _receipt: receiptNo(), _elder: elder.id, ...clean };
    addRow(f, row);
    drafts.delete(`${elder.id}:form-${id}`);
    cancelTicketsOf(elder.id, id);
    audit.append({
      type: 'form.submitted',
      actor: { role: 'elder', id: elder.id },
      elderId: elder.id,
      summary: `您送出了「${f.title}」，收件編號 ${row._receipt}`,
      detail: { formId: id, receiptNo: row._receipt },
    });
    return { receiptNo: row._receipt, submittedAt: row._t, doneMsg: f.doneMsg };
  }

  /** 陪辦 session 送出後，同一份資料寫進表單回覆 */
  function onAssistSubmitted({ service, elder, helper, data, caseNo }) {
    const f = service.formId ? forms.get(service.formId) : null;
    if (!f) return;
    const answers = {};
    for (const x of f.fields) if (data[x.id] != null && data[x.id] !== '') answers[x.id] = String(data[x.id]);
    const by = { village_chief: '里長陪辦', official: '1999 客服陪辦', family: '家人陪辦' }[helper?.helperType] ?? '陪辦';
    addRow(f, {
      _id: crypto.randomUUID(),
      _t: now(),
      _by: by,
      _via: 'assist',
      _helper: helper ? `${helper.title} ${helper.name}` : null,
      _receipt: caseNo,
      _elder: elder.id,
      ...answers,
    });
    drafts.delete(`${elder.id}:${service.id}`);
  }

  // ───────────────────────── 半路求助

  /** 陪辦 session 建立時帶入長輩已經填好的答案（session key 就是題目 id） */
  function prefill(elderId, service) {
    const d = drafts.get(`${elderId}:${service.id}`);
    if (!d || d.expiresAt < now()) return null;
    return d.answers;
  }

  function saveDraft(elder, f, answers) {
    const clean = cleanAnswers(f, answers ?? {}, { partial: true });
    drafts.set(`${elder.id}:form-${f.id}`, { answers: clean, expiresAt: now() + 30 * 60 * 1000 });
    return clean;
  }

  function ticketView(t, forElder = false) {
    const elder = findUser(t.elderId);
    const helper = t.helperId ? findUser(t.helperId) : null;
    return {
      id: t.id,
      formId: t.formId,
      formTitle: forms.get(t.formId)?.title ?? '',
      serviceId: `form-${t.formId}`,
      status: t.status,
      createdAt: t.createdAt,
      expiresAt: t.expiresAt,
      answered: t.answered,
      total: t.total,
      question: t.question,
      sessionId: t.sessionId ?? null,
      elder: { id: t.elderId, displayName: forElder ? elder.profile.realName : maskName(elder.profile.realName) },
      helper: helper ? publicHelper(helper) : null,
    };
  }

  function publishTicket(t) {
    notify(t.elderId, 'form:ticket', ticketView(t, true));
    for (const h of HELPERS) if (isStaff(h)) notify(h.id, 'form:ticket', ticketView(t));
  }

  function cancelTicketsOf(elderId, formId) {
    for (const t of tickets.values()) {
      if (t.elderId === elderId && t.formId === formId && t.status === 'waiting') {
        t.status = 'cancelled';
        publishTicket(t);
      }
    }
  }

  /**
   * 長輩填到一半按「找人幫我」。
   *   online  → 開一張線上客服求助單，承辦工作台即時跳出，客服按「接手」就發起陪辦
   *   nearby  → 產生一次性配對碼，旁邊的人用台北通掃了就直接陪辦這份表單
   *   trusted → 通知信任的人（家人／里長），對方手機跳出「去幫他」
   * 三種都會先保存目前的答案，陪辦開始時自動帶入。
   */
  function requestHelp(elder, id, { mode, answers, question, helperId } = {}) {
    const f = requireForm(id, { open: true });
    if (f.allowAssist === false) throw forbidden('這份表單不開放陪辦', 'ASSIST_DISABLED');
    const clean = saveDraft(elder, f, answers);
    const serviceId = `form-${f.id}`;
    const answered = Object.keys(clean).length;
    if (mode === 'nearby') {
      return { mode, ...assist.createPairingCode(elder, { serviceId }) };
    }
    if (mode === 'trusted') {
      return { mode, help: assist.requestHelp(elder, { helperId, serviceId }) };
    }
    if (mode !== 'online') throw badRequest('請選擇要找誰幫忙', 'INVALID_MODE');
    for (const t of tickets.values()) {
      if (t.elderId === elder.id && t.formId === id && t.status === 'waiting' && t.expiresAt > now()) {
        t.answered = answered;
        t.question = String(question ?? '').slice(0, 80) || t.question;
        publishTicket(t);
        return { mode, ticket: ticketView(t, true) };
      }
    }
    if (!ticketLimiter.take(elder.id)) throw tooMany('求助次數太多了，請稍後再試', 'HELP_RATE_LIMITED');
    const t = {
      id: crypto.randomUUID(),
      formId: id,
      elderId: elder.id,
      status: 'waiting',
      createdAt: now(),
      expiresAt: now() + 10 * 60 * 1000,
      answered,
      total: f.fields.filter((x) => x.type !== 'file').length,
      question: String(question ?? '').slice(0, 80),
    };
    tickets.set(t.id, t);
    audit.append({
      type: 'help.online_requested',
      actor: { role: 'elder', id: elder.id },
      elderId: elder.id,
      summary: `您在填「${f.title}」時請線上客服幫忙`,
    });
    publishTicket(t);
    return { mode, ticket: ticketView(t, true) };
  }

  function cancelTicket(elder, ticketId) {
    const t = tickets.get(ticketId);
    if (!t || t.elderId !== elder.id) throw notFound('找不到這個求助');
    if (t.status === 'waiting') {
      t.status = 'cancelled';
      publishTicket(t);
    }
    return ticketView(t, true);
  }

  function listTickets(staff) {
    requireStaff(staff);
    return [...tickets.values()]
      .filter((t) => t.status === 'waiting' && t.expiresAt > now())
      .sort((a, b) => a.createdAt - b.createdAt)
      .map((t) => ticketView(t));
  }

  /** 客服接手：對長輩發起陪辦（長輩手機一樣會先看到是誰、要按同意） */
  function takeTicket(staff, ticketId) {
    requireStaff(staff);
    const t = tickets.get(ticketId);
    if (!t || t.status !== 'waiting' || t.expiresAt < now()) throw conflict('這位長輩已經有人接手或取消了', 'TICKET_GONE');
    const elder = findUser(t.elderId);
    const view = assist.requestForElder(staff, { serviceId: `form-${t.formId}`, elderId: elder.id, method: 'online_help' });
    t.status = 'taken';
    t.helperId = staff.id;
    t.sessionId = view.id;
    publishTicket(t);
    return view;
  }

  function sweep() {
    for (const t of tickets.values()) {
      if (t.status === 'waiting' && t.expiresAt < now()) {
        t.status = 'expired';
        publishTicket(t);
      }
    }
    for (const [k, d] of drafts) if (d.expiresAt < now()) drafts.delete(k);
  }

  load();

  return {
    forms,
    publicForm: (id) => publicForm(requireForm(id)),
    getForm: (id) => forms.get(id) ?? null,
    listForms,
    getFormForStaff,
    putForm,
    deleteForm,
    listRows,
    openForElder,
    submitByElder,
    onAssistSubmitted,
    prefill,
    requestHelp,
    cancelTicket,
    listTickets,
    takeTicket,
    sweep,
  };
}
