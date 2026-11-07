/**
 * 承辦人用表單後台做出來的「靜態表單」：每份表單有固定網址與 QR Code，
 * 長輩用台北通掃描後自己填；不會填時可以找人介入陪辦。
 *
 * 表單欄位沿用網頁後台編輯器的格式：{ id, type, label, hint, required, options, profile? }
 * 為了讓陪辦也能用同一份表單，這裡把表單轉成陪辦 session 用的「業務」定義（formToService）。
 */

/** 長輩實名帳號裡可以一鍵帶入的個資 */
export const PROFILE_KEYS = ['realName', 'birthday', 'idNo', 'phone', 'residentAddress'];
const PROFILE_LABEL = { realName: '姓名', birthday: '出生日期', idNo: '身分證字號', phone: '電話', residentAddress: '地址' };

/** 判斷題目是不是在問長輩自己的個資（可由實名帳號帶入，且要長輩同意才提供） */
export function profileKeyOf(f) {
  if (f.profile && PROFILE_KEYS.includes(f.profile)) return f.profile;
  if (f.profile === null) return null;
  const l = String(f.label ?? '');
  switch (f.type) {
    case 'idno':
      return 'idNo';
    case 'phone':
      return 'phone';
    case 'address':
      return /位置|地點|哪裡壞/.test(l) ? null : 'residentAddress';
    case 'date':
      return /出生|生日/.test(l) ? 'birthday' : null;
    case 'text':
      return /姓名|名字/.test(l) ? 'realName' : null;
    default:
      return null;
  }
}

const OPTION_TYPES = new Set(['radio', 'select', 'checkbox']);
export const FIELD_TYPES = new Set([
  'radio', 'checkbox', 'select', 'text', 'textarea', 'date', 'number', 'phone', 'idno', 'address', 'file', 'consent',
]);

let seq = 0;
const q = (type, label, hint = '', required = true, options = []) => ({
  id: `q${++seq}`,
  type,
  label,
  hint,
  required,
  options,
});

/** Demo 預先發布的表單（固定 id，QR Code 海報印出來之後重新部署也不會失效） */
export function seedForms(now) {
  seq = 0;
  const t = now();
  const list = [
    {
      id: 'chongyang',
      title: '重陽敬老餐會報名',
      dept: '臺北市中山區正得里辦公處',
      desc: '11 月 20 日中午 12 點，在正得里活動中心，免費參加。名額 80 位，額滿為止。',
      fields: [
        q('text', '你的姓名', '請填身分證上的名字'),
        q('phone', '你的聯絡電話', '活動有變動時通知你'),
        q('radio', '你想吃葷食還是素食', '', true, ['葷食', '素食']),
        q('radio', '需要有人去接你嗎', '', true, ['需要接送', '我自己過去']),
        q('number', '一共幾個人參加', '包含你自己，最多 2 位'),
        q('consent', '我同意里辦公處用這些資料辦理報名'),
      ],
      deadline: '2026-11-18',
      allowAssist: true,
      once: true,
      doneMsg: '報名好了！活動前一天里辦公處會再打電話提醒你。',
      status: 'open',
      createdAt: t - 5 * 86400000,
      updated: t - 5 * 86400000,
    },
    {
      id: 'flu-shot',
      title: '長者流感疫苗預約',
      dept: '臺北市中山區健康服務中心',
      desc: '65 歲以上免費接種。預約好時段，到時候帶健保卡來就可以。',
      fields: [
        q('text', '你的姓名', '請填身分證上的名字'),
        q('idno', '你的身分證字號', '英文字母加 9 個數字'),
        q('date', '你的出生日期'),
        q('phone', '你的聯絡電話'),
        q('radio', '想在哪個時段打', '', true, ['11/15（六）上午', '11/15（六）下午', '11/22（六）上午']),
        q('radio', '以前打疫苗有沒有不舒服', '', true, ['沒有', '有，發燒或過敏', '不記得']),
        q('textarea', '還有什麼想告訴醫護人員的', '例如正在吃的藥', false),
        q('consent', '我確認上面填的資料都正確'),
      ],
      deadline: '2026-11-20',
      allowAssist: true,
      once: true,
      doneMsg: '預約好了！當天請帶健保卡，提早 10 分鐘到。',
      status: 'open',
      createdAt: t - 9 * 86400000,
      updated: t - 9 * 86400000,
    },
    {
      id: 'lamp',
      title: '路燈與道路損壞通報',
      dept: '臺北市政府工務局',
      desc: '發現路燈不亮或馬路破洞，請在這裡告訴我們。',
      fields: [
        q('radio', '哪裡壞了', '', true, ['路燈不亮', '馬路有洞', '人行道破損', '其他']),
        q('address', '在哪個位置', '寫路名和附近的店家也可以'),
        q('phone', '你的電話', '處理好之後通知你', false),
      ],
      deadline: '',
      allowAssist: true,
      once: false,
      doneMsg: '收到了，謝謝你！我們會盡快派人去看。',
      status: 'open',
      createdAt: t - 20 * 86400000,
      updated: t - 20 * 86400000,
    },
  ];
  // 題目代號每份表單各自從 q1 開始
  for (const f of list) f.fields.forEach((x, i) => (x.id = `q${i + 1}`));
  return list;
}

