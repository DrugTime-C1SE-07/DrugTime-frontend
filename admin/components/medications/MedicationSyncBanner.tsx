import { ListChecks, RefreshCw, Wand2 } from "lucide-react";

export default function MedicationSyncBanner() {
  return (
    <section className="medication-sync-banner" aria-label="Đồng bộ dữ liệu tự động">
      <div className="medication-sync-banner__copy">
        <div className="medication-sync-banner__icon-box" aria-hidden="true">
          <Wand2 size={20} strokeWidth={2.2} />
        </div>
        <div>
          <h2>Tự động đối soát Dược thư & DAV</h2>
          <p>Cronjob đồng bộ dữ liệu chạy mỗi 03:00 sáng.</p>
        </div>
      </div>

      <div className="medication-sync-banner__actions">
        <button type="button">
          <ListChecks size={16} strokeWidth={2} aria-hidden="true" />
          <span>Cấu hình luật đối soát</span>
        </button>
        <button type="button" className="is-primary">
          <RefreshCw size={16} strokeWidth={2} aria-hidden="true" />
          <span>Chạy quét ngay</span>
        </button>
      </div>
    </section>
  );
}
