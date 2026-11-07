import { test } from 'node:test';
import assert from 'node:assert/strict';
import { startTestServer, wait, ELDER_SECRETS } from './harness.js';

/** 完整走一次敬老卡申請，回傳過程中的資料供各測試檢查。 */
async function runSeniorCardFlow(h) {
  const elder = await h.login('elder-wang');
  const helper = await h.login('helper-chief');
  const elderSock = h.listen(elder.token);
  const helperSock = h.listen(helper.token);
  await Promise.all([elderSock.ready, helperSock.ready]);

  const { body: pairing } = await elder.post('/elder/pairing-code');
  assert.match(pairing.code, /^\d{6}$/);

  const req = await helper.post('/helper/requests', {
    serviceId: 'senior-card',
    method: 'pairing_code',
    code: pairing.qrPayload,
  });
  assert.equal(req.status, 202);
  const id = req.body.id;
  assert.equal(req.body.status, 'pending');
  assert.equal(req.body.elder.displayName, '王○明');

  await wait();
  const incoming = elderSock.events.find((e) => e.event === 'session:update' && e.payload.id === id);
  assert.ok(incoming, '長輩手機應收到協助請求推播');
  assert.equal(incoming.payload.helper.name, '陳美玲');
  assert.equal(incoming.payload.helper.verified, true);

  assert.equal((await elder.post(`/elder/sessions/${id}/respond`, { accept: true })).body.status, 'active');

  const authorize = async (key) => {
    const r = await helper.post(`/helper/sessions/${id}/fields/${key}/request`);
    assert.equal(r.status, 200, JSON.stringify(r.body));
    const e = await elder.get(`/sessions/${id}`);
    assert.equal(e.body.pendingAuthField.key, key);
    assert.ok(e.body.pendingAuthField.purpose);
    assert.ok(e.body.pendingAuthField.retention);
    const a = await elder.post(`/elder/sessions/${id}/fields/${key}/authorize`, { approve: true });
    assert.equal(a.body.fields[key].status, 'authorized');
  };

  await helper.post(`/helper/sessions/${id}/step`, { step: 1 });
  for (const k of ['realName', 'birthday', 'idNo']) await authorize(k);
  await helper.post(`/helper/sessions/${id}/step`, { step: 2 });
  for (const k of ['residentAddress', 'phone']) await authorize(k);
  await helper.post(`/helper/sessions/${id}/step`, { step: 3 });
  const choice = await elder.post(`/elder/sessions/${id}/fields/pickup/input`, { value: 'mail' });
  assert.equal(choice.status, 200);

  const helperMid = await helper.get(`/sessions/${id}`);
  const rs = await helper.post(`/helper/sessions/${id}/request-submit`);
  assert.equal(rs.body.phase, 'reviewing');

  const done = await elder.post(`/elder/sessions/${id}/submit`, { confirm: true });
  assert.equal(done.body.status, 'completed');
  assert.match(done.body.caseNo, /^TP\d{8}-\d{5}$/);
  await wait();

  return { elder, helper, id, helperSock, elderSock, helperMid, done };
}

test('完整流程：配對碼 → 同意 → 逐項授權 → 長輩送出', async () => {
  const h = await startTestServer();
  try {
    const { elder, helper, id, done, helperMid } = await runSeniorCardFlow(h);
    const apps = await elder.get('/elder/applications');
    assert.equal(apps.body.length, 1);
    assert.equal(apps.body[0].caseNo, done.body.caseNo);
    assert.equal(apps.body[0].data, undefined, '紀錄清單不回傳申辦內容');
    const hv = await helper.get(`/sessions/${id}`);
    assert.equal(hv.body.caseNo, done.body.caseNo);
    assert.equal(helperMid.body.fields.pickup.value, 'mail', '非敏感選項協助者可以看到');
    assert.equal(hv.body.fields.pickup.value, null, '完成後連非敏感值也清除');
  } finally {
    await h.close();
  }
});

