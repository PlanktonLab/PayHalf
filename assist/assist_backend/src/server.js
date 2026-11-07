import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Server } from 'socket.io';
import { buildConfig } from './config.js';
import { createTokenService } from './core/token.js';
import { createAuditLog } from './core/audit.js';
import { createAssistService } from './core/assistService.js';
import { createFormService } from './core/formService.js';
import { buildHttpApp, LOCAL_ORIGIN } from './http/app.js';
import { initPrefs } from './data/users.js';
import { findUser } from './data/users.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_WEB = path.resolve(here, '../../assist_web/build/web');
// 舊版承辦人表單後台（repo 根目錄的 admin-form-builder），保留在 /admin/legacy/ 供對照
const DEFAULT_ADMIN = path.resolve(here, '../../../admin-form-builder');

/**
 * 建立完整服務（HTTP API + Socket.IO 即時推播）。
 * Socket 只負責「伺服器推送」，所有動作都走 REST，方便授權檢查與測試。
 */
export function createAssistServer(overrides = {}) {
  // 表單與回覆存在 repo 外層的 var/（部署時 rsync 不會蓋掉）；測試傳 dataDir: null 只放記憶體
  const config = buildConfig({
    staticDir: DEFAULT_WEB,
    adminDir: DEFAULT_ADMIN,
    dataDir: process.env.DATA_DIR ?? path.resolve(here, '../../../var'),
    ...overrides,
  });
  initPrefs(config.dataDir);
  const now = overrides.now ?? (() => Date.now());
  const tokens = createTokenService({ secret: config.tokenSecret, ttlMs: config.tokenTtlMs, now });
  const audit = createAuditLog({ now });

  let io = null;
  const notify = (userId, event, payload) => io?.to(`user:${userId}`).emit(event, payload);
  const hooks = {};
  const assist = createAssistService({ config, audit, notify, now, hooks });
  const forms = createFormService({ config, assist, audit, notify, now });
  hooks.prefill = forms.prefill;
  hooks.onSubmitted = forms.onAssistSubmitted;
  hooks.onUndone = forms.onAssistUndone;

  const app = buildHttpApp({ config, tokens, assist, audit, forms });
  const httpServer = http.createServer(app);

  io = new Server(httpServer, {
    cors: { origin: (origin, cb) => cb(null, !origin || LOCAL_ORIGIN.test(origin)) },
    maxHttpBufferSize: 1024,
  });
  io.use((socket, next) => {
    const claims = tokens.verify(socket.handshake.auth?.token);
    const user = claims ? findUser(claims.sub) : null;
    if (!user || user.role !== claims.role) return next(new Error('UNAUTHORIZED'));
    socket.data.user = user;
    next();
  });
  io.on('connection', (socket) => {
    socket.join(`user:${socket.data.user.id}`);
    if (!overrides.quiet) console.log(`[socket] ${socket.data.user.role} ${socket.data.user.id} 已連線`);
    socket.emit('ready', { userId: socket.data.user.id });
    // 用戶端不能透過 socket 下任何指令
    socket.onAny(() => {});
  });

  // 定時清理不能因為單一筆資料出錯就讓整個服務掛掉
  const timer = setInterval(() => {
    try {
      assist.sweep();
    } catch (e) {
      console.error('[sweep] assist', e);
    }
    try {
      forms.sweep();
    } catch (e) {
      console.error('[sweep] forms', e);
    }
  }, config.sweepIntervalMs);
  timer.unref();

  return {
    config,
    app,
    io,
    assist,
    forms,
    audit,
    tokens,
    httpServer,
    listen(port = config.port) {
      return new Promise((resolve) => httpServer.listen(port, config.host, () => resolve(httpServer.address().port)));
    },
    async close() {
      clearInterval(timer);
      io.close();
      await new Promise((r) => httpServer.close(() => r()));
    },
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  // demo 現場：任何漏接的錯誤都只記錄，不讓服務整個掛掉（掛掉會丟失所有進行中的陪辦）
  process.on('uncaughtException', (e) => console.error('[uncaught]', e));
  process.on('unhandledRejection', (e) => console.error('[unhandled]', e));
  // demo 現場會反覆排練同一位長輩：放寬求助／請求次數限制（身分查詢的限制維持不變）
  const ten = 10 * 60 * 1000;
  const server = createAssistServer({
    helpRequestLimit: { max: 100, windowMs: ten },
    trustedRequestLimit: { max: 100, windowMs: ten },
    pairingAttemptLimit: { max: 60, windowMs: ten },
    ticketLimit: { max: 100, windowMs: ten },
  });
  const port = await server.listen();
  console.log(`陪辦 demo 後端已啟動：http://localhost:${port}`);
  console.log(`  承辦工作台（陪辦＋表單）：http://localhost:${port}/#/console`);
  console.log(`  長輩手機模擬：http://localhost:${port}/#/elder`);
  console.log(`  並排示範：http://localhost:${port}/#/demo`);
}
