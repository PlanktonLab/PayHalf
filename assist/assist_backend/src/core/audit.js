import crypto from 'node:crypto';

const GENESIS = '0'.repeat(64);

/**
 * 只能新增、不能修改的稽核紀錄，每筆都包含前一筆的雜湊（hash chain）。
 * 任何一筆被竄改，verify() 都會失敗並指出位置。
 *
 * 規則：detail 只能放「發生了什麼」，絕不放個資的值。
 */
export function createAuditLog({ now = () => Date.now() } = {}) {
  const entries = [];

  const hashOf = (entry) =>
    crypto
      .createHash('sha256')
      .update(
        JSON.stringify({
          seq: entry.seq,
          ts: entry.ts,
          type: entry.type,
          actor: entry.actor,
          sessionId: entry.sessionId,
          elderId: entry.elderId,
          helperId: entry.helperId,
          summary: entry.summary,
          helperSummary: entry.helperSummary,
          detail: entry.detail,
          prevHash: entry.prevHash,
        }),
      )
      .digest('hex');

  return {
    append({ type, actor, sessionId = null, elderId = null, helperId = null, summary, helperSummary = null, detail = {} }) {
      const prevHash = entries.length ? entries[entries.length - 1].hash : GENESIS;
      const entry = {
        seq: entries.length + 1,
        ts: now(),
        type,
        actor,
        sessionId,
        elderId,
        helperId,
        summary,
        helperSummary,
        detail,
        prevHash,
      };
      entry.hash = hashOf(entry);
      entries.push(Object.freeze(entry));
      return entry;
    },
    forElder(elderId) {
      return entries.filter((e) => e.elderId === elderId);
    },
    forHelper(helperId) {
      // 協助者只能看到自己做的事，且不含「是否比對成功」等內部欄位
      return entries
        .filter((e) => e.helperId === helperId && e.actor?.role === 'helper')
        .map(({ detail, elderId, helperSummary, summary, ...rest }) => ({ ...rest, summary: helperSummary ?? summary }));
    },
    verify() {
      let prev = GENESIS;
      for (const e of entries) {
        if (e.prevHash !== prev || hashOf(e) !== e.hash) {
          return { ok: false, brokenAt: e.seq, length: entries.length };
        }
        prev = e.hash;
      }
      return { ok: true, length: entries.length, headHash: prev };
    },
    /** 僅供測試模擬竄改。 */
    _unsafeEntries: entries,
  };
}
