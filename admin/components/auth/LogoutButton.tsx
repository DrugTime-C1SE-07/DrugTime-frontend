"use client";

import { LogOut } from "lucide-react";
import { useState } from "react";

type LogoutButtonProps = {
  /** Class của nút; mặc định là kiểu nút icon trên Topbar. */
  className?: string;
  iconSize?: number;
};

/** Nút Đăng xuất dùng chung cho Topbar và Sidebar: xóa cookie phiên rồi về trang đăng nhập. */
export default function LogoutButton({
  className = "admin-topbar__icon-button",
  iconSize = 22,
}: LogoutButtonProps) {
  const [pending, setPending] = useState(false);

  async function handleLogout() {
    setPending(true);
    try {
      await fetch("/api/session/logout", { method: "POST" });
    } finally {
      window.location.assign("/auth/login");
    }
  }

  return (
    <button
      className={className}
      type="button"
      aria-label="Đăng xuất"
      title="Đăng xuất"
      onClick={handleLogout}
      disabled={pending}
    >
      <LogOut size={iconSize} strokeWidth={2.2} />
    </button>
  );
}
