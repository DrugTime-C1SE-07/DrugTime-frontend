import { apiFetchWithSession } from "./client";
import { PAGE_SIZE, skipFor, type DeletionQueuePage } from "../deletion-requests/queue";

/** Một trang hàng chờ yêu cầu xóa dữ liệu (`GET /admin/deletion-requests`, contract 5.06). Chỉ gọi từ server. */
export function fetchDeletionQueue(page: number): Promise<DeletionQueuePage> {
  const query = new URLSearchParams({ skip: String(skipFor(page)), limit: String(PAGE_SIZE) });
  return apiFetchWithSession<DeletionQueuePage>(`/admin/deletion-requests?${query}`, {
    method: "GET",
  });
}
