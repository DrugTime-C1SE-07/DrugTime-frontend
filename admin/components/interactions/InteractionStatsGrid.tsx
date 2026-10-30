"use client";

import { AlertOctagon, CheckCircle2, Clock3, Database, type LucideIcon } from "lucide-react";

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

type StatItem = {
  tone: "primary" | "success" | "warning" | "danger";
  label: string;
  value: string;
  /** Tỉ lệ 0–100 kèm chú thích; có thì hiện thanh tỉ lệ thay cho badge. */
  meter?: { percent: number; caption: string };
  badge?: string;
  icon: LucideIcon;
};

const ACCURACY_PERCENT = 99.6;

const formatPercent = (value: number) => value.toLocaleString("vi-VN", { maximumFractionDigits: 1 });

export default function InteractionStatsGrid({ stats }: InteractionStatsGridProps) {
  const total = stats?.total ?? 3842;
  const contraindicated = stats?.contraindicated ?? 418;
  const pending = stats?.pendingCount ?? 14;

  const items: StatItem[] = [
    {
      tone: "primary",
      label: "Tổng số quy tắc",
      value: total.toLocaleString("vi-VN"),
      badge: "+12 mới",
      icon: Database,
    },
    {
      tone: "danger",
      label: "Chống chỉ định",
      value: contraindicated.toLocaleString("vi-VN"),
      meter: { percent: total > 0 ? (contraindicated / total) * 100 : 0, caption: "tổng quy tắc" },
      icon: AlertOctagon,
    },
    {
      tone: "warning",
      label: "Cần duyệt bóc tách",
      value: pending.toLocaleString("vi-VN"),
      badge: "Chờ Dược sĩ",
      icon: Clock3,
    },
    {
      tone: "success",
      label: "Độ chính xác đối soát",
      value: `${formatPercent(ACCURACY_PERCENT)}%`,
      meter: { percent: ACCURACY_PERCENT, caption: "đạt chuẩn BYT" },
      icon: CheckCircle2,
    },
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
              <strong>{stat.value}</strong>
              {stat.meter ? (
                <div className="stat-meter">
                  <span className="stat-meter__track" aria-hidden="true">
                    <i className="stat-meter__fill" style={{ transform: `scaleX(${stat.meter.percent / 100})` }} />
                  </span>
                  <span className="stat-meter__text">
                    {formatPercent(stat.meter.percent)}% {stat.meter.caption}
                  </span>
                </div>
              ) : stat.badge ? (
                <em className="medication-stat__badge">{stat.badge}</em>
              ) : null}
            </div>
          </article>
        );
      })}
    </div>
  );
}
