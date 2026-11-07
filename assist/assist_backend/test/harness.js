import { io as connect } from 'socket.io-client';
import { createAssistServer } from '../src/server.js';

/** 啟動一個使用假時鐘的測試伺服器。 */
export async function startTestServer(overrides = {}) {
  const clock = { t: Date.UTC(2026, 10, 7, 2, 0, 0) };
  const server = createAssistServer({ staticDir: null, adminDir: null, quiet: true, now: () => clock.t, ...overrides });
  const port = await server.listen(0);
  const base = `http://localhost:${port}`;
  const sockets = [];

  async function call(token, method, path, body) {
    const res = await fetch(base + '/api' + path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    return { status: res.status, body: text ? JSON.parse(text) : null, raw: text };
  }

  async function login(userId) {
    const { body } = await call(null, 'POST', '/auth/demo-login', { userId });
    const token = body.token;
    return {
      token,
      get: (p) => call(token, 'GET', p),
      post: (p, b = {}) => call(token, 'POST', p, b),
    };
  }

  /** 連上 socket 並收集所有推播。 */
  function listen(token) {
    const events = [];
    const socket = connect(base, { auth: { token }, transports: ['websocket'], forceNew: true });
    sockets.push(socket);
    socket.onAny((event, payload) => events.push({ event, payload }));
    const ready = new Promise((resolve, reject) => {
      socket.on('ready', resolve);
      socket.on('connect_error', reject);
    });
    return { socket, events, ready };
  }

  return {
    server,
    clock,
    base,
    call,
    login,
    listen,
    advance(ms) {
      clock.t += ms;
      server.assist.sweep();
    },
    async close() {
      sockets.forEach((s) => s.close());
      await server.close();
    },
  };
}

export const wait = (ms = 50) => new Promise((r) => setTimeout(r, ms));

export const ELDER_SECRETS = [
  '王大明',
  '1948-03-15',
  'A102837499',
  '0912-345-678',
  '臺北市中山區吉林路 69 號 4 樓',
];
