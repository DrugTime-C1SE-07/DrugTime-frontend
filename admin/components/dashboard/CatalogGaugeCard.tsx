import type { SyncRun } from "../../lib/types/catalog-sync";
import { cleanRate } from "../../lib/dashboard/metrics";
import { Gauge } from "./charts";
import DashboardCard from "./DashboardCard";

export type CatalogCounts = {
  medications: number | null;
  ingredients: number | null;
  drugInteractions: number | null;
  foodInteractions: number | null;
};

const format = (value: number | null) => (value === null ? "—" : value.toLocaleString("vi-VN"));

export default function CatalogGaugeCard({ counts, runs, runsError }: { counts: CatalogCounts; runs: SyncRun[]; runsError?: string }) {
  const interactions = counts.drugInteractions === null || counts.foodInteractions === null ? null : counts.drugInteractions + counts.foodInteractions;
  const rate = cleanRate(runs);
  const missing = Object.values(counts).some(value => value === null);
  const stats = [
    { label: "Thuốc", value: counts.medications },
    { label: "Hoạt chất", value: counts.ingredients },
    { label: "Tương tác", value: interactions },
  ];
  return (
    <DashboardCard className="bento-catalog" title="Danh mục" subtitle="Số bản ghi hiện có">
      <dl className="bento-catalog__numbers">
        {stats.map(stat => (
          <div key={stat.label}>
            <dd aria-label={stat.value === null ? `${stat.label}: chưa tải được` : undefined}>{format(stat.value)}</dd>
            <dt>{stat.label}</dt>
          </div>
        ))}
      </dl>
      {missing ? <p className="bento-card__note" role="alert">Một số số liệu danh mục chưa tải được. Hãy tải lại trang.</p> : null}
      {runsError ? (
        <p className="bento-card__note" role="alert">{runsError}</p>
      ) : rate === null ? (
        <p className="bento-card__state">Chưa có bản ghi đồng bộ để tính tỉ lệ không lỗi.</p>
      ) : (
        <>
          <Gauge value={rate} label="Bản ghi đồng bộ không lỗi" />
          <p className="bento-catalog__caption">Bản ghi đồng bộ không lỗi</p>
        </>
      )}
    </DashboardCard>
  );
}
