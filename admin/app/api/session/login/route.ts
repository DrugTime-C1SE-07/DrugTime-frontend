import { NextResponse, type NextRequest } from "next/server";

import { apiFetch, toBrowserError } from "@/lib/api/client";
import { setSessionCookie, type AdminAuthResult } from "@/lib/auth/session";

/** Đăng nhập admin: gọi Backend API, đặt cookie httpOnly; trình duyệt không nhận token. */
export async function POST(request: NextRequest) {
  let email = "";
  let password = "";
  try {
    const body = await request.json();
    email = String(body?.email ?? "");
    password = String(body?.password ?? "");
  } catch {
    return NextResponse.json({ error: "invalid_input" }, { status: 422 });
  }

  try {
    const result = await apiFetch<AdminAuthResult>("/auth/admin/login", {
      body: { email, password },
    });
    const response = NextResponse.json({ expires_at: result.session.expires_at });
    setSessionCookie(response, request, result.session);
    return response;
  } catch (error) {
    const { status, code } = toBrowserError(error, "login");
    return NextResponse.json({ error: code }, { status });
  }
}