/** 把表單轉成陪辦 session 用的業務定義（id 一律加上 form- 前綴，避免和既有業務撞名） */
export function formToService(form) {
  const service = {
    id: `form-${form.id}`,
    formId: form.id,
    title: form.title || '未命名表單',
    category: '線上表單',
    summary: form.desc || '',
    agency: form.dept || '臺北市政府',
    legalBasis: '個人資料保護法第 15 條：執行法定職務必要範圍內（Demo 示意）',
    retention: '依各局處表單保存規定（Demo 示意）',
    estMinutes: Math.max(2, Math.ceil(form.fields.length * 0.8)),
    steps: [],
  };
  const profile = [];
  const others = [];
  for (const f of form.fields) {
    if (f.type === 'file') continue; // 照片／檔案陪辦時先略過，之後可到現場補件
    const pk = profileKeyOf(f);
    if (pk) {
      profile.push({
        key: f.id,
        label: f.label || PROFILE_LABEL[pk],
        type: 'profile',
        profileKey: pk,
        required: f.required !== false,
        riskLevel: pk === 'idNo' ? 'high' : 'medium',
        purpose: f.hint || `${service.agency}辦理「${service.title}」需要`,
        risks: pk === 'idNo' ? ['身分證字號可以拿來辦很多事，請確認是您自己要申請'] : [],
      });
    } else if (OPTION_TYPES.has(f.type) || f.type === 'consent') {
      const opts = f.type === 'consent' ? ['我同意'] : f.options;
      others.push({
        key: f.id,
        label: f.label,
        type: 'choice',
        multi: f.type === 'checkbox',
        required: f.required !== false,
        options: opts.map((o) => ({ value: o, label: o })),
      });
    } else {
      others.push({ key: f.id, label: f.label, type: 'text', inputType: f.type, hint: f.hint, required: f.required !== false });
    }
  }
  service.steps.push({
    id: 'intro',
    title: '表單說明',
    elderGuide: form.desc || `這是「${service.title}」。`,
    helperScript: '先跟長輩說明這份表單要做什麼，確認長輩想辦再按「下一步」。',
    fields: [],
  });
  if (profile.length) {
    service.steps.push({
      id: 'profile',
      title: '基本資料',
      elderGuide: '這些資料可以從您的台北通帳號帶入，您同意才會提供。',
      helperScript: '請長輩自己按同意，不要替長輩按。',
      fields: profile,
    });
  }
  for (let i = 0; i < others.length; i += 2) {
    const chunk = others.slice(i, i + 2);
    service.steps.push({
      id: `q${i / 2 + 1}`,
      title: chunk[0].label.length > 12 ? `問題 ${i + 1}${chunk.length > 1 ? `–${i + 2}` : ''}` : chunk[0].label,
      elderGuide: '請您自己在手機上回答。',
      helperScript: '把題目念給長輩聽，讓長輩自己在手機上回答。',
      fields: chunk,
    });
  }
  service.steps.push({
    id: 'review',
    title: '確認送出',
    elderGuide: '請您看一下資料對不對。確認沒問題，由您自己按「確認送出」。',
    helperScript: '按「請長輩確認送出」，送出鍵只有長輩能按。',
    fields: [],
  });
  for (const step of service.steps) {
    for (const field of step.fields) {
      field.sensitive = field.type === 'profile';
      if (field.sensitive) {
        field.recipient = service.agency;
        field.retention = service.retention;
        field.legalBasis = service.legalBasis;
      }
    }
  }
  return service;
}

