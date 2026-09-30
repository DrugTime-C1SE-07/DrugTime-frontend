import { ArrowRight, TrendingUp, type LucideIcon } from "lucide-react";

type KpiCardProps = {
  tone: "blue" | "red";
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
    <article className={`dashboard-kpi dashboard-kpi--${tone}`}>
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
        <strong>{value}</strong>
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