test('資安：協助者在整個流程中（API 與推播）都拿不到任何長輩個資', async () => {
  const h = await startTestServer();
  try {
    const { helperSock, helperMid, helper, id } = await runSeniorCardFlow(h);
    const corpus = [
      JSON.stringify(helperMid.body),
      JSON.stringify(helperSock.events),
      (await helper.get(`/sessions/${id}`)).raw,
      (await helper.get('/helper/sessions')).raw,
      (await helper.get('/helper/audit')).raw,
    ].join('\n');
    for (const secret of ELDER_SECRETS) {
      assert.ok(!corpus.includes(secret), `協助者資料中出現了長輩個資：${secret}`);
    }
    // 授權後狀態可見，但值為 null
    assert.equal(helperMid.body.fields.idNo.status, 'authorized');
    assert.equal(helperMid.body.fields.idNo.value, null);
  } finally {
    await h.close();
  }
});

test('資安：完成後協辦 session 不再保留個資，個資只留在申辦案件', async () => {
  const h = await startTestServer();
  try {
    const { elder, id } = await runSeniorCardFlow(h);
    const ev = await elder.get(`/sessions/${id}`);
    for (const f of Object.values(ev.body.fields)) assert.equal(f.value, null);
  } finally {
    await h.close();
  }
});

test('防列舉：以身分資料查找時，找得到與找不到的回應完全無法分辨', async () => {
  const h = await startTestServer();
  try {
    const helper = await h.login('helper-family');
    const elder = await h.login('elder-wang');
    const elderSock = h.listen(elder.token);
    await elderSock.ready;

    const hit = await helper.post('/helper/requests', {
      serviceId: 'village-activity',
      method: 'identity',
      name: '王大明',
      birthday: '1948-03-15',
      idLast4: '7499',
    });
    const miss = await helper.post('/helper/requests', {
      serviceId: 'village-activity',
      method: 'identity',
      name: '王大明',
      birthday: '1948-03-16',
      idLast4: '7499',
    });
    assert.equal(hit.status, 202);
    assert.equal(miss.status, 202);
    const shape = (v) => {
      const { id, createdAt, expiresAt, lastActivityAt, timeline, ...rest } = v;
      return { ...rest, timeline: timeline.map((t) => t.text) };
    };
    assert.deepEqual(shape(hit.body), shape(miss.body));

    await wait();
    const delivered = elderSock.events.filter((e) => e.event === 'session:update');
    assert.equal(delivered.length, 1, '只有比對成功的那一筆會送到長輩手機');
    assert.equal(delivered[0].payload.id, hit.body.id);

    // 幽靈請求逾時的樣子也跟真的一樣
    h.advance(h.server.config.pendingRequestTtlMs + 1);
    const a = await helper.get(`/sessions/${hit.body.id}`);
    const b = await helper.get(`/sessions/${miss.body.id}`);
    assert.equal(a.body.status, 'expired');
    assert.equal(b.body.status, 'expired');

    // 長輩自己的紀錄看得到有人查找他
    const log = await elder.get('/elder/audit');
    assert.ok(log.body.some((e) => e.type === 'lookup.identity'));
  } finally {
    await h.close();
  }
});

test('限流：身分查找 10 分鐘內超過 5 次會被擋下', async () => {
  const h = await startTestServer({ maxPendingPerHelper: 100 });
  try {
    const helper = await h.login('helper-family');
    const body = { serviceId: 'senior-card', method: 'identity', name: '張三', birthday: '1950-01-01', idLast4: '1234' };
    for (let i = 0; i < 5; i++) assert.equal((await helper.post('/helper/requests', body)).status, 202);
    const blocked = await helper.post('/helper/requests', body);
    assert.equal(blocked.status, 429);
    assert.equal(blocked.body.error.code, 'LOOKUP_RATE_LIMITED');
    h.advance(10 * 60 * 1000 + 1);
    assert.equal((await helper.post('/helper/requests', body)).status, 202);
  } finally {
    await h.close();
  }
});

