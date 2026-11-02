"use client";

import { useEffect, useState } from "react";
import { listSyncRuns, syncStatus, syncTime } from "../../../lib/api/catalog-sync";
import type { SyncPage } from "../../../lib/types/catalog-sync";
import Pagination from "../../../components/ui/Pagination";

export default function ScraperLogsPage() {
  const [source, setSource] = useState(""); const [status, setStatus] = useState(""); const [offset, setOffset] = useState(0);
  const [page, setPage] = useState<SyncPage | null>(null); const [error, setError] = useState(""); const [loading, setLoading] = useState(true); const [revision, setRevision] = useState(0);
  useEffect(() => {
    const controller = new AbortController(); setLoading(true); setError("");
    listSyncRuns(source, status, offset, controller.signal).then(value => { if (!controller.signal.aborted) setPage(value); })
      .catch(reason => { if (!controller.signal.aborted) setError(reason.message); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [source, status, offset, revision]);
  return <section><h1>Lịch sử đồng bộ danh mục</h1><div className="live-filters">
    <label>Nguồn<select value={source} onChange={event => { setSource(event.target.value); setOffset(0); }}><option value="">Tất cả</option><option value="dav_drugbank">DAV / DrugBank</option><option value="duoc_thu_qg">Dược thư Quốc gia</option></select></label>
    <label>Trạng thái<select value={status} onChange={event => { setStatus(event.target.value); setOffset(0); }}><option value="">Tất cả</option><option value="dang_chay">Đang chạy</option><option value="thanh_cong">Thành công</option><option value="that_bai">Thất bại</option></select></label>
    <button type="button" onClick={() => setRevision(value => value + 1)} disabled={loading}>Tải lại</button>
  </div>
    {loading ? <p role="status">Đang tải lịch sử…</p> : error ? <p role="alert" className="live-error">{error}</p> : page && <>
      {page.items.length === 0 ? <p>Chưa có lượt đồng bộ khớp bộ lọc.</p> : <div className="live-table-wrap"><table className="live-table"><caption>Giờ Việt Nam</caption><thead><tr><th>ID / Nguồn</th><th>Bắt đầu / kết thúc</th><th>Trạng thái</th><th>Thêm / sửa / lỗi</th><th>Kích hoạt</th><th>Báo cáo lỗi</th></tr></thead><tbody>{page.items.map(run => <tr key={run.id}><td>{run.id} / {run.source}</td><td>{syncTime(run.started_at)}<br />{syncTime(run.finished_at)}</td><td>{syncStatus[run.status]}</td><td>{run.records_inserted} / {run.records_updated} / {run.records_failed}</td><td>{run.triggered_by === "scheduler" ? "Lịch tự động" : "Quản trị viên"}</td><td>{typeof run.error_details?.message === "string" ? run.error_details.message : "—"}</td></tr>)}</tbody></table></div>}
      <Pagination offset={offset} total={page.total} onChange={setOffset} />
    </>}
  </section>;
}
