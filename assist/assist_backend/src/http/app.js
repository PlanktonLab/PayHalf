import express from 'express';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { ApiError, unauthorized, forbidden, badRequest } from '../core/errors.js';
import { HELPERS, ELDERS, findUser, findElderByTownpassAccount, publicHelper, publicElder } from '../data/users.js';
import { SERVICES, findService, serviceSummary } from '../data/services.js';
import { LEGAL_INFO } from '../data/legal.js';
import { posterSvg, posterPage, landingPage, LAYOUTS } from '../poster/poster.js';
import { posterPdf } from '../poster/pdf.js';

export const LOCAL_ORIGIN = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/;

export function buildHttpApp({ config, tokens, assist, audit, forms }) {
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
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    }
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });

  // 表單後台存整份表單，允許大一點；其他 API 維持 10kb
  app.use('/api/console', express.json({ limit: '200kb' }));
  app.use(express.json({ limit: '10kb' }));

  // QR Code 裡的固定網址。nginx 的 /api、/socket.io 區塊沒有轉送 Host（內層 proxy_set_header 會蓋掉外層），
  // 所以從 nginx 進來的請求 Host 是 127.0.0.1:<port>：視為正式站。本機開發用 localhost 則照實際網址。
  const baseUrl = (req) => {
    if (config.publicUrl) return config.publicUrl.replace(/\/$/, '');
    const host = req.headers['x-forwarded-host'] ?? req.headers.host ?? 'localhost';
    if (/^127\./.test(host)) return 'https://payhalf.plankton.tw';
    return `${/^(localhost|\[::1\]|10\.|192\.168\.)/.test(host) ? 'http' : 'https'}://${host}`;
  };
  const formUrl = (req, id) => `${baseUrl(req)}/f/${encodeURIComponent(id)}`;

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

  const wrapAsync = (fn) => (req, res, next) => Promise.resolve(fn(req, res)).catch(next);
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

  // ── Demo 快速觸發：由預設信任的人直接向長輩發出請求（整個 App 都是 demo，正式版沒有這支）
  api.post(
    '/demo/trusted-request',
    wrap((req) => {
      const helper = findUser(req.body?.helperId);
      const elder = findUser(req.body?.elderId);
      if (!helper || helper.role !== 'helper') throw badRequest('沒有這個協助者');
      if (!elder || elder.role !== 'elder') throw badRequest('沒有這位長輩');
      const serviceId = req.body?.serviceId ?? SERVICES[0].id;
      return assist.requestTrusted(helper, { serviceId, elderId: elder.id });
    }),
  );

  // ── 公開資訊
  api.get('/services', (_req, res) => res.json(SERVICES.filter((s) => s.open !== false).map(serviceSummary)));
  api.get(
    '/services/:id',
    wrap((req) => {
      const s = findService(req.params.id);
      if (!s) throw new ApiError(404, 'NOT_FOUND', '找不到這項業務');
      return s;
    }),
  );
  api.get('/legal', (_req, res) => res.json(LEGAL_INFO));

  // ── 海報 PDF：實際尺寸，可直接送印（壓克力立牌 9.1 × 14.4 cm、A4、明信片）
  api.get(
    '/forms/:id/poster.pdf',
    wrapAsync(async (req, res) => {
      const form = forms.publicForm(req.params.id);
      const layout = LAYOUTS[req.query.layout] ? req.query.layout : 'a4';
      const svg = await posterSvg(form, { layout, url: formUrl(req, form.id) });
      const pdf = await posterPdf(svg, layout, { fontDir: config.dataDir ? path.join(config.dataDir, 'fonts') : undefined });
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader(
        'Content-Disposition',
        `${req.query.download ? 'attachment' : 'inline'}; filename*=UTF-8''${encodeURIComponent(`${form.title}_${LAYOUTS[layout].name}.pdf`)}`,
      );
      res.send(pdf);
    }),
  );

  // ── 靜態 QR Code 表單（公開：表單內容與海報）
  api.get('/forms/:id', wrap((req) => ({ ...forms.publicForm(req.params.id), url: formUrl(req, req.params.id) })));
  api.get(
    '/forms/:id/poster.svg',
    wrapAsync(async (req, res) => {
      const form = forms.publicForm(req.params.id);
      const layout = LAYOUTS[req.query.layout] ? req.query.layout : 'a4';
      res.setHeader('Content-Type', 'image/svg+xml; charset=utf-8');
      res.setHeader('Cache-Control', 'no-cache');
      if (req.query.download) {
        res.setHeader('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(`${form.title}_${LAYOUTS[layout].name}.svg`)}`);
      }
      res.send(await posterSvg(form, { layout, url: formUrl(req, form.id) }));
    }),
  );

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
    wrap((req) =>
      assist.authorizeField(req.user, req.params.id, req.params.key, req.body?.approve === true, req.body?.value),
    ),
  );
  elder.post(
    '/sessions/:id/fields/:key/self-authorize',
    wrap((req) => assist.selfAuthorizeField(req.user, req.params.id, req.params.key, req.body?.value)),
  );
  elder.post(
    '/sessions/:id/fields/:key/edit',
    wrap((req) => assist.editField(req.user, req.params.id, req.params.key, req.body?.value)),
  );
  elder.post('/sessions/:id/step', wrap((req) => assist.elderStep(req.user, req.params.id, req.body?.step)));
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
  elder.get('/trusted', wrap((req) => assist.listTrusted(req.user)));
  elder.post('/trusted', wrap((req) => assist.addTrusted(req.user, req.body ?? {})));
  elder.get('/trusted/candidates', wrap((req) => assist.trustCandidates(req.user)));
  // 加好友：產生邀請碼、看誰掃了、確認
  elder.post('/trust-invite', wrap((req) => assist.createTrustInvite(req.user)));
  elder.get('/trust-requests', wrap((req) => assist.listTrustRequests(req.user)));
  elder.post(
    '/trust-requests/:id/respond',
    wrap((req) => assist.respondTrustRequest(req.user, req.params.id, req.body?.accept === true)),
  );
  // 長輩主動請信任的人來幫忙
  elder.get('/help-requests', wrap((req) => assist.listHelpForElder(req.user)));
  elder.post('/help-requests', wrap((req) => assist.requestHelp(req.user, req.body ?? {})));
  elder.post('/help-requests/:id/cancel', wrap((req) => assist.cancelHelp(req.user, req.params.id)));
  elder.post('/trusted/:helperId/remove', wrap((req) => assist.removeTrusted(req.user, req.params.helperId)));
  elder.post('/sessions/:id/block', wrap((req) => assist.blockHelper(req.user, req.params.id)));
  // 靜態 QR 表單：長輩自己填、送出、半路找人幫忙
  elder.get('/forms/:id', wrap((req) => forms.openForElder(req.user, req.params.id)));
  elder.post('/forms/:id/submit', wrap((req) => forms.submitByElder(req.user, req.params.id, req.body ?? {})));
  elder.post('/forms/:id/help', wrap((req) => forms.requestHelp(req.user, req.params.id, req.body ?? {})));
  elder.post('/form-tickets/:id/cancel', wrap((req) => forms.cancelTicket(req.user, req.params.id)));
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
      else if (body.method === 'trusted') view = assist.requestTrusted(req.user, body);
      else throw badRequest('請選擇找到長輩的方式', 'INVALID_METHOD');
      res.status(202);
      return view;
    }),
  );
  helper.get('/sessions', wrap((req) => assist.listForHelper(req.user)));
  helper.get('/trusted-elders', wrap((req) => assist.listTrustingElders(req.user)));
  helper.get('/help-requests', wrap((req) => assist.listHelpForHelper(req.user)));
  helper.post('/trust-invite/accept', wrap((req) => assist.acceptTrustInvite(req.user, req.body ?? {})));
  helper.get('/audit', wrap((req) => assist.helperAudit(req.user)));
  helper.post(
    '/sessions/:id/step',
    wrap((req) => assist.gotoStep(req.user, req.params.id, req.body?.step)),
  );
  helper.post(
    '/sessions/:id/elder-nav',
    wrap((req) => assist.setElderNav(req.user, req.params.id, req.body?.enabled)),
  );
  helper.post(
    '/sessions/:id/elder-self-auth',
    wrap((req) => assist.setElderSelfAuth(req.user, req.params.id, req.body?.enabled)),
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

  // ── 承辦人員：表單後台、線上求助
  const staff = express.Router();
  staff.use(requireRole('helper'));
  staff.get('/forms', wrap((req) => forms.listForms(req.user)));
  staff.get('/forms/:id', wrap((req) => ({ ...forms.getFormForStaff(req.user, req.params.id), url: formUrl(req, req.params.id) })));
  staff.put('/forms/:id', wrap((req) => forms.putForm(req.user, req.params.id, req.body ?? {})));
  staff.delete('/forms/:id', wrap((req) => forms.deleteForm(req.user, req.params.id)));
  staff.get('/forms/:id/responses', wrap((req) => forms.listRows(req.user, req.params.id)));
  staff.get('/help-tickets', wrap((req) => forms.listTickets(req.user)));
  staff.post(
    '/help-tickets/:id/take',
    wrap((req, res) => {
      res.status(202);
      return forms.takeTicket(req.user, req.params.id);
    }),
  );
  api.use('/console', staff);

  app.use('/api', api);

  // ── iOS Universal Links：iPhone 相機掃 https://<網域>/f/<表單> 時，已安裝台北通就直接開 App
  const aasa = {
    applinks: {
      details: [
        {
          appIDs: config.iosAppIds,
          components: [{ '/': '/f/*', comment: '靜態 QR Code 表單' }],
        },
      ],
    },
  };
  app.get(['/.well-known/apple-app-site-association', '/apple-app-site-association'], (_req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.send(JSON.stringify(aasa));
  });

  // ── 靜態 QR Code 指向的網址（一般相機掃到時的說明頁）與可列印的海報頁
  app.get('/f/:id', (req, res) => {
    let form = null;
    try {
      form = forms.publicForm(req.params.id);
    } catch {
      res.status(404);
    }
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(landingPage(form, formUrl(req, req.params.id), req.params.id));
  });
  app.get(
    '/poster/:id',
    wrapAsync(async (req, res) => {
      const form = forms.publicForm(req.params.id);
      const layout = LAYOUTS[req.query.layout] ? req.query.layout : 'a4';
      const svg = await posterSvg(form, { layout, url: formUrl(req, form.id) });
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.setHeader('Cache-Control', 'no-cache');
      res.send(posterPage(form, svg, layout));
    }),
  );

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
    // Flutter Web 的檔名沒有 hash，前面的 Cloudflare 會讓瀏覽器把 .js 快取 4 小時（連 no-cache 都會被覆寫）。
    // 所以在 index.html → flutter_bootstrap.js → main.dart.js 這條鏈上加 ?v=<內容雜湊>：
    // 每次部署網址就不同，絕對拿到新版；沒改時網址不變，照樣吃快取。
    const webVersion = (() => {
      let cache = { mtime: 0, v: '' };
      return () => {
        const file = path.join(config.staticDir, 'main.dart.js');
        const mtime = fs.statSync(file).mtimeMs;
        if (mtime !== cache.mtime) {
          const v = crypto.createHash('sha1').update(fs.readFileSync(file)).digest('hex').slice(0, 10);
          cache = { mtime, v };
        }
        return cache.v;
      };
    })();
    const sendRewritten = (res, name, type, rewrite) => {
      const text = fs.readFileSync(path.join(config.staticDir, name), 'utf8');
      res.setHeader('Content-Type', type);
      res.setHeader('Cache-Control', 'no-cache');
      res.send(rewrite(text, webVersion()));
    };
    app.get(['/', '/index.html'], (_req, res) =>
      sendRewritten(res, 'index.html', 'text/html; charset=utf-8', (t, v) =>
        t.replaceAll('flutter_bootstrap.js"', `flutter_bootstrap.js?v=${v}"`),
      ),
    );
    app.get('/flutter_bootstrap.js', (_req, res) =>
      sendRewritten(res, 'flutter_bootstrap.js', 'text/javascript; charset=utf-8', (t, v) =>
        t.replaceAll('"mainJsPath":"main.dart.js"', `"mainJsPath":"main.dart.js?v=${v}"`),
      ),
    );
    // Flutter Web 的 main.dart.js 等檔名沒有 hash，部署後檔名不變。
    // 一律 no-cache（每次向伺服器確認，沒變就回 304），避免 CDN／瀏覽器拿舊版好幾個小時
    app.use(
      express.static(config.staticDir, {
        index: 'index.html',
        setHeaders: (res) => res.setHeader('Cache-Control', 'no-cache'),
      }),
    );
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
