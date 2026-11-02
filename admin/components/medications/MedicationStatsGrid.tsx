export default function MedicationStatsGrid({ total }: { total: number | null }) {
  return <div className="live-summary"><strong>{total === null ? "Chưa có số liệu" : `${total.toLocaleString("vi-VN")} thuốc khớp tìm kiếm`}</strong></div>;
}
