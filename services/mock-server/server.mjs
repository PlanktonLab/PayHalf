/**
 * 協辦 (Assisted Application) — 共用模擬後端(開發與展示用,不是正式後端)。
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
 * 用途:讓兩支手機連同一個後端,子女或看護那支一送出,長輩那支輪詢後立刻看到邀請。
 * 路徑與回傳格式和 `src/assist/api.ts` 檔頭列的 Spring API 一致,Spring 完成後可直接替換。
 *
 * 執行:  node mock-server/server.mjs
 *   PORT=8787 HOST=127.0.0.1(預設)。要讓區網內的實體手機連線,設 HOST=0.0.0.0。
 *
 * 限制:資料只在記憶體,重新啟動就清空。沒有真正的身分驗證:用請求裡的 elderIdNo 比對長輩,
 * 這只是模擬;真實後端必須用登入身分比對。沒有任何個資會寫入檔案或記錄檔。
 * 資料全為虛構。
 */
import http from 'node:http';
import crypto from 'node:crypto';

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '127.0.0.1';

const MINUTE = 60 * 1000;
const DAY = 24 * 60 * MINUTE;
const INVITE_TTL_MS = 30 * MINUTE;
const QR_TTL_MS = 5 * MINUTE;
const UNDO_WINDOW_MS = 5000;

const HELPER_TYPES = ['FAMILY', 'VILLAGE_CHIEF', 'CAREGIVER'];
const LANGS = ['zh-Hant', 'en', 'vi', 'id'];
const FIELD_KEYS = ['name', 'idNumber', 'birthday', 'bank', 'account'];
const REASONS = [...FIELD_KEYS, 'notMine'];

/** @type {Array<Record<string, any>>} */
let requests = [];
/** @type {Array<Record<string, any>>} */
let delegations = [
  {
    id: 'dg-demo-1',
    elderIdNo: 'A123456789',
    helperType: 'FAMILY',
    helperName: '王小明(兒子)',
    expiresAt: new Date(Date.now() + 365 * DAY).toISOString()
  },
  {
    id: 'dg-demo-2',
    elderIdNo: 'A123456789',
    helperType: 'CAREGIVER',
    helperName: 'Sari',
    expiresAt: new Date(Date.now() + 30 * DAY).toISOString()
  }
];

const normalizeId = (value) => String(value ?? '').trim().toUpperCase();

const randomString = (length) => {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.randomBytes(length);
  return Array.from(bytes, (b) => chars[b % chars.length]).join('');
};

class HttpError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

const send = (res, status, body) => {
  const text = JSON.stringify(body ?? {});
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Cache-Control': 'no-store'
  });
  res.end(text);
};

const readBody = (req) =>
  new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 100 * 1024) {
        reject(new HttpError(413, 'INVALID'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (!chunks.length) return resolve({});
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(new HttpError(400, 'INVALID'));
      }
    });
    req.on('error', reject);
  });

const isInviteExpired = (r) => new Date(r.expiresAt).getTime() < Date.now();

const withStatus = (r) =>
  isInviteExpired(r) && ['PENDING', 'ACCEPTED', 'REVISION'].includes(r.status)
    ? { ...r, status: 'EXPIRED' }
    : r;

/** 對外只給必要欄位:不含長輩的完整身分證字號,也不含 QR 代碼 */
const publicView = (r) => {
  const { elderIdNo, token, tokenUsed, ...rest } = withStatus(r);
  return rest;
};

const findRequest = (id) => {
  const found = requests.find((r) => r.id === id);
  if (!found) throw new HttpError(404, 'NOT_FOUND');
  return found;
};

const validateFields = (fields) => {
  if (!Array.isArray(fields) || fields.length !== FIELD_KEYS.length) throw new HttpError(400, 'INVALID');
  return fields.map((f) => {
    if (!f || !FIELD_KEYS.includes(f.key)) throw new HttpError(400, 'INVALID');
    const value = String(f.value ?? '').trim().slice(0, 200);
    if (!value) throw new HttpError(400, 'INVALID');
    return { key: f.key, value };
  });
};

