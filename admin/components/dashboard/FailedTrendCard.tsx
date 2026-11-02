import type { SyncRun } from "../../lib/types/catalog-sync";
import { chronological, recordTotals, runLabel, seriesByRun, statusShare } from "../../lib/dashboard/metrics";
import { LineChart, NOT_ENOUGH_RUNS, palette } from "./charts";
import DashboardCard from "./DashboardCard";

const RUNS = 10;

export default function FailedTrendCard({ runs, error }: { runs: SyncRun[]; error?: string }) {
  const failed = seriesByRun(runs, "records_failed", RUNS);
  const totals = recordTotals(runs);
  const failedRuns = statusShare(runs).that_bai.count;
  return (
    <DashboardCard
      className="bento-failed"
      title="Bản ghi lỗi theo lượt"
      aside={
        <span className="bento-chip bento-chip--alert">{failedRuns} lượt thất bại</span>
      }
      error={error}
      empty={failed.length < 2 && NOT_ENOUGH_RUNS}
    >
      <LineChart
        id="failed"
        label={`Bản ghi lỗi theo lượt: ${failed.join(", ")}`}
        series={[{ values: failed, color: palette.accent, dots: true }]}
        xLabels={chronological(runs, RUNS).map(runLabel)}
      />
      <dl className="bento-stats bento-stats--row">
        <div><dt>Tổng bản ghi lỗi</dt><dd className="is-alert">{totals.failed.toLocaleString("vi-VN")}</dd></div>
        <div><dt>Lượt có lỗi</dt><dd>{runs.filter(run => run.records_failed > 0).length}</dd></div>
        <div><dt>Cao nhất một lượt</dt><dd>{Math.max(0, ...failed).toLocaleString("vi-VN")}</dd></div>
      </dl>
    </DashboardCard>
  );
}
