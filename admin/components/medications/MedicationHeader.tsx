"use client";

import { ChevronRight, Download, Plus } from "lucide-react";

interface MedicationHeaderProps {
  onOpenCreateModal: () => void;
  onExportData: () => void;
}

export default function MedicationHeader({
  onOpenCreateModal,
  onExportData,
}: MedicationHeaderProps) {
  return (
    <header className="medications-header">
      <div>
        <nav className="dashboard-breadcrumb" aria-label="Đường dẫn">
          <span>DrugTime Admin</span>
          <ChevronRight size={14} strokeWidth={2} aria-hidden="true" />
          <strong>Danh mục CSDL</strong>
        </nav>
        <h1>Danh mục thuốc tự lưu trữ</h1>
        <p>
          Cơ sở dữ liệu biệt dược và hoạt chất bóc tách từ Dược thư Quốc gia & Cục Quản lý Dược (DAV)
        </p>
      </div>

      <div className="medications-header__actions">
        <button
          className="dashboard-action dashboard-action--secondary"
          type="button"
          onClick={onExportData}
        >
          <Download size={18} strokeWidth={2} aria-hidden="true" />
          Xuất dữ liệu
        </button>
        <button
          className="dashboard-action dashboard-action--primary"
          type="button"
          onClick={onOpenCreateModal}
        >
          <Plus size={18} strokeWidth={2.2} aria-hidden="true" />
          Thêm thuốc mới
        </button>
      </div>
    </header>
  );
}