test('配對碼：一次性、會過期、重新產生後舊碼失效', async () => {
  const h = await startTestServer();
  try {
    const elder = await h.login('elder-wang');
    const helper = await h.login('helper-chief');
    const req = (code) => helper.post('/helper/requests', { serviceId: 'senior-card', method: 'pairing_code', code });

    const c1 = (await elder.post('/elder/pairing-code')).body.code;
    const c2 = (await elder.post('/elder/pairing-code')).body.code;
    assert.equal((await req(c1)).status, 404, '舊碼應失效');
    const ok = await req(c2);
    assert.equal(ok.status, 202);
    await helper.post(`/sessions/${ok.body.id}/end`);
    assert.equal((await req(c2)).status, 404, '用過的碼不能再用');

    const c3 = (await elder.post('/elder/pairing-code')).body.code;
    h.advance(h.server.config.pairingCodeTtlMs + 1);
    assert.equal((await req(c3)).status, 404, '過期的碼不能用');
  } finally {
    await h.close();
  }
});

test('權限：角色、身分與 token 都會被檢查', async () => {
  const h = await startTestServer();
  try {
    const elder = await h.login('elder-wang');
    const otherElder = await h.login('elder-lee');
    const helper = await h.login('helper-chief');
    const otherHelper = await h.login('helper-1999');
    const code = (await elder.post('/elder/pairing-code')).body.code;
    const id = (await helper.post('/helper/requests', { serviceId: 'senior-card', method: 'pairing_code', code })).body.id;
    await elder.post(`/elder/sessions/${id}/respond`, { accept: true });
    await helper.post(`/helper/sessions/${id}/step`, { step: 1 });
    await helper.post(`/helper/sessions/${id}/fields/idNo/request`);

    assert.equal((await h.call(null, 'GET', `/sessions/${id}`)).status, 401);
    assert.equal((await h.call(elder.token + 'x', 'GET', `/sessions/${id}`)).status, 401, '竄改的 token');
    const [payload, sig] = helper.token.split('.');
    const forged = Buffer.from(JSON.stringify({ ...JSON.parse(Buffer.from(payload, 'base64url')), role: 'elder', sub: 'elder-wang' })).toString('base64url');
    assert.equal((await h.call(`${forged}.${sig}`, 'GET', `/sessions/${id}`)).status, 401, '偽造身分的 token');

    assert.equal((await helper.post(`/elder/sessions/${id}/fields/idNo/authorize`, { approve: true })).status, 403, '協助者不能替長輩授權');
    assert.equal((await helper.post(`/elder/sessions/${id}/submit`, { confirm: true })).status, 403, '協助者不能替長輩送出');
    assert.equal((await elder.post(`/helper/sessions/${id}/step`, { step: 2 })).status, 403);

    assert.equal((await otherElder.get(`/sessions/${id}`)).status, 404, '別的長輩看不到');
    assert.equal((await otherElder.post(`/elder/sessions/${id}/fields/idNo/authorize`, { approve: true })).status, 404);
    assert.equal((await otherHelper.get(`/sessions/${id}`)).status, 404, '別的協助者看不到');
    assert.equal((await otherHelper.post(`/helper/sessions/${id}/step`, { step: 2 })).status, 404);
  } finally {
    await h.close();
  }
});

test('授權規則：一次只能一個請求、同欄位最多問 3 次、資料未齊不能送出', async () => {
  const h = await startTestServer();
  try {
    const elder = await h.login('elder-wang');
    const helper = await h.login('helper-chief');
    const code = (await elder.post('/elder/pairing-code')).body.code;
    const id = (await helper.post('/helper/requests', { serviceId: 'senior-card', method: 'pairing_code', code })).body.id;
    await elder.post(`/elder/sessions/${id}/respond`, { accept: true });

    assert.equal((await helper.post(`/helper/sessions/${id}/fields/idNo/request`)).body.error.code, 'FIELD_NOT_IN_STEP');
    await helper.post(`/helper/sessions/${id}/step`, { step: 1 });
    assert.equal((await helper.post(`/helper/sessions/${id}/fields/idNo/request`)).status, 200);
    assert.equal((await helper.post(`/helper/sessions/${id}/fields/birthday/request`)).body.error.code, 'AUTH_PENDING');
    assert.equal((await helper.post(`/helper/sessions/${id}/step`, { step: 2 })).body.error.code, 'AUTH_PENDING');

    await elder.post(`/elder/sessions/${id}/fields/idNo/authorize`, { approve: false });
    await helper.post(`/helper/sessions/${id}/fields/idNo/request`);
    await elder.post(`/elder/sessions/${id}/fields/idNo/authorize`, { approve: false });
    await helper.post(`/helper/sessions/${id}/fields/idNo/request`);
    await elder.post(`/elder/sessions/${id}/fields/idNo/authorize`, { approve: false });
    const fourth = await helper.post(`/helper/sessions/${id}/fields/idNo/request`);
    assert.equal(fourth.status, 429);
    assert.equal(fourth.body.error.code, 'FIELD_REQUEST_LIMIT');

    const submit = await helper.post(`/helper/sessions/${id}/request-submit`);
    assert.equal(submit.body.error.code, 'INCOMPLETE');

    assert.equal((await elder.post(`/elder/sessions/${id}/fields/pickup/input`, { value: 'mail' })).body.error.code, 'FIELD_NOT_IN_STEP');
  } finally {
    await h.close();
  }
});

