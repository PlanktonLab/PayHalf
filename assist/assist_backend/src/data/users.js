import fs from 'node:fs';
import path from 'node:path';

/**
 * Demo 用模擬帳號。正式版：長輩與家人親友來自台北通實名帳號，
 * 里長來自民政局里長名冊，客服來自市府內部帳號系統。
 * 身分證字號皆為通過檢查碼的虛構號碼。
 */
export const HELPERS = [
  {
    id: 'helper-chief',
    role: 'helper',
    helperType: 'village_chief',
    name: '陳美玲',
    title: '里長',
    org: '臺北市中山區正得里辦公處',
    verified: true,
  },
  {
    id: 'helper-family',
    role: 'helper',
    helperType: 'family',
    name: '王小華',
    title: '家人／親友',
    org: null,
    verified: false,
  },
  {
    id: 'helper-1999',
    role: 'helper',
    helperType: 'official',
    name: '林志明',
    title: '1999 市民熱線客服',
    org: '臺北市政府 1999 市民當家熱線',
    verified: true,
  },
];

export const ELDERS = [
  {
    id: 'elder-wang',
    role: 'elder',
    verifyLevel: 3,
    // 對應台北通 App 模擬帳號（TownPass/assets/mock_data/account.json）的 id
    townpassAccountId: '7f3562f4-bb3f-4ec7-89b9-da3b4b5ff250',
    // 台北通帳號名稱（好友列表直接顯示這個，不用另外取暱稱）
    account: 'wz7786',
    profile: {
      realName: '王大明',
      birthday: '1948-03-15',
      idNo: 'A102837499',
      phone: '0912-345-678',
      residentAddress: '臺北市中山區吉林路 69 號 4 樓',
    },
  },
  {
    id: 'elder-lee',
    role: 'elder',
    verifyLevel: 3,
    account: 'lee1102',
    profile: {
      realName: '李秀英',
      birthday: '1951-11-02',
      idNo: 'F220481634',
      phone: '0928-765-432',
      residentAddress: '臺北市大安區龍坡里和平東路二段 98 號 5 樓',
    },
  },
];

// ───────────────────────── 介面語言（使用者偏好）
// 正式版在註冊台北通帳號時填寫；demo 在 App 左上角「切換身分」面板切換。
// 存在 var/prefs.json，換手機登入也會套用同一個語言。

/** App 支援的介面語言：繁中、英文，以及在台外籍移工常用的越南文、印尼文、泰文，加上日文、韓文 */
export const LANGS = ['zh-TW', 'en', 'vi', 'id', 'th', 'ja', 'ko'];

const langs = new Map();
let prefsFile = null;

export function initPrefs(dataDir) {
  langs.clear();
  prefsFile = dataDir ? path.join(dataDir, 'prefs.json') : null;
  if (!prefsFile || !fs.existsSync(prefsFile)) return;
  try {
    const saved = JSON.parse(fs.readFileSync(prefsFile, 'utf8'));
    for (const [id, lang] of Object.entries(saved.langs ?? {})) if (LANGS.includes(lang)) langs.set(id, lang);
  } catch (e) {
    console.error('[prefs] 讀取失敗', e.message);
  }
}

export function userLang(id) {
  return langs.get(id) ?? 'zh-TW';
}

export function setUserLang(id, lang) {
  if (!LANGS.includes(lang)) return false;
  langs.set(id, lang);
  if (prefsFile) {
    try {
      fs.mkdirSync(path.dirname(prefsFile), { recursive: true });
      fs.writeFileSync(prefsFile, JSON.stringify({ langs: Object.fromEntries(langs) }));
    } catch (e) {
      console.error('[prefs] 保存失敗', e.message);
    }
  }
  return true;
}

export function findElderByTownpassAccount(accountId) {
  return ELDERS.find((e) => e.townpassAccountId && e.townpassAccountId === accountId) ?? null;
}

export function findUser(id) {
  return HELPERS.find((u) => u.id === id) ?? ELDERS.find((u) => u.id === id) ?? null;
}

/** 對外可公開的身分資訊（不含任何個資）。 */
export function publicHelper(h) {
  return {
    id: h.id,
    name: h.name,
    title: h.title,
    helperType: h.helperType,
    org: h.org,
    verified: h.verified,
    lang: langs.get(h.id) ?? null,
  };
}

export function maskName(name) {
  const chars = [...(name ?? '').trim()];
  if (chars.length === 0) return '';
  if (chars.length === 1) return chars[0];
  if (chars.length === 2) return `${chars[0]}○`;
  return chars[0] + '○'.repeat(chars.length - 2) + chars[chars.length - 1];
}

/** 長輩本人看自己帳號時使用。 */
export function publicElder(e) {
  return {
    id: e.id,
    name: e.profile.realName,
    verifyLevel: e.verifyLevel,
    lang: langs.get(e.id) ?? null,
  };
}
