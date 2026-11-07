import { test } from 'node:test';
import assert from 'node:assert/strict';
import { startTestServer, wait, ELDER_SECRETS } from './harness.js';

const CHONGYANG = { q1: '王大明', q2: '0912-345-678', q3: '素食', q4: '需要接送', q5: '1', q6: '我同意' };

test('公開表單與 QR Code 海報', async () => {
  const h = await startTestServer();
  try {
    const f = await h.call(null, 'GET', '/forms/chongyang');
    assert.equal(f.status, 200);
    assert.equal(f.body.title, '重陽敬老餐會報名');
    assert.match(f.body.url, /\/f\/chongyang$/);
    assert.equal(f.body.fields.find((x) => x.id === 'q1').profile, 'realName');
    for (const layout of ['a4', 'stand', 'postcard']) {
      const res = await fetch(`${h.base}/api/forms/chongyang/poster.svg?layout=${layout}`);
      assert.equal(res.status, 200);
      assert.match(res.headers.get('content-type'), /image\/svg\+xml/);
      const svg = await res.text();
      assert.ok(svg.startsWith('<svg'));
      assert.ok(svg.includes('重陽敬老餐會報名'));
    }
    const page = await fetch(`${h.base}/f/chongyang`);
    assert.ok((await page.text()).includes('台北通'));
    assert.equal((await h.call(null, 'GET', '/forms/nope')).status, 404);
    // 只有開放陪辦的已發布表單會出現在陪辦業務清單
    const svc = await h.call(null, 'GET', '/services');
    assert.ok(svc.body.some((s) => s.id === 'form-flu-shot'));
  } finally {
    await h.close();
  }
});

test('長輩自己填：帶入個資、送出、後台即時看到，一人限填一次', async () => {
  const h = await startTestServer();
  try {
    const elder = await h.login('elder-wang');
    const staff = await h.login('helper-1999');
    const sock = h.listen(staff.token);
    await sock.ready;

    const open = await elder.get('/elder/forms/chongyang');
    assert.equal(open.body.prefill.q1, '王大明');
    assert.equal(open.body.prefill.q2, '0912-345-678');
    assert.equal(open.body.submitted, null);

    const missing = await elder.post('/elder/forms/chongyang/submit', { answers: { q1: '王大明' } });
    assert.equal(missing.body.error.code, 'INCOMPLETE');
    const bad = await elder.post('/elder/forms/chongyang/submit', { answers: { ...CHONGYANG, q3: '牛排' } });
    assert.equal(bad.body.error.code, 'INVALID_OPTION');

    const ok = await elder.post('/elder/forms/chongyang/submit', { answers: CHONGYANG });
    assert.equal(ok.status, 200, JSON.stringify(ok.body));
    assert.match(ok.body.receiptNo, /^F\d{8}-\d{5}$/);

    await wait();
    assert.ok(sock.events.some((e) => e.event === 'form:response' && e.payload.formId === 'chongyang'));
    const rows = await staff.get('/console/forms/chongyang/responses');
    assert.equal(rows.body[0]._receipt, ok.body.receiptNo);
    assert.equal(rows.body[0]._via, 'self');
    assert.equal(rows.body[0].q3, '素食');
    assert.ok(rows.body.some((r) => r._sample), '預設表單附示意回覆');

    const again = await elder.post('/elder/forms/chongyang/submit', { answers: CHONGYANG });
    assert.equal(again.body.error.code, 'ALREADY_SUBMITTED');
    assert.ok((await elder.get('/elder/forms/chongyang')).body.submitted);
  } finally {
    await h.close();
  }
});

test('表單後台只給承辦人員；發布新表單後可以填、草稿不公開', async () => {
  const h = await startTestServer();
  try {
    const family = await h.login('helper-family');
    assert.equal((await family.get('/console/forms')).body.error.code, 'NOT_STAFF');
    const elder = await h.login('elder-lee');
    assert.equal((await elder.get('/console/forms')).status, 403);

    const chief = await h.login('helper-chief');
    const body = {
      title: '社區健走報名',
      dept: '正得里辦公處',
      fields: [
        { id: 'a', type: 'text', label: '你的姓名' },
        { id: 'b', type: 'checkbox', label: '哪幾天', options: ['六', '日'] },
      ],
      status: 'draft',
    };
    const put = await h.call(chief.token, 'PUT', '/console/forms/walk-2026', body);
    assert.equal(put.status, 200, JSON.stringify(put.body));
    assert.equal((await h.call(null, 'GET', '/forms/walk-2026')).status, 404);

    await h.call(chief.token, 'PUT', '/console/forms/walk-2026', { ...body, status: 'open' });
    const open = await elder.get('/elder/forms/walk-2026');
    assert.equal(open.body.prefill.a, '李秀英');
    const sub = await elder.post('/elder/forms/walk-2026/submit', { answers: { a: '李秀英', b: ['六', '日'] } });
    assert.equal(sub.status, 200, JSON.stringify(sub.body));
    const rows = await chief.get('/console/forms/walk-2026/responses');
    assert.equal(rows.body[0].b, '六、日');
    const list = await chief.get('/console/forms');
    assert.equal(list.body.find((f) => f.id === 'walk-2026').responses, 1);

    await h.call(chief.token, 'PUT', '/console/forms/walk-2026', { ...body, status: 'closed' });
    const closed = await elder.post('/elder/forms/walk-2026/submit', { answers: { a: '李秀英', b: '六' } });
    assert.equal(closed.body.error.code, 'FORM_CLOSED');
  } finally {
    await h.close();
  }
});

