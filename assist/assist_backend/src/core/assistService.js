import crypto from 'node:crypto';
import { findService, allFields } from '../data/services.js';
import { findUser, maskName, publicHelper, ELDERS } from '../data/users.js';
import { badRequest, forbidden, notFound, conflict, tooMany } from './errors.js';
import { createRateLimiter } from './rateLimit.js';
import { helperView, elderView } from './views.js';

const ROLE_ACTOR = (user) => ({ role: user.role, id: user.id });
const SYSTEM = { role: 'system', id: 'system' };
const OPEN = new Set(['pending', 'active']);

/**
 * 協辦 session 狀態機。
 *
 *   pending ──accept──► active ──submit──► completed
 *      │                  │
 *      ├─reject─► rejected└─end / timeout─► ended
 *      ├─cancel─► cancelled
 *      └─timeout► expired
 *
 * 安全不變條件：
 *  1. 協助者端拿到的資料一律經過 helperView()，看不到敏感欄位的值。
 *  2. 敏感欄位必須長輩逐項同意，同一時間只能有一個授權請求。
 *  3. 送出只能由長輩觸發。
 *  4. 以身分資料查找時，比對成功與否對協助者完全不可分辨。
 *  5. 每個動作都寫入 hash-chain 稽核紀錄，紀錄不含個資的值。
 */
