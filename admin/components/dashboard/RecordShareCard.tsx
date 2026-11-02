import type { SyncRun } from "../../lib/types/catalog-sync";
import { percent, recordTotals, statusShare } from "../../lib/dashboard/metrics";
import { ProgressBar, palette } from "./charts";
import DashboardCard from "./DashboardCard";

export default function RecordShareCard({ runs, error }: { runs: SyncRun[]; error?: string }) {
  const totals = recordTotals(runs);
  const success = statusShare(runs).thanh_cong;
  const n = (value: number) => value.toLocaleString("vi-VN");
  return (
    <DashboardCard
      className="bento-share"
      title="Cơ cấu bản ghi"
      aside={<span className="bento-chip bento-chip--solid">{n(totals.total)} bản ghi</span>}
      error={error}
      empty={runs.length === 0 && "Chưa có lượt đồng bộ nào."}
    >
      <ProgressBar label="Thêm mới" value={percent(totals.inserted, totals.total)} color={palette.primary} detail={`${n(totals.inserted)} bản ghi`} />
      <ProgressBar label="Cập nhật" value={percent(totals.updated, totals.total)} color={palette.secondary} detail={`${n(totals.updated)} bản ghi`} />
      <ProgressBar label="Lỗi" value={percent(totals.failed, totals.total)} color={palette.accent} detail={`${n(totals.failed)} bản ghi`} />
      <ProgressBar label="Lượt thành công" value={success.percent} color={palette.violet} detail={`${success.count} trên ${runs.length} lượt`} />
    </DashboardCard>
  );
}
