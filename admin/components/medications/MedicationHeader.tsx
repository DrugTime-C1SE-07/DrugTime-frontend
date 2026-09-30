import { ChevronRight, Download, Plus } from "lucide-react";

export default function MedicationHeader() {
  return (
    <header className="medications-header">
      <div>
        <nav className="dashboard-breadcrumb" aria-label="Đường dẫn">
          <span>DrugTime Admin</span>
          <ChevronRight size={16} strokeWidth={2.4} aria-hidden="true" />
          <strong>Danh mục CSDL</strong>
        </nav>
        <h1>Danh mục thuốc tự lưu trữ</h1>
        <p>Cơ sở dữ liệu biệt dược và hoạt chất bóc tách từ Dược thư Quốc gia & Cục Quản lý Dược</p>
      </div>

      <div className="medications-header__actions">
        <button className="dashboard-action dashboard-action--secondary" type="button">
          <Download size={20} strokeWidth={2.4} aria-hidden="true" />
          Xuất file Excel / CSV
        </button>
        <button className="dashboard-action dashboard-action--primary" type="button">
          <Plus size={21} strokeWidth={2.6} aria-hidden="true" />
          Thêm thuốc mới
        </button>
      </div>
    </header>
  );
}
