import { Clock } from "lucide-react";

const chartLabels = [
  "Thứ 2 (24/02)",
  "Thứ 3 (25/02)",
  "Thứ 4 (26/02)",
  "Thứ 5 (27/02)",
  "Thứ 6 (28/02)",
  "Thứ 7 (01/03)",
  "Hôm nay",
];

export default function SyncStatusPanel() {
  return (
    <section className="dashboard-panel dashboard-sync">
      <div className="dashboard-panel__header">
        <div>
          <div className="dashboard-title-row">
            <h2>Trạng thái đồng bộ</h2>
            <span>LIVE</span>
          </div>
          <p>Bóc tách tự động từ dichvucong.dav.gov.vn & CSDL Dược Quốc gia</p>
        </div>
        <div className="dashboard-tabs" role="tablist" aria-label="Khoảng thời gian">
          <button type="button" className="dashboard-tabs__active">
            7 ngày qua
          </button>
          <button type="button">30 ngày qua</button>
        </div>
      </div>

      <div className="dashboard-sync__stats">
        <div>
          <span>Tỷ lệ thành công</span>
          <strong className="text-green">98.7%</strong>
        </div>
        <div>
          <span>Bản ghi thu nạp</span>
          <strong className="text-blue">14,210</strong>
        </div>
        <div>
          <span>Lỗi DOM / Phản hồi chậm</span>
          <strong className="text-red">185</strong>
        </div>
      </div>

      <div className="dashboard-chart" aria-label="Biểu đồ trạng thái đồng bộ 7 ngày qua">
        <svg viewBox="0 0 760 300" role="img" aria-labelledby="sync-chart-title">
          <title id="sync-chart-title">Dữ liệu thành công tăng dần, lỗi DOM ổn định thấp</title>
          <defs>
            <linearGradient id="syncArea" x1="0" x2="0" y1="0" y2="1">
              <stop offset="0%" stopColor="#0876a6" stopOpacity="0.2" />
              <stop offset="100%" stopColor="#0876a6" stopOpacity="0.02" />
            </linearGradient>
          </defs>
          <path className="chart-grid" d="M0 72H760M0 140H760M0 208H760" />
          <path className="chart-area" d="M0 246 C80 218 130 198 210 190 C330 178 450 166 560 146 C650 130 710 112 760 94 L760 270 L0 270 Z" />
          <path className="chart-line chart-line--success" d="M0 246 C80 218 130 198 210 190 C330 178 450 166 560 146 C650 130 710 112 760 94" />
          <path className="chart-line chart-line--error" d="M0 266 C110 260 210 262 310 266 C430 272 520 260 610 256 C680 252 725 254 760 254" />
          {[120, 250, 380, 510, 640, 760].map((x) => (
            <circle key={x} cx={x} cy={x === 760 ? 94 : x === 640 ? 128 : x === 510 ? 148 : x === 380 ? 164 : x === 250 ? 180 : 210} r="5" />
          ))}
        </svg>
        <div className="dashboard-chart__labels">
          {chartLabels.map((label) => (
            <span key={label}>{label}</span>
          ))}
        </div>
      </div>

      <div className="dashboard-sync__legend">
        <span>
          <i className="legend-dot legend-dot--blue" />
          Dữ liệu thành công
        </span>
        <span>
          <i className="legend-line legend-line--red" />
          Lỗi DOM / Timeout
        </span>
        <span>
          <Clock size={20} strokeWidth={2.2} aria-hidden="true" />
          Chu kỳ cào: Mỗi 04:00 AM hằng ngày
        </span>
      </div>
    </section>
  );
}