test('長輩可以撤回已授權的資料', async () => {
  const h = await startTestServer();
  try {
    const elder = await h.login('elder-wang');
    const helper = await h.login('helper-chief');
    const code = (await elder.post('/elder/pairing-code')).body.code;
    const id = (await helper.post('/helper/requests', { serviceId: 'senior-card', method: 'pairing_code', code })).body.id;
    await elder.post(`/elder/sessions/${id}/respond`, { accept: true });
    await helper.post(`/helper/sessions/${id}/step`, { step: 1 });
    await helper.post(`/helper/sessions/${id}/fields/idNo/request`);
    await elder.post(`/elder/sessions/${id}/fields/idNo/authorize`, { approve: true });
    const r = await elder.post(`/elder/sessions/${id}/fields/idNo/revoke`);
    assert.equal(r.body.fields.idNo.status, 'empty');
    assert.equal(r.body.fields.idNo.value, null);
  } finally {
    await h.close();
  }
});

test('防騷擾：同一協助者被拒絕 3 次後自動封鎖，之後請求不會再送達', async () => {
  const h = await startTestServer();
  try {
    const elder = await h.login('elder-wang');
    const helper = await h.login('helper-family');
    const elderSock = h.listen(elder.token);
    await elderSock.ready;
    const identity = { serviceId: 'senior-card', method: 'identity', name: '王大明', birthday: '1948-03-15', idLast4: '7499' };

    for (let i = 0; i < 3; i++) {
      const id = (await helper.post('/helper/requests', identity)).body.id;
      assert.equal((await elder.post(`/elder/sessions/${id}/respond`, { accept: false })).body.status, 'rejected');
    }
    await wait();
    const before = elderSock.events.length;
    const again = await helper.post('/helper/requests', identity);
    assert.equal(again.status, 202, '對協助者看起來仍然正常送出');
    await wait();
    assert.equal(elderSock.events.length, before, '但長輩不會再收到');
    assert.equal((await elder.get(`/sessions/${again.body.id}`)).status, 404);

    const code = (await elder.post('/elder/pairing-code')).body.code;
    const byCode = await helper.post('/helper/requests', { serviceId: 'senior-card', method: 'pairing_code', code });
    assert.equal(byCode.status, 403);

    const log = await elder.get('/elder/audit');
    assert.ok(log.body.some((e) => e.type === 'helper.auto_blocked'));
  } finally {
    await h.close();
  }
});

test('結束與逾時：長輩一按結束，協助者立即失效；閒置會自動結束並清除個資', async () => {
  const h = await startTestServer();
  try {
    const elder = await h.login('elder-wang');
    const helper = await h.login('helper-chief');
    const start = async () => {
      const code = (await elder.post('/elder/pairing-code')).body.code;
      const id = (await helper.post('/helper/requests', { serviceId: 'senior-card', method: 'pairing_code', code })).body.id;
      await elder.post(`/elder/sessions/${id}/respond`, { accept: true });
      return id;
    };

    const id1 = await start();
    assert.equal((await elder.post(`/sessions/${id1}/end`)).body.status, 'ended');
    assert.equal((await helper.post(`/helper/sessions/${id1}/step`, { step: 1 })).status, 409);

    const id2 = await start();
    await helper.post(`/helper/sessions/${id2}/step`, { step: 1 });
    await helper.post(`/helper/sessions/${id2}/fields/idNo/request`);
    await elder.post(`/elder/sessions/${id2}/fields/idNo/authorize`, { approve: true });
    h.advance(h.server.config.sessionIdleTtlMs + 1);
    const ended = await elder.get(`/sessions/${id2}`);
    assert.equal(ended.body.status, 'ended');
    assert.equal(ended.body.endReason, 'timeout');
    assert.equal(ended.body.fields.idNo.value, null);
  } finally {
    await h.close();
  }
});

