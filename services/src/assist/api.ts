/**
 * 協辦 (Assisted Application) — 後端存取層。
 * Copyright (C) 2026 協辦 team
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU Affero General Public License as published by the Free Software Foundation, either version 3
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
 * even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License along with this program.
 * If not, see https://www.gnu.org/licenses/.
 *
 * ── 兩種模式 ──
 * 1. 記憶體模擬(預設):資料只存在這個網頁裡,重新整理就重置,不會跨裝置同步。
 * 2. HTTP 模式:設定環境變數 `VITE_ASSIST_API_BASE` 才啟用,兩支手機連同一個後端,
 *    子女或看護那支手機一送出,長輩那支手機輪詢後立刻跳出邀請。
 *      VITE_ASSIST_API_BASE=auto                  → 連同一台電腦的 :8787(`mock-server/server.mjs`)
 *      VITE_ASSIST_API_BASE=https://host/api/assist → 連到真正的後端(Spring)
 *
 * ── 與 Spring 後端對接 ──
 * 路徑都在 `/api/assist` 底下:
 *   listPending      POST   /requests/pending      { elderIdNo }
 *   createHelperRequest POST /requests             { elderIdNo, helperType, ... }
 *   getRequest       GET    /requests/{id}
 *   acceptRequest    POST   /requests/{id}/accept
 *   rejectRequest    POST   /requests/{id}/reject
 *   reviseRequest    POST   /requests/{id}/revise  { reasons }
 *   confirmRequest   POST   /requests/{id}/confirm
 *   undoRequest      POST   /requests/{id}/undo
 *   redeemQr         POST   /qr/redeem             { token, elderIdNo }
 *   listDelegations  POST   /delegations/list      { elderIdNo }
 *   addDelegation    POST   /delegations           { elderIdNo, helperType, helperName, days }
 *   endDelegation    POST   /delegations/{id}/end  { elderIdNo }
 * 錯誤以 `{ "error": "EXPIRED" | "NOT_YOU" | "USED" | "INVALID" | "NOT_FOUND" | "TOO_LATE" }` 回傳。
 * 真實後端要用登入身分比對長輩,不能只信任請求裡的 elderIdNo;這裡的 elderIdNo 只是模擬伺服器的做法。
 * 資料全為虛構。
 */
import seed from '../../public/mock/assist_requests.json';
import { AssistError } from './types';
import type {
  AssistField,
  AssistRequest,
  DelegateType,
  Delegation,
  HelperType,
  Lang,
  RequestStatus,
  RevisionReason
} from './types';

const MINUTE = 60 * 1000;
const DAY = 24 * 60 * MINUTE;
const UNDO_WINDOW_MS = 5000;
const QR_TTL_MS = 5 * MINUTE;
/** 邀請本身的有效時間(比 QR 久,長輩不必在 5 分鐘內回應) */
const INVITE_TTL_MS = 30 * MINUTE;

export const DEFAULT_ELDER_ID = 'elder-001';
/** 沒有從 App 取得登入者時,HTTP 模式使用的示範身分證字號(虛構) */
export const DEFAULT_ELDER_ID_NO = 'A123456789';

const API_BASE_ENV = import.meta.env.VITE_ASSIST_API_BASE as string | undefined;

/** 是否連到共用後端(兩支手機同步);否則使用記憶體模擬 */
export const USE_HTTP = !!API_BASE_ENV;

const apiBase = () => {
  if (!API_BASE_ENV) return '';
  if (API_BASE_ENV === 'auto') {
    return `${window.location.protocol}//${window.location.hostname}:8787/api/assist`;
  }
  return API_BASE_ENV.replace(/\/$/, '');
};

const KNOWN_ERRORS = ['EXPIRED', 'NOT_YOU', 'USED', 'INVALID', 'NOT_FOUND', 'TOO_LATE'];

const http = async <T>(method: string, path: string, body?: unknown): Promise<T> => {
  let response: Response;
  try {
    response = await fetch(`${apiBase()}${path}`, {
      method,
      headers: body === undefined ? undefined : { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body)
    });
  } catch {
    throw new AssistError('NETWORK');
  }
  const data = (await response.json().catch(() => ({}))) as { error?: string };
  if (!response.ok) {
    throw new AssistError(
      data.error && KNOWN_ERRORS.includes(data.error)
        ? (data.error as AssistError['code'])
        : 'NETWORK'
    );
  }
  return data as T;
};

/** 示範資料目前綁定的長輩帳號(僅記憶體模擬使用) */
let demoElderId = DEFAULT_ELDER_ID;

