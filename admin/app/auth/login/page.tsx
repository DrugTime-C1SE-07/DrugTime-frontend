import { Suspense } from "react";
import LoginForm from "../../../components/auth/LoginForm";
import { ToastProvider } from "../../../components/ui/Toast";

export default function LoginPage() {
  return (
    <ToastProvider>
      <main className="admin-login-page">
        <Suspense
          fallback={
            <div className="admin-login-loading">
              <span>Đang chuẩn bị môi trường bảo mật...</span>
            </div>
          }
        >
          <LoginForm />
        </Suspense>
      </main>
    </ToastProvider>
  );
}
