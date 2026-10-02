import { cookies } from "next/headers";
import type { ReactNode } from "react";

import SessionKeepAlive from "../../components/auth/SessionKeepAlive";
import Sidebar from "../../components/layout/Sidebar";
import Topbar from "../../components/layout/Topbar";
import { SESSION_COOKIE, readExpiry } from "../../lib/auth/session";

export default function DashboardLayout({
  children,
}: {
  children: ReactNode;
}) {
  // Đọc hạn phiên ở server (cookie httpOnly) để client biết khi nào gia hạn.
  const expiresAt = readExpiry(cookies().get(SESSION_COOKIE)?.value);

  return (
    <div className="admin-shell">
      <SessionKeepAlive expiresAt={expiresAt} />
      <Sidebar />
      <main className="admin-shell__content">
        <Topbar />
        <div className="admin-shell__body">{children}</div>
      </main>
    </div>
  );
}
