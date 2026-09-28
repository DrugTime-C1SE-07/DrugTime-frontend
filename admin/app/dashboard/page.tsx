import DashboardHeader from "../../components/dashboard/DashboardHeader";
import DataQualityPanel from "../../components/dashboard/DataQualityPanel";
import KpiCard from "../../components/dashboard/KpiCard";
import SyncStatusPanel from "../../components/dashboard/SyncStatusPanel";
import WorkersTable from "../../components/dashboard/WorkersTable";
import { AlertTriangle, ClipboardCheck, Database } from "lucide-react";

export default function DashboardPage() {
  return (
    <section className="dashboard-page">
      <DashboardHeader />

      <div className="dashboard-kpi-grid">
        <KpiCard
          tone="blue"
          icon={Database}
          eyebrow="Tập dữ liệu"
          title="Tổng số thuốc"
          value="14,850"
          unit="biệt dược"
          pill="+142 tuần này"
          footerPrimary="98.2% kiểm duyệt dược lý"
          footerSecondary="Kho Dược DAV"
        />
        <KpiCard
          tone="blue"
          icon={ClipboardCheck}
          eyebrow="Cần xử lý"
          title="Bản ghi cần thẩm định"
          value="286"
          unit="bản ghi mới"
          footerPrimary="Cần chuyên viên dược đối soát & duyệt nhãn"
          footerSecondary="Xem hàng đợi duyệt"
        />
        <KpiCard
          tone="red"
          icon={AlertTriangle}
          eyebrow="Đơn thuốc tải lên"
          title="Chuỗi quét OCR chưa khớp"
          value="42"
          unit="chuỗi quét mờ/lỗi"
          footerPrimary="Ảnh quét người dùng cần map"
          footerSecondary="Mở bàn đối soát"
        />
      </div>

      <div className="dashboard-main-grid">
        <SyncStatusPanel />
        <DataQualityPanel />
      </div>

      <WorkersTable />
    </section>
  );
}
