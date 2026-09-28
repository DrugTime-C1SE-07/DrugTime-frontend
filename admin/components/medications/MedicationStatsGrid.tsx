import { AlertTriangle, ClipboardCheck, Database, ShieldCheck } from "lucide-react";

const stats = [
  {
    tone: "blue",
    label: "Tổng số bản ghi",
    value: "14,850",
    icon: Database,
  },
  {
    tone: "green",
    label: "Đã xác thực",
    value: "14,422",
    percent: "97.1%",
    icon: ShieldCheck,
  },
  {
    tone: "blue",
    label: "Cào mới / Cần thẩm định",
    value: "286",
    percent: "1.9%",
    icon: ClipboardCheck,
  },
  {
    tone: "red",
    label: "Thiếu thông tin",
    value: "142",
    percent: "1.0%",
    icon: AlertTriangle,
  },
];

export default function MedicationStatsGrid() {
  return (
    <div className="medication-stats-grid">
      {stats.map((stat) => {
        const Icon = stat.icon;

        return (
          <article className={`medication-stat medication-stat--${stat.tone}`} key={stat.label}>
            <div>
              <span>{stat.label}</span>
              <strong>{stat.value}</strong>
            </div>
            <div className="medication-stat__side">
              {stat.percent ? <em>{stat.percent}</em> : null}
              <span aria-hidden="true">
                <Icon size={30} strokeWidth={2.4} />
              </span>
            </div>
          </article>
        );
      })}
    </div>
  );
}
