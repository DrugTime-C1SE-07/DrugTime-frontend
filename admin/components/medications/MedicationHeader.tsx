"use client";

export default function MedicationHeader({ onOpenCreateModal, onExportData, disabled }: { onOpenCreateModal: () => void; onExportData: () => void; disabled?: boolean }) {
  return <header className="dashboard-header"><div><h1>Danh mục thuốc</h1><p>Quản lý dữ liệu thuốc đã lưu trên máy chủ.</p></div><div className="live-actions">
    <button className="dashboard-action dashboard-action--secondary" type="button" onClick={onExportData} disabled={disabled}>Xuất trang hiện tại</button>
    <button className="dashboard-action dashboard-action--primary" type="button" onClick={onOpenCreateModal} disabled={disabled}>Thêm thuốc</button>
  </div></header>;
}
