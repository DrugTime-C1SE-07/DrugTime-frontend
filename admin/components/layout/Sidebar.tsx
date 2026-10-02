"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  ClipboardCheck,
  Database,
  LayoutDashboard,
  LogOut,
  Notebook,
  PillIcon,
  ScanText,
  UserRound,
  type LucideIcon,
} from "lucide-react";
import { useAuthSession } from "../../lib/auth/session";
import { useToast } from "../ui/Toast";

type SidebarItem = {
  label: string;
  href: string;
  icon: LucideIcon;
  badge?: number;
};

const sidebarItems: SidebarItem[] = [
  {
    label: "Tổng quan dữ liệu",
    href: "/dashboard",
    icon: LayoutDashboard,
  },
  {
    label: "Danh mục thuốc",
    href: "/dashboard/medications",
    icon: PillIcon,
  },
  {
    label: "Quy tắc tương tác",
    href: "/dashboard/interactions",
    icon: ClipboardCheck,
  },
  {
    label: "Nhật ký",
    href: "/dashboard/scraper-logs",
    icon: Notebook,
  },
  {
    label: "Đối soát OCR",
    href: "/dashboard/ocr-review",
    icon: ScanText,
    badge: 3,
  },
];

function isActivePath(pathname: string, href: string) {
  if (href === "/dashboard") {
    return pathname === href;
  }

  return pathname === href || pathname.startsWith(`${href}/`);
}

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, logout } = useAuthSession();
  const { showToast } = useToast();

  const handleLogout = () => {
    logout();
    showToast({
      type: "info",
      title: "Đã đăng xuất",
      message: "Phiên làm việc quản trị đã được kết thúc an toàn.",
    });
    router.push("/auth/login");
  };

  return (
    <aside className="admin-sidebar" aria-label="Menu quản trị">
      <div className="admin-sidebar__brand">
        <div className="admin-sidebar__brand-icon" aria-hidden="true">
          <Database size={20} strokeWidth={2.4} />
        </div>
        <div className="admin-sidebar__brand-text">
          <div className="admin-sidebar__brand-row">
            <span className="admin-sidebar__brand-name">DrugTime</span>
            <span className="admin-sidebar__brand-badge">ADMIN</span>
          </div>
          <span className="admin-sidebar__subtitle">Hệ thống nhắc uống thuốc</span>
        </div>
      </div>

      <div className="admin-sidebar__status" aria-label="Trạng thái hệ thống: Hoạt động v1.2">
        <div className="admin-sidebar__status-left">
          <span className="admin-sidebar__status-dot" aria-hidden="true" />
          <span>Hệ thống hoạt động</span>
        </div>
        <span className="admin-sidebar__status-version">v1.2</span>
      </div>

      <nav className="admin-sidebar__nav">
        {sidebarItems.map((item) => {
          const Icon = item.icon;
          const active = isActivePath(pathname, item.href);

          return (
            <Link
              key={item.href}
              className={`admin-sidebar__link${active ? " admin-sidebar__link--active" : ""}`}
              href={item.href}
              aria-current={active ? "page" : undefined}
            >
              <Icon size={18} strokeWidth={2} />
              <span>{item.label}</span>
              {item.badge ? (
                <span className="admin-sidebar__badge" aria-label={`${item.badge} mục cần xử lý`}>
                  {item.badge}
                </span>
              ) : null}
            </Link>
          );
        })}
      </nav>

      <div className="admin-sidebar__account">
        <div className="admin-sidebar__avatar" aria-hidden="true" title={user?.roleName || "Quản trị viên"}>
          {user?.avatarInitials ? (
            <span style={{ fontSize: 11, fontWeight: 700 }}>{user.avatarInitials}</span>
          ) : (
            <UserRound size={16} strokeWidth={2.2} />
          )}
        </div>
        <div className="admin-sidebar__account-text">
          <strong title={user?.name || "DS. Lê Minh Trí"}>{user?.name || "DS. Lê Minh Trí"}</strong>
          <span title={user?.title || "Quản trị Dữ liệu Dược"}>{user?.title || "Quản trị Dữ liệu Dược"}</span>
        </div>
        <button
          className="admin-sidebar__logout"
          type="button"
          aria-label="Đăng xuất"
          title="Đăng xuất khỏi hệ thống"
          onClick={handleLogout}
        >
          <LogOut size={16} strokeWidth={2} />
        </button>
      </div>
    </aside>
  );
}
