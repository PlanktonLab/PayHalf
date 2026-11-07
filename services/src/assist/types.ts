/**
 * 協辦 (Assisted Application) — 讓長輩由 1999 客服、家人、里長或看護協助辦理,長輩只需確認。
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
 */

export type Lang = 'zh-Hant' | 'en' | 'vi' | 'id';

export type HelperType = 'CS_1999' | 'FAMILY' | 'VILLAGE_CHIEF' | 'CAREGIVER';

export type RequestStatus =
  | 'PENDING'
  | 'ACCEPTED'
  | 'REJECTED'
  | 'REVISION'
  | 'CONFIRMED'
  | 'EXPIRED';

export type FieldKey = 'name' | 'idNumber' | 'birthday' | 'bank' | 'account';

export interface AssistField {
  key: FieldKey;
  value: string;
}

export interface AssistRequest {
  id: string;
  elderId: string;
  helperType: HelperType;
  helperName: string;
  serviceId: string;
  fields: AssistField[];
  status: RequestStatus;
  /** ISO 字串 */
  expiresAt: string;
  elderLang: Lang;
  revisionNote?: string;
  caseNo?: string;
  confirmedAt?: number;
  /** QR 一次性代碼(只放代碼,不放個資) */
  token?: string;
  tokenUsed?: boolean;
}

export type DelegateType = Exclude<HelperType, 'CS_1999'>;

export interface Delegation {
  id: string;
  helperType: DelegateType;
  helperName: string;
  /** ISO 字串 */
  expiresAt: string;
}

export type RedeemErrorCode = 'EXPIRED' | 'NOT_YOU' | 'USED' | 'INVALID';

export class AssistError extends Error {
  code: RedeemErrorCode | 'NOT_FOUND' | 'TOO_LATE';

  constructor(code: AssistError['code']) {
    super(code);
    this.code = code;
  }
}
