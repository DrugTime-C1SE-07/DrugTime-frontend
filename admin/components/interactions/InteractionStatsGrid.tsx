"use client";

import { AlertOctagon, CheckCircle2, Clock3, Database } from "lucide-react";

interface InteractionStatsGridProps {
  stats?: {
    total: number;
    contraindicated: number;
    major: number;
    moderate: number;
    minor: number;
    pendingCount?: number;
  };
}

export default function InteractionStatsGrid({ stats }: InteractionStatsGridProps) {
  const total = stats?.total ?? 3842;
  const contraindicated = stats?.contraindicated ?? 418;
  const pending = stats?.pendingCount ?? 14;
  const accuracy = "99.6%";

  const items = [
    {
      tone: "neutral" as const,
      label: "TỔNG SỐ QUY TẮC",
      value: total.toLocaleString("vi-VN"),
      badge: "+12 mới",
      badgeType: "success" as const,
      icon: Database,
    },
    {
      tone: "contraindicated" as const,
      label: "CHỐNG CHỈ ĐỊNH",
      value: contraindicated.toLocaleString("vi-VN"),
      badge: "10.8% nguy cơ",
      badgeType: "danger" as const,
      icon: AlertOctagon,
    },
    {
      tone: "pending" as const,
      label: "CẦN DUYỆT BÓC TÁCH",
      value: pending.toLocaleString("vi-VN"),
      badge: "Chờ Dược sĩ",
      badgeType: "info" as const,
      icon: Clock3,
    },
    {
      tone: "accuracy" as const,
      label: "ĐỘ CHÍNH XÁC ĐỐI SOÁT",
      value: accuracy,
      badge: "Đạt chuẩn BYT",
      badgeType: "success" as const,
      icon: CheckCircle2,
    },
  ];

  return (
    <div className="medication-stats-grid">
      {items.map((stat) => {
        const Icon = stat.icon;

        return (
          <article
            className={`medication-stat interaction-stat--${stat.tone}`}
            key={stat.label}
          >
            <div className="medication-stat__content">
              <span className="medication-stat__label">{stat.label}</span>
              <strong>{stat.value}</strong>
            </div>
            <div className="medication-stat__side">
              {stat.badge ? (
                <em className={`medication-stat__badge medication-stat__badge--${stat.badgeType}`}>
                  {stat.badge}
                </em>
              ) : null}
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
