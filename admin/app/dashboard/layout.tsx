import { Open_Sans } from "next/font/google";
import { cookies } from "next/headers";
import type { ReactNode } from "react";

import SessionKeepAlive from "../../components/auth/SessionKeepAlive";
import Sidebar from "../../components/layout/Sidebar";
import Topbar from "../../components/layout/Topbar";
import { ToastProvider } from "../../components/ui/Toast";
import { SESSION_COOKIE, readExpiry } from "../../lib/auth/session";
import "./dashboard-theme.css";

const openSans = Open_Sans({
  subsets: ["latin", "vietnamese"],
  weight: ["400", "600", "700"],
  display: "swap",
  variable: "--font-open-sans",
});

export default function DashboardLayout({
  children,
}: {
  children: ReactNode;
}) {
  // Đọc hạn phiên ở server (cookie httpOnly) để client biết khi nào gia hạn.
  const expiresAt = readExpiry(cookies().get(SESSION_COOKIE)?.value);

  return (
    // Theme chỉ áp trong .admin-theme để trang Login (dùng chung globals.css) không đổi; bọc ngoài ToastProvider để toast cũng nhận theme.
    <div className={`admin-theme ${openSans.variable}`}>
      <ToastProvider>
        <div className="admin-shell">
          <SessionKeepAlive expiresAt={expiresAt} />
          <Sidebar />
          <main className="admin-shell__content">
            <Topbar />
            <div className="admin-shell__body">{children}</div>
          </main>
        </div>
      </ToastProvider>
    </div>
  );
}
