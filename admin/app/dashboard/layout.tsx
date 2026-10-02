import type { ReactNode } from "react";
import Sidebar from "../../components/layout/Sidebar";
import Topbar from "../../components/layout/Topbar";
import { ToastProvider } from "../../components/ui/Toast";

export default function DashboardLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <ToastProvider>
      <div className="admin-shell">
        <Sidebar />
        <main className="admin-shell__content">
          <Topbar />
          <div className="admin-shell__body">{children}</div>
        </main>
      </div>
    </ToastProvider>
  );
}
