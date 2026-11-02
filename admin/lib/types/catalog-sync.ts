export type SyncSource = "dav_drugbank" | "duoc_thu_qg";
export type SyncStatus = "dang_chay" | "thanh_cong" | "that_bai";
export interface SyncRun {
  id: number;
  source: SyncSource;
  status: SyncStatus;
  started_at: string;
  finished_at: string | null;
  records_inserted: number;
  records_updated: number;
  records_failed: number;
  error_details: Record<string, unknown> | null;
  triggered_by: "scheduler" | "admin_thu_cong";
}
export type SyncPage = { items: SyncRun[]; total: number; limit: number; offset: number };
