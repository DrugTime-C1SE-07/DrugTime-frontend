import type { SyncRun } from "../../lib/types/catalog-sync";
import { syncStatus, syncTime } from "../../lib/api/catalog-sync";
import { cleanRate, latestRun, syncSourceLabel } from "../../lib/dashboard/metrics";
import DashboardCard from "./DashboardCard";

const dayPart = (iso: string, part: "day" | "month") =>
  new Intl.DateTimeFormat("vi-VN", { timeZone: "Asia/Ho_Chi_Minh", [part]: part === "day" ? "2-digit" : "short" }).format(new Date(iso));

export default function LatestRunCard({ runs, error }: { runs: SyncRun[]; error?: string }) {
  const run = latestRun(runs);
  const rate = run ? cleanRate([run]) : null;
  return (
    <DashboardCard className="bento-latest" title="Lượt đồng bộ gần nhất" error={error} empty={!run && "Chưa có lượt đồng bộ nào."}>
      {run ? (
        <div className="bento-latest__layout">
          <time className="bento-latest__date" dateTime={run.started_at}>
            <span>{dayPart(run.started_at, "month")}</span>
            <strong>{dayPart(run.started_at, "day")}</strong>
          </time>
          <div className="bento-latest__detail">
            <span className={`bento-chip bento-chip--${run.status}`}>{syncStatus[run.status]}</span>
            <p>{syncSourceLabel[run.source]}</p>
            <small>Bắt đầu {syncTime(run.started_at)}</small>
            {rate === null ? (
              <small>Lượt này chưa ghi nhận bản ghi.</small>
            ) : (
              <div className="bento-progress__track bento-progress__track--teal" role="progressbar" aria-label="Bản ghi không lỗi của lượt này" aria-valuenow={rate} aria-valuemin={0} aria-valuemax={100} aria-valuetext={`${rate}% bản ghi không lỗi`}>
                <div style={{ width: `${rate}%` }} />
              </div>
            )}
          </div>
        </div>
      ) : null}
    </DashboardCard>
  );
}
