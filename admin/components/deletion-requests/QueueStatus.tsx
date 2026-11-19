import LogoutButton from "../auth/LogoutButton";
import RefreshButton from "./RefreshButton";
import type { QueueErrorView } from "../../lib/deletion-requests/queue";

type QueueStatusProps = { view: QueueErrorView | "empty" };

/** Khối trạng thái thay cho bảng. Các trạng thái lỗi không hiển thị dòng hay tổng số nào. */
export default function QueueStatus({ view }: QueueStatusProps) {
  switch (view) {
    case "empty":
      return (
        <p className="deletion-queue__status" role="status">
          Không có yêu cầu chờ duyệt.
        </p>
      );
    case "unavailable":
      return (
        <div className="deletion-queue__status deletion-queue__status--error" role="alert">
          <p>Không tải được hàng chờ. Vui lòng thử lại.</p>
          <RefreshButton label="Thử lại" />
        </div>
      );
    case "forbidden":
      return (
        <div className="deletion-queue__status deletion-queue__status--error" role="alert">
          <p>Tài khoản này không có quyền xem hàng chờ yêu cầu xóa dữ liệu.</p>
        </div>
      );
    case "session_expired":
      // Không redirect thẳng: cookie còn hạn thì middleware đẩy /auth/login về lại /dashboard.
      return (
        <div className="deletion-queue__status deletion-queue__status--error" role="alert">
          <p>Phiên đăng nhập đã hết hiệu lực. Đăng xuất rồi đăng nhập lại để tiếp tục.</p>
          <LogoutButton className="dashboard-action dashboard-action--secondary" iconSize={16} />
        </div>
      );
  }
}
