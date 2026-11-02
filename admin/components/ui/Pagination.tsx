"use client";

type Props = { offset: number; total: number; limit?: number; disabled?: boolean; onChange: (offset: number) => void };
export default function Pagination({ offset, total, limit = 20, disabled, onChange }: Props) {
  return <nav className="live-pagination" aria-label="Phân trang">
    <button type="button" disabled={disabled || offset === 0} onClick={() => onChange(Math.max(0, offset - limit))}>Trang trước</button>
    <span aria-live="polite">{total === 0 ? "0 bản ghi" : `${offset + 1}–${Math.min(offset + limit, total)} / ${total}`}</span>
    <button type="button" disabled={disabled || offset + limit >= total} onClick={() => onChange(offset + limit)}>Trang sau</button>
  </nav>;
}
