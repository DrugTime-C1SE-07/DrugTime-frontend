import { ShieldCheck } from "lucide-react";

type QualityTone = "green" | "blue" | "red";

type QualityItem = {
  label: string;
  percent: number;
  tone: QualityTone;
};

// Dữ liệu mẫu; tổng 100%. Vòng tròn, số ở giữa và các thanh đều đọc từ mảng này.
const qualityItems: QualityItem[] = [
  { label: "Đã xác thực & chuẩn Dược thư", percent: 84, tone: "green" },
  { label: "Dữ liệu mới / Chờ kiểm duyệt", percent: 14, tone: "blue" },
  { label: "Thiếu trường thông tin", percent: 2, tone: "red" },
];

const RING_RADIUS = 52;
const RING_CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS;
// Khe hở giữa hai cung liền nhau (đơn vị viewBox); cung nhỏ hơn khe thì không trừ.
const SEGMENT_GAP = 2;

export default function DataQualityPanel() {
  const [headline] = qualityItems;
  let offset = 0;
  const segments = qualityItems.map((item) => {
    const length = (item.percent / 100) * RING_CIRCUMFERENCE;
    const visible = length > SEGMENT_GAP * 2 ? length - SEGMENT_GAP : length;
    const segment = { ...item, visible, offset };
    offset += length;
    return segment;
  });

  return (
    <section className="dashboard-panel dashboard-quality">
      <div className="dashboard-quality__header">
        <h2>Chất lượng dữ liệu</h2>
        <span aria-hidden="true">
          <ShieldCheck size={26} strokeWidth={2.3} />
        </span>
      </div>

      <div
        className="quality-ring"
        role="img"
        aria-label={qualityItems.map((item) => `${item.label} ${item.percent}%`).join(", ")}
      >
        <svg viewBox="0 0 120 120" aria-hidden="true">
          <circle className="quality-ring__track" cx="60" cy="60" r={RING_RADIUS} />
          {segments.map((segment) => (
            <circle
              key={segment.label}
              className={`quality-ring__segment quality-ring__segment--${segment.tone}`}
              cx="60"
              cy="60"
              r={RING_RADIUS}
              strokeDasharray={`${segment.visible} ${RING_CIRCUMFERENCE - segment.visible}`}
              strokeDashoffset={-segment.offset}
            />
          ))}
        </svg>
        <div className="quality-ring__label">
          <span>{headline.percent}%</span>
          <strong>Đã xác thực</strong>
        </div>
      </div>

      <div className="quality-list">
        {qualityItems.map((item) => (
          <div className="quality-item" key={item.label}>
            <div>
              <span className={`quality-dot quality-dot--${item.tone}`} />
              <strong>{item.label}</strong>
              <em>{item.percent}%</em>
            </div>
            <span className="quality-track">
              <i className={`quality-fill quality-fill--${item.tone}`} style={{ width: `${item.percent}%` }} />
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
