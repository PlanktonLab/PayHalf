import crypto from 'node:crypto';

/**
 * 預設設定。測試或 demo 可在 createAssistServer(overrides) 時覆寫。
 * 所有時間單位為毫秒。
 */
export function buildConfig(overrides = {}) {
  return {
    port: Number(process.env.PORT ?? 3000),
    // 部署在 nginx 後面時設 HOST=127.0.0.1，只讓本機的 nginx 連得到
    host: process.env.HOST || undefined,
    // 正式環境必須由環境變數提供，這裡每次啟動隨機產生，重啟後舊 token 全部失效。
    tokenSecret: process.env.TOKEN_SECRET ?? crypto.randomBytes(32).toString('hex'),
    tokenTtlMs: 8 * 60 * 60 * 1000,
    pairingCodeTtlMs: 2 * 60 * 1000,
    pendingRequestTtlMs: Number(process.env.PENDING_TTL_MS ?? 3 * 60 * 1000),
    sessionIdleTtlMs: Number(process.env.SESSION_IDLE_TTL_MS ?? 30 * 60 * 1000),
    sessionMaxTtlMs: 60 * 60 * 1000,
    sweepIntervalMs: 5 * 1000,
    // 以「姓名＋生日＋身分證末四碼」查找長輩的次數上限（每位協助者）
    identityLookupLimit: { max: 5, windowMs: 10 * 60 * 1000 },
    // 輸入配對碼的嘗試上限（每位協助者）
    pairingAttemptLimit: { max: 10, windowMs: 10 * 60 * 1000 },
    // 每位協助者同時可等待回應的請求數
    maxPendingPerHelper: 3,
    // 同一欄位最多可請求授權幾次（避免一直跳窗施壓長輩）
    maxFieldRequests: 3,
    // 同一協助者在 24 小時內被同一長輩拒絕幾次後自動封鎖
    autoBlockAfterRejects: 3,
    autoBlockWindowMs: 24 * 60 * 60 * 1000,
    // 信任的人：每位長輩最多幾位、信任的人直接發起請求的次數上限
    maxTrustedPerElder: 5,
    trustedRequestLimit: { max: 5, windowMs: 10 * 60 * 1000 },
    // 長輩主動請信任的人來幫忙：多久沒回應就失效、次數上限
    helpRequestTtlMs: Number(process.env.HELP_REQUEST_TTL_MS ?? 10 * 60 * 1000),
    helpRequestLimit: { max: 5, windowMs: 10 * 60 * 1000 },
    // 加好友（信任的人）邀請碼：長輩出示 QR／6 位數，家人掃了之後長輩再按一次同意
    trustInviteTtlMs: Number(process.env.TRUST_INVITE_TTL_MS ?? 5 * 60 * 1000),
    // Demo 預設好友：王大明（elder-wang）已信任家人王小華（helper-family）、
    // 李秀英（elder-lee）已信任里長陳美玲（helper-chief）。demo 可直接發請求，不用配對碼
    demoTrust: [
      ['elder-wang', 'helper-family'],
      ['elder-lee', 'helper-chief'],
    ],
    // 送出後可撤回的時間（降低誤觸送出的風險）。網頁原型原設 5 秒，長輩反應較慢，放寬為 10 秒
    undoWindowMs: 10 * 1000,
    staticDir: process.env.STATIC_DIR ?? null,
    // QR Code 裡的網址開頭；沒設就用請求的 Host
    publicUrl: process.env.PUBLIC_URL ?? null,
    dataDir: null,
    // Universal Links 允許的 iOS App（Team ID.Bundle ID），逗號分隔
    iosAppIds: (process.env.IOS_APP_IDS ?? 'GM583TGZB5.com.samjiang.townpass').split(',').map((x) => x.trim()).filter(Boolean),
    adminDir: null,
    ...overrides,
  };
}
