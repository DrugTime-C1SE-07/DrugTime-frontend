import { ChevronDown, Search } from "lucide-react";

const filters = ["Nguồn: Tất cả", "Trạng thái: Tất cả chất lượng", "Nhóm: Tất cả"];

export default function MedicationFilters() {
  return (
    <section className="medication-filters" aria-label="Bộ lọc danh mục thuốc">
      <label className="medication-search">
        <Search size={24} strokeWidth={2.2} aria-hidden="true" />
        <input placeholder="Tìm kiếm tên thuốc, hoạt chất, số đăng ký DAV..." aria-label="Tìm kiếm thuốc" />
      </label>

      {filters.map((filter) => (
        <button className="medication-filter-button" type="button" key={filter}>
          {filter}
          <ChevronDown size={20} strokeWidth={2.4} aria-hidden="true" />
        </button>
      ))}
    </section>
  );
}
