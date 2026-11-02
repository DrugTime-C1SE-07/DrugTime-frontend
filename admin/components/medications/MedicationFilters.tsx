"use client";

export default function MedicationFilters({ search, onChange }: { search: string; onChange: (value: string) => void }) {
  return <div className="live-filters"><label>Tìm theo tên thuốc<input type="search" value={search} maxLength={100} onChange={event => onChange(event.target.value)} placeholder="Nhập tên thuốc" /></label>
    <button type="button" onClick={() => onChange("")} disabled={!search}>Xóa tìm kiếm</button>
  </div>;
}
