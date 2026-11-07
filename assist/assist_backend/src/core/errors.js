export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export const badRequest = (msg, code = 'BAD_REQUEST') => new ApiError(400, code, msg);
export const unauthorized = (msg = '請先登入', code = 'UNAUTHORIZED') => new ApiError(401, code, msg);
export const forbidden = (msg = '您沒有權限執行這個動作', code = 'FORBIDDEN') => new ApiError(403, code, msg);
export const notFound = (msg = '找不到資料', code = 'NOT_FOUND') => new ApiError(404, code, msg);
export const conflict = (msg, code = 'CONFLICT') => new ApiError(409, code, msg);
export const tooMany = (msg, code = 'RATE_LIMITED') => new ApiError(429, code, msg);
