"use client";

import type { InteractionFilterState, RuleKind } from "../../lib/types/interaction";
export default function InteractionFilters({ filters, onChange }: { filters: InteractionFilterState; onChange: (value: InteractionFilterState) => void }) {
  return <div className="live-filters">
    <label>Loại quy tắc<select value={filters.kind} onChange={event => onChange({ ...filters, kind: event.target.value as RuleKind, interactionType: "" })}><option value="drug_drug">Thuốc – thuốc</option><option value="drug_food">Thuốc – thực phẩm</option></select></label>
    <label>Tìm kiếm<input type="search" maxLength={100} value={filters.search} onChange={event => onChange({ ...filters, search: event.target.value })} /></label>
    <label>Mức độ<select value={filters.severity} onChange={event => onChange({ ...filters, severity: event.target.value })}><option value="">Tất cả</option>{[1, 2, 3, 4].map(level => <option key={level} value={level}>Mức {level}</option>)}</select></label>
    {filters.kind === "drug_drug" && <label>Phân loại<select value={filters.interactionType} onChange={event => onChange({ ...filters, interactionType: event.target.value })}><option value="">Tất cả</option><option value="chong_chi_dinh">Chống chỉ định</option><option value="phu_thuoc_lieu">Phụ thuộc liều</option></select></label>}
  </div>;
}
