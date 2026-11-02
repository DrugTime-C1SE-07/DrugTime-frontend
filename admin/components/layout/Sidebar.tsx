"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ClipboardCheck, LayoutDashboard, Notebook, PillIcon, ScanText } from "lucide-react";
import LogoutButton from "../auth/LogoutButton";

const items = [
  { label: "Tổng quan dữ liệu", href: "/dashboard", icon: LayoutDashboard },
  { label: "Danh mục thuốc", href: "/dashboard/medications", icon: PillIcon },
  { label: "Quy tắc tương tác", href: "/dashboard/interactions", icon: ClipboardCheck },
  { label: "Nhật ký đồng bộ", href: "/dashboard/scraper-logs", icon: Notebook },
  { label: "Đối soát OCR", href: "/dashboard/ocr-review", icon: ScanText },
];

/** Thanh điều hướng ngang của khu quản trị (tên file giữ nguyên để không đổi chỗ import). */
export default function Sidebar() {
  const pathname = usePathname();
  const isActive = (href: string) => (href === "/dashboard" ? pathname === href : pathname === href || pathname.startsWith(`${href}/`));
  const current = items.find(item => isActive(item.href));
  return (
    <header className="admin-navbar">
      <nav className="admin-navbar__nav" aria-label="Menu quản trị">
        {items.map(item => {
          const active = isActive(item.href);
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              title={item.label}
              aria-label={active ? undefined : item.label}
              aria-current={active ? "page" : undefined}
              className={`admin-navbar__link${active ? " admin-navbar__link--active" : ""}`}
            >
              <Icon size={20} aria-hidden="true" />
              {active ? <span>{item.label}</span> : null}
            </Link>
          );
        })}
      </nav>
      <p className="admin-navbar__title">
        DrugTime Admin<span aria-hidden="true"> / </span><span className="visually-hidden">, </span>{current?.label ?? "Quản trị dữ liệu"}
      </p>
      <LogoutButton className="admin-navbar__logout" iconSize={20} />
    </header>
  );
}
