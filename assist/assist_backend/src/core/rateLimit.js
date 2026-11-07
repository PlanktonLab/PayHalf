/** 滑動視窗限流：key 在 windowMs 內最多 max 次。 */
export function createRateLimiter({ max, windowMs, now = () => Date.now() }) {
  const hits = new Map();
  return {
    /** 回傳 true 表示允許並記錄一次；false 表示超過上限。 */
    take(key) {
      const t = now();
      const list = (hits.get(key) ?? []).filter((ts) => t - ts < windowMs);
      if (list.length >= max) {
        hits.set(key, list);
        return false;
      }
      list.push(t);
      hits.set(key, list);
      return true;
    },
    remaining(key) {
      const t = now();
      const list = (hits.get(key) ?? []).filter((ts) => t - ts < windowMs);
      return Math.max(0, max - list.length);
    },
  };
}
