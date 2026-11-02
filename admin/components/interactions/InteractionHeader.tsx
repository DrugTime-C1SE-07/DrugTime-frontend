"use client";

export default function InteractionHeader({ onOpenCreateModal, onExportData, disabled }: { onOpenCreateModal: () => void; onExportData: () => void; disabled?: boolean }) {
  return <header className="dashboard-header"><div><h1>Quy tắc tương tác</h1><p>Quản lý theo hoạt chất và phiên bản đã lưu.</p></div><div className="live-actions"><button className="dashboard-action dashboard-action--secondary" type="button" disabled={disabled} onClick={onExportData}>Xuất trang hiện tại</button><button className="dashboard-action dashboard-action--primary" type="button" disabled={disabled} onClick={onOpenCreateModal}>Thêm quy tắc</button></div></header>;
}
