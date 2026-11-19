/**
 * Logic thuần của hàng chờ yêu cầu xóa dữ liệu (task 5.07). Không import `next/*` để test được
 * bằng `node --test` (scripts/deletion-queue.test.mjs). Hình dạng dữ liệu theo contract 5.06
 * của `GET /admin/deletion-requests`.
 */

export const PAGE_SIZE = 20;

export type DeletionRequest = {
  id: number;
  user_id: string;
  requested_at: string;
  status: "cho_duyet";
};

export type DeletionQueuePage = {
  items: DeletionRequest[];
  total: number;
};

export type QueueErrorView = "session_expired" | "forbidden" | "unavailable";

/** Đọc `?page=` từ URL; thiếu hoặc không phải số nguyên dương thì về trang 1. */
export function parsePage(raw: string | string[] | undefined): number {
  if (typeof raw !== "string" || !/^[1-9]\d*$/.test(raw)) {
    return 1;
  }
  return Number(raw);
}

export function skipFor(page: number): number {
  return (page - 1) * PAGE_SIZE;
}

export function pageCount(total: number): number {
  return Math.max(1, Math.ceil(total / PAGE_SIZE));
}

/**
 * Trang hiện tại vượt cuối vì hàng chờ đã ngắn lại: trả trang hợp lệ cuối cùng để chuyển hướng.
 * Hàng chờ rỗng hoặc trang còn dữ liệu thì trả `null`.
 */
export function overflowTarget(page: number, total: number, itemCount: number): number | null {
  if (itemCount > 0 || total === 0) {
    return null;
  }
  const last = pageCount(total);
  return page > last ? last : null;
}

const VN_DATE_TIME = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Asia/Ho_Chi_Minh",
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

/** `dd/MM/yyyy HH:mm` theo Asia/Ho_Chi_Minh; dựng từ parts để không phụ thuộc dấu phân cách của ICU. */
export function formatRequestedAt(iso: string): string {
  const parts: Record<string, string> = {};
  for (const part of VN_DATE_TIME.formatToParts(new Date(iso))) {
    parts[part.type] = part.value;
  }
  return `${parts.day}/${parts.month}/${parts.year} ${parts.hour}:${parts.minute}`;
}

/** 401 và 403 có màn riêng; mọi lỗi khác (422, 5xx, mạng) là không tải được. */
export function queueErrorView(status: number): QueueErrorView {
  if (status === 401) return "session_expired";
  if (status === 403) return "forbidden";
  return "unavailable";
}
