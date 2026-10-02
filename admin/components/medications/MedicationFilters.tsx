"use client";

import React from "react";
import { RotateCcw, Search, X } from "lucide-react";
import { MedicationFilterState } from "../../lib/types/medication";

interface MedicationFiltersProps {
  filters: MedicationFilterState;
  onFilterChange: (filters: MedicationFilterState) => void;
  onReset: () => void;
  sources: string[];
  groups: string[];
  totalFiltered: number;
}

export default function MedicationFilters({
  filters,
  onFilterChange,
  onReset,
  sources,
  groups,
  totalFiltered,
}: MedicationFiltersProps) {
  const hasActiveFilters =
    Boolean(filters.search) ||
    filters.source !== "all" ||
    filters.quality !== "all" ||
    filters.group !== "all";

  return (
    <section className="medication-filters" aria-label="Bộ lọc danh mục thuốc">
      <div className="medication-search">
        <Search size={18} strokeWidth={2} aria-hidden="true" style={{ flexShrink: 0 }} />
        <input
          value={filters.search}
          onChange={(e) => onFilterChange({ ...filters, search: e.target.value })}
          placeholder="Tìm kiếm tên thuốc, hoạt chất, số đăng ký DAV..."
          aria-label="Tìm kiếm tên thuốc, hoạt chất, số đăng ký DAV"
        />
        <button
          type="button"
          onClick={() => onFilterChange({ ...filters, search: "" })}
          style={{
            visibility: filters.search ? "visible" : "hidden",
            pointerEvents: filters.search ? "auto" : "none",
            background: "transparent",
            border: 0,
            cursor: "pointer",
            color: "var(--color-muted)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: 20,
            height: 20,
            padding: 0,
            flexShrink: 0,
          }}
          aria-label="Xóa từ khóa tìm kiếm"
          tabIndex={filters.search ? 0 : -1}
        >
          <X size={15} strokeWidth={2.2} />
        </button>
      </div>

      <div className="filter-select filter-select--source">
        <select
          value={filters.source}
          onChange={(e) => onFilterChange({ ...filters, source: e.target.value })}
          aria-label="Lọc theo nguồn dữ liệu"
        >
          <option value="all">Nguồn: Tất cả</option>
          {sources.map((src) => (
            <option key={src} value={src}>
              Nguồn: {src}
            </option>
          ))}
        </select>
      </div>

      <div className="filter-select filter-select--quality">
        <select
          value={filters.quality}
          onChange={(e) => onFilterChange({ ...filters, quality: e.target.value })}
          aria-label="Lọc theo chất lượng / xác thực"
        >
          <option value="all">Chất lượng: Tất cả</option>
          <option value="verified">Đã xác thực</option>
          <option value="pending">Cần duyệt</option>
          <option value="missing">Thiếu thông tin</option>
        </select>
      </div>

      <div className="filter-select filter-select--group">
        <select
          value={filters.group}
          onChange={(e) => onFilterChange({ ...filters, group: e.target.value })}
          aria-label="Lọc theo nhóm điều trị"
        >
          <option value="all">Nhóm: Tất cả</option>
          {groups.map((grp) => (
            <option key={grp} value={grp}>
              Nhóm: {grp}
            </option>
          ))}
        </select>
      </div>

      <button
        type="button"
        className={`filter-reset-btn ${hasActiveFilters ? "filter-reset-btn--active" : "filter-reset-btn--disabled"}`}
        onClick={onReset}
        disabled={!hasActiveFilters}
        title={hasActiveFilters ? "Đặt lại tất cả bộ lọc về mặc định" : "Chưa áp dụng bộ lọc nào"}
        aria-label="Đặt lại tất cả bộ lọc"
      >
        <RotateCcw size={14} strokeWidth={2.2} aria-hidden="true" style={{ flexShrink: 0 }} />
        <span>Đặt lại</span>
      </button>
    </section>
  );
}