// ───────────────────────── Demo 示意回覆

const SURNAMES = '陳林黃張李王吳劉蔡楊許鄭謝郭洪曾邱廖賴周';
const GIVEN = ['美玉', '金龍', '秀琴', '文雄', '麗華', '志明', '淑芬', '建國', '玉蘭', '正雄', '阿珠', '春嬌', '進財', '月娥', '振興'];
const ROADS = ['吉林路', '林森北路', '民生東路', '中山北路', '松江路', '長安東路', '錦州街'];
const BY = [
  ['本人（台北通）', 0.55],
  ['家人陪辦', 0.2],
  ['里長陪辦', 0.13],
  ['1999 客服陪辦', 0.12],
];

/** 每份種子表單產生固定的示意回覆，讓後台一打開就有東西看（標記 _sample，可隱藏） */
export function sampleRows(form, now) {
  let h = 0;
  for (const c of form.id) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  const r = () => {
    h = (h * 1103515245 + 12345) >>> 0;
    return (h >>> 8) / 16777216;
  };
  const pick = (a) => a[Math.floor(r() * a.length)];
  const n = { chongyang: 37, 'flu-shot': 52, lamp: 14 }[form.id] ?? 0;
  const rows = [];
  for (let i = 0; i < n; i++) {
    const name = pick(SURNAMES) + pick(GIVEN);
    let x = r();
    let by = BY[0][0];
    for (const [k, p] of BY) {
      if (x < p) {
        by = k;
        break;
      }
      x -= p;
    }
    const row = {
      _id: `sample-${form.id}-${i}`,
      _t: now() - Math.floor(r() * 5 * 86400000) - 600000,
      _by: by,
      _via: by.startsWith('本人') ? 'self' : 'assist',
      _receipt: `F2026110${Math.floor(r() * 7) + 1}-${String(Math.floor(r() * 100000)).padStart(5, '0')}`,
      _sample: true,
    };
    for (const f of form.fields) {
      if (!f.required && r() < 0.5) continue;
      const pk = profileKeyOf(f);
      let v;
      if (pk === 'realName') v = name;
      else if (pk === 'idNo') v = `${pick('AFH')}${r() < 0.5 ? 1 : 2}${String(Math.floor(r() * 1e8)).padStart(8, '0')}`;
      else if (pk === 'phone') v = `09${String(Math.floor(r() * 1e2)).padStart(2, '0')}-${String(Math.floor(r() * 1e3)).padStart(3, '0')}-${String(Math.floor(r() * 1e3)).padStart(3, '0')}`;
      else if (pk === 'birthday') v = `19${40 + Math.floor(r() * 21)}-${String(1 + Math.floor(r() * 12)).padStart(2, '0')}-${String(1 + Math.floor(r() * 28)).padStart(2, '0')}`;
      else if (pk === 'residentAddress' || f.type === 'address') v = `臺北市中山區${pick(ROADS)}${1 + Math.floor(r() * 200)} 號`;
      else if (f.type === 'radio' || f.type === 'select') v = r() < 0.6 ? f.options[0] : pick(f.options);
      else if (f.type === 'checkbox') v = f.options.filter(() => r() < 0.5).join('、') || f.options[0];
      else if (f.type === 'consent') v = '我同意';
      else if (f.type === 'number') v = String(r() < 0.7 ? 1 : 2);
      else if (f.type === 'textarea') v = pick(['有高血壓，每天吃藥', '膝蓋不好，希望不用排太久', '沒有', '想跟太太一起打']);
      else v = '';
      if (v) row[f.id] = v;
    }
    rows.push(row);
  }
  return rows.sort((a, b) => b._t - a._t);
}
