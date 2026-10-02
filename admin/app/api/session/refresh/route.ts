import { NextResponse, type NextRequest } from "next/server";

import { apiFetch, toBrowserError } from "@/lib/api/client";
import {
  SESSION_COOKIE,
  clearSessionCookie,
  setSessionCookie,
  type AdminAuthResult,
} from "@/lib/auth/session";

/** Gia hạn phiên admin (20 phút) khi người dùng còn thao tác. */
export async function POST(request: NextRequest) {
  const token = request.cookies.get(SESSION_COOKIE)?.value;
  if (!token) {
    return NextResponse.json({ error: "session_expired" }, { status: 401 });
  }

  try {
    const result = await apiFetch<AdminAuthResult>("/auth/admin/session/refresh", {
      body: { session_token: token },
    });
    const response = NextResponse.json({ expires_at: result.session.expires_at });
    setSessionCookie(response, request, result.session);
    return response;
  } catch (error) {
    const { status, code } = toBrowserError(error, "session");
    const response = NextResponse.json({ error: code }, { status });
    if (status === 401 || status === 403) {
      clearSessionCookie(response);
    }
    return response;
  }
}
