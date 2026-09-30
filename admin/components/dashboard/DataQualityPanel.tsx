import { ShieldCheck } from "lucide-react";

const qualityItems = [
  {
    label: "Đã xác thực & chuẩn Dược thư",
    value: "84%",
    width: "84%",
    tone: "green",
  },
  {
    label: "Dữ liệu mới / Chờ kiểm duyệt",
    value: "14%",
    width: "14%",
    tone: "blue",
  },
  {
    label: "Thiếu trường thông tin",
    value: "2%",
    width: "2%",
    tone: "red",
  },
];

export default function DataQualityPanel() {
  return (
    <section className="dashboard-panel dashboard-quality">
      <div className="dashboard-quality__header">
        <h2>Chất lượng dữ liệu</h2>
        <span aria-hidden="true">
          <ShieldCheck size={26} strokeWidth={2.3} />
        </span>
      </div>

      <div className="quality-ring" aria-label="98.2 phần trăm chuẩn hóa">
        <span>98.2%</span>
        <strong>Chuẩn hóa</strong>
      </div>

      <div className="quality-list">
        {qualityItems.map((item) => (
          <div className="quality-item" key={item.label}>
            <div>
              <span className={`quality-dot quality-dot--${item.tone}`} />
              <strong>{item.label}</strong>
              <em>{item.value}</em>
            </div>
            <span className="quality-track">
              <i className={`quality-fill quality-fill--${item.tone}`} style={{ width: item.width }} />
            </span>
          </div>
        ))}
      </div>

      <div className="dashboard-quality__footer">
        <span>Cập nhật bảng quy chuẩn:</span>
        <strong>Dược Điển Việt Nam</strong>
      </div>
    </section>
  );
}
