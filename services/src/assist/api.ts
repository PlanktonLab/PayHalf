/**
 * 協辦 (Assisted Application) — 模擬後端。
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
 * ── 與 Spring 後端對接說明 ──
 * 這個檔案的每個匯出函式,對應後端一支 API(見 長輩端畫面規格.md 第 5 節):
 *   listPending      GET    /assist-requests/pending
 *   getRequest       GET    /assist-requests/{id}
 *   acceptRequest    POST   /assist-requests/{id}/accept
 *   rejectRequest    POST   /assist-requests/{id}/reject
 *   reviseRequest    POST   /assist-requests/{id}/revise
 *   confirmRequest   POST   /assist-requests/{id}/confirm
 *   undoRequest      POST   /assist-requests/{id}/undo
 *   redeemQr         POST   /qr/redeem   (後端必須驗證登入者就是目標長輩)
 *   listDelegations / addDelegation / endDelegation   /delegations
 * 後端完成後,只要把函式內容換成 axios 呼叫即可,畫面與 store 不用動。
 * 目前為前端記憶體模擬,資料全為虛構。
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
  RequestStatus
} from './types';

const MINUTE = 60 * 1000;
const DAY = 24 * 60 * MINUTE;
const UNDO_WINDOW_MS = 5000;
const QR_TTL_MS = 5 * MINUTE;

export const DEFAULT_ELDER_ID = 'elder-001';

/** 示範資料目前綁定的長輩帳號 */
let demoElderId = DEFAULT_ELDER_ID;

/**
 * 在 App 內會收到真正的登入者 ID;把示範資料改綁給這個帳號,
 * 否則示範請求會因為帳號不同而全部看不到。真實後端不需要這個函式。
 */
export const rebindDemoElder = (userId: string) => {
  if (!userId || userId === demoElderId) return;
  requests.forEach((item) => {
    if (item.elderId === demoElderId) item.elderId = userId;
  });
  demoElderId = userId;
};

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

export const listPending = async (elderId: string) => {
  await wait();
  return clone(
    requests
      .filter((item) => item.elderId === elderId)
      .map(withStatus)
      .filter((item) => item.status === 'PENDING' || item.status === 'ACCEPTED')
  );
};

export const getRequest = async (id: string) => {
  await wait();
  return clone(withStatus(find(id)));
};

export const acceptRequest = async (id: string) => {
  await wait();
  const target = find(id);
  if (withStatus(target).status === 'EXPIRED') throw new AssistError('EXPIRED');
  target.status = 'ACCEPTED';
  return clone(target);
};

export const rejectRequest = async (id: string) => {
  await wait();
  const target = find(id);
  target.status = 'REJECTED';
  return clone(target);
};

export const reviseRequest = async (id: string, note: string) => {
  await wait();
  const target = find(id);
  target.status = 'REVISION';
  target.revisionNote = note;
  return clone(target);
};

export const confirmRequest = async (id: string) => {
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
export const undoRequest = async (id: string) => {
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
export const redeemQr = async (token: string, elderId: string) => {
  await wait();
  const target = requests.find((item) => item.token === token);
  if (!target) throw new AssistError('INVALID');
  if (target.tokenUsed) throw new AssistError('USED');
  if (isExpired(target)) throw new AssistError('EXPIRED');
  if (target.elderId !== elderId) throw new AssistError('NOT_YOU');
  target.tokenUsed = true;
  target.status = 'ACCEPTED';
  return clone(target);
};

export interface HelperRequestInput {
  elderId: string;
  helperType: Exclude<HelperType, 'CS_1999'>;
  helperName: string;
  elderLang: Lang;
  serviceId: string;
  fields: AssistField[];
}

/** 協助者幫長輩填好資料後,產生一次性、短效的 QR 代碼 */
export const createHelperRequest = async (input: HelperRequestInput) => {
  await wait();
  const request: AssistRequest = {
    id: `ar-${randomString(6)}`,
    elderId: input.elderId,
    helperType: input.helperType,
    helperName: input.helperName,
    serviceId: input.serviceId,
    fields: input.fields,
    status: 'PENDING',
    expiresAt: new Date(Date.now() + QR_TTL_MS).toISOString(),
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

export const listDelegations = async () => {
  await wait();
  return clone(delegations.filter((item) => new Date(item.expiresAt).getTime() > Date.now()));
};

export const addDelegation = async (helperType: DelegateType, helperName: string, days: number) => {
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

export const endDelegation = async (id: string) => {
  await wait();
  delegations = delegations.filter((item) => item.id !== id);
};
