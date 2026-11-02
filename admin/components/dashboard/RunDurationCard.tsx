import type { SyncRun } from "../../lib/types/catalog-sync";
import { chronological, durationMinutes, runLabel } from "../../lib/dashboard/metrics";
import { LineChart, NOT_ENOUGH_RUNS, palette } from "./charts";
import DashboardCard from "./DashboardCard";

const RUNS = 12;

export default function RunDurationCard({ runs, error }: { runs: SyncRun[]; error?: string }) {
  const finished = runs.filter(run => run.finished_at !== null);
  const minutes = durationMinutes(finished, RUNS);
  const average = minutes.length ? Math.round(minutes.reduce((sum, value) => sum + value, 0) / minutes.length) : 0;
  return (
    <DashboardCard
      className="bento-duration"
      title="Thời lượng mỗi lượt"
      subtitle="Chỉ tính các lượt đã kết thúc, đơn vị phút"
      aside={<span className="bento-chip">Trung bình {average} phút</span>}
      error={error}
      empty={minutes.length < 2 && NOT_ENOUGH_RUNS}
    >
      <LineChart
        id="duration"
        label={`Thời lượng theo lượt (phút): ${minutes.join(", ")}`}
        series={[{ values: minutes, color: palette.primary, area: true }]}
        peak={{ series: 0, text: value => `Lâu nhất: ${value} phút` }}
        xLabels={chronological(finished, RUNS).map(runLabel)}
      />
    </DashboardCard>
  );
}
