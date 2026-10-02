"use client";

import React, { useState, useMemo } from "react";
import Link from "next/link";
import {
  AlertCircle,
  AlertTriangle,
  Check,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  Clock3,
  Eye,
  Pencil,
  ShieldAlert,
  Tag,
  Trash2,
  Wrench,
  SearchX,
} from "lucide-react";
import { Medication } from "../../lib/types/medication";
import { initialInteractions } from "../../lib/data/mock-interactions";
import { Modal } from "../ui/Modal";

interface MedicationTableProps {
  medications: Medication[];
  onQuickApprove: (medication: Medication) => void;
  onEdit: (medication: Medication) => void;
  onViewDetail: (medication: Medication) => void;
  onDelete: (medication: Medication) => void;
  onResetFilters?: () => void;
}

const qualityLabels = {
  verified: "Đã xác thực",
  pending: "Cần duyệt",
  missing: "Thiếu thông tin",
};

function QualityIcon({ quality }: { quality: Medication["quality"] }) {
  if (quality === "missing") {
    return <AlertCircle size={14} strokeWidth={2.4} aria-hidden="true" />;
  }

  if (quality === "pending") {
    return <Clock3 size={14} strokeWidth={2.4} aria-hidden="true" />;
  }

  return <CheckCircle2 size={14} strokeWidth={2.4} aria-hidden="true" />;
}

