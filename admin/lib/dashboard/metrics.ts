import type { SyncRun, SyncSource, SyncStatus } from "../types/catalog-sync";

/**
 * Số liệu dẫn xuất cho trang Tổng quan, tính từ lịch sử đồng bộ thật.
 * Hàm thuần (không React) để kiểm thử bằng node:test; mọi hàm an toàn với mảng rỗng và chia 0.
 */
export type Point = { x: number; y: number };
export type RecordKey = "records_inserted" | "records_updated" | "records_failed";

const MS_PER_MINUTE = 60_000;
const TIME_ZONE = "Asia/Ho_Chi_Minh";

export const syncSourceLabel: Record<SyncSource, string> = { dav_drugbank: "DAV DrugBank", duoc_thu_qg: "Dược thư QG" };

/** Nhãn trục x: ngày/tháng của lượt theo giờ Việt Nam. */
export function runLabel(run: SyncRun): string {
  // Ghép tay vì dấu phân cách của vi-VN khác nhau giữa các bản ICU ("29/10" hay "29-10").
  const parts = new Intl.DateTimeFormat("vi-VN", { timeZone: TIME_ZONE, day: "2-digit", month: "2-digit" }).formatToParts(new Date(run.started_at));
  const part = (type: "day" | "month") => parts.find(p => p.type === type)?.value ?? "";
  return `${part("day")}/${part("month")}`;
}

export function percent(part: number, whole: number): number {
  if (whole <= 0) return 0;
  return Math.round((part / whole) * 1000) / 10;
}

/** Lượt cũ → mới, chỉ giữ `limit` lượt gần nhất. */
export function chronological(runs: SyncRun[], limit = runs.length): SyncRun[] {
  const sorted = [...runs].sort((a, b) => Date.parse(a.started_at) - Date.parse(b.started_at));
  return limit > 0 ? sorted.slice(-limit) : [];
}

export function latestRun(runs: SyncRun[]): SyncRun | null {
  return chronological(runs).at(-1) ?? null;
}

export function statusShare(runs: SyncRun[]): Record<SyncStatus, { count: number; percent: number }> {
  const count = (status: SyncStatus) => runs.filter(run => run.status === status).length;
  const share = (status: SyncStatus) => ({ count: count(status), percent: percent(count(status), runs.length) });
  return { thanh_cong: share("thanh_cong"), that_bai: share("that_bai"), dang_chay: share("dang_chay") };
}

export function countBySource(runs: SyncRun[]): Record<SyncSource, number> {
  return {
    dav_drugbank: runs.filter(run => run.source === "dav_drugbank").length,
    duoc_thu_qg: runs.filter(run => run.source === "duoc_thu_qg").length,
  };
}

export function seriesByRun(runs: SyncRun[], key: RecordKey, limit = runs.length): number[] {
  return chronological(runs, limit).map(run => run[key]);
}

export type RecordTotals = { inserted: number; updated: number; failed: number; total: number };

export function recordTotals(runs: SyncRun[]): RecordTotals {
  const sum = (key: RecordKey) => runs.reduce((total, run) => total + run[key], 0);
  const inserted = sum("records_inserted");
  const updated = sum("records_updated");
  const failed = sum("records_failed");
  return { inserted, updated, failed, total: inserted + updated + failed };
}

/** Phút chạy của từng lượt đã kết thúc; lượt đang chạy bị bỏ qua thay vì ước lượng. */
export function durationMinutes(runs: SyncRun[], limit = runs.length): number[] {
  return chronological(runs.filter(run => run.finished_at !== null), limit).map(run =>
    Math.max(0, Math.round((Date.parse(run.finished_at as string) - Date.parse(run.started_at)) / MS_PER_MINUTE)),
  );
}

/** Tỉ lệ % bản ghi không lỗi; `null` khi chưa có bản ghi nào (UI hiện trạng thái trống). */
export function cleanRate(runs: SyncRun[]): number | null {
  const { failed, total } = recordTotals(runs);
  return total === 0 ? null : percent(total - failed, total);
}

export function peakIndex(values: number[]): number {
  if (values.length === 0) return -1;
  return values.reduce((best, value, index) => (value > values[best] ? index : best), 0);
}

/** Đặt giá trị vào khung w×h (gốc 0 ở đáy), chừa `pad` trên/dưới; `ceiling` để nhiều chuỗi dùng chung thang. */
export function scale(values: number[], width: number, height: number, pad = 0, ceiling?: number): Point[] {
  if (values.length === 0) return [];
  const min = Math.min(0, ...values);
  const range = Math.max(ceiling ?? 0, ...values) - min || 1;
  const step = values.length > 1 ? width / (values.length - 1) : 0;
  return values.map((value, index) => ({
    x: round(index * step),
    y: round(height - pad - ((value - min) / range) * (height - 2 * pad)),
  }));
}

export function linePath(points: Point[]): string {
  if (points.length < 2) return "";
  return points.map((p, index) => `${index === 0 ? "M" : "L"} ${p.x} ${p.y}`).join(" ");
}

/** Đường cong mượt qua mọi điểm (điểm điều khiển nằm giữa hai điểm theo trục x). */
export function smoothPath(points: Point[]): string {
  if (points.length < 2) return "";
  return points.reduce((path, p, index) => {
    if (index === 0) return `M ${p.x} ${p.y}`;
    const prev = points[index - 1];
    const midX = round((prev.x + p.x) / 2);
    return `${path} C ${midX} ${prev.y}, ${midX} ${p.y}, ${p.x} ${p.y}`;
  }, "");
}

/** Khép một đường (line hoặc smooth) xuống đáy khung để tô vùng. */
export function areaPath(path: string, points: Point[], height: number): string {
  if (!path || points.length < 2) return "";
  return `${path} L ${points[points.length - 1].x} ${height} L ${points[0].x} ${height} Z`;
}

/** Cung nửa trên của đồng hồ, từ trái (0%) theo chiều kim đồng hồ đến `ratio` (0–1). */
export function gaugeArc(ratio: number, cx: number, cy: number, radius: number): string {
  const clamped = Math.min(1, Math.max(0, ratio));
  if (clamped === 0) return "";
  const angle = Math.PI - clamped * Math.PI;
  const endX = round(cx + radius * Math.cos(angle));
  const endY = round(cy - radius * Math.sin(angle));
  return `M ${cx - radius} ${cy} A ${radius} ${radius} 0 0 1 ${endX} ${endY}`;
}

function round(value: number): number {
  return Math.round(value * 100) / 100;
}
