import type { SyncPage } from "../types/catalog-sync";
import { browserRequest } from "./browser-client";

export function syncQuery(source = "", status = "", offset = 0, limit = 20): string {
  const query = new URLSearchParams({ offset: String(offset), limit: String(limit) });
  if (source) query.set("source", source);
  if (status) query.set("status", status);
  return query.toString();
}
export const listSyncRuns = (source: string, status: string, offset: number, signal?: AbortSignal) =>
  browserRequest<SyncPage>(`/api/session/catalog-sync-runs?${syncQuery(source, status, offset)}`, { signal });
export const syncTime = (value: string | null) => value
  ? new Date(value).toLocaleString("vi-VN", { timeZone: "Asia/Ho_Chi_Minh" }) : "Chưa kết thúc";
export const syncStatus = { dang_chay: "Đang chạy", thanh_cong: "Thành công", that_bai: "Thất bại" };