export function createAssistService({ config, audit, notify = () => {}, now = () => Date.now() }) {
  const sessions = new Map();
  const pairingCodes = new Map(); // code -> { elderId, expiresAt }
  const elderActiveCode = new Map(); // elderId -> code
  const blocks = new Map(); // elderId -> Set<helperId>
  const rejects = []; // { elderId, helperId, ts }
  const applications = [];
  const identityLimiter = createRateLimiter({ ...config.identityLookupLimit, now });
  const pairingLimiter = createRateLimiter({ ...config.pairingAttemptLimit, now });
  const trustedLimiter = createRateLimiter({ ...config.trustedRequestLimit, now });
  // 信任的人：elderId -> Map<helperId, { since }>
  // 只有長輩本人能新增，而且必須是「已經真的陪辦過一次」的人（第一次一定要掃 QR Code）。
  const trust = new Map();
  for (const [elderId, helperId] of config.demoTrust ?? []) {
    if (findUser(elderId) && findUser(helperId)) trust.set(elderId, new Map([[helperId, { since: now(), demo: true }]]));
  }

  // ───────────────────────── helpers

  const hView = (s) => helperView(s, config);
  const eView = (s) => ({ ...elderView(s), helperTrusted: isTrusted(s.elderId, s.helperId) });

  function isTrusted(elderId, helperId) {
    return trust.get(elderId)?.has(helperId) ?? false;
  }

  function notifyTrust(elderId, helperId) {
    notify(elderId, 'trusted:update', {});
    notify(helperId, 'trusted:update', {});
  }

  function publish(s) {
    notify(s.helperId, 'session:update', hView(s));
    if (s.elderId) notify(s.elderId, 'session:update', eView(s));
  }

  function timeline(s, actor, text) {
    s.timeline.push({ ts: now(), actor, text });
  }

  function touch(s) {
    s.lastActivityAt = now();
  }

  function isBlocked(elderId, helperId) {
    return blocks.get(elderId)?.has(helperId) ?? false;
  }

  function block(elderId, helperId) {
    if (!blocks.has(elderId)) blocks.set(elderId, new Set());
    blocks.get(elderId).add(helperId);
    // 封鎖一定同時取消信任
    if (trust.get(elderId)?.delete(helperId)) notifyTrust(elderId, helperId);
  }

  function hasOpen(elderId, helperId) {
    for (const s of sessions.values()) {
      if (s.elderId === elderId && s.helperId === helperId && OPEN.has(s.status)) return true;
    }
    return false;
  }

  function requireService(serviceId) {
    const service = findService(serviceId);
    if (!service) throw badRequest('找不到這項業務');
    return service;
  }

  function fieldOf(service, key) {
    const f = allFields(service).find((x) => x.key === key);
    if (!f) throw notFound('找不到這個欄位');
    return f;
  }

  function fieldInCurrentStep(s, service, key) {
    const f = fieldOf(service, key);
    if (!service.steps[s.currentStep].fields.some((x) => x.key === key)) {
      throw badRequest('這個欄位不在目前的步驟', 'FIELD_NOT_IN_STEP');
    }
    return f;
  }

  function wipeValues(s) {
    for (const st of Object.values(s.fields)) st.value = null;
  }

  /** 長輩修改的資料：只接受一般文字，去掉前後空白 */
  function cleanValue(value) {
    if (typeof value !== 'string') throw badRequest('請輸入資料內容', 'INVALID_VALUE');
    const v = value.trim();
    if (!v) throw badRequest('資料不能是空白', 'INVALID_VALUE');
    if (v.length > 100) throw badRequest('資料太長了', 'INVALID_VALUE');
    // eslint-disable-next-line no-control-regex
    if (/[\u0000-\u001f\u007f]/.test(v)) throw badRequest('資料含有無法辨識的字元', 'INVALID_VALUE');
    return v;
  }

  /** 這一步的欄位都完成了：自動帶到下一步（長輩自己換頁開啟時） */
  function autoAdvance(s, service) {
    if (!s.elderNav || s.phase !== 'filling' || s.pendingAuth) return;
    if (s.currentStep >= service.steps.length - 1) return;
    const step = service.steps[s.currentStep];
    if (!step.fields.length) return;
    if (!step.fields.every((f) => ['authorized', 'filled'].includes(s.fields[f.key].status))) return;
    s.currentStep += 1;
    s.focusField = null;
    timeline(s, 'system', `這一步完成，自動到第 ${s.currentStep + 1} 步：${service.steps[s.currentStep].title}`);
  }

  function checkPendingLimit(helper) {
    let n = 0;
    for (const s of sessions.values()) if (s.helperId === helper.id && s.status === 'pending') n++;
    if (n >= config.maxPendingPerHelper) {
      throw tooMany('您還有太多請求等待長輩回應，請稍候再試', 'TOO_MANY_PENDING');
    }
  }

  function ownedByHelper(helper, id) {
    const s = sessions.get(id);
    if (!s || s.helperId !== helper.id) throw notFound('找不到這個協辦');
    return s;
  }

  function ownedByElder(elder, id) {
    const s = sessions.get(id);
    // 幽靈請求（elderId 為 null）對任何長輩都不存在
    if (!s || !s.elderId || s.elderId !== elder.id) throw notFound('找不到這個協辦');
    return s;
  }

  function requireActive(s, phase = 'filling') {
    if (s.status !== 'active') throw conflict('這個協辦已經結束', 'SESSION_NOT_ACTIVE');
    if (phase && s.phase !== phase) {
      throw conflict(
        phase === 'filling' ? '長輩正在確認送出，請稍候' : '目前不在確認送出階段',
        'WRONG_PHASE',
      );
    }
  }

  function createSession({ helper, service, elderId, elderLabel, method }) {
    const t = now();
    const fields = {};
    for (const f of allFields(service)) fields[f.key] = { status: 'empty', value: null, requestCount: 0, edited: false };
    const s = {
      id: crypto.randomUUID(),
      serviceId: service.id,
      helperId: helper.id,
      elderId,
      elderLabel,
      method,
      status: 'pending',
      phase: 'filling',
      createdAt: t,
      expiresAt: t + config.pendingRequestTtlMs,
      startedAt: null,
      endedAt: null,
      endReason: null,
      endedBy: null,
      lastActivityAt: t,
      currentStep: 0,
      focusField: null,
      pendingAuth: null,
      // 長輩自己換頁：完成一步後自動到下一步，且長輩可按上一頁／下一頁。陪辦人員可關閉
      elderNav: true,
      // 長輩自己授權：不用等陪辦人員發出請求，長輩可以直接點開欄位同意提供。陪辦人員可關閉
      elderSelfAuth: true,
      caseNo: null,
      undoUntil: null,
      fields,
      timeline: [],
    };
    timeline(s, 'helper', `${helper.title} ${helper.name} 送出協助請求`);
    sessions.set(s.id, s);

    // 協助者看到的稽核摘要：無論比對成功與否都完全相同
    audit.append({
      type: 'request.created',
      actor: ROLE_ACTOR(helper),
      sessionId: s.id,
      helperId: helper.id,
      summary: `送出「${service.title}」協辦請求`,
      detail: { method },
    });

    if (elderId) {
      audit.append({
        type: 'request.delivered',
        actor: SYSTEM,
        sessionId: s.id,
        elderId,
        helperId: helper.id,
        summary: `${helper.title} ${helper.name} 想協助您辦理「${service.title}」`,
        detail: { method },
      });
    }
    publish(s);
    return s;
  }

  // ───────────────────────── 長輩：配對碼

  function createPairingCode(elder) {
    const old = elderActiveCode.get(elder.id);
    if (old) pairingCodes.delete(old);
    let code;
    do {
      code = String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
    } while (pairingCodes.has(code));
    const expiresAt = now() + config.pairingCodeTtlMs;
    pairingCodes.set(code, { elderId: elder.id, expiresAt });
    elderActiveCode.set(elder.id, code);
    audit.append({
      type: 'pairing_code.created',
      actor: ROLE_ACTOR(elder),
      elderId: elder.id,
      summary: '您產生了一組協助配對碼',
    });
    return { code, expiresAt, qrPayload: `townpass-assist:${code}` };
  }

  // ───────────────────────── 協助者：發起請求

  function requestByCode(helper, { serviceId, code }) {
    const service = requireService(serviceId);
    const normalized = String(code ?? '')
      .replace(/^townpass-assist:/, '')
      .trim();
    if (!/^\d{6}$/.test(normalized)) throw badRequest('配對碼是 6 位數字', 'INVALID_CODE_FORMAT');
    if (!pairingLimiter.take(helper.id)) {
      throw tooMany('嘗試次數過多，請 10 分鐘後再試', 'PAIRING_RATE_LIMITED');
    }
    checkPendingLimit(helper);

    const entry = pairingCodes.get(normalized);
    if (!entry || entry.expiresAt < now()) {
      audit.append({
        type: 'lookup.code_failed',
        actor: ROLE_ACTOR(helper),
        helperId: helper.id,
        summary: '輸入的配對碼無效',
      });
      throw notFound('配對碼無效或已過期，請長輩重新產生', 'CODE_NOT_FOUND');
    }
    // 一次性：用過即失效
    pairingCodes.delete(normalized);
    elderActiveCode.delete(entry.elderId);

    if (isBlocked(entry.elderId, helper.id)) {
      throw forbidden('對方目前無法接受您的協助請求', 'BLOCKED');
    }
    if (hasOpen(entry.elderId, helper.id)) {
      throw conflict('您已經對這位長輩送出請求了', 'DUPLICATE_REQUEST');
    }
    const elder = findUser(entry.elderId);
    const s = createSession({
      helper,
      service,
      elderId: elder.id,
      elderLabel: maskName(elder.profile.realName),
      method: 'pairing_code',
    });
    return hView(s);
  }

  function requestByIdentity(helper, { serviceId, name, birthday, idLast4 }) {
    const service = requireService(serviceId);
    const cleanName = String(name ?? '').trim();
    if (cleanName.length < 1 || cleanName.length > 20) throw badRequest('請輸入姓名', 'INVALID_NAME');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(birthday ?? ''))) {
      throw badRequest('出生日期格式為 YYYY-MM-DD', 'INVALID_BIRTHDAY');
    }
    if (!/^\d{4}$/.test(String(idLast4 ?? ''))) {
      throw badRequest('請輸入身分證末四碼數字', 'INVALID_ID_LAST4');
    }
    if (!identityLimiter.take(helper.id)) {
      throw tooMany('查找次數過多，請 10 分鐘後再試，或請長輩出示配對碼', 'LOOKUP_RATE_LIMITED');
    }
    checkPendingLimit(helper);

    const match = ELDERS.find(
      (e) =>
        e.profile.realName === cleanName &&
        e.profile.birthday === birthday &&
        e.profile.idNo.slice(-4) === idLast4,
    );
    const deliverable = Boolean(match) && !isBlocked(match.id, helper.id) && !hasOpen(match.id, helper.id);

    // 內部稽核記錄真實結果；長輩可以在自己的紀錄裡看到「有人用您的資料查找您」
    audit.append({
      type: 'lookup.identity',
      actor: SYSTEM,
      elderId: match?.id ?? null,
      helperId: helper.id,
      summary: deliverable
        ? `${helper.title} ${helper.name} 用您的姓名、生日與身分證末四碼找到您`
        : `${helper.title} ${helper.name} 用您的資料查找您，但已被系統擋下`,
      detail: { matched: Boolean(match), delivered: deliverable },
    });

    // 找不到、被封鎖、重複請求 → 建立「幽靈請求」：
    // 對協助者而言，它跟真的請求一樣顯示「等待長輩回應」，時間到一樣顯示逾時。
    const s = createSession({
      helper,
      service,
      elderId: deliverable ? match.id : null,
      elderLabel: maskName(cleanName),
      method: 'identity',
    });
    return hView(s);
  }

  // ───────────────────────── 信任的人

  /** 長輩把「這次陪辦的人」加為信任的人。必須已經同意過這個人的協助。 */
  function addTrusted(elder, sessionId) {
    const s = ownedByElder(elder, sessionId);
    if (!s.startedAt) throw conflict('要先接受過這個人的協助，才能加為信任的人', 'NOT_ACCEPTED');
    const helper = findUser(s.helperId);
    if (isBlocked(elder.id, helper.id)) throw forbidden('您已封鎖這個人', 'BLOCKED');
    if (!trust.has(elder.id)) trust.set(elder.id, new Map());
    const list = trust.get(elder.id);
    if (list.has(helper.id)) return listTrusted(elder);
    if (list.size >= config.maxTrustedPerElder) {
      throw conflict(`信任的人最多 ${config.maxTrustedPerElder} 位，請先移除一位`, 'TOO_MANY_TRUSTED');
    }
    list.set(helper.id, { since: now() });
    audit.append({
      type: 'trust.added',
      actor: ROLE_ACTOR(elder),
      sessionId: s.id,
      elderId: elder.id,
      helperId: helper.id,
      summary: `您把 ${helper.title} ${helper.name} 加為信任的人，對方之後不用配對碼就能請求陪您辦`,
    });
    notifyTrust(elder.id, helper.id);
    return listTrusted(elder);
  }

  function removeTrusted(elder, helperId) {
    const helper = findUser(helperId);
    if (!helper || !trust.get(elder.id)?.delete(helperId)) throw notFound('這個人不在您信任的名單裡');
    audit.append({
      type: 'trust.removed',
      actor: ROLE_ACTOR(elder),
      elderId: elder.id,
      helperId,
      summary: `您把 ${helper.title} ${helper.name} 從信任的人移除`,
    });
    notifyTrust(elder.id, helperId);
    return listTrusted(elder);
  }

  function listTrusted(elder) {
    return [...(trust.get(elder.id) ?? new Map())].map(([helperId, t]) => ({
      helper: publicHelper(findUser(helperId)),
      since: t.since,
    }));
  }

  /** 協助者看到「信任我的長輩」：只有遮罩後的姓名，不含上線狀態或任何個資。 */
  function listTrustingElders(helper) {
    const out = [];
    for (const [elderId, list] of trust) {
      const t = list.get(helper.id);
      if (!t) continue;
      const elder = findUser(elderId);
      out.push({ elderId, displayName: maskName(elder.profile.realName), since: t.since });
    }
    return out;
  }

  /** 信任的人直接發起請求：不用配對碼，長輩一樣要按同意、一樣逐項授權。 */
  function requestTrusted(helper, { serviceId, elderId }) {
    const service = requireService(serviceId);
    if (!isTrusted(elderId, helper.id) || isBlocked(elderId, helper.id)) {
      throw forbidden('對方沒有把您加為信任的人，請改用配對碼', 'NOT_TRUSTED');
    }
    if (!trustedLimiter.take(helper.id)) {
      throw tooMany('請求次數過多，請 10 分鐘後再試', 'TRUSTED_RATE_LIMITED');
    }
    checkPendingLimit(helper);
    if (hasOpen(elderId, helper.id)) throw conflict('您已經對這位長輩送出請求了', 'DUPLICATE_REQUEST');
    const elder = findUser(elderId);
    const s = createSession({
      helper,
      service,
      elderId,
      elderLabel: maskName(elder.profile.realName),
      method: 'trusted',
    });
    return hView(s);
  }

  // ───────────────────────── 長輩：回應請求

  function respond(elder, id, accept) {
    const s = ownedByElder(elder, id);
    if (s.status !== 'pending') throw conflict('這個請求已經失效', 'REQUEST_NOT_PENDING');
    const helper = findUser(s.helperId);
    const service = findService(s.serviceId);
    touch(s);

    if (accept) {
      for (const other of sessions.values()) {
        if (other.elderId === elder.id && other.status === 'active') {
          throw conflict('您目前已經有一個進行中的協助，請先結束它', 'ALREADY_ACTIVE');
        }
      }
      s.status = 'active';
      s.startedAt = now();
      s.expiresAt = null;
      timeline(s, 'elder', '長輩同意接受協助');
      audit.append({
        type: 'request.accepted',
        actor: ROLE_ACTOR(elder),
        sessionId: s.id,
        elderId: elder.id,
        helperId: helper.id,
        summary: `您同意 ${helper.title} ${helper.name} 協助辦理「${service.title}」`,
      });
    } else {
      s.status = 'rejected';
      s.endedAt = now();
      s.endedBy = 'elder';
      s.endReason = 'rejected';
      timeline(s, 'elder', '長輩婉拒了這次協助');
      audit.append({
        type: 'request.rejected',
        actor: ROLE_ACTOR(elder),
        sessionId: s.id,
        elderId: elder.id,
        helperId: helper.id,
        summary: `您拒絕了 ${helper.title} ${helper.name} 的協助請求`,
      });
      rejects.push({ elderId: elder.id, helperId: helper.id, ts: now() });
      const recent = rejects.filter(
        (r) =>
          r.elderId === elder.id &&
          r.helperId === helper.id &&
          now() - r.ts < config.autoBlockWindowMs,
      ).length;
      if (recent >= config.autoBlockAfterRejects && !isBlocked(elder.id, helper.id)) {
        block(elder.id, helper.id);
        audit.append({
          type: 'helper.auto_blocked',
          actor: SYSTEM,
          sessionId: s.id,
          elderId: elder.id,
          helperId: helper.id,
          summary: `${helper.name} 多次被您拒絕，系統已自動封鎖他的請求`,
        });
      }
    }
    publish(s);
    return eView(s);
  }

  // ───────────────────────── 協助者：導覽

  function gotoStep(helper, id, step) {
    const s = ownedByHelper(helper, id);
    requireActive(s);
    const service = findService(s.serviceId);
    if (!Number.isInteger(step) || step < 0 || step >= service.steps.length) {
      throw badRequest('步驟不存在', 'INVALID_STEP');
    }
    if (s.pendingAuth) throw conflict('請等長輩回應目前的授權請求', 'AUTH_PENDING');
    s.currentStep = step;
    s.focusField = null;
    touch(s);
    timeline(s, 'helper', `帶到第 ${step + 1} 步：${service.steps[step].title}`);
    publish(s);
    return hView(s);
  }

  function setElderNav(helper, id, enabled) {
    const s = ownedByHelper(helper, id);
    requireActive(s, null);
    if (typeof enabled !== 'boolean') throw badRequest('請指定開或關', 'INVALID_VALUE');
    if (s.elderNav === enabled) return hView(s);
    s.elderNav = enabled;
    touch(s);
    timeline(s, 'helper', enabled ? '開啟「長輩自己換頁」' : '關閉「長輩自己換頁」，改由陪辦人員帶著換頁');
    publish(s);
    return hView(s);
  }

  function focusField(helper, id, key) {
    const s = ownedByHelper(helper, id);
    requireActive(s);
    const service = findService(s.serviceId);
    if (key !== null) fieldInCurrentStep(s, service, key);
    s.focusField = key;
    touch(s);
    publish(s);
    return hView(s);
  }

  function requestField(helper, id, key) {
    const s = ownedByHelper(helper, id);
    requireActive(s);
    const service = findService(s.serviceId);
    const f = fieldInCurrentStep(s, service, key);
    if (!f.sensitive) throw badRequest('這個欄位請長輩直接在手機上選擇', 'NOT_SENSITIVE');
    const st = s.fields[key];
    if (st.status === 'authorized') throw conflict('長輩已經同意提供這項資料', 'ALREADY_AUTHORIZED');
    if (s.pendingAuth) throw conflict('請等長輩回應目前的授權請求', 'AUTH_PENDING');
    if (st.requestCount >= config.maxFieldRequests) {
      throw tooMany('這個欄位已經詢問太多次了。請尊重長輩的決定，或改用臨櫃辦理', 'FIELD_REQUEST_LIMIT');
    }
    st.status = 'requested';
    st.requestCount += 1;
    s.pendingAuth = key;
    s.focusField = key;
    touch(s);
    timeline(s, 'helper', `請長輩授權「${f.label}」`);
    audit.append({
      type: 'field.requested',
      actor: ROLE_ACTOR(helper),
      sessionId: s.id,
      elderId: s.elderId,
      helperId: helper.id,
      summary: `${helper.name} 請您提供「${f.label}」`,
      helperSummary: `請長輩授權提供「${f.label}」`,
      detail: { field: key },
    });
    publish(s);
    return hView(s);
  }

  // ───────────────────────── 長輩：換頁

  function elderStep(elder, id, step) {
    const s = ownedByElder(elder, id);
    requireActive(s);
    const service = findService(s.serviceId);
    if (!s.elderNav) throw forbidden('陪辦人員會帶您到下一步', 'ELDER_NAV_OFF');
    if (!Number.isInteger(step) || step < 0 || step >= service.steps.length || Math.abs(step - s.currentStep) !== 1) {
      throw badRequest('步驟不存在', 'INVALID_STEP');
    }
    if (s.pendingAuth) throw conflict('請先回答畫面上的問題', 'AUTH_PENDING');
    s.currentStep = step;
    s.focusField = null;
    touch(s);
    timeline(s, 'elder', `長輩自己翻到第 ${step + 1} 步：${service.steps[step].title}`);
    publish(s);
    return eView(s);
  }

  // ───────────────────────── 長輩：授權與填寫

  /** 長輩不等陪辦人員請求，自己點開欄位同意提供（「長輩自己授權」開啟時） */
  function selfAuthorizeField(elder, id, key, value) {
    const s = ownedByElder(elder, id);
    requireActive(s);
    const service = findService(s.serviceId);
    const f = fieldInCurrentStep(s, service, key);
    if (s.pendingAuth === key) return authorizeField(elder, id, key, true, value);
    if (!s.elderSelfAuth) throw forbidden('請等陪辦人員請您提供這項資料', 'ELDER_SELF_AUTH_OFF');
    if (!f.sensitive) throw badRequest('這個欄位請直接選擇', 'NOT_SENSITIVE');
    if (s.pendingAuth) throw conflict('請先回答畫面上的問題', 'AUTH_PENDING');
    if (s.fields[key].status === 'authorized') throw conflict('您已經同意提供這項資料了', 'ALREADY_AUTHORIZED');
    return authorizeField(elder, id, key, true, value, { self: true });
  }

  function setElderSelfAuth(helper, id, enabled) {
    const s = ownedByHelper(helper, id);
    requireActive(s, null);
    if (typeof enabled !== 'boolean') throw badRequest('請指定開或關', 'INVALID_VALUE');
    if (s.elderSelfAuth === enabled) return hView(s);
    s.elderSelfAuth = enabled;
    touch(s);
    timeline(s, 'helper', enabled ? '開啟「長輩自己授權」' : '關閉「長輩自己授權」，改由陪辦人員逐項請長輩確認');
    publish(s);
    return hView(s);
  }

  function authorizeField(elder, id, key, approve, value, { self = false } = {}) {
    const s = ownedByElder(elder, id);
    requireActive(s);
    const service = findService(s.serviceId);
    const f = fieldOf(service, key);
    if (!self && s.pendingAuth !== key) throw conflict('這個授權請求已經失效', 'AUTH_NOT_PENDING');
    const st = s.fields[key];
    if (approve) {
      const original = elder.profile[f.profileKey];
      // 長輩可以在授權時改成正確的內容（例如帳號裡的地址是舊的）
      const v = value === undefined || value === null ? original : cleanValue(value);
      st.status = 'authorized';
      st.value = v;
      st.edited = v !== original;
    } else {
      st.status = 'denied';
      st.value = null;
    }
    s.pendingAuth = null;
    if (s.focusField === key) s.focusField = null;
    touch(s);
    timeline(
      s,
      'elder',
      approve
        ? `長輩${self ? '自己' : ''}同意提供「${f.label}」${st.edited ? '（有修改內容）' : ''}`
        : `長輩不同意提供「${f.label}」`,
    );
    audit.append({
      type: approve ? 'field.authorized' : 'field.denied',
      actor: ROLE_ACTOR(elder),
      sessionId: s.id,
      elderId: elder.id,
      helperId: s.helperId,
      summary: approve
        ? `您同意提供「${f.label}」給「${service.title}」（${service.agency}）`
        : `您不同意提供「${f.label}」`,
      detail: { field: key },
    });
    if (approve) autoAdvance(s, service);
    publish(s);
    return eView(s);
  }

  function revokeField(elder, id, key) {
    const s = ownedByElder(elder, id);
    requireActive(s);
    const service = findService(s.serviceId);
    const f = fieldOf(service, key);
    const st = s.fields[key];
    if (!f.sensitive || st.status !== 'authorized') throw badRequest('這項資料沒有被授權', 'NOT_AUTHORIZED');
    st.status = 'empty';
    st.value = null;
    st.edited = false;
    touch(s);
    timeline(s, 'elder', `長輩撤回「${f.label}」`);
    audit.append({
      type: 'field.revoked',
      actor: ROLE_ACTOR(elder),
      sessionId: s.id,
      elderId: elder.id,
      helperId: s.helperId,
      summary: `您撤回了「${f.label}」`,
      detail: { field: key },
    });
    publish(s);
    return eView(s);
  }

  /** 已提供的資料，長輩可以再修改（填寫中或確認送出畫面都可以） */
  function editField(elder, id, key, value) {
    const s = ownedByElder(elder, id);
    requireActive(s, null);
    const service = findService(s.serviceId);
    const f = fieldOf(service, key);
    const st = s.fields[key];
    if (!f.sensitive || st.status !== 'authorized') throw badRequest('這項資料還沒有提供', 'NOT_AUTHORIZED');
    const v = cleanValue(value);
    if (v === st.value) return eView(s);
    st.value = v;
    st.edited = v !== elder.profile[f.profileKey];
    touch(s);
    timeline(s, 'elder', `長輩修改了「${f.label}」`);
    audit.append({
      type: 'field.edited',
      actor: ROLE_ACTOR(elder),
      sessionId: s.id,
      elderId: elder.id,
      helperId: s.helperId,
      summary: `您修改了「${f.label}」`,
      helperSummary: `長輩修改了「${f.label}」`,
      detail: { field: key },
    });
    publish(s);
    return eView(s);
  }

  function inputChoice(elder, id, key, value) {
    const s = ownedByElder(elder, id);
    requireActive(s);
    const service = findService(s.serviceId);
    const f = fieldInCurrentStep(s, service, key);
    if (f.type !== 'choice') throw badRequest('這個欄位需要授權，不能直接填寫', 'NOT_CHOICE');
    const option = f.options.find((o) => o.value === value);
    if (!option) throw badRequest('沒有這個選項', 'INVALID_OPTION');
    s.fields[key].status = 'filled';
    s.fields[key].value = value;
    touch(s);
    timeline(s, 'elder', `長輩選擇「${f.label}：${option.label}」`);
    audit.append({
      type: 'field.filled',
      actor: ROLE_ACTOR(elder),
      sessionId: s.id,
      elderId: elder.id,
      helperId: s.helperId,
      summary: `您選擇了「${f.label}：${option.label}」`,
      detail: { field: key, value },
    });
    autoAdvance(s, service);
    publish(s);
    return eView(s);
  }

  // ───────────────────────── 送出

  function requestSubmit(helper, id) {
    const s = ownedByHelper(helper, id);
    requireActive(s);
    if (s.pendingAuth) throw conflict('請等長輩回應目前的授權請求', 'AUTH_PENDING');
    const service = findService(s.serviceId);
    const missing = allFields(service).filter(
      (f) => f.required && !['authorized', 'filled'].includes(s.fields[f.key].status),
    );
    if (missing.length) {
      throw badRequest(`還有欄位沒完成：${missing.map((f) => f.label).join('、')}`, 'INCOMPLETE');
    }
    s.phase = 'reviewing';
    s.currentStep = service.steps.length - 1;
    s.focusField = null;
    touch(s);
    timeline(s, 'helper', '請長輩確認並送出');
    publish(s);
    return hView(s);
  }

  function submit(elder, id, confirm) {
    const s = ownedByElder(elder, id);
    requireActive(s, 'reviewing');
    const service = findService(s.serviceId);
    touch(s);
    if (!confirm) {
      s.phase = 'filling';
      timeline(s, 'elder', '長輩想再確認一下資料');
      publish(s);
      return eView(s);
    }
    const t = new Date(now());
    const ymd = `${t.getFullYear()}${String(t.getMonth() + 1).padStart(2, '0')}${String(t.getDate()).padStart(2, '0')}`;
    s.caseNo = `TP${ymd}-${crypto.randomInt(0, 100000).toString().padStart(5, '0')}`;
    const data = {};
    for (const [k, st] of Object.entries(s.fields)) data[k] = st.value;
    applications.push({
      caseNo: s.caseNo,
      serviceId: s.serviceId,
      serviceTitle: service.title,
      agency: service.agency,
      elderId: elder.id,
      helperId: s.helperId,
      sessionId: s.id,
      submittedAt: now(),
      // 申辦資料進入受理機關系統；協辦 session 本身不再保留個資
      data,
    });
    s.status = 'completed';
    s.endedAt = now();
    s.endedBy = 'elder';
    s.endReason = 'submitted';
    s.undoUntil = now() + config.undoWindowMs;
    wipeValues(s);
    timeline(s, 'elder', `長輩已送出申請，案件編號 ${s.caseNo}`);
    audit.append({
      type: 'application.submitted',
      actor: ROLE_ACTOR(elder),
      sessionId: s.id,
      elderId: elder.id,
      helperId: s.helperId,
      summary: `您送出了「${service.title}」，案件編號 ${s.caseNo}`,
      detail: { caseNo: s.caseNo },
    });
    publish(s);
    return eView(s);
  }

  /** 送出後短時間內可撤回：收回案件，資料回到確認畫面。 */
  function undoSubmit(elder, id) {
    const s = ownedByElder(elder, id);
    if (s.status !== 'completed' || !s.undoUntil) throw conflict('這個申請不能撤回', 'NOT_UNDOABLE');
    if (now() > s.undoUntil) throw conflict('已經超過可以撤回的時間', 'TOO_LATE');
    const idx = applications.findIndex((a) => a.caseNo === s.caseNo && a.elderId === elder.id);
    if (idx < 0) throw conflict('這個申請不能撤回', 'NOT_UNDOABLE');
    const [app] = applications.splice(idx, 1);
    for (const [k, v] of Object.entries(app.data)) s.fields[k].value = v;
    const caseNo = s.caseNo;
    s.status = 'active';
    s.phase = 'reviewing';
    s.caseNo = null;
    s.undoUntil = null;
    s.endedAt = null;
    s.endedBy = null;
    s.endReason = null;
    touch(s);
    timeline(s, 'elder', '長輩撤回了送出，回到確認畫面');
    audit.append({
      type: 'application.undone',
      actor: ROLE_ACTOR(elder),
      sessionId: s.id,
      elderId: elder.id,
      helperId: s.helperId,
      summary: `您撤回了案件 ${caseNo}`,
      helperSummary: null,
      detail: { caseNo },
    });
    publish(s);
    return eView(s);
  }

  // ───────────────────────── 結束 / 封鎖

  function end(user, id, reason = 'manual') {
    const s = user.role === 'helper' ? ownedByHelper(user, id) : ownedByElder(user, id);
    if (!OPEN.has(s.status)) throw conflict('這個協辦已經結束', 'SESSION_NOT_ACTIVE');
    s.status = s.status === 'pending' ? 'cancelled' : 'ended';
    s.endedAt = now();
    s.endedBy = user.role;
    s.endReason = reason;
    s.pendingAuth = null;
    wipeValues(s);
    timeline(s, user.role, user.role === 'elder' ? '長輩結束了協助' : '協助者結束了協助');
    audit.append({
      type: 'session.ended',
      actor: ROLE_ACTOR(user),
      sessionId: s.id,
      elderId: s.elderId,
      helperId: s.helperId,
      summary: user.role === 'elder' ? '您結束了這次協助' : '協助者結束了這次協助',
      helperSummary: user.role === 'helper' ? '您結束了這次協助' : null,
      detail: { reason },
    });
    publish(s);
    return user.role === 'helper' ? hView(s) : eView(s);
  }

  function blockHelper(elder, id) {
    const s = ownedByElder(elder, id);
    const helper = findUser(s.helperId);
    block(elder.id, helper.id);
    audit.append({
      type: 'helper.blocked',
      actor: ROLE_ACTOR(elder),
      sessionId: s.id,
      elderId: elder.id,
      helperId: helper.id,
      summary: `您封鎖並回報了 ${helper.title} ${helper.name}`,
    });
    if (OPEN.has(s.status)) {
      if (s.status === 'pending') {
        s.status = 'rejected';
        s.endedAt = now();
        s.endedBy = 'elder';
        s.endReason = 'blocked';
        timeline(s, 'elder', '長輩婉拒了這次協助');
        publish(s);
      } else {
        end(elder, id, 'blocked');
      }
    }
    return eView(sessions.get(id));
  }

  // ───────────────────────── 查詢

  const byNewest = (a, b) => b.createdAt - a.createdAt;

  function getSession(user, id) {
    return user.role === 'helper' ? hView(ownedByHelper(user, id)) : eView(ownedByElder(user, id));
  }

  function listForHelper(helper) {
    return [...sessions.values()].filter((s) => s.helperId === helper.id).sort(byNewest).map(hView);
  }

  function listForElder(elder) {
    return [...sessions.values()].filter((s) => s.elderId === elder.id).sort(byNewest).map(eView);
  }

  function elderAudit(elder) {
    return audit
      .forElder(elder.id)
      .map(({ seq, ts, type, summary, sessionId, actor, hash }) => ({
        seq,
        ts,
        type,
        summary,
        sessionId,
        actorRole: actor.role,
        hash,
      }))
      .reverse();
  }

  function elderApplications(elder) {
    return applications
      .filter((a) => a.elderId === elder.id)
      .map(({ data, ...rest }) => ({ ...rest, helper: findUser(rest.helperId)?.name ?? null }))
      .reverse();
  }

  // ───────────────────────── 逾時清理

  function sweep() {
    const t = now();
    for (const [code, entry] of pairingCodes) {
      if (entry.expiresAt < t) {
        pairingCodes.delete(code);
        if (elderActiveCode.get(entry.elderId) === code) elderActiveCode.delete(entry.elderId);
      }
    }
    for (const s of sessions.values()) {
      if (s.status === 'pending' && t >= s.expiresAt) {
        s.status = 'expired';
        s.endedAt = t;
        s.endedBy = 'system';
        s.endReason = 'timeout';
        timeline(s, 'system', '等待逾時，請求已失效');
        if (s.elderId) {
          audit.append({
            type: 'request.expired',
            actor: SYSTEM,
            sessionId: s.id,
            elderId: s.elderId,
            helperId: s.helperId,
            summary: '協助請求等待逾時，已自動失效',
          });
        }
        publish(s);
      } else if (
        s.status === 'active' &&
        (t - s.lastActivityAt >= config.sessionIdleTtlMs || t - s.startedAt >= config.sessionMaxTtlMs)
      ) {
        s.status = 'ended';
        s.endedAt = t;
        s.endedBy = 'system';
        s.endReason = 'timeout';
        s.pendingAuth = null;
        wipeValues(s);
        timeline(s, 'system', '太久沒有動作，系統已自動結束協助');
        audit.append({
          type: 'session.timeout',
          actor: SYSTEM,
          sessionId: s.id,
          elderId: s.elderId,
          helperId: s.helperId,
          summary: '太久沒有動作，系統已自動結束協助',
        });
        publish(s);
      }
    }
  }

  return {
    createPairingCode,
    requestByCode,
    requestByIdentity,
    requestTrusted,
    addTrusted,
    removeTrusted,
    listTrusted,
    listTrustingElders,
    respond,
    gotoStep,
    setElderNav,
    elderStep,
    editField,
    focusField,
    requestField,
    authorizeField: (elder, id, key, approve, value) => authorizeField(elder, id, key, approve, value),
    selfAuthorizeField,
    setElderSelfAuth,
    revokeField,
    inputChoice,
    requestSubmit,
    submit,
    undoSubmit,
    end,
    blockHelper,
    getSession,
    listForHelper,
    listForElder,
    elderAudit,
    elderApplications,
    helperAudit: (helper) => audit.forHelper(helper.id).reverse(),
    sweep,
    _sessions: sessions,
  };
}
