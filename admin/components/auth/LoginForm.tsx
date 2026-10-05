"use client";

import React, { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import {
  AlertCircle,
  AlertTriangle,
  ArrowRight,
  CheckCircle2,
  Clock,
  Database,
  Eye,
  EyeOff,
  HelpCircle,
  Info,
  Lock,
  Mail,
  PhoneCall,
  Shield,
  ShieldAlert,
  ShieldCheck,
  Stethoscope,
} from "lucide-react";
import { useAuthSession } from "../../lib/auth/session";
import { useToast } from "../ui/Toast";
import { Modal } from "../ui/Modal";

const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION_MS = 15 * 60 * 1000; // 15 minutes lockout

export default function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { login } = useAuthSession();
  const { showToast } = useToast();

  // Form State
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [rememberMe, setRememberMe] = useState(true);
  const [showPassword, setShowPassword] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Validation State
  const [fieldErrors, setFieldErrors] = useState<{ email?: string; password?: string }>({});
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Security Lockout Protection State
  const [failedAttempts, setFailedAttempts] = useState<number>(0);
  const [lockoutEndTime, setLockoutEndTime] = useState<number | null>(null);
  const [remainingLockoutSeconds, setRemainingLockoutSeconds] = useState<number>(0);

  // Forgot Password Modal State
  const [isForgotModalOpen, setIsForgotModalOpen] = useState(false);
  const [forgotEmail, setForgotEmail] = useState("");
  const [forgotError, setForgotError] = useState<string | null>(null);
  const [forgotSuccess, setForgotSuccess] = useState(false);
  const [isForgotSubmitting, setIsForgotSubmitting] = useState(false);

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
    } else if (password.length < 6) {
      errors.password = "Mật khẩu bảo mật phải có ít nhất 6 ký tự.";
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
      const res = await login(email, password, rememberMe);

      if (!res.success) {
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
          setSubmitError(res.error || "Email công vụ hoặc mật khẩu không chính xác. Vui lòng kiểm tra lại.");
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
        message: `Chào mừng ${res.user?.name} (${res.user?.title}) đã đăng nhập vào hệ thống.`,
      });

      const redirectUrl = searchParams.get("redirect") || "/dashboard";
      router.push(redirectUrl);
    } catch {
      setSubmitError("Đã xảy ra sự cố kết nối tới máy chủ xác thực. Vui lòng thử lại sau ít phút.");
      setIsSubmitting(false);
    }
  };

  // Forgot Password Handler
  const handleForgotSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setForgotError(null);

    const trimmed = forgotEmail.trim();
    if (!trimmed) {
      setForgotError("Vui lòng nhập địa chỉ email công vụ của bạn.");
      return;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(trimmed)) {
      setForgotError("Địa chỉ email không đúng định dạng hợp lệ.");
      return;
    }

    setIsForgotSubmitting(true);

    // Simulate sending recovery request
    setTimeout(() => {
      setIsForgotSubmitting(false);
      setForgotSuccess(true);
    }, 800);
  };

  return (
    <div className="admin-login-layout">
      {/* Cột trái: Giới thiệu hệ thống Y tế & Chuẩn mực Dược lâm sàng */}
      <section className="admin-login-hero" aria-label="Giới thiệu Cổng Quản trị Dược lâm sàng">
        <div className="admin-login-hero-inner">
          <div className="admin-login-hero-badge">
            <Shield size={14} strokeWidth={2.4} />
            <span>HỆ THỐNG Y TẾ QUỐC GIA · BỘ Y TẾ</span>
          </div>

          <h1 className="admin-login-hero-title">
            Cổng Quản trị Dữ liệu Dược &amp; Cảnh báo Tương tác Thuốc
          </h1>

          <p className="admin-login-hero-desc">
            Nền tảng hỗ trợ Dược sĩ lâm sàng và Ban Quản lý dữ liệu Dược đối soát quy tắc tương tác,
            chuẩn hóa danh mục biệt dược và giám sát an toàn kê đơn theo tiêu chuẩn y tế quốc gia.
          </p>

          <div className="admin-login-features">
            <div className="admin-login-feature-item">
              <div className="admin-login-feature-icon">
                <Stethoscope size={20} strokeWidth={2.2} />
              </div>
              <div>
                <strong>Thẩm định theo Quyết định 5948/QĐ-BYT</strong>
                <p>Quản lý các quy tắc tương tác Thuốc - Thuốc và Thuốc - Thức ăn đối kháng, hiệp đồng.</p>
              </div>
            </div>

            <div className="admin-login-feature-item">
              <div className="admin-login-feature-icon">
                <Database size={20} strokeWidth={2.2} />
              </div>
              <div>
                <strong>Chuẩn hóa CSDL Cục Quản lý Dược (DAV)</strong>
                <p>Đồng bộ dữ liệu số đăng ký lưu hành, hoạt chất, hàm lượng và dạng bào chế chính thống.</p>
              </div>
            </div>

            <div className="admin-login-feature-item">
              <div className="admin-login-feature-icon">
                <ShieldCheck size={20} strokeWidth={2.2} />
              </div>
              <div>
                <strong>Bảo mật Y tế Cấp độ 3 &amp; Lưu vết Access Log</strong>
                <p>Tuân thủ Thông tư 27/2021/TT-BYT, bảo vệ dữ liệu sức khỏe và phân quyền định danh chặt chẽ.</p>
              </div>
            </div>
          </div>

          <div className="admin-login-hero-status">
            <span className="admin-login-hero-status-dot" aria-hidden="true" />
            <span>Hệ thống trực tuyến v1.2 · Trung tâm dữ liệu Dược lâm sàng sẵn sàng</span>
          </div>
        </div>
      </section>

      {/* Cột phải: Form Đăng nhập Chuyên môn Chuẩn chỉnh */}
      <section className="admin-login-panel" aria-label="Biểu mẫu đăng nhập">
        <div className="admin-login-card">
          <div className="admin-login-header">
            <div className="admin-login-header-icon" aria-hidden="true">
              <Database size={22} strokeWidth={2.4} />
            </div>
            <div>
              <h2 className="admin-login-heading">Đăng nhập Quản trị</h2>
              <p className="admin-login-subheading">
                Vui lòng sử dụng tài khoản công vụ được cấp bởi Ban Quản trị Hệ thống.
              </p>
            </div>
          </div>

          {/* Banner Tạm Khóa An Ninh khi vượt quá số lần thử */}
          {isLockedOut ? (
            <div className="admin-login-lockout-banner" role="alert">
              <Clock size={20} strokeWidth={2.2} className="admin-login-lockout-icon" />
              <div>
                <strong>Tài khoản đang bị tạm khóa</strong>
                <p>
                  Đăng nhập thất bại quá 5 lần. Hệ thống tạm khóa biểu mẫu trong{" "}
                  <span className="admin-login-countdown">{formatCountdown(remainingLockoutSeconds)}</span> để bảo vệ an toàn dữ liệu.
                </p>
              </div>
            </div>
          ) : submitError ? (
            <div className="admin-login-alert" role="alert">
              <AlertCircle size={18} strokeWidth={2.4} style={{ flexShrink: 0 }} />
              <span>{submitError}</span>
            </div>
          ) : null}

          {/* Form Đăng Nhập */}
          <form onSubmit={handleSubmit} className="admin-login-form" noValidate>
            {/* Trường Email */}
            <div className="admin-login-field">
              <label htmlFor="admin-email" className="admin-login-label">
                Email công vụ y tế <span className="admin-login-required">*</span>
              </label>
              <div
                className={`admin-login-input-wrap ${
                  fieldErrors.email ? "admin-login-input-wrap--error" : ""
                }`}
              >
                <Mail className="admin-login-input-icon" size={18} strokeWidth={2} />
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
                  autoComplete="email"
                  aria-invalid={Boolean(fieldErrors.email)}
                  aria-describedby={fieldErrors.email ? "admin-email-error" : undefined}
                  required
                />
              </div>
              {fieldErrors.email ? (
                <div id="admin-email-error" className="admin-login-field-error" role="alert">
                  <AlertCircle size={13} strokeWidth={2.2} />
                  <span>{fieldErrors.email}</span>
                </div>
              ) : null}
            </div>

            {/* Trường Mật khẩu */}
            <div className="admin-login-field">
              <div className="admin-login-label-row">
                <label htmlFor="admin-password" className="admin-login-label">
                  Mật khẩu truy cập <span className="admin-login-required">*</span>
                </label>
                <button
                  type="button"
                  className="admin-login-forgot-btn"
                  onClick={() => {
                    setForgotEmail(email);
                    setForgotSuccess(false);
                    setForgotError(null);
                    setIsForgotModalOpen(true);
                  }}
                >
                  Quên mật khẩu?
                </button>
              </div>
              <div
                className={`admin-login-input-wrap ${
                  fieldErrors.password ? "admin-login-input-wrap--error" : ""
                }`}
              >
                <Lock className="admin-login-input-icon" size={18} strokeWidth={2} />
                <input
                  id="admin-password"
                  type={showPassword ? "text" : "password"}
                  className="admin-login-input"
                  placeholder="Nhập mật khẩu của bạn"
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
                  required
                />
                <button
                  type="button"
                  className="admin-login-password-toggle"
                  onClick={() => setShowPassword(!showPassword)}
                  aria-label={showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
                  tabIndex={0}
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
              {fieldErrors.password ? (
                <div id="admin-password-error" className="admin-login-field-error" role="alert">
                  <AlertCircle size={13} strokeWidth={2.2} />
                  <span>{fieldErrors.password}</span>
                </div>
              ) : null}
            </div>

            {/* Duy trì đăng nhập */}
            <div className="admin-login-options">
              <label className="admin-login-checkbox-label">
                <input
                  type="checkbox"
                  checked={rememberMe}
                  disabled={isSubmitting || isLockedOut}
                  onChange={(e) => setRememberMe(e.target.checked)}
                />
                <span>Duy trì phiên đăng nhập trên trình duyệt này</span>
              </label>
            </div>

            {/* Nút bấm Submit */}
            <button
              type="submit"
              className="admin-login-submit-btn"
              disabled={isSubmitting || isLockedOut}
            >
              {isSubmitting ? (
                <span>Đang xác thực thông tin chứng chỉ...</span>
              ) : isLockedOut ? (
                <span>Đang tạm khóa ({formatCountdown(remainingLockoutSeconds)})</span>
              ) : (
                <>
                  <span>Đăng nhập vào Hệ thống</span>
                  <ArrowRight size={18} strokeWidth={2.4} />
                </>
              )}
            </button>
          </form>

          {/* Chân trang Bảo mật Y tế chuẩn */}
          <div className="admin-login-trust">
            <ShieldCheck size={18} strokeWidth={2.2} className="admin-login-trust__icon" />
            <div className="admin-login-trust__text">
              <strong>Bảo mật thông tin dữ liệu y tế cấp 3</strong>
              <p>
                Mọi lượt truy cập dữ liệu thuốc và chỉnh sửa quy tắc tương tác đều được lưu vết định danh
                trong Access Log theo quy chuẩn Thông tư 27/2021/TT-BYT.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Modal Hướng dẫn Quên mật khẩu / Cấp lại quyền chuyên môn y tế */}
      <Modal
        isOpen={isForgotModalOpen}
        onClose={() => setIsForgotModalOpen(false)}
        title="Khôi phục quyền truy cập Cổng Quản trị"
        subtitle="Hệ thống xác thực và cấp lại mật khẩu chuyên môn y tế"
        size="md"
        footer={
          <>
            <button
              type="button"
              className="dashboard-action dashboard-action--secondary"
              onClick={() => setIsForgotModalOpen(false)}
            >
              Đóng
            </button>
            {!forgotSuccess ? (
              <button
                type="button"
                className="dashboard-action dashboard-action--primary"
                onClick={handleForgotSubmit}
                disabled={isForgotSubmitting}
              >
                {isForgotSubmitting ? "Đang gửi yêu cầu..." : "Gửi yêu cầu khôi phục"}
              </button>
            ) : null}
          </>
        }
      >
        <div className="admin-forgot-modal-body">
          {forgotSuccess ? (
            <div className="admin-forgot-success-box">
              <CheckCircle2 size={36} strokeWidth={2.4} style={{ color: "var(--color-success)" }} />
              <div>
                <strong style={{ fontSize: 15, display: "block", color: "var(--color-text)", marginBottom: 4 }}>
                  Yêu cầu khôi phục đã được tiếp nhận
                </strong>
                <p style={{ fontSize: 13, color: "var(--color-secondary-text)", lineHeight: 1.5, margin: 0 }}>
                  Hệ thống đã gửi liên kết đặt lại mật khẩu an toàn đến email công vụ:{" "}
                  <strong>{forgotEmail}</strong>. Vui lòng kiểm tra hộp thư (bao gồm cả thư mục Junk/Spam) và thực hiện xác thực theo hướng dẫn.
                </p>
              </div>
            </div>
          ) : (
            <form onSubmit={handleForgotSubmit}>
              <p style={{ fontSize: 13.5, color: "var(--color-secondary-text)", lineHeight: 1.5, marginTop: 0, marginBottom: 16 }}>
                Để đảm bảo an toàn dữ liệu y tế theo quy định, liên kết khôi phục chỉ được gửi đến địa chỉ email công vụ đã được cấp quyền quản trị.
              </p>

              {forgotError ? (
                <div className="admin-login-alert" style={{ marginBottom: 14 }} role="alert">
                  <AlertCircle size={16} strokeWidth={2.4} />
                  <span>{forgotError}</span>
                </div>
              ) : null}

              <div className="admin-login-field">
                <label htmlFor="forgot-email" className="admin-login-label">
                  Email công vụ đã đăng ký
                </label>
                <div className="admin-login-input-wrap">
                  <Mail className="admin-login-input-icon" size={18} strokeWidth={2} />
                  <input
                    id="forgot-email"
                    type="email"
                    className="admin-login-input"
                    placeholder="ví dụ: ten.ho@drugtime.vn"
                    value={forgotEmail}
                    onChange={(e) => {
                      setForgotEmail(e.target.value);
                      setForgotError(null);
                    }}
                    required
                  />
                </div>
              </div>
            </form>
          )}

          {/* Hotline Hỗ trợ kỹ thuật y tế khẩn cấp */}
          <div className="admin-forgot-support-box">
            <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
              <PhoneCall size={16} strokeWidth={2.2} style={{ color: "var(--color-primary)" }} />
              <strong style={{ fontSize: 13, color: "var(--color-text)" }}>
                Hỗ trợ kỹ thuật khẩn cấp cho Khoa Dược
              </strong>
            </div>
            <p style={{ fontSize: 12.5, color: "var(--color-muted)", margin: 0, lineHeight: 1.45 }}>
              Trong trường hợp khẩn cấp cần cấp lại tài khoản thẩm định đơn thuốc, vui lòng liên hệ trực tiếp:
              <br />
              <strong>Hotline IT Y tế:</strong> 1900-6868 (Nhánh 2) · <strong>Email:</strong> it-security@drugtime.vn
            </p>
          </div>
        </div>
      </Modal>
    </div>
  );
}
