import type { SyncRun } from "../../lib/types/catalog-sync";
import { chronological, recordTotals, runLabel, seriesByRun } from "../../lib/dashboard/metrics";
import { LineChart, NOT_ENOUGH_RUNS, palette } from "./charts";
import DashboardCard from "./DashboardCard";

const RUNS = 10;

export default function RecordsAreaCard({ runs, error }: { runs: SyncRun[]; error?: string }) {
  const inserted = seriesByRun(runs, "records_inserted", RUNS);
  const updated = seriesByRun(runs, "records_updated", RUNS);
  const totals = recordTotals(runs);
  return (
    <DashboardCard
      className="bento-records"
      title="Thêm mới và cập nhật"
      aside={
        <p className="bento-legend">
          <span><i style={{ background: palette.primary }} aria-hidden="true" />Thêm mới</span>
          <span><i style={{ background: palette.lilac }} aria-hidden="true" />Cập nhật</span>
        </p>
      }
      error={error}
      empty={inserted.length < 2 && NOT_ENOUGH_RUNS}
    >
      <div className="bento-records__layout">
        <dl className="bento-records__totals">
          <div><dt>Thêm mới</dt><dd>{totals.inserted.toLocaleString("vi-VN")}</dd></div>
          <div><dt>Cập nhật</dt><dd>{totals.updated.toLocaleString("vi-VN")}</dd></div>
          <div><dt>Bản ghi lỗi</dt><dd className="is-alert">{totals.failed.toLocaleString("vi-VN")}</dd></div>
        </dl>
        <LineChart
          id="records"
          label={`Theo lượt, thêm mới: ${inserted.join(", ")}; cập nhật: ${updated.join(", ")}`}
          series={[
            { values: inserted, color: palette.primary, smooth: true, area: true },
            { values: updated, color: palette.lilac, smooth: true, faint: true },
          ]}
          peak={{ series: 0, text: value => `Cao nhất: ${value.toLocaleString("vi-VN")}` }}
          xLabels={chronological(runs, RUNS).map(runLabel)}
        />
      </div>
    </DashboardCard>
  );
}
