"use client";

import { AlertTriangle, ClipboardCheck, Database, ShieldCheck } from "lucide-react";

interface MedicationStatsGridProps {
  stats?: {
    total: number;
    verified: number;
    pending: number;
    missing: number;
  };
}

export default function MedicationStatsGrid({ stats }: MedicationStatsGridProps) {
  const total = stats?.total ?? 14850;
  const verified = stats?.verified ?? 14422;
  const pending = stats?.pending ?? 286;
  const missing = stats?.missing ?? 142;

  const verifiedPercent = total > 0 ? ((verified / total) * 100).toFixed(1) + "%" : "0%";
  const pendingPercent = total > 0 ? ((pending / total) * 100).toFixed(1) + "%" : "0%";
  const missingPercent = total > 0 ? ((missing / total) * 100).toFixed(1) + "%" : "0%";

  const items = [
    {
      tone: "neutral" as const,
      label: "TỔNG SỐ BẢN GHI",
      value: total.toLocaleString("vi-VN"),
      icon: Database,
    },
    {
      tone: "green" as const,
      label: "ĐÃ XÁC THỰC",
      value: verified.toLocaleString("vi-VN"),
      percent: verifiedPercent,
      icon: ShieldCheck,
    },
    {
      tone: "blue" as const,
      label: "DỮ LIỆU CÀO / CẦN DUYỆT",
      value: pending.toLocaleString("vi-VN"),
      percent: pendingPercent,
      icon: ClipboardCheck,
    },
    {
      tone: "red" as const,
      label: "THIẾU THÔNG TIN",
      value: missing.toLocaleString("vi-VN"),
      percent: missingPercent,
      icon: AlertTriangle,
    },
  ];

  return (
    <div className="medication-stats-grid">
      {items.map((stat) => {
        const Icon = stat.icon;

        return (
          <article className={`medication-stat medication-stat--${stat.tone}`} key={stat.label}>
            <div className="medication-stat__content">
              <span className="medication-stat__label">{stat.label}</span>
              <strong>{stat.value}</strong>
            </div>
            <div className="medication-stat__side">
              {stat.percent ? <em className="medication-stat__badge">{stat.percent}</em> : null}
              <div className="medication-stat__icon-box" aria-hidden="true">
                <Icon size={20} strokeWidth={2.2} />
              </div>
            </div>
          </article>
        );
      })}
    </div>
  );
}
