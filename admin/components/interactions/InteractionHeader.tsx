"use client";

import { ChevronRight, Download, Plus } from "lucide-react";

interface InteractionHeaderProps {
  onOpenCreateModal: () => void;
  onExportData: () => void;
}

export default function InteractionHeader({
  onOpenCreateModal,
  onExportData,
}: InteractionHeaderProps) {
  return (
    <header className="interactions-header">
      <div>
        <nav className="dashboard-breadcrumb" aria-label="Đường dẫn">
          <span>DrugTime Admin</span>
          <ChevronRight size={14} strokeWidth={2} aria-hidden="true" />
          <span>Danh mục CSDL</span>
          <ChevronRight size={14} strokeWidth={2} aria-hidden="true" />
          <strong>Quy tắc tương tác</strong>
        </nav>
        <h1>Quy tắc tương tác thuốc</h1>
        <p>
          Cơ sở tri thức cảnh báo tương tác thuốc Dược thư Quốc gia, DrugBank &amp; FDA phục vụ kê đơn và nhắc uống an toàn
        </p>
      </div>

      <div className="interactions-header__actions">
        <button
          className="dashboard-action dashboard-action--secondary"
          type="button"
          onClick={onExportData}
        >
          <Download size={18} strokeWidth={2} aria-hidden="true" />
          Xuất ma trận đối soát
        </button>
        <button
          className="dashboard-action dashboard-action--primary"
          type="button"
          onClick={onOpenCreateModal}
        >
          <Plus size={18} strokeWidth={2.2} aria-hidden="true" />
          Thêm quy tắc mới
        </button>
      </div>
    </header>
  );
}
