/**
 * Đọc mã liên kết từ link mời `https://<host>/link#code=<mã>` (task 3.14).
 * Mã nằm sau dấu `#` nên không bao giờ được gửi lên server; trang chỉ đọc nó ở trình duyệt.
 * Cùng định dạng với app: 10 ký tự chữ hoa và số, bỏ 0 O 1 I L (contract `LinkCode.code`).
 */

const LINK_CODE = /^[A-HJKMNP-Z2-9]{10}$/;

export const APP_PACKAGE = 'vn.drugtime.drugtime_mobile';

/** `#code=K7M2Q9XAR4` → `K7M2Q9XAR4`; thiếu hoặc sai định dạng → `null`. */
export function parseInviteHash(hash: string): string | null {
  const params = new URLSearchParams(hash.startsWith('#') ? hash.slice(1) : hash);
  const code = params.get('code');
  return code !== null && LINK_CODE.test(code) ? code : null;
}

/** `K7M2Q9XAR4` → `K7M2 Q9XA R4`, giống cách app hiển thị. */
export function groupCode(code: string): string {
  return code.match(/.{1,4}/g)?.join(' ') ?? '';
}

/**
 * Intent URL mở thẳng app DrugTime trên Android, dùng khi trình duyệt (ví dụ trong Zalo) không
 * tự chuyển link sang app. Trình duyệt xử lý URL `intent:` ngay trên máy, không gửi đi đâu,
 * nên đặt mã ở query không làm lộ mã. Chưa cài app thì mở trang tải app.
 */
export function androidIntentUrl(code: string, host: string, fallbackUrl: string): string {
  return (
    `intent://${host}/link?code=${encodeURIComponent(code)}` +
    `#Intent;scheme=https;package=${APP_PACKAGE};` +
    `S.browser_fallback_url=${encodeURIComponent(fallbackUrl)};end`
  );
}
