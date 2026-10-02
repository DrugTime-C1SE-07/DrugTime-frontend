import { NextResponse } from "next/server";

import { clearSessionCookie } from "@/lib/auth/session";

/** Đăng xuất: xóa cookie phiên. Backend chưa có endpoint thu hồi phiên (token hết hạn sau ≤ 20 phút). */
export async function POST() {
  const response = NextResponse.json({ ok: true });
  clearSessionCookie(response);
  return response;
}