const handlers = {
  // 協助者送出:建立邀請與一次性 QR 代碼(只有這個回應會帶 token)
  'POST /requests': async (_req, _params, body) => {
    const elderIdNo = normalizeId(body.elderIdNo);
    const helperName = String(body.helperName ?? '').trim().slice(0, 60);
    if (!elderIdNo || !helperName) throw new HttpError(400, 'INVALID');
    if (!HELPER_TYPES.includes(body.helperType)) throw new HttpError(400, 'INVALID');
    const elderLang = LANGS.includes(body.elderLang) ? body.elderLang : 'zh-Hant';
    const request = {
      id: `ar-${randomString(6)}`,
      elderIdNo,
      helperType: body.helperType,
      helperName,
      serviceId: 'elderBonus',
      fields: validateFields(body.fields),
      status: 'PENDING',
      expiresAt: new Date(Date.now() + INVITE_TTL_MS).toISOString(),
      tokenExpiresAt: new Date(Date.now() + QR_TTL_MS).toISOString(),
      elderLang,
      token: randomString(16),
      tokenUsed: false
    };
    requests = [request, ...requests].slice(0, 500);
    const { elderIdNo: _omit, tokenUsed: _used, ...rest } = request;
    return { status: 201, body: rest };
  },

  // 長輩手機輪詢:有沒有人要幫我辦
  'POST /requests/pending': async (_req, _params, body) => {
    const elderIdNo = normalizeId(body.elderIdNo);
    if (!elderIdNo) throw new HttpError(400, 'INVALID');
    const list = requests
      .filter((r) => r.elderIdNo === elderIdNo)
      .map(withStatus)
      .filter((r) => r.status === 'PENDING' || r.status === 'ACCEPTED')
      .reverse()
      .map(publicView);
    return { status: 200, body: list };
  },

  'GET /requests/:id': async (_req, params) => ({
    status: 200,
    body: publicView(findRequest(params.id))
  }),

  'POST /requests/:id/accept': async (_req, params) => {
    const r = findRequest(params.id);
    if (withStatus(r).status === 'EXPIRED') throw new HttpError(410, 'EXPIRED');
    r.status = 'ACCEPTED';
    return { status: 200, body: publicView(r) };
  },

  'POST /requests/:id/reject': async (_req, params) => {
    const r = findRequest(params.id);
    r.status = 'REJECTED';
    return { status: 200, body: publicView(r) };
  },

  'POST /requests/:id/revise': async (_req, params, body) => {
    const r = findRequest(params.id);
    const reasons = Array.isArray(body.reasons) ? body.reasons.filter((x) => REASONS.includes(x)) : [];
    if (!reasons.length) throw new HttpError(400, 'INVALID');
    r.status = 'REVISION';
    r.revisionReasons = [...new Set(reasons)];
    return { status: 200, body: publicView(r) };
  },

  'POST /requests/:id/confirm': async (_req, params) => {
    const r = findRequest(params.id);
    if (withStatus(r).status === 'EXPIRED') throw new HttpError(410, 'EXPIRED');
    if (r.status !== 'ACCEPTED') throw new HttpError(409, 'INVALID');
    const now = new Date();
    const date = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}`;
    r.status = 'CONFIRMED';
    r.caseNo = `EB-${date}-${randomString(4)}`;
    r.confirmedAt = Date.now();
    return { status: 200, body: publicView(r) };
  },

  'POST /requests/:id/undo': async (_req, params) => {
    const r = findRequest(params.id);
    if (r.status !== 'CONFIRMED' || !r.confirmedAt) throw new HttpError(409, 'TOO_LATE');
    if (Date.now() - r.confirmedAt > UNDO_WINDOW_MS + 500) throw new HttpError(409, 'TOO_LATE');
    r.status = 'ACCEPTED';
    delete r.caseNo;
    delete r.confirmedAt;
    return { status: 200, body: publicView(r) };
  },

  // 長輩掃 QR:代碼只能用一次、限時,而且只有目標長輩本人能兌換
  'POST /qr/redeem': async (_req, _params, body) => {
    const token = String(body.token ?? '');
    const elderIdNo = normalizeId(body.elderIdNo);
    const r = requests.find((x) => x.token === token);
    if (!r) throw new HttpError(404, 'INVALID');
    if (r.tokenUsed) throw new HttpError(409, 'USED');
    if (isInviteExpired(r) || new Date(r.tokenExpiresAt).getTime() < Date.now()) {
      throw new HttpError(410, 'EXPIRED');
    }
    if (r.elderIdNo !== elderIdNo) throw new HttpError(403, 'NOT_YOU');
    r.tokenUsed = true;
    if (r.status === 'PENDING') r.status = 'ACCEPTED';
    return { status: 200, body: publicView(r) };
  },

  'POST /delegations/list': async (_req, _params, body) => {
    const elderIdNo = normalizeId(body.elderIdNo);
    const list = delegations
      .filter((d) => d.elderIdNo === elderIdNo && new Date(d.expiresAt).getTime() > Date.now())
      .map(({ elderIdNo: _e, ...rest }) => rest);
    return { status: 200, body: list };
  },

  'POST /delegations': async (_req, _params, body) => {
    const elderIdNo = normalizeId(body.elderIdNo);
    const helperName = String(body.helperName ?? '').trim().slice(0, 60);
    const days = Math.min(365, Math.max(1, Number(body.days) || 30));
    if (!elderIdNo || !helperName || !HELPER_TYPES.includes(body.helperType)) {
      throw new HttpError(400, 'INVALID');
    }
    const item = {
      id: `dg-${randomString(5)}`,
      elderIdNo,
      helperType: body.helperType,
      helperName,
      expiresAt: new Date(Date.now() + days * DAY).toISOString()
    };
    delegations = [...delegations, item];
    const { elderIdNo: _e, ...rest } = item;
    return { status: 201, body: rest };
  },

  'POST /delegations/:id/end': async (_req, params, body) => {
    const elderIdNo = normalizeId(body.elderIdNo);
    const target = delegations.find((d) => d.id === params.id);
    if (!target) throw new HttpError(404, 'NOT_FOUND');
    if (target.elderIdNo !== elderIdNo) throw new HttpError(403, 'NOT_YOU');
    delegations = delegations.filter((d) => d.id !== params.id);
    return { status: 200, body: {} };
  },

  'GET /health': async () => ({ status: 200, body: { ok: true, requests: requests.length } })
};

/** 把 `POST /requests/:id/accept` 這樣的路徑樣板轉成比對用的規則 */
const routes = Object.entries(handlers).map(([key, handler]) => {
  const [method, template] = key.split(' ');
  const names = [];
  const pattern = new RegExp(
    '^' +
      template.replace(/:([a-zA-Z]+)/g, (_m, name) => {
        names.push(name);
        return '([^/]+)';
      }) +
      '$'
  );
  return { method, pattern, names, handler };
});

const server = http.createServer(async (req, res) => {
  const started = Date.now();
  let status = 500;
  try {
    if (req.method === 'OPTIONS') {
      status = 204;
      send(res, 204, {});
      return;
    }
    const url = new URL(req.url ?? '/', 'http://localhost');
    const path = url.pathname.replace(/^\/api\/assist/, '') || '/';
    const route = routes.find((r) => r.method === req.method && r.pattern.test(path));
    if (!route) throw new HttpError(404, 'NOT_FOUND');
    const match = path.match(route.pattern);
    const params = Object.fromEntries(route.names.map((name, i) => [name, decodeURIComponent(match[i + 1])]));
    const body = req.method === 'POST' ? await readBody(req) : {};
    const result = await route.handler(req, params, body);
    status = result.status;
    send(res, result.status, result.body);
  } catch (error) {
    if (error instanceof HttpError) {
      status = error.status;
      send(res, error.status, { error: error.code });
    } else {
      status = 500;
      send(res, 500, { error: 'INVALID' });
    }
  } finally {
    // 只記錄方法、路徑與狀態碼,不記錄任何請求內容(內含個資)
    console.log(`${req.method} ${(req.url ?? '').split('?')[0]} -> ${status} (${Date.now() - started}ms)`);
  }
});

server.listen(PORT, HOST, () => {
  console.log(`協辦模擬後端已啟動:http://${HOST}:${PORT}/api/assist  (Ctrl+C 結束)`);
});
