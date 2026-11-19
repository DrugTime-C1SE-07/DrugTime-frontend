"use client";

import { AlertTriangle, ClipboardCheck, Database, ShieldCheck, type LucideIcon } from "lucide-react";

interface MedicationStatsGridProps {
  stats?: {
    total: number;
    verified: number;
    pending: number;
    missing: number;
  };
}

type StatItem = {
  tone: "primary" | "success" | "warning" | "danger";
  label: string;
  value: number;
  /** Tỉ lệ so với tổng (0–100); có thì hiện thanh tỉ lệ. */
  percent?: number;
  icon: LucideIcon;
};

export default function MedicationStatsGrid({ stats }: MedicationStatsGridProps) {
  const total = stats?.total ?? 14850;
  const verified = stats?.verified ?? 14422;
  const pending = stats?.pending ?? 286;
  const missing = stats?.missing ?? 142;

  const share = (count: number) => (total > 0 ? (count / total) * 100 : 0);

  const items: StatItem[] = [
    { tone: "primary", label: "Tổng số bản ghi", value: total, icon: Database },
    { tone: "success", label: "Đã xác thực", value: verified, percent: share(verified), icon: ShieldCheck },
    { tone: "warning", label: "Dữ liệu cào / Cần duyệt", value: pending, percent: share(pending), icon: ClipboardCheck },
    { tone: "danger", label: "Thiếu thông tin", value: missing, percent: share(missing), icon: AlertTriangle },
  ];

  return (
    <div className="medication-stats-grid">
      {items.map((stat) => {
        const Icon = stat.icon;

        return (
          <article className={`medication-stat tone-${stat.tone}`} key={stat.label}>
            <div className="medication-stat__icon-box" aria-hidden="true">
              <Icon size={20} strokeWidth={2.2} />
            </div>
            <div className="medication-stat__content">
              <span className="medication-stat__label" title={stat.label}>
                {stat.label}
              </span>
              <strong>{stat.value.toLocaleString("vi-VN")}</strong>
              {stat.percent !== undefined ? (
                <div className="stat-meter">
                  <span className="stat-meter__track" aria-hidden="true">
                    <i className="stat-meter__fill" style={{ transform: `scaleX(${stat.percent / 100})` }} />
                  </span>
                  <span className="stat-meter__text">
                    {stat.percent.toLocaleString("vi-VN", { maximumFractionDigits: 1 })}% tổng số
                  </span>
                </div>
              ) : null}
            </div>
          </article>
        );
      })}
    </div>
  );
}
