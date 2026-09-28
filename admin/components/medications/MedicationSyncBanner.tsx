import { ListChecks, RefreshCw, Wand2 } from "lucide-react";

export default function MedicationSyncBanner() {
  return (
    <section className="medication-sync-banner">
      <div className="medication-sync-banner__copy">
        <span aria-hidden="true">
          <Wand2 size={24} strokeWidth={2.4} />
        </span>
        <div>
          <h2>Tự động đối soát Dược thư & DAV</h2>
          <p>Cronjob đồng bộ dữ liệu chạy mỗi 03:00 sáng.</p>
        </div>
      </div>

      <div className="medication-sync-banner__actions">
        <button type="button">
          <ListChecks size={20} strokeWidth={2.3} aria-hidden="true" />
          Cấu hình luật đối soát
        </button>
        <button type="button" className="is-primary">
          <RefreshCw size={20} strokeWidth={2.3} aria-hidden="true" />
          Chạy quét ngay
        </button>
      </div>
    </section>
  );
}