test('同時只能接受一個協助', async () => {
  const h = await startTestServer();
  try {
    const elder = await h.login('elder-wang');
    const a = await h.login('helper-chief');
    const b = await h.login('helper-1999');
    const req = async (helper) => {
      const code = (await elder.post('/elder/pairing-code')).body.code;
      return (await helper.post('/helper/requests', { serviceId: 'senior-card', method: 'pairing_code', code })).body.id;
    };
    const id1 = await req(a);
    const id2 = await req(b);
    await elder.post(`/elder/sessions/${id1}/respond`, { accept: true });
    const r = await elder.post(`/elder/sessions/${id2}/respond`, { accept: true });
    assert.equal(r.body.error.code, 'ALREADY_ACTIVE');
  } finally {
    await h.close();
  }
});

test('稽核：hash chain 可驗證，任何竄改都會被發現', async () => {
  const h = await startTestServer();
  try {
    const { elder } = await runSeniorCardFlow(h);
    const v = await elder.get('/audit/verify');
    assert.equal(v.body.ok, true);
    assert.ok(v.body.length > 10);

    const entries = h.server.audit._unsafeEntries;
    entries[3] = { ...entries[3], summary: '被竄改的內容' };
    const v2 = await elder.get('/audit/verify');
    assert.equal(v2.body.ok, false);
    assert.equal(v2.body.brokenAt, 4);
  } finally {
    await h.close();
  }
});

test('Socket：沒有有效 token 無法連線', async () => {
  const h = await startTestServer();
  try {
    const { ready } = h.listen('not-a-token');
    await assert.rejects(ready, /UNAUTHORIZED/);
  } finally {
    await h.close();
  }
});

test('台北通 App 登入：以帳號換取長輩 token，未開通帳號會被拒絕', async () => {
  const h = await startTestServer();
  try {
    const ok = await h.call(null, 'POST', '/auth/townpass-login', { accountId: '7f3562f4-bb3f-4ec7-89b9-da3b4b5ff250' });
    assert.equal(ok.status, 200);
    assert.equal(ok.body.user.id, 'elder-wang');
    const me = await h.call(ok.body.token, 'GET', '/me');
    assert.equal(me.body.name, '王大明');
    const bad = await h.call(null, 'POST', '/auth/townpass-login', { accountId: 'someone-else' });
    assert.equal(bad.status, 401);
  } finally {
    await h.close();
  }
});

test('送出後 10 秒內可撤回：案件收回、資料回到確認畫面；超過時間就不能撤回', async () => {
  const h = await startTestServer();
  try {
    const { elder, helper, id, done } = await runSeniorCardFlow(h);
    assert.ok(done.body.undoUntil > 0);
    const undone = await elder.post(`/elder/sessions/${id}/undo`);
    assert.equal(undone.status, 200, JSON.stringify(undone.body));
    assert.equal(undone.body.status, 'active');
    assert.equal(undone.body.phase, 'reviewing');
    assert.equal(undone.body.fields.idNo.value, 'A102837499', '資料回到長輩的確認畫面');
    assert.equal((await elder.get('/elder/applications')).body.length, 0, '案件被收回');
    const hv = await helper.get(`/sessions/${id}`);
    assert.equal(hv.body.fields.idNo.value, null, '撤回後協助者仍看不到個資');
    assert.equal((await helper.post(`/elder/sessions/${id}/undo`)).status, 403, '協助者不能替長輩撤回');

    const again = await elder.post(`/elder/sessions/${id}/submit`, { confirm: true });
    assert.equal(again.body.status, 'completed');
    h.advance(h.server.config.undoWindowMs + 1);
    const late = await elder.post(`/elder/sessions/${id}/undo`);
    assert.equal(late.status, 409);
    assert.equal(late.body.error.code, 'TOO_LATE');
  } finally {
    await h.close();
  }
});