let requests: AssistRequest[] = seed.requests.map((item) => ({
  id: item.id,
  elderId: item.elderId,
  helperType: item.helperType as HelperType,
  helperName: item.helperName,
  serviceId: item.serviceId,
  status: item.status as RequestStatus,
  expiresAt: new Date(Date.now() + item.expiresInMinutes * MINUTE).toISOString(),
  elderLang: item.elderLang as Lang,
  fields: item.fields as AssistField[]
}));

let delegations: Delegation[] = seed.delegations.map((item) => ({
  id: item.id,
  helperType: item.helperType as DelegateType,
  helperName: item.helperName,
  expiresAt: new Date(Date.now() + item.daysValid * DAY).toISOString()
}));

/**
 * 在 App 內會收到真正的登入者 ID;把示範資料改綁給這個帳號,
 * 否則示範請求會因為帳號不同而全部看不到。只有記憶體模擬需要,真實後端不需要這個函式。
 */
export const rebindDemoElder = (userId: string) => {
  if (!userId || userId === demoElderId) return;
  requests.forEach((item) => {
    if (item.elderId === demoElderId) item.elderId = userId;
  });
  demoElderId = userId;
};

const clone = <T>(value: T): T => JSON.parse(JSON.stringify(value));

const wait = () => new Promise<void>((resolve) => setTimeout(resolve, 120));

const isExpired = (request: AssistRequest) => new Date(request.expiresAt).getTime() < Date.now();

const withStatus = (request: AssistRequest): AssistRequest => {
  if (
    isExpired(request) &&
    (request.status === 'PENDING' || request.status === 'ACCEPTED' || request.status === 'REVISION')
  ) {
    return { ...request, status: 'EXPIRED' };
  }
  return request;
};

const find = (id: string) => {
  const target = requests.find((item) => item.id === id);
  if (!target) throw new AssistError('NOT_FOUND');
  return target;
};

const randomString = (length: number) => {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = new Uint8Array(length);
  if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
    crypto.getRandomValues(bytes);
  } else {
    for (let i = 0; i < length; i++) bytes[i] = Math.floor(Math.random() * 256);
  }
  return Array.from(bytes, (b) => chars[b % chars.length]).join('');
};

/**
 * 長輩的待確認邀請。
 * @param elderKey 記憶體模擬為帳號 ID;HTTP 模式為身分證字號
 */
export const listPending = async (elderKey: string): Promise<AssistRequest[]> => {
  if (USE_HTTP) return http('POST', '/requests/pending', { elderIdNo: elderKey });
  await wait();
  return clone(
    requests
      .filter((item) => item.elderId === elderKey)
      .map(withStatus)
      .filter((item) => item.status === 'PENDING' || item.status === 'ACCEPTED')
  );
};

export const getRequest = async (id: string): Promise<AssistRequest> => {
  if (USE_HTTP) return http('GET', `/requests/${encodeURIComponent(id)}`);
  await wait();
  return clone(withStatus(find(id)));
};

export const acceptRequest = async (id: string): Promise<AssistRequest> => {
  if (USE_HTTP) return http('POST', `/requests/${encodeURIComponent(id)}/accept`, {});
  await wait();
  const target = find(id);
  if (withStatus(target).status === 'EXPIRED') throw new AssistError('EXPIRED');
  target.status = 'ACCEPTED';
  return clone(target);
};

export const rejectRequest = async (id: string): Promise<AssistRequest> => {
  if (USE_HTTP) return http('POST', `/requests/${encodeURIComponent(id)}/reject`, {});
  await wait();
  const target = find(id);
  target.status = 'REJECTED';
  return clone(target);
};

/** 長輩點選「哪裡不對」後送回給協助者 */
export const reviseRequest = async (
  id: string,
  reasons: RevisionReason[]
): Promise<AssistRequest> => {
  if (USE_HTTP) return http('POST', `/requests/${encodeURIComponent(id)}/revise`, { reasons });
  await wait();
  const target = find(id);
  target.status = 'REVISION';
  target.revisionReasons = reasons;
  return clone(target);
};

