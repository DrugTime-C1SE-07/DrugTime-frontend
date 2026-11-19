import { formatRequestedAt, type DeletionRequest } from "../../lib/deletion-requests/queue";

const STATUS_LABEL: Record<DeletionRequest["status"], string> = {
  cho_duyet: "Chờ duyệt",
};

/** Bảng chỉ đọc; giữ nguyên thứ tự backend trả về (requested_at rồi id tăng dần). */
export default function DeletionQueueTable({ items }: { items: DeletionRequest[] }) {
  return (
    <div className="medication-table-card deletion-queue__card">
      <table className="deletion-queue__table">
        <caption className="deletion-queue__caption">Yêu cầu xóa dữ liệu đang chờ duyệt</caption>
        <thead>
          <tr>
            <th scope="col">Mã yêu cầu</th>
            <th scope="col">Mã người gửi</th>
            <th scope="col">Thời điểm gửi</th>
            <th scope="col">Trạng thái</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.id}>
              <td>{item.id}</td>
              <td className="deletion-queue__user-id">{item.user_id}</td>
              <td>
                <time dateTime={item.requested_at}>{formatRequestedAt(item.requested_at)}</time>
              </td>
              <td>
                <span className="deletion-queue__badge">{STATUS_LABEL[item.status] ?? item.status}</span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
