import { Suspense } from "react";
import LoginBackground from "../../../components/auth/LoginBackground";
import LoginForm from "../../../components/auth/LoginForm";
import { ToastProvider } from "../../../components/ui/Toast";

export default function LoginPage() {
  return (
    <ToastProvider>
      <main className="admin-login-page">
        <LoginBackground />
        <div className="admin-login-stage">
          <Suspense fallback={<div className="admin-login-loading">Đang tải…</div>}>
            <LoginForm />
          </Suspense>
        </div>
      </main>
    </ToastProvider>
  );
}
