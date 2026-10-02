"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";

const MESSAGES: Record<string, string> = {
  invalid_credentials: "Email hoặc mật khẩu không đúng.",
  admin_required: "Tài khoản này không có quyền quản trị.",
  invalid_input: "Email không hợp lệ hoặc mật khẩu ngắn hơn 8 ký tự.",
  rate_limited: "Bạn thao tác quá nhanh, vui lòng thử lại sau ít phút.",
  unavailable: "Hệ thống đang bận, vui lòng thử lại sau.",
};

export default function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const response = await fetch("/api/session/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      if (response.ok) {
        router.replace("/dashboard");
        router.refresh();
        return;
      }
      const data = await response.json().catch(() => ({}));
      setError(MESSAGES[data?.error] ?? MESSAGES.unavailable);
    } catch {
      setError("Không kết nối được máy chủ, vui lòng kiểm tra mạng.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form className="auth-form" onSubmit={handleSubmit} noValidate>
      <label className="auth-form__field">
        <span>Email</span>
        <input
          type="email"
          name="email"
          autoComplete="username"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          required
        />
      </label>
      <label className="auth-form__field">
        <span>Mật khẩu</span>
        <input
          type="password"
          name="password"
          autoComplete="current-password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          required
        />
      </label>
      {error ? (
        <p className="auth-form__error" role="alert">
          {error}
        </p>
      ) : null}
      <button className="auth-form__submit" type="submit" disabled={submitting}>
        {submitting ? "Đang đăng nhập..." : "Đăng nhập"}
      </button>
    </form>
  );
}
