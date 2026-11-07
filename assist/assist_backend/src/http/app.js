import express from 'express';
import fs from 'node:fs';
import { ApiError, unauthorized, forbidden, badRequest } from '../core/errors.js';
import { HELPERS, ELDERS, findUser, findElderByTownpassAccount, publicHelper, publicElder } from '../data/users.js';
import { SERVICES, findService, serviceSummary } from '../data/services.js';
import { LEGAL_INFO } from '../data/legal.js';

export const LOCAL_ORIGIN = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/;

export function buildHttpApp({ config, tokens, assist, audit }) {
  const app = express();
  app.disable('x-powered-by');

  // ── 基本安全標頭
  app.use((req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('Permissions-Policy', 'geolocation=(), microphone=()');
    if (req.path.startsWith('/api/')) res.setHeader('Cache-Control', 'no-store');
    next();
  });

  // ── CORS：只允許本機開發來源（flutter run -d chrome 會用不同 port）
  app.use((req, res, next) => {
    const origin = req.headers.origin;
    if (origin && LOCAL_ORIGIN.test(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
      res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    }
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });

  app.use(express.json({ limit: '10kb' }));

  // ── 驗證
  const authenticate = (req, _res, next) => {
    const header = req.headers.authorization ?? '';
    const claims = tokens.verify(header.startsWith('Bearer ') ? header.slice(7) : null);
    const user = claims ? findUser(claims.sub) : null;
    if (!user || user.role !== claims.role) return next(unauthorized());
    req.user = user;
    next();
  };
  const requireRole = (role) => (req, _res, next) =>
    req.user.role === role ? next() : next(forbidden());

  const wrap = (fn) => (req, res, next) => {
    try {
      const out = fn(req, res);
      if (out !== undefined) res.json(out);
    } catch (e) {
      next(e);
    }
  };

  const api = express.Router();

  api.get('/health', (_req, res) => res.json({ ok: true }));

  // ── Demo 登入：正式版改接台北通實名 OAuth
  api.get('/auth/demo-accounts', (_req, res) =>
    res.json({
      helpers: HELPERS.map(publicHelper),
      elders: ELDERS.map((e) => ({ ...publicElder(e), birthday: e.profile.birthday })),
    }),
  );
  api.post(
    '/auth/demo-login',
    wrap((req) => {
      const user = findUser(req.body?.userId);
      if (!user) throw badRequest('沒有這個 demo 帳號');
      const token = tokens.issue({ sub: user.id, role: user.role });
      return { token, user: user.role === 'helper' ? { role: 'helper', ...publicHelper(user) } : { role: 'elder', ...publicElder(user) } };
    }),
  );

  // ── 台北通 App 登入：App 已完成實名驗證，以帳號換取協辦用 token。
  // 正式版應由後端向台北通驗證 App 的 OAuth access token，而不是直接相信 accountId。
  api.post(
    '/auth/townpass-login',
    wrap((req) => {
      const elder = findElderByTownpassAccount(req.body?.accountId);
      if (!elder) throw unauthorized('這個台北通帳號尚未開通陪辦', 'ACCOUNT_NOT_LINKED');
      const token = tokens.issue({ sub: elder.id, role: 'elder' });
      return { token, user: { role: 'elder', ...publicElder(elder) } };
    }),
  );

  // ── 公開資訊
  api.get('/services', (_req, res) => res.json(SERVICES.map(serviceSummary)));
  api.get(
    '/services/:id',
    wrap((req) => {
      const s = findService(req.params.id);
      if (!s) throw new ApiError(404, 'NOT_FOUND', '找不到這項業務');
      return s;
    }),
  );
  api.get('/legal', (_req, res) => res.json(LEGAL_INFO));

  // ── 以下需要登入
  api.use(authenticate);

  api.get(
    '/me',
    wrap((req) =>
      req.user.role === 'helper'
        ? { role: 'helper', ...publicHelper(req.user) }
        : { role: 'elder', ...publicElder(req.user) },
    ),
  );
  api.get('/audit/verify', (_req, res) => res.json(audit.verify()));

  api.get('/sessions/:id', wrap((req) => assist.getSession(req.user, req.params.id)));
  api.post('/sessions/:id/end', wrap((req) => assist.end(req.user, req.params.id, 'manual')));

  // ── 長輩
  const elder = express.Router();
  elder.use(requireRole('elder'));
  elder.post('/pairing-code', wrap((req) => assist.createPairingCode(req.user)));
  elder.get('/sessions', wrap((req) => assist.listForElder(req.user)));
  elder.get('/audit', wrap((req) => assist.elderAudit(req.user)));
  elder.get('/applications', wrap((req) => assist.elderApplications(req.user)));
  elder.post(
    '/sessions/:id/respond',
    wrap((req) => assist.respond(req.user, req.params.id, req.body?.accept === true)),
  );
  elder.post(
    '/sessions/:id/fields/:key/authorize',
    wrap((req) => assist.authorizeField(req.user, req.params.id, req.params.key, req.body?.approve === true)),
  );
  elder.post(
    '/sessions/:id/fields/:key/revoke',
    wrap((req) => assist.revokeField(req.user, req.params.id, req.params.key)),
  );
  elder.post(
    '/sessions/:id/fields/:key/input',
    wrap((req) => assist.inputChoice(req.user, req.params.id, req.params.key, req.body?.value)),
  );
  elder.post(
    '/sessions/:id/submit',
    wrap((req) => assist.submit(req.user, req.params.id, req.body?.confirm === true)),
  );
  elder.post('/sessions/:id/undo', wrap((req) => assist.undoSubmit(req.user, req.params.id)));
  elder.post('/sessions/:id/block', wrap((req) => assist.blockHelper(req.user, req.params.id)));
  api.use('/elder', elder);

  // ── 協助者
  const helper = express.Router();
  helper.use(requireRole('helper'));
  helper.post(
    '/requests',
    wrap((req, res) => {
      const body = req.body ?? {};
      let view;
      if (body.method === 'pairing_code') view = assist.requestByCode(req.user, body);
      else if (body.method === 'identity') view = assist.requestByIdentity(req.user, body);
      else throw badRequest('請選擇找到長輩的方式', 'INVALID_METHOD');
      res.status(202);
      return view;
    }),
  );
  helper.get('/sessions', wrap((req) => assist.listForHelper(req.user)));
  helper.get('/audit', wrap((req) => assist.helperAudit(req.user)));
  helper.post(
    '/sessions/:id/step',
    wrap((req) => assist.gotoStep(req.user, req.params.id, req.body?.step)),
  );
  helper.post(
    '/sessions/:id/focus',
    wrap((req) => assist.focusField(req.user, req.params.id, req.body?.fieldKey ?? null)),
  );
  helper.post(
    '/sessions/:id/fields/:key/request',
    wrap((req) => assist.requestField(req.user, req.params.id, req.params.key)),
  );
  helper.post(
    '/sessions/:id/request-submit',
    wrap((req) => assist.requestSubmit(req.user, req.params.id)),
  );
  api.use('/helper', helper);

  app.use('/api', api);

  // ── 承辦人表單後台：已整合進承辦工作台的「表單」（/#/forms）。
  //    舊版單檔原型保留在 /admin/legacy/ 供對照。
  if (config.adminDir && fs.existsSync(config.adminDir)) {
    app.use('/admin/legacy', express.static(config.adminDir, { index: 'index.html' }));
  }
  if (config.staticDir && fs.existsSync(config.staticDir)) {
    app.get(['/admin', '/admin/'], (_req, res) => res.redirect('/#/forms'));
  } else if (config.adminDir && fs.existsSync(config.adminDir)) {
    app.get(['/admin', '/admin/'], (_req, res) => res.redirect('/admin/legacy/'));
  }

  // ── 前端靜態檔（Flutter Web build）
  if (config.staticDir && fs.existsSync(config.staticDir)) {
    app.use(express.static(config.staticDir, { index: 'index.html' }));
  }

  // ── 錯誤處理：不外洩內部錯誤細節
  app.use((req, res) => res.status(404).json({ error: { code: 'NOT_FOUND', message: '找不到這個路徑' } }));
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err instanceof ApiError) {
      return res.status(err.status).json({ error: { code: err.code, message: err.message } });
    }
    if (err?.type === 'entity.parse.failed' || err?.type === 'entity.too.large') {
      return res.status(400).json({ error: { code: 'BAD_BODY', message: '請求格式錯誤' } });
    }
    console.error(err);
    return res.status(500).json({ error: { code: 'INTERNAL', message: '系統忙碌中，請稍後再試' } });
  });

  return app;
}
