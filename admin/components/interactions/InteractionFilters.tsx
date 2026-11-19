"use client";

import React from "react";
import { RotateCcw, Search, X } from "lucide-react";
import { SEVERITY_LABELS, SEVERITY_ORDER } from "../../lib/constants/severity";
import { InteractionFilterState } from "../../lib/types/interaction";

type FilterOption = { value: string; label: string };

const TARGET_OPTIONS: FilterOption[] = [
  { value: "drug_drug", label: "Thuốc - Thuốc" },
  { value: "drug_food", label: "Thuốc - Thực phẩm" },
];

const MECHANISM_OPTIONS: FilterOption[] = [
  { value: "pk", label: "Dược động học (PK)" },
  { value: "pd", label: "Dược lực học (PD)" },
  { value: "both", label: "Phối hợp PK/PD" },
  { value: "unknown", label: "Chưa rõ" },
];

const STATUS_OPTIONS: FilterOption[] = [
  { value: "verified", label: "Đã xác thực" },
  { value: "pending", label: "Chờ thẩm định" },
];

/** Nhãn của giá trị đang chọn, dùng cho title khi select bị cắt ở max-width. */
const labelOf = (options: FilterOption[], value: string) =>
  options.find((option) => option.value === value)?.label ?? "Tất cả";

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

      <label className="filter-select filter-select--severity">
        <span className="filter-select__label">Mức độ</span>
        <select
          value={filters.severity}
          onChange={(e) => onFilterChange({ ...filters, severity: e.target.value })}
          title={(SEVERITY_LABELS as Record<string, string>)[filters.severity] ?? "Tất cả"}
        >
          <option value="all">Tất cả</option>
          {SEVERITY_ORDER.map((severity) => (
            <option key={severity} value={severity}>
              {SEVERITY_LABELS[severity]}
            </option>
          ))}
        </select>
      </label>

      <label className="filter-select filter-select--target-type">
        <span className="filter-select__label">Phân loại</span>
        <select
          value={filters.targetType}
          onChange={(e) => onFilterChange({ ...filters, targetType: e.target.value })}
          title={labelOf(TARGET_OPTIONS, filters.targetType)}
        >
          <option value="all">Tất cả</option>
          {TARGET_OPTIONS.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>

      <label className="filter-select filter-select--mechanism">
        <span className="filter-select__label">Cơ chế</span>
        <select
          value={filters.mechanismType}
          onChange={(e) => onFilterChange({ ...filters, mechanismType: e.target.value })}
          title={labelOf(MECHANISM_OPTIONS, filters.mechanismType)}
        >
          <option value="all">Tất cả</option>
          {MECHANISM_OPTIONS.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>

      <label className="filter-select filter-select--status">
        <span className="filter-select__label">Trạng thái</span>
        <select
          value={filters.status}
          onChange={(e) => onFilterChange({ ...filters, status: e.target.value })}
          title={labelOf(STATUS_OPTIONS, filters.status)}
        >
          <option value="all">Tất cả</option>
          {STATUS_OPTIONS.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>

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
