import Link from "next/link";
export default function MedicationSyncBanner() {
  return <aside className="medication-sync-banner"><p>Xem các lượt đồng bộ danh mục đã được ghi nhận.</p><Link href="/dashboard/scraper-logs">Lịch sử đồng bộ</Link></aside>;
}
