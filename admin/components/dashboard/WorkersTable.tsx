import { ArrowRight, CheckCircle2, CircleAlert, TerminalSquare } from "lucide-react";

const workers = [
  {
    source: "dichvucong.dav.gov.vn",
    tone: "green",
    time: "Hôm nay, 04:00 AM",
    records: "850",
    note: "+14 mới",
    duration: "3 phút 24 giây",
    status: "Hoàn thành",
    statusTone: "green",
  },
  {
    source: "Drugbank.vn",
    tone: "blue",
    time: "Hôm qua, 22:30 PM",
    records: "1,240",
    note: "",
    duration: "8 phút 12 giây",
    status: "Hoàn thành",
    statusTone: "green",
  },
  {
    source: "Bộ Y Tế - Thông tư Dược lâm sàng",
    tone: "red",
    time: "28/02/2025, 14:15 PM",
    records: "32 / 120",
    note: "",
    duration: "45 giây (Abort)",
    status: "Cần đối soát tay",
    statusTone: "red",
  },
];

export default function WorkersTable() {
  return (
    <section className="dashboard-panel dashboard-workers">
      <div className="dashboard-workers__header">
        <div className="dashboard-workers__title">
          <span aria-hidden="true">
            <TerminalSquare size={26} strokeWidth={2.3} />
          </span>
          <div>
            <h2>Nhật ký & Tiến trình Workers</h2>
          </div>
        </div>
        <button type="button">
          Xem toàn bộ
          <ArrowRight size={22} strokeWidth={2.4} aria-hidden="true" />
        </button>
      </div>

      <div className="workers-table" role="table" aria-label="Nhật ký tiến trình workers">
        <div className="workers-table__head" role="row">
          <span>Nguồn dữ liệu</span>
          <span>Thời điểm chạy</span>
          <span>Bản ghi</span>
          <span>Thời lượng</span>
          <span>Trạng thái</span>
        </div>
        {workers.map((worker) => (
          <div className="workers-table__row" role="row" key={worker.source}>
            <strong>
              <i className={`worker-source-dot worker-source-dot--${worker.tone}`} />
              {worker.source}
            </strong>
            <span>{worker.time}</span>
            <span className={worker.statusTone === "red" ? "text-red" : undefined}>
              {worker.records}
              {worker.note ? <em> ({worker.note})</em> : null}
            </span>
            <span>{worker.duration}</span>
            <span className={`worker-status worker-status--${worker.statusTone}`}>
              {worker.statusTone === "red" ? (
                <CircleAlert size={22} strokeWidth={2.3} aria-hidden="true" />
              ) : (
                <CheckCircle2 size={22} strokeWidth={2.3} aria-hidden="true" />
              )}
              {worker.status}
            </span>
          </div>
        ))}
      </div>

      <div className="dashboard-workers__footer">
        <button type="button">Khởi động lại Worker</button>
      </div>
    </section>
  );
}
