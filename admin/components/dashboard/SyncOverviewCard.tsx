import { CircleCheck, CircleX, LoaderCircle } from "lucide-react";

import type { SyncRun } from "../../lib/types/catalog-sync";
import { countBySource, statusShare, syncSourceLabel } from "../../lib/dashboard/metrics";
import { Donut, palette } from "./charts";
import DashboardCard from "./DashboardCard";

export default function SyncOverviewCard({ runs, error }: { runs: SyncRun[]; error?: string }) {
  const share = statusShare(runs);
  const bySource = countBySource(runs);
  return (
    <DashboardCard
      dark
      className="bento-overview"
      title="Tình trạng đồng bộ"
      aside={<span className="bento-chip bento-chip--glass">{runs.length} lượt gần nhất</span>}
      error={error}
      empty={runs.length === 0 && "Chưa có lượt đồng bộ nào."}
    >
      <div className="bento-overview__donuts">
        <Donut value={share.thanh_cong.percent} color={palette.violet} icon={<CircleCheck size={18} />} label="Thành công" caption={`${share.thanh_cong.count} lượt`} />
        <Donut value={share.that_bai.percent} color={palette.accent} icon={<CircleX size={18} />} label="Thất bại" caption={`${share.that_bai.count} lượt`} />
        <Donut value={share.dang_chay.percent} color={palette.secondary} icon={<LoaderCircle size={18} />} label="Đang chạy" caption={`${share.dang_chay.count} lượt`} />
      </div>
      <ul className="bento-overview__sources" aria-label="Số lượt theo nguồn">
        {(Object.keys(syncSourceLabel) as (keyof typeof syncSourceLabel)[]).map(source => (
          <li key={source} className={bySource[source] > 0 ? "is-active" : undefined}>
            {syncSourceLabel[source]} <strong>{bySource[source]}</strong>
          </li>
        ))}
      </ul>
    </DashboardCard>
  );
}
