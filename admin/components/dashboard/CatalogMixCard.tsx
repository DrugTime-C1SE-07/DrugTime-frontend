import { SegmentBar, palette, type Segment } from "./charts";
import type { CatalogCounts } from "./CatalogGaugeCard";
import DashboardCard from "./DashboardCard";

export default function CatalogMixCard({ counts }: { counts: CatalogCounts }) {
  const loaded = Object.values(counts).every(value => value !== null);
  const segments: Segment[] = [
    { label: "Thuốc", value: counts.medications ?? 0, color: palette.navy },
    { label: "Hoạt chất", value: counts.ingredients ?? 0, color: palette.secondary },
    { label: "Tương tác thuốc", value: counts.drugInteractions ?? 0, color: palette.primary },
    { label: "Tương tác thức ăn", value: counts.foodInteractions ?? 0, color: palette.violet },
  ];
  const total = segments.reduce((sum, s) => sum + s.value, 0);
  return (
    <DashboardCard
      className="bento-mix"
      title="Cơ cấu danh mục"
      error={loaded ? undefined : "Chưa tải được đủ số liệu danh mục."}
      empty={total === 0 && "Danh mục chưa có bản ghi nào."}
    >
      <div className="bento-mix__total">
        <span>Tổng bản ghi</span>
        <strong>{total.toLocaleString("vi-VN")}</strong>
      </div>
      <SegmentBar label={segments.map(s => `${s.label}: ${s.value.toLocaleString("vi-VN")}`).join(", ")} segments={segments} />
      <ul className="bento-mix__legend">
        {segments.map(s => (
          <li key={s.label}>
            <i style={{ background: s.color }} aria-hidden="true" />
            <strong>{s.value.toLocaleString("vi-VN")}</strong>
            <span>{s.label}</span>
          </li>
        ))}
      </ul>
    </DashboardCard>
  );
}
