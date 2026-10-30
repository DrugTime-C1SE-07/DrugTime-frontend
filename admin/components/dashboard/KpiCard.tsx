import { ArrowRight, TrendingUp, type LucideIcon } from "lucide-react";

import CountUp from "./CountUp";

/** accent: số liệu chung; warning: cần xử lý; danger: lỗi. Màu lấy từ lớp .tone-* trong globals.css. */
export type KpiTone = "accent" | "warning" | "danger";

type KpiCardProps = {
  tone: KpiTone;
  /** Thẻ nổi bật nền đặc; chỉ một thẻ mỗi trang. */
  featured?: boolean;
  icon: LucideIcon;
  eyebrow: string;
  title: string;
  value: string;
  unit: string;
  pill?: string;
  footerPrimary: string;
  footerSecondary: string;
};

export default function KpiCard({
  tone,
  featured = false,
  icon: Icon,
  eyebrow,
  title,
  value,
  unit,
  pill,
  footerPrimary,
  footerSecondary,
}: KpiCardProps) {
  return (
    <article className={`dashboard-kpi tone-${tone}${featured ? " dashboard-kpi--featured" : ""}`}>
      <div className="dashboard-kpi__top">
        <div className="dashboard-kpi__icon" aria-hidden="true">
          <Icon size={25} strokeWidth={2.4} />
        </div>
        <div className="dashboard-kpi__label">
          <span>{eyebrow}</span>
          <strong>{title}</strong>
        </div>
        {pill ? (
          <span className="dashboard-kpi__pill">
            <TrendingUp size={18} strokeWidth={2.5} aria-hidden="true" />
            {pill}
          </span>
        ) : null}
      </div>

      <div className="dashboard-kpi__metric">
        <strong>
          <CountUp value={value} />
        </strong>
        <span>{unit}</span>
      </div>

      <div className="dashboard-kpi__footer">
        <span>{footerPrimary}</span>
        <strong>
          {footerSecondary}
          <ArrowRight size={22} strokeWidth={2.4} aria-hidden="true" />
        </strong>
      </div>
    </article>
  );
}
