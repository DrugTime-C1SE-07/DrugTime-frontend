import { Bell, CircleHelp, UserRound } from "lucide-react";

import LogoutButton from "../auth/LogoutButton";

type TopbarProps = {
  syncLabel?: string;
  notificationCount?: number;
};

export default function Topbar({
  syncLabel = "Sync: 2 phút trước",
  notificationCount = 1,
}: TopbarProps) {
  return (
    <header className="admin-topbar" aria-label="Thanh công cụ quản trị">
      <div className="admin-topbar__actions">
        <div className="admin-topbar__sync" aria-label={syncLabel}>
          <span aria-hidden="true" />
          <strong>{syncLabel}</strong>
        </div>

        <button className="admin-topbar__icon-button" type="button" aria-label="Trợ giúp">
          <CircleHelp size={24} strokeWidth={2.2} />
        </button>

        <button className="admin-topbar__icon-button" type="button" aria-label="Thông báo">
          <Bell size={24} strokeWidth={2.2} />
          {notificationCount > 0 ? (
            <span className="admin-topbar__notification-dot" aria-label={`${notificationCount} thông báo mới`} />
          ) : null}
        </button>

        <button className="admin-topbar__profile" type="button" aria-label="Tài khoản quản trị">
          <UserRound size={23} strokeWidth={2.4} />
        </button>

        <LogoutButton />
      </div>
    </header>
  );
}
