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
  };
}