export default function MedicationTable({
  medications,
  onQuickApprove,
  onEdit,
  onViewDetail,
  onDelete,
  onResetFilters,
}: MedicationTableProps) {
  const [currentPage, setCurrentPage] = useState(1);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [deleteConfirmTarget, setDeleteConfirmTarget] = useState<Medication | null>(null);

  const totalItems = medications.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / rowsPerPage));

  // Reset to page 1 if current page exceeds total pages
  const safePage = Math.min(currentPage, totalPages);

  const paginatedMedications = useMemo(() => {
    const startIndex = (safePage - 1) * rowsPerPage;
    return medications.slice(startIndex, startIndex + rowsPerPage);
  }, [medications, safePage, rowsPerPage]);

  const startIndex = totalItems === 0 ? 0 : (safePage - 1) * rowsPerPage + 1;
  const endIndex = Math.min(safePage * rowsPerPage, totalItems);

  // Pagination navigation numbers calculation
  const getPageNumbers = () => {
    const pages: (number | string)[] = [];
    if (totalPages <= 7) {
      for (let i = 1; i <= totalPages; i++) pages.push(i);
    } else {
      pages.push(1);
      if (safePage > 3) pages.push("...");
      const start = Math.max(2, safePage - 1);
      const end = Math.min(totalPages - 1, safePage + 1);
      for (let i = start; i <= end; i++) pages.push(i);
      if (safePage < totalPages - 2) pages.push("...");
      pages.push(totalPages);
    }
    return pages;
  };

  const getInteractionCount = (med: Medication) => {
    const ingWords = med.ingredient.toLowerCase().split(/[\s+,/]+/).filter((w) => w.length > 3);
    const nameWords = med.name.toLowerCase().split(/[\s+,/]+/).filter((w) => w.length > 3);
    const searchTerms = [...ingWords, ...nameWords];

    return initialInteractions.filter((item) => {
      if (item.isDeleted) return false;
      const da = item.drugA.toLowerCase();
      const db = item.drugB.toLowerCase();
      return searchTerms.some((term) => da.includes(term) || db.includes(term));
    }).length;
  };

  const handleConfirmDelete = () => {
    if (deleteConfirmTarget) {
      onDelete(deleteConfirmTarget);
      setDeleteConfirmTarget(null);
    }
  };

  return (
    <>
      <section className="medication-table-card">
        <div className="medication-table-scroll">
          <div className="medication-table" role="table" aria-label="Danh mục thuốc tự lưu trữ">
            <div className="medication-table__head" role="row">
              <span>Tên thuốc & dạng bào chế</span>
              <span>Hoạt chất & hàm lượng</span>
              <span>Số đăng ký</span>
              <span>Nguồn dữ liệu</span>
              <span>Nhóm điều trị</span>
              <span>Trạng thái</span>
              <span>Thao tác</span>
            </div>

            {totalItems === 0 ? (
              <div
                style={{
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  justifyContent: "center",
                  padding: "48px 16px",
                  gap: 12,
                  color: "var(--color-muted)",
                }}
              >
                <SearchX size={36} strokeWidth={1.8} />
                <strong style={{ fontSize: 15, color: "var(--color-text)" }}>
                  Không tìm thấy thuốc phù hợp
                </strong>
                <p style={{ margin: 0, fontSize: 13 }}>
                  Thử tìm kiếm với từ khóa khác hoặc thiết lập lại bộ lọc để xem toàn bộ danh mục.
                </p>
                {onResetFilters ? (
                  <button
                    type="button"
                    className="dashboard-action dashboard-action--secondary"
                    onClick={onResetFilters}
                    style={{ marginTop: 8 }}
                  >
                    Đặt lại bộ lọc
                  </button>
                ) : null}
              </div>
            ) : (
              paginatedMedications.map((medication) => (
                <div
                  className={`medication-table__row medication-table__row--${medication.quality}`}
                  role="row"
                  key={medication.id || medication.name}
                >
                  <div className="medication-name">
                    <span className="medication-name-title">
                      {medication.name}
                      {medication.noteBadge ? (
                        <em title="Thuốc cần kiểm soát đặc biệt" aria-label="Lưu ý">
                          {medication.noteBadge}
                        </em>
                      ) : null}
                    </span>
                    {medication.form ? (
                      <span className="medication-name-form">{medication.form}</span>
                    ) : null}
                    {medication.formWarning ? (
                      <span className="medication-name-warning">
                        <AlertTriangle size={12} strokeWidth={2.4} aria-hidden="true" />
                        {medication.formWarning}
                      </span>
                    ) : null}
                  </div>

                  <div className="medication-ingredient">
                    <span className="medication-ingredient-title">{medication.ingredient}</span>
                    <div style={{ display: "flex", alignItems: "center", gap: 6, flexWrap: "wrap", marginTop: 2 }}>
                      <span className="medication-ingredient-strength">{medication.strength}</span>
                      {(() => {
                        const count = getInteractionCount(medication);
                        if (count === 0) return null;
                        const term = medication.ingredient.split(/[\s+,/]+/)[0] || medication.name;
                        return (
                          <Link
                            href={`/dashboard/interactions?search=${encodeURIComponent(term)}`}
                            className="medication-table-interaction-badge"
                            title={`Xem ${count} quy tắc tương tác lâm sàng của ${medication.ingredient}`}
                            onClick={(e) => e.stopPropagation()}
                          >
                            <ShieldAlert size={11} strokeWidth={2.4} />
                            <span>{count} tương tác</span>
                          </Link>
                        );
                      })()}
                    </div>
                  </div>

                  <div>
                    <span
                      className={`medication-regno${
                        medication.isRegNoMissing ? " medication-regno--missing" : ""
                      }`}
                    >
                      {medication.regNo}
                    </span>
                  </div>

                  <div>
                    <span className="medication-source-wrap">
                      {medication.source}
                      <span className="medication-source-tag">{medication.sourceTag}</span>
                    </span>
                  </div>

                  <div>
                    <span className="medication-group-badge">
                      <Tag size={12} strokeWidth={2} aria-hidden="true" />
                      {medication.group}
                    </span>
                  </div>

                  <div>
                    <span
                      className={`medication-quality-badge medication-quality-badge--${medication.quality}`}
                    >
                      <QualityIcon quality={medication.quality} />
                      {qualityLabels[medication.quality]}
                    </span>
                  </div>

                  <div className="medication-actions">
                    {medication.quality === "pending" ? (
                      <button
                        className="medication-action-btn medication-action-btn--approve"
                        type="button"
                        title="Duyệt nhanh bản ghi"
                        aria-label={`Duyệt ${medication.name}`}
                        onClick={() => onQuickApprove(medication)}
                      >
                        <Check size={16} strokeWidth={2.4} />
                      </button>
                    ) : null}

                    {medication.quality === "missing" ? (
                      <button
                        className="medication-action-btn medication-action-btn--fix"
                        type="button"
                        title="Bổ sung thông tin thiếu"
                        aria-label={`Bổ sung thông tin cho ${medication.name}`}
                        onClick={() => onEdit(medication)}
                      >
                        <Wrench size={14} strokeWidth={2.2} />
                      </button>
                    ) : null}

                    <button
                      className="medication-action-btn"
                      type="button"
                      title="Chỉnh sửa thông tin"
                      aria-label={`Chỉnh sửa ${medication.name}`}
                      onClick={() => onEdit(medication)}
                    >
                      <Pencil size={15} strokeWidth={2} />
                    </button>

                    <button
                      className="medication-action-btn"
                      type="button"
                      title="Xem chi tiết"
                      aria-label={`Xem chi tiết ${medication.name}`}
                      onClick={() => onViewDetail(medication)}
                    >
                      <Eye size={15} strokeWidth={2} />
                    </button>

                    <button
                      className="medication-action-btn medication-action-btn--delete"
                      type="button"
                      title="Xóa thuốc"
                      aria-label={`Xóa thuốc ${medication.name}`}
                      onClick={() => setDeleteConfirmTarget(medication)}
                    >
                      <Trash2 size={15} strokeWidth={2} />
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        <div className="medication-pagination">
          <div className="medication-pagination__info">
            <span>
              Hiển thị <strong>{startIndex} - {endIndex}</strong> trong tổng số{" "}
              <strong>{totalItems.toLocaleString("vi-VN")}</strong> bản ghi
            </span>
            <span className="medication-pagination__divider" aria-hidden="true" />
            <label className="medication-pagination__rows-select">
              Số hàng:
              <select
                value={rowsPerPage}
                onChange={(e) => {
                  setRowsPerPage(Number(e.target.value));
                  setCurrentPage(1);
                }}
                aria-label="Số hàng hiển thị mỗi trang"
              >
                <option value={10}>10 / trang</option>
                <option value={25}>25 / trang</option>
                <option value={50}>50 / trang</option>
              </select>
            </label>
          </div>

          <nav className="medication-pages" aria-label="Phân trang danh mục thuốc">
            <button
              type="button"
              disabled={safePage <= 1}
              onClick={() => setCurrentPage(1)}
              title="Trang đầu"
              aria-label="Trang đầu"
            >
              <ChevronsLeft size={16} strokeWidth={2.2} />
            </button>
            <button
              type="button"
              disabled={safePage <= 1}
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
              title="Trang trước"
              aria-label="Trang trước"
            >
              <ChevronLeft size={16} strokeWidth={2.2} />
            </button>

            {getPageNumbers().map((item, idx) =>
              typeof item === "number" ? (
                <button
                  type="button"
                  key={item}
                  className={item === safePage ? "is-active" : ""}
                  onClick={() => setCurrentPage(item)}
                  aria-current={item === safePage ? "page" : undefined}
                >
                  {item}
                </button>
              ) : (
                <span key={`ellipsis-${idx}`} className="medication-pages__ellipsis" aria-hidden="true">
                  ...
                </span>
              )
            )}

            <button
              type="button"
              disabled={safePage >= totalPages}
              onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
              title="Trang sau"
              aria-label="Trang sau"
            >
              <ChevronRight size={16} strokeWidth={2.2} />
            </button>
            <button
              type="button"
              disabled={safePage >= totalPages}
              onClick={() => setCurrentPage(totalPages)}
              title="Trang cuối"
              aria-label="Trang cuối"
            >
              <ChevronsRight size={16} strokeWidth={2.2} />
            </button>
          </nav>
        </div>
      </section>

      {/* Modal xác nhận xóa mềm */}
      <Modal
        isOpen={Boolean(deleteConfirmTarget)}
        onClose={() => setDeleteConfirmTarget(null)}
        title="Xác nhận xóa thuốc khỏi danh mục"
        size="sm"
        footer={
          <>
            <button
              type="button"
              className="dashboard-action dashboard-action--secondary"
              onClick={() => setDeleteConfirmTarget(null)}
            >
              Hủy bỏ
            </button>
            <button
              type="button"
              className="dashboard-action dashboard-action--primary"
              style={{ background: "var(--color-danger)" }}
              onClick={handleConfirmDelete}
            >
              Xác nhận xóa
            </button>
          </>
        }
      >
        <div className="modal-confirm-delete">
          <div
            style={{
              width: 48,
              height: 48,
              borderRadius: "50%",
              background: "var(--color-danger-soft)",
              color: "var(--color-danger)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              margin: "0 auto",
            }}
          >
            <Trash2 size={24} strokeWidth={2.2} />
          </div>
          <p>
            Bạn có chắc chắn muốn xóa bản ghi thuốc{" "}
            <strong style={{ color: "var(--color-text)" }}>
              {deleteConfirmTarget?.name}
            </strong>{" "}
            (SĐK: {deleteConfirmTarget?.regNo}) khỏi danh mục hiển thị không?
          </p>
          <span style={{ fontSize: 12, color: "var(--color-muted)", marginTop: 6, display: "block" }}>
            Hệ thống thực hiện xóa mềm (Soft Delete). Bạn có thể hoàn tác ngay trong thông báo.
          </span>
        </div>
      </Modal>
    </>
  );
}
