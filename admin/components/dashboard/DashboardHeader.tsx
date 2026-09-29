import { ChevronRight, Download, RefreshCw } from "lucide-react";

export default function DashboardHeader() {
  return (
    <header className="dashboard-header">
      <div>
        <nav className="dashboard-breadcrumb" aria-label="Đường dẫn">
          <span>DrugTime Admin</span>
          <ChevronRight size={16} strokeWidth={2.4} aria-hidden="true" />
          <strong>Giám sát Hệ thống</strong>
        </nav>
        <h1>Tổng quan dữ liệu</h1>
      </div>

      <div className="dashboard-header__actions">
        <button className="dashboard-action dashboard-action--secondary" type="button">
          <Download size={20} strokeWidth={2.4} aria-hidden="true" />
          Xuất báo cáo
        </button>
        <button className="dashboard-action dashboard-action--primary" type="button">
          <RefreshCw size={20} strokeWidth={2.4} aria-hidden="true" />
          Đồng bộ tức thì
        </button>
      </div>
    </header>
  );
}
