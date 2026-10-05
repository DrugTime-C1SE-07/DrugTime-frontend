import { NextResponse, type NextRequest } from "next/server";

import { SESSION_COOKIE, isSessionValid } from "./lib/auth/session";

/**
 * Chặn /dashboard khi chưa có phiên hoặc phiên đã hết hạn. Chỉ kiểm có phiên và hạn;
 * quyền admin vẫn do Backend API quyết định ở mỗi request.
 */
export function middleware(request: NextRequest) {
  const token = request.cookies.get(SESSION_COOKIE)?.value;
  const valid = isSessionValid(token);
  const { pathname } = request.nextUrl;

  if (pathname.startsWith("/dashboard") && !valid) {
    const url = request.nextUrl.clone();
    url.pathname = "/auth/login";
    url.search = "";
    const response = NextResponse.redirect(url);
    if (token) {
      response.cookies.delete(SESSION_COOKIE);
    }
    return response;
  }

  if (pathname === "/auth/login" && valid) {
    const url = request.nextUrl.clone();
    url.pathname = "/dashboard";
    url.search = "";
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*", "/auth/login"],
};
