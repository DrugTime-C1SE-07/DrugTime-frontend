"use client";

import { Bell, CircleHelp, UserRound } from "lucide-react";
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
  const { showToast } = useToast();

  return (
    <header className="admin-topbar" aria-label="Thanh công cụ quản trị">
      <div className="admin-topbar__actions">
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

        <button className="admin-topbar__profile" type="button" aria-label="Tài khoản quản trị">
          <UserRound size={18} strokeWidth={2.2} />
        </button>

        <LogoutButton iconSize={18} />
      </div>
    </header>
  );
}
