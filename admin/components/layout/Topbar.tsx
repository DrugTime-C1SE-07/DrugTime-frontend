"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Bell, CircleHelp, LogOut, ShieldCheck, UserRound } from "lucide-react";
import { useAuthSession } from "../../lib/auth/session";
import { useToast } from "../ui/Toast";

import LogoutButton from "../auth/LogoutButton";

type TopbarProps = {
  syncLabel?: string;
  notificationCount?: number;
};

export default function Topbar({
  syncLabel = "Sync: 2 phút trước",
  notificationCount = 1,
}: TopbarProps) {
  const router = useRouter();
  const { user, logout } = useAuthSession();
  const { showToast } = useToast();
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const handleLogout = () => {
    logout();
    setIsMenuOpen(false);
    showToast({
      type: "info",
      title: "Đã đăng xuất",
      message: "Phiên làm việc quản trị đã kết thúc an toàn.",
    });
    router.push("/auth/login");
  };

  return (
    <header className="admin-topbar" aria-label="Thanh công cụ quản trị">
      <div className="admin-topbar__actions" style={{ position: "relative" }}>
        <div className="admin-topbar__sync" aria-label={syncLabel}>
          <span aria-hidden="true" />
          <strong>{syncLabel}</strong>
        </div>

        <button
          className="admin-topbar__icon-button"
          type="button"
          aria-label="Trợ giúp"
          title="Trợ giúp nghiệp vụ Dược lâm sàng"
          onClick={() => {
            showToast({
              type: "info",
              title: "Tài liệu Dược Lâm Sàng",
              message: "Căn cứ Quyết định 5948/QĐ-BYT ban hành hướng dẫn kiểm tra tương tác thuốc.",
            });
          }}
        >
          <CircleHelp size={18} strokeWidth={2} />
        </button>

        <button
          className="admin-topbar__icon-button"
          type="button"
          aria-label="Thông báo"
          title={`${notificationCount} thông báo mới`}
          onClick={() => {
            showToast({
              type: "info",
              title: "Thông báo hệ thống",
              message: "Đã đồng bộ 142 bản ghi mới từ Cục Quản lý Dược (DAV).",
            });
          }}
        >
          <Bell size={18} strokeWidth={2} />
          {notificationCount > 0 ? (
            <span
              className="admin-topbar__notification-dot"
              aria-label={`${notificationCount} thông báo mới`}
            />
          ) : null}
        </button>

        <button
          className="admin-topbar__profile"
          type="button"
          aria-label="Tài khoản quản trị"
          title={`Đang đăng nhập: ${user?.name || "DS. Lê Minh Trí"}`}
          onClick={() => setIsMenuOpen(!isMenuOpen)}
        >
          {user?.avatarInitials ? (
            <span style={{ fontSize: 12, fontWeight: 700, color: "var(--color-primary)" }}>
              {user.avatarInitials}
            </span>
          ) : (
            <UserRound size={18} strokeWidth={2.2} />
          )}
        </button>

        {/* User quick profile popover */}
        {isMenuOpen ? (
          <div
            style={{
              position: "absolute",
              top: "100%",
              right: 0,
              marginTop: 8,
              width: 280,
              background: "#ffffff",
              borderRadius: 10,
              border: "1px solid var(--color-border)",
              boxShadow: "0 10px 25px rgba(0,0,0,0.1)",
              padding: "16px",
              zIndex: 1000,
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 12 }}>
              <div
                style={{
                  width: 36,
                  height: 36,
                  borderRadius: "50%",
                  background: "var(--color-primary-soft)",
                  color: "var(--color-primary)",
                  display: "grid",
                  placeItems: "center",
                  fontWeight: 700,
                  fontSize: 13,
                }}
              >
                {user?.avatarInitials || "LT"}
              </div>
              <div>
                <strong style={{ display: "block", fontSize: 14 }}>{user?.name || "DS. Lê Minh Trí"}</strong>
                <span style={{ display: "block", fontSize: 12, color: "var(--color-muted)" }}>
                  {user?.title || "Quản trị Dữ liệu Dược"}
                </span>
              </div>
            </div>

            <div
              style={{
                fontSize: 11.5,
                background: "var(--color-shell)",
                padding: "8px 10px",
                borderRadius: 6,
                marginBottom: 12,
                display: "flex",
                alignItems: "center",
                gap: 6,
                color: "var(--color-secondary-text)",
              }}
            >
              <ShieldCheck size={14} style={{ color: "var(--color-success)" }} />
              <span>{user?.licenseNumber || "CCHN-01824/BYT-HN"}</span>
            </div>

            <button
              type="button"
              onClick={handleLogout}
              style={{
                width: "100%",
                padding: "8px 12px",
                borderRadius: 6,
                border: "1px solid #fee2e2",
                background: "#fef2f2",
                color: "#b91c1c",
                fontWeight: 600,
                fontSize: 13,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                gap: 6,
                cursor: "pointer",
              }}
            >
              <LogOut size={14} strokeWidth={2} />
              Đăng xuất an toàn
            </button>
          </div>
        ) : null}
      </div>
    </header>
  );
}
