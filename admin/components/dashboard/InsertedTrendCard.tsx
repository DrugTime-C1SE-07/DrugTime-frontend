import type { SyncRun } from "../../lib/types/catalog-sync";
import { chronological, runLabel, seriesByRun } from "../../lib/dashboard/metrics";
import { CapsuleBars, LineChart, NOT_ENOUGH_RUNS, palette } from "./charts";
import DashboardCard from "./DashboardCard";

const LINE_RUNS = 10;
const BAR_RUNS = 7;

export default function InsertedTrendCard({ runs, error }: { runs: SyncRun[]; error?: string }) {
  const line = seriesByRun(runs, "records_inserted", LINE_RUNS);
  const bars = chronological(runs, BAR_RUNS);
  const total = runs.reduce((sum, run) => sum + run.records_inserted, 0);
  const best = Math.max(0, ...line);
  const average = runs.length ? Math.round(total / runs.length) : 0;
  return (
    <DashboardCard
      className="bento-inserted"
      title="Bản ghi thêm mới"
      subtitle={`${line.length} lượt đồng bộ gần nhất`}
      error={error}
      empty={line.length < 2 && NOT_ENOUGH_RUNS}
    >
      <LineChart
        id="inserted"
        label={`Bản ghi thêm mới theo lượt: ${line.join(", ")}`}
        series={[{ values: line, color: palette.primary, smooth: true }]}
        xLabels={chronological(runs, LINE_RUNS).map(runLabel)}
      />
      <dl className="bento-stats">
        <div><dt><i style={{ background: palette.primary }} aria-hidden="true" />Tổng thêm mới</dt><dd>{total.toLocaleString("vi-VN")}</dd></div>
        <div><dt><i style={{ background: palette.secondary }} aria-hidden="true" />Cao nhất một lượt</dt><dd>{best.toLocaleString("vi-VN")}</dd></div>
        <div><dt><i style={{ background: palette.lilac }} aria-hidden="true" />Trung bình mỗi lượt</dt><dd>{average.toLocaleString("vi-VN")}</dd></div>
      </dl>
      <CapsuleBars
        label={`Thêm mới ${bars.length} lượt gần nhất: ${bars.map(run => `${runLabel(run)} ${run.records_inserted}`).join(", ")}`}
        values={bars.map(run => run.records_inserted)}
        labels={bars.map(runLabel)}
        colors={bars.map(run => (run.source === "dav_drugbank" ? palette.secondary : palette.primary))}
      />
      <p className="bento-legend">
        <span><i style={{ background: palette.secondary }} aria-hidden="true" />DAV DrugBank</span>
        <span><i style={{ background: palette.primary }} aria-hidden="true" />Dược thư QG</span>
      </p>
    </DashboardCard>
  );
}
