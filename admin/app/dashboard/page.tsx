import CatalogGaugeCard, { type CatalogCounts } from "../../components/dashboard/CatalogGaugeCard";
import CatalogMixCard from "../../components/dashboard/CatalogMixCard";
import FailedTrendCard from "../../components/dashboard/FailedTrendCard";
import InsertedTrendCard from "../../components/dashboard/InsertedTrendCard";
import LatestRunCard from "../../components/dashboard/LatestRunCard";
import RecordShareCard from "../../components/dashboard/RecordShareCard";
import RecordsAreaCard from "../../components/dashboard/RecordsAreaCard";
import RunDurationCard from "../../components/dashboard/RunDurationCard";
import SyncOverviewCard from "../../components/dashboard/SyncOverviewCard";
import { apiFetchWithSession } from "../../lib/api/client";
import type { SyncPage } from "../../lib/types/catalog-sync";

const SYNC_RUNS = 20;
const SYNC_ERROR = "Không tải được lịch sử đồng bộ. Hãy kiểm tra phiên đăng nhập hoặc thử tải lại.";

type Total = { total: number };
const count = (path: string) => apiFetchWithSession<Total>(`${path}?skip=0&limit=1`, { method: "GET" });
const totalOf = (result: PromiseSettledResult<Total>) => (result.status === "fulfilled" ? result.value.total : null);

export default async function DashboardPage() {
  const [sync, medications, ingredients, drugInteractions, foodInteractions] = await Promise.allSettled([
    apiFetchWithSession<SyncPage>(`/admin/catalog/sync-runs?offset=0&limit=${SYNC_RUNS}`, { method: "GET" }),
    count("/admin/medications"),
    count("/admin/active-ingredients"),
    count("/admin/drug-interactions"),
    count("/admin/drug-food-interactions"),
  ]);
  const runs = sync.status === "fulfilled" ? sync.value.items : [];
  const error = sync.status === "rejected" ? SYNC_ERROR : undefined;
  const counts: CatalogCounts = {
    medications: totalOf(medications),
    ingredients: totalOf(ingredients),
    drugInteractions: totalOf(drugInteractions),
    foodInteractions: totalOf(foodInteractions),
  };

  return (
    <section className="bento" aria-labelledby="bento-title">
      <h1 id="bento-title" className="visually-hidden">Tổng quan dữ liệu</h1>
      <div className="bento__col bento__col--left">
        <InsertedTrendCard runs={runs} error={error} />
        <FailedTrendCard runs={runs} error={error} />
      </div>
      <div className="bento__col bento__col--center">
        <SyncOverviewCard runs={runs} error={error} />
        <RecordsAreaCard runs={runs} error={error} />
        <RunDurationCard runs={runs} error={error} />
      </div>
      <div className="bento__col bento__col--right">
        <CatalogGaugeCard counts={counts} runs={runs} runsError={error} />
        <LatestRunCard runs={runs} error={error} />
        <RecordShareCard runs={runs} error={error} />
        <CatalogMixCard counts={counts} />
      </div>
    </section>
  );
}