export const confirmRequest = async (id: string): Promise<AssistRequest> => {
  if (USE_HTTP) return http('POST', `/requests/${encodeURIComponent(id)}/confirm`, {});
  await wait();
  const target = find(id);
  if (withStatus(target).status === 'EXPIRED') throw new AssistError('EXPIRED');
  const now = new Date();
  const date = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(
    now.getDate()
  ).padStart(2, '0')}`;
  target.status = 'CONFIRMED';
  target.caseNo = `EB-${date}-${randomString(4)}`;
  target.confirmedAt = Date.now();
  return clone(target);
};

/** 確認送出後 5 秒內可撤回 */
export const undoRequest = async (id: string): Promise<AssistRequest> => {
  if (USE_HTTP) return http('POST', `/requests/${encodeURIComponent(id)}/undo`, {});
  await wait();
  const target = find(id);
  if (target.status !== 'CONFIRMED' || !target.confirmedAt) throw new AssistError('TOO_LATE');
  if (Date.now() - target.confirmedAt > UNDO_WINDOW_MS + 500) throw new AssistError('TOO_LATE');
  target.status = 'ACCEPTED';
  target.caseNo = undefined;
  target.confirmedAt = undefined;
  return clone(target);
};

export const UNDO_SECONDS = UNDO_WINDOW_MS / 1000;

/** 長輩掃 QR 後兌換。真實後端要驗證登入者就是目標長輩。 */
export const redeemQr = async (token: string, elderKey: string): Promise<AssistRequest> => {
  if (USE_HTTP) return http('POST', '/qr/redeem', { token, elderIdNo: elderKey });
  await wait();
  const target = requests.find((item) => item.token === token);
  if (!target) throw new AssistError('INVALID');
  if (target.tokenUsed) throw new AssistError('USED');
  const tokenExpiry = new Date(target.tokenExpiresAt ?? target.expiresAt).getTime();
  if (isExpired(target) || tokenExpiry < Date.now()) throw new AssistError('EXPIRED');
  if (target.elderId !== elderKey) throw new AssistError('NOT_YOU');
  target.tokenUsed = true;
  target.status = 'ACCEPTED';
  return clone(target);
};

export interface HelperRequestInput {
  /** 記憶體模擬為帳號 ID;HTTP 模式為長輩的身分證字號(協助者填的) */
  elderId: string;
  helperType: Exclude<HelperType, 'CS_1999'>;
  helperName: string;
  elderLang: Lang;
  serviceId: string;
  fields: AssistField[];
}

/** 協助者幫長輩填好資料後送出:建立邀請,並產生一次性、短效的 QR 代碼 */
export const createHelperRequest = async (input: HelperRequestInput): Promise<AssistRequest> => {
  if (USE_HTTP) {
    return http('POST', '/requests', {
      elderIdNo: input.elderId,
      helperType: input.helperType,
      helperName: input.helperName,
      elderLang: input.elderLang,
      serviceId: input.serviceId,
      fields: input.fields
    });
  }
  await wait();
  const request: AssistRequest = {
    id: `ar-${randomString(6)}`,
    elderId: input.elderId,
    helperType: input.helperType,
    helperName: input.helperName,
    serviceId: input.serviceId,
    fields: input.fields,
    status: 'PENDING',
    expiresAt: new Date(Date.now() + INVITE_TTL_MS).toISOString(),
    tokenExpiresAt: new Date(Date.now() + QR_TTL_MS).toISOString(),
    elderLang: input.elderLang,
    token: randomString(16),
    tokenUsed: false
  };
  requests = [request, ...requests];
  return clone(request);
};

/** QR 內容只放代碼,不放任何個資。格式沿用既有的 Base64(JSON)。 */
export const buildQrPayload = (token: string) => btoa(JSON.stringify({ type: 'assist', token }));

export const parseQrPayload = (payload: string): string | null => {
  try {
    const obj = JSON.parse(atob(payload));
    return obj && obj.type === 'assist' && typeof obj.token === 'string' ? obj.token : null;
  } catch {
    return null;
  }
};

export const listDelegations = async (elderKey?: string): Promise<Delegation[]> => {
  if (USE_HTTP) return http('POST', '/delegations/list', { elderIdNo: elderKey });
  await wait();
  return clone(delegations.filter((item) => new Date(item.expiresAt).getTime() > Date.now()));
};

export const addDelegation = async (
  helperType: DelegateType,
  helperName: string,
  days: number,
  elderKey?: string
): Promise<Delegation> => {
  if (USE_HTTP) {
    return http('POST', '/delegations', { elderIdNo: elderKey, helperType, helperName, days });
  }
  await wait();
  const item: Delegation = {
    id: `dg-${randomString(5)}`,
    helperType,
    helperName,
    expiresAt: new Date(Date.now() + days * DAY).toISOString()
  };
  delegations = [...delegations, item];
  return clone(item);
};

export const endDelegation = async (id: string, elderKey?: string): Promise<void> => {
  if (USE_HTTP) {
    await http('POST', `/delegations/${encodeURIComponent(id)}/end`, { elderIdNo: elderKey });
    return;
  }
  await wait();
  delegations = delegations.filter((item) => item.id !== id);
};
