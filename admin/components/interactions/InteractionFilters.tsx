"use client";

import React from "react";
import { RotateCcw, Search, X } from "lucide-react";
import { InteractionFilterState } from "../../lib/types/interaction";

interface InteractionFiltersProps {
  filters: InteractionFilterState;
  onFilterChange: (filters: InteractionFilterState) => void;
  onReset: () => void;
  totalFiltered: number;
}

export default function InteractionFilters({
  filters,
  onFilterChange,
  onReset,
  totalFiltered,
}: InteractionFiltersProps) {
  const hasActiveFilters =
    Boolean(filters.search) ||
    filters.severity !== "all" ||
    filters.targetType !== "all" ||
    filters.mechanismType !== "all" ||
    filters.status !== "all";

  return (
    <section className="medication-filters" aria-label="Bộ lọc quy tắc tương tác thuốc">
      <div className="medication-search">
        <Search size={18} strokeWidth={2} aria-hidden="true" style={{ flexShrink: 0 }} />
        <input
          value={filters.search}
          onChange={(e) => onFilterChange({ ...filters, search: e.target.value })}
          placeholder="Tìm theo tên thuốc A, thuốc B, mã ATC (B01AA03), cơ chế..."
          aria-label="Tìm kiếm cặp tương tác thuốc"
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

      <div className="filter-select filter-select--severity">
        <select
          value={filters.severity}
          onChange={(e) => onFilterChange({ ...filters, severity: e.target.value })}
          aria-label="Lọc theo mức độ cảnh báo"
        >
          <option value="all">Mức độ: Tất cả</option>
          <option value="contraindicated">🔴 Chống chỉ định</option>
          <option value="major">🔵 Nghiêm trọng</option>
          <option value="moderate">🔵 Thận trọng</option>
        </select>
      </div>

      <div className="filter-select filter-select--target-type">
        <select
          value={filters.targetType}
          onChange={(e) => onFilterChange({ ...filters, targetType: e.target.value })}
          aria-label="Lọc theo phân loại tương tác"
        >
          <option value="all">Phân loại: Tất cả</option>
          <option value="drug_drug">Thuốc - Thuốc</option>
          <option value="drug_food">Thuốc - Thực phẩm</option>
        </select>
      </div>

      <div className="filter-select filter-select--mechanism">
        <select
          value={filters.mechanismType}
          onChange={(e) => onFilterChange({ ...filters, mechanismType: e.target.value })}
          aria-label="Lọc theo cơ chế tương tác"
        >
          <option value="all">Cơ chế: Tất cả</option>
          <option value="pk">Dược động học (PK)</option>
          <option value="pd">Dược lực học (PD)</option>
          <option value="both">Phối hợp PK/PD</option>
          <option value="unknown">Chưa rõ</option>
        </select>
      </div>

      <div className="filter-select filter-select--status">
        <select
          value={filters.status}
          onChange={(e) => onFilterChange({ ...filters, status: e.target.value })}
          aria-label="Lọc theo trạng thái kiểm duyệt"
        >
          <option value="all">Trạng thái: Tất cả</option>
          <option value="verified">Đã xác thực</option>
          <option value="pending">Chờ thẩm định</option>
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
