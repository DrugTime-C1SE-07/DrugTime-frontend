import type { NextRequest, NextResponse } from "next/server";

/**
 * Phiên Admin Web lưu trong cookie httpOnly: JavaScript trên trình duyệt không đọc được token.
 * File này không dùng API riêng của Node để middleware (edge runtime) import được.
 */
export const SESSION_COOKIE = "dt_admin_session";

/** Phiên do Backend API cấp (`session` trong phản hồi /auth/admin/*). */
export type BackendSession = {
  access_token: string;
  token_type: "bearer";
  session_type: "mobile" | "admin_web";
  expires_at: string;
  expires_in: number;
};

export type AdminAuthResult = {
  user_id: string;
  session: BackendSession;
};

/**
 * Thời điểm hết hạn (ms) đọc từ `exp` của JWT. Không kiểm chữ ký: Backend API kiểm ở mỗi request,
 * ở đây chỉ để biết khi nào chuyển người dùng về trang đăng nhập.
 */
export function readExpiry(token: string | undefined): number | null {
  const payload = token?.split(".")[1];
  if (!payload) return null;
  try {
    const base64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    const exp = JSON.parse(atob(padded)).exp;
    return typeof exp === "number" ? exp * 1000 : null;
  } catch {
    return null;
  }
}

export function isSessionValid(token: string | undefined, now = Date.now()): boolean {
  const expiry = readExpiry(token);
  return expiry !== null && expiry > now;
}

function isSecure(request: NextRequest): boolean {
  return process.env.NODE_ENV === "production" || request.nextUrl.protocol === "https:";
}

export function setSessionCookie(
  response: NextResponse,
  request: NextRequest,
  session: BackendSession,
): void {
  response.cookies.set({
    name: SESSION_COOKIE,
    value: session.access_token,
    httpOnly: true,
    sameSite: "lax",
    secure: isSecure(request),
    path: "/",
    maxAge: session.expires_in,
  });
}

export function clearSessionCookie(response: NextResponse): void {
  response.cookies.set({
    name: SESSION_COOKIE,
    value: "",
    httpOnly: true,
    sameSite: "lax",
    path: "/",
    maxAge: 0,
  });
}
