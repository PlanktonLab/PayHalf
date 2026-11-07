import crypto from 'node:crypto';

/**
 * 極簡的 HMAC-SHA256 簽章 token（JWT 概念，不引入額外套件）。
 * 格式：base64url(payload).base64url(signature)
 * 正式版應改接台北通既有的 OAuth / 實名身分驗證。
 */
export function createTokenService({ secret, ttlMs, now = () => Date.now() }) {
  const sign = (data) => crypto.createHmac('sha256', secret).update(data).digest('base64url');

  return {
    issue(claims) {
      const payload = Buffer.from(
        JSON.stringify({ ...claims, iat: now(), exp: now() + ttlMs }),
      ).toString('base64url');
      return `${payload}.${sign(payload)}`;
    },
    verify(token) {
      if (typeof token !== 'string') return null;
      const [payload, signature] = token.split('.');
      if (!payload || !signature) return null;
      const expected = Buffer.from(sign(payload));
      const actual = Buffer.from(signature);
      if (expected.length !== actual.length || !crypto.timingSafeEqual(expected, actual)) return null;
      try {
        const claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
        if (typeof claims.exp !== 'number' || claims.exp < now()) return null;
        return claims;
      } catch {
        return null;
      }
    },
  };
}