test('填到一半找線上客服：已填的帶進陪辦，陪辦送出後寫進回覆，客服看不到個資', async () => {
  const h = await startTestServer();
  try {
    const elder = await h.login('elder-wang');
    const staff = await h.login('helper-1999');
    const elderSock = h.listen(elder.token);
    const staffSock = h.listen(staff.token);
    await Promise.all([elderSock.ready, staffSock.ready]);

    const help = await elder.post('/elder/forms/flu-shot/help', {
      mode: 'online',
      answers: { q1: '王大明', q2: 'A102837499', q5: '11/15（六）上午' },
      question: '以前打疫苗有沒有不舒服',
    });
    assert.equal(help.status, 200, JSON.stringify(help.body));
    const ticketId = help.body.ticket.id;
    await wait();
    const pushed = staffSock.events.find((e) => e.event === 'form:ticket');
    assert.equal(pushed.payload.elder.displayName, '王○明');
    assert.equal(pushed.payload.answered, 3);
    for (const secret of ELDER_SECRETS) assert.ok(!JSON.stringify(pushed.payload).includes(secret));

    const tickets = await staff.get('/console/help-tickets');
    assert.equal(tickets.body.length, 1);
    const take = await staff.post(`/console/help-tickets/${ticketId}/take`);
    assert.equal(take.status, 202, JSON.stringify(take.body));
    const id = take.body.id;
    assert.equal(take.body.serviceId, 'form-flu-shot');
    assert.equal(take.body.fields.q1.status, 'authorized');
    assert.equal(take.body.fields.q1.value, null, '客服看不到帶入的個資');
    assert.equal(take.body.fields.q5.value, '11/15（六）上午');
    // 第二位客服不能再接
    assert.equal((await staff.post(`/console/help-tickets/${ticketId}/take`)).body.error.code, 'TICKET_GONE');

    assert.equal((await elder.post(`/elder/sessions/${id}/respond`, { accept: true })).body.status, 'active');
    let s = (await elder.get(`/sessions/${id}`)).body;
    // 從還沒完成的基本資料那一步開始（出生日期、電話還沒填）
    assert.equal(s.currentStep, 1);
    for (const key of ['q3', 'q4']) {
      const r = await elder.post(`/elder/sessions/${id}/fields/${key}/self-authorize`);
      assert.equal(r.status, 200, JSON.stringify(r.body));
    }
    s = (await elder.get(`/sessions/${id}`)).body;
    await elder.post(`/elder/sessions/${id}/step`, { step: 2 });
    assert.equal((await elder.post(`/elder/sessions/${id}/fields/q6/input`, { value: '沒有' })).status, 200);
    await elder.post(`/elder/sessions/${id}/step`, { step: 3 });
    const txt = await elder.post(`/elder/sessions/${id}/fields/q7/input`, { value: '有高血壓' });
    assert.equal(txt.status, 200, JSON.stringify(txt.body));
    assert.equal((await elder.post(`/elder/sessions/${id}/fields/q8/input`, { value: '我同意' })).status, 200);

    const rs = await staff.post(`/helper/sessions/${id}/request-submit`);
    assert.equal(rs.status, 200, JSON.stringify(rs.body));
    const done = await elder.post(`/elder/sessions/${id}/submit`, { confirm: true });
    assert.equal(done.body.status, 'completed');

    const rows = await staff.get('/console/forms/flu-shot/responses');
    const row = rows.body[0];
    assert.equal(row._via, 'assist');
    assert.equal(row._by, '1999 客服陪辦');
    assert.equal(row.q2, 'A102837499');
    assert.equal(row.q7, '有高血壓');
    assert.equal(row._receipt, done.body.caseNo);

    // 10 秒內撤回：表單回覆也收回
    const undo = await elder.post(`/elder/sessions/${id}/undo`);
    assert.equal(undo.status, 200, JSON.stringify(undo.body));
    const after = await staff.get('/console/forms/flu-shot/responses');
    assert.ok(!after.body.some((r) => r._receipt === done.body.caseNo));
  } finally {
    await h.close();
  }
});

test('請旁邊的人幫我：配對碼綁定這份表單；信任的人收到的求助帶著表單', async () => {
  const h = await startTestServer();
  try {
    const elder = await h.login('elder-wang');
    const r = await elder.post('/elder/forms/chongyang/help', { mode: 'nearby', answers: { q3: '葷食' } });
    assert.match(r.body.code, /^\d{6}$/);
    const stranger = await h.login('helper-chief');
    const req = await stranger.post('/helper/requests', { method: 'pairing_code', serviceId: 'senior-card', code: r.body.code });
    assert.equal(req.status, 202, JSON.stringify(req.body));
    assert.equal(req.body.serviceId, 'form-chongyang');
    assert.equal(req.body.fields.q3.value, '葷食');

    const fam = await elder.post('/elder/forms/flu-shot/help', { mode: 'trusted', helperId: 'helper-family' });
    assert.equal(fam.body.help.serviceId, 'form-flu-shot');
    const family = await h.login('helper-family');
    const list = await family.get('/helper/help-requests');
    assert.equal(list.body[0].serviceTitle, '長者流感疫苗預約');
  } finally {
    await h.close();
  }
});
