"use client";

import React, { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { AlertCircle, ArrowRight, Clock, Eye, EyeOff, Lock, Mail, Pill } from "lucide-react";
import { useToast } from "../ui/Toast";

const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION_MS = 15 * 60 * 1000; // 15 minutes lockout
const MIN_PASSWORD_LENGTH = 8;

/** Thông báo theo mã lỗi của /api/session/login (xem `toBrowserError` trong lib/api/client.ts). */
const MESSAGES: Record<string, string> = {
  invalid_credentials: "Email hoặc mật khẩu không đúng.",
  admin_required: "Tài khoản này không có quyền quản trị.",
  invalid_input: "Email không hợp lệ hoặc mật khẩu ngắn hơn 8 ký tự.",
  rate_limited: "Bạn thao tác quá nhanh, vui lòng thử lại sau ít phút.",
  unavailable: "Hệ thống đang bận, vui lòng thử lại sau.",
};

export default function LoginForm() {
  const router = useRouter();
  const { showToast } = useToast();

  // Form State
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Validation State
  const [fieldErrors, setFieldErrors] = useState<{ email?: string; password?: string }>({});
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Security Lockout Protection State
  const [failedAttempts, setFailedAttempts] = useState<number>(0);
  const [lockoutEndTime, setLockoutEndTime] = useState<number | null>(null);
  const [remainingLockoutSeconds, setRemainingLockoutSeconds] = useState<number>(0);

  // Restore lockout state from sessionStorage on mount
  useEffect(() => {
    try {
      const storedLockout = sessionStorage.getItem("drugtime_lockout_until");
      const storedAttempts = sessionStorage.getItem("drugtime_failed_attempts");

      if (storedAttempts) {
        setFailedAttempts(parseInt(storedAttempts, 10) || 0);
      }

      if (storedLockout) {
        const lockoutTime = parseInt(storedLockout, 10);
        if (lockoutTime > Date.now()) {
          setLockoutEndTime(lockoutTime);
        } else {
          sessionStorage.removeItem("drugtime_lockout_until");
          sessionStorage.removeItem("drugtime_failed_attempts");
        }
      }
    } catch {
      // Ignore storage errors
    }
  }, []);

  // Countdown timer for lockout
  useEffect(() => {
    if (!lockoutEndTime) {
      setRemainingLockoutSeconds(0);
      return;
    }

    const updateRemaining = () => {
      const remainingMs = lockoutEndTime - Date.now();
      if (remainingMs <= 0) {
        setLockoutEndTime(null);
        setFailedAttempts(0);
        setRemainingLockoutSeconds(0);
        sessionStorage.removeItem("drugtime_lockout_until");
        sessionStorage.removeItem("drugtime_failed_attempts");
      } else {
        setRemainingLockoutSeconds(Math.ceil(remainingMs / 1000));
      }
    };

    updateRemaining();
    const interval = setInterval(updateRemaining, 1000);
    return () => clearInterval(interval);
  }, [lockoutEndTime]);

  // Format countdown minutes and seconds
  const formatCountdown = (totalSec: number) => {
    const mins = Math.floor(totalSec / 60);
    const secs = totalSec % 60;
    return `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
  };

  const isLockedOut = Boolean(lockoutEndTime && remainingLockoutSeconds > 0);

  // Client-side field validations
  const validateForm = (): boolean => {
    const errors: { email?: string; password?: string } = {};

    const trimmedEmail = email.trim();
    if (!trimmedEmail) {
      errors.email = "Vui lòng nhập địa chỉ email công vụ.";
    } else {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(trimmedEmail)) {
        errors.email = "Định dạng email không hợp lệ (ví dụ: duocsicuatoi@drugtime.vn).";
      }
    }

    if (!password) {
      errors.password = "Vui lòng nhập mật khẩu tài khoản.";
    } else if (password.length < MIN_PASSWORD_LENGTH) {
      errors.password = `Mật khẩu bảo mật phải có ít nhất ${MIN_PASSWORD_LENGTH} ký tự.`;
    }

    setFieldErrors(errors);
    return Object.keys(errors).length === 0;
  };

  // Submit Handler
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitError(null);

    if (isLockedOut) {
      setSubmitError(
        `Tài khoản đang bị tạm khóa để bảo vệ an ninh. Vui lòng thử lại sau ${formatCountdown(remainingLockoutSeconds)}.`
      );
      return;
    }

    if (!validateForm()) {
      return;
    }

    setIsSubmitting(true);

    try {
      const response = await fetch("/api/session/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email.trim(), password }),
      });

      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        const code: string = typeof data?.error === "string" ? data.error : "unavailable";

        // Chỉ sai email/mật khẩu mới tính vào số lần thử; lỗi hệ thống hay quyền thì báo thẳng.
        if (code !== "invalid_credentials") {
          setSubmitError(MESSAGES[code] ?? MESSAGES.unavailable);
          setIsSubmitting(false);
          return;
        }

        const nextAttempts = failedAttempts + 1;
        setFailedAttempts(nextAttempts);
        sessionStorage.setItem("drugtime_failed_attempts", nextAttempts.toString());

        if (nextAttempts >= MAX_FAILED_ATTEMPTS) {
          const lockoutTime = Date.now() + LOCKOUT_DURATION_MS;
          setLockoutEndTime(lockoutTime);
          sessionStorage.setItem("drugtime_lockout_until", lockoutTime.toString());
          setSubmitError(
            "Bạn đã nhập sai thông tin quá 5 lần. Để bảo vệ an toàn dữ liệu y tế, hệ thống tạm khóa đăng nhập trong 15 phút."
          );
        } else if (nextAttempts >= 3) {
          setSubmitError(
            `Email công vụ hoặc mật khẩu không chính xác. Cảnh báo an ninh: Bạn đã thử sai ${nextAttempts}/${MAX_FAILED_ATTEMPTS} lần.`
          );
        } else {
          setSubmitError(MESSAGES.invalid_credentials);
        }

        setIsSubmitting(false);
        return;
      }

      // Success
      sessionStorage.removeItem("drugtime_failed_attempts");
      sessionStorage.removeItem("drugtime_lockout_until");

      showToast({
        type: "success",
        title: "Đăng nhập thành công",
      });

      router.replace("/dashboard");
      router.refresh();
    } catch {
      setSubmitError("Không kết nối được máy chủ, vui lòng kiểm tra mạng.");
      setIsSubmitting(false);
    }
  };

  return (
    <section className="admin-login-card" aria-labelledby="admin-login-title">
      <div className="admin-login-brand">
        <span className="admin-login-brand__icon" aria-hidden="true">
          <Pill size={20} strokeWidth={2.4} />
        </span>
        <span className="admin-login-brand__name">DrugTime Admin</span>
      </div>
      <h1 id="admin-login-title" className="admin-login-heading">
        Đăng nhập
      </h1>
      <p className="admin-login-subheading">Tài khoản quản trị viên DrugTime</p>

      {isLockedOut ? (
        <div className="admin-login-lockout-banner" role="alert">
          <Clock size={20} strokeWidth={2.2} className="admin-login-lockout-icon" aria-hidden="true" />
          <div>
            <strong>Tạm khóa đăng nhập</strong>
            <p>
              Sai quá {MAX_FAILED_ATTEMPTS} lần. Thử lại sau{" "}
              <span className="admin-login-countdown">{formatCountdown(remainingLockoutSeconds)}</span>.
            </p>
          </div>
        </div>
      ) : submitError ? (
        <div className="admin-login-alert" role="alert">
          <AlertCircle size={18} strokeWidth={2.4} className="admin-login-alert__icon" aria-hidden="true" />
          <span>{submitError}</span>
        </div>
      ) : null}

      <form onSubmit={handleSubmit} className="admin-login-form" noValidate>
        <div className="admin-login-field">
          <label htmlFor="admin-email" className="admin-login-label">
            Email
          </label>
          <div className={`admin-login-input-wrap${fieldErrors.email ? " admin-login-input-wrap--error" : ""}`}>
            <Mail className="admin-login-input-icon" size={18} strokeWidth={2} aria-hidden="true" />
            <input
              id="admin-email"
              type="email"
              className="admin-login-input"
              placeholder="name@drugtime.vn"
              value={email}
              disabled={isSubmitting || isLockedOut}
              onChange={(e) => {
                setEmail(e.target.value);
                if (fieldErrors.email) {
                  setFieldErrors((prev) => ({ ...prev, email: undefined }));
                }
              }}
              autoComplete="username"
              inputMode="email"
              aria-invalid={Boolean(fieldErrors.email)}
              aria-describedby={fieldErrors.email ? "admin-email-error" : undefined}
              aria-required="true"
              required
            />
          </div>
          {fieldErrors.email ? (
            <div id="admin-email-error" className="admin-login-field-error" role="alert">
              <AlertCircle size={14} strokeWidth={2.2} aria-hidden="true" />
              <span>{fieldErrors.email}</span>
            </div>
          ) : null}
        </div>

        <div className="admin-login-field">
          <label htmlFor="admin-password" className="admin-login-label">
            Mật khẩu
          </label>
          <div className={`admin-login-input-wrap${fieldErrors.password ? " admin-login-input-wrap--error" : ""}`}>
            <Lock className="admin-login-input-icon" size={18} strokeWidth={2} aria-hidden="true" />
            <input
              id="admin-password"
              type={showPassword ? "text" : "password"}
              className="admin-login-input"
              value={password}
              disabled={isSubmitting || isLockedOut}
              onChange={(e) => {
                setPassword(e.target.value);
                if (fieldErrors.password) {
                  setFieldErrors((prev) => ({ ...prev, password: undefined }));
                }
              }}
              autoComplete="current-password"
              aria-invalid={Boolean(fieldErrors.password)}
              aria-describedby={fieldErrors.password ? "admin-password-error" : undefined}
              aria-required="true"
              required
            />
            <button
              type="button"
              className="admin-login-password-toggle"
              onClick={() => setShowPassword(!showPassword)}
              aria-label={showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
              aria-pressed={showPassword}
            >
              {showPassword ? <EyeOff size={18} aria-hidden="true" /> : <Eye size={18} aria-hidden="true" />}
            </button>
          </div>
          {fieldErrors.password ? (
            <div id="admin-password-error" className="admin-login-field-error" role="alert">
              <AlertCircle size={14} strokeWidth={2.2} aria-hidden="true" />
              <span>{fieldErrors.password}</span>
            </div>
          ) : null}
        </div>

        <button type="submit" className="admin-login-submit-btn" disabled={isSubmitting || isLockedOut}>
          {isSubmitting ? (
            <span>Đang đăng nhập…</span>
          ) : isLockedOut ? (
            <span>Tạm khóa ({formatCountdown(remainingLockoutSeconds)})</span>
          ) : (
            <>
              <span>Đăng nhập</span>
              <ArrowRight size={18} strokeWidth={2.4} aria-hidden="true" />
            </>
          )}
        </button>
      </form>

      <p className="admin-login-footnote">© 2026 DrugTime</p>
    </section>
  );
}
