export default function InteractionStatsGrid({ total }: { total: number | null }) {
  return <div className="live-summary"><strong>{total === null ? "Chưa có số liệu" : `${total.toLocaleString("vi-VN")} quy tắc khớp bộ lọc của loại đang chọn`}</strong></div>;
}
