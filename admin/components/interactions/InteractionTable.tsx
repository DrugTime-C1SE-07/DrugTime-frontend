"use client";

import React, { useMemo, useState } from "react";
import {
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  Pencil,
  Pill,
  SearchX,
  Trash2,
  Utensils,
} from "lucide-react";
import { Interaction } from "../../lib/types/interaction";
import { Modal } from "../ui/Modal";

interface InteractionTableProps {
  interactions: Interaction[];
  selectedId?: string | null;
  onSelect: (interaction: Interaction) => void;
  onDelete?: (interaction: Interaction) => void;
  onResetFilters?: () => void;
}

const severityLabel: Record<Interaction["severity"], string> = {
  contraindicated: "Chống chỉ định",
  major: "Nghiêm trọng",
  moderate: "Thận trọng",
  minor: "Thận trọng",
};

export default function InteractionTable({
  interactions,
  selectedId,
  onSelect,
  onDelete,
  onResetFilters,
}: InteractionTableProps) {
  const [currentPage, setCurrentPage] = useState(1);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [deleteConfirmTarget, setDeleteConfirmTarget] = useState<Interaction | null>(null);

  const totalItems = interactions.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / rowsPerPage));
  const safePage = Math.min(currentPage, totalPages);

  const paginatedInteractions = useMemo(() => {
    const startIndex = (safePage - 1) * rowsPerPage;
    return interactions.slice(startIndex, startIndex + rowsPerPage);
  }, [interactions, safePage, rowsPerPage]);

  const startIndex = totalItems === 0 ? 0 : (safePage - 1) * rowsPerPage + 1;
  const endIndex = Math.min(safePage * rowsPerPage, totalItems);

  // Exact pagination navigation number sequence matching MedicationTable
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

  const handleConfirmDelete = () => {
    if (deleteConfirmTarget && onDelete) {
      onDelete(deleteConfirmTarget);
      setDeleteConfirmTarget(null);
    }
  };

  return (
    <>
      <section className="interaction-frame3-card" aria-label="Bảng quy tắc tương tác thuốc">
        <div className="interaction-frame3-table-scroll">
          <table className="interaction-frame3-table">
            <thead>
              <tr>
                <th scope="col" style={{ width: "32%" }}>Cặp tác nhân tương tác</th>
                <th scope="col" style={{ width: "16%" }}>Phân loại</th>
                <th scope="col" style={{ width: "18%" }}>Mức độ cảnh báo</th>
                <th scope="col" style={{ width: "18%" }}>Mã ATC đối soát</th>
                <th scope="col" style={{ width: "16%", textAlign: "right" }}>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {totalItems === 0 ? (
                <tr>
                  <td colSpan={5}>
                    <div className="interaction-frame3-empty-state">
                      <SearchX size={28} strokeWidth={2} aria-hidden="true" />
                      <div>
                        <h3>Không tìm thấy quy tắc tương tác phù hợp</h3>
                        <p>Thử từ khóa khác hoặc điều chỉnh lại các tiêu chí bộ lọc.</p>
                      </div>
                      {onResetFilters ? (
                        <button
                          type="button"
                          className="dashboard-action dashboard-action--secondary"
                          onClick={onResetFilters}
                        >
                          Đặt lại tất cả bộ lọc
                        </button>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ) : (
                paginatedInteractions.map((item) => {
                  const isActive = item.id === selectedId;
                  const classSubtitle =
                    [item.drugAClass, item.drugBClass].filter(Boolean).join(" • ") ||
                    "Dược thư Quốc gia Việt Nam";
                  const atcDisplay =
                    item.atcCodeA && item.atcCodeB
                      ? `${item.atcCodeA} ⇄ ${item.atcCodeB}`
                      : item.atcCodeA || item.atcCodeB || "Đang cập nhật";

                  return (
                    <tr
                      key={item.id}
                      className={isActive ? "interaction-frame3-table__row--active" : undefined}
                    >
                      <td>
                        <div className="interaction-frame3-cell-pair">
                          <div
                            className={`interaction-frame3-row-indicator ${
                              item.severity === "contraindicated"
                                ? "interaction-frame3-row-indicator--danger"
                                : ""
                            }`}
                            aria-hidden="true"
                          />
                          <div className="interaction-frame3-pair-text">
                            <strong className="interaction-frame3-pair-title">
                              {item.drugA} ⇄ {item.drugB}
                            </strong>
                            <span className="interaction-frame3-pair-subtitle" title={classSubtitle}>
                              {classSubtitle}
                            </span>
                          </div>
                        </div>
                      </td>
                      <td>
                        <span className="interaction-frame3-target-tag">
                          {item.targetType === "drug_food" ? (
                            <Utensils size={12} aria-hidden="true" />
                          ) : (
                            <Pill size={12} aria-hidden="true" />
                          )}
                          {item.targetType === "drug_food" ? "Thuốc - Thực phẩm" : "Thuốc - Thuốc"}
                        </span>
                      </td>
                      <td>
                        <span
                          className={`interaction-frame3-badge-pill interaction-frame3-badge-pill--${item.severity}`}
                        >
                          <span className="pill-dot" aria-hidden="true" />
                          {severityLabel[item.severity]}
                        </span>
                      </td>
                      <td>
                        <code className="interaction-frame3-atc-pill">{atcDisplay}</code>
                      </td>
                      <td>
                        <div className="interaction-frame3-actions">
                          <button
                            type="button"
                            className="interaction-frame3-action-btn"
                            onClick={() => onSelect(item)}
                            aria-label={`Hiệu chỉnh quy tắc ${item.drugA} và ${item.drugB}`}
                          >
                            <Pencil size={14} aria-hidden="true" />
                            Hiệu chỉnh
                          </button>
                          {onDelete ? (
                            <button
                              type="button"
                              className="interaction-frame3-delete-btn"
                              onClick={() => setDeleteConfirmTarget(item)}
                              aria-label={`Xóa mềm quy tắc ${item.drugA} và ${item.drugB}`}
                              title="Xóa mềm quy tắc"
                            >
                              <Trash2 size={15} aria-hidden="true" />
                            </button>
                          ) : null}
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {totalItems > 0 ? (
          <div className="medication-pagination" aria-label="Phân trang bảng quy tắc tương tác">
            <div className="medication-pagination__info">
              <span>Hiển thị</span>
              <strong>
                {startIndex} - {endIndex}
              </strong>
              <span>trên</span>
              <strong>{totalItems.toLocaleString("vi-VN")}</strong>
              <span>quy tắc</span>
              <div className="medication-pagination__divider" />
              <div className="medication-pagination__rows-select">
                <label htmlFor="inter-rows-per-page">Dòng:</label>
                <select
                  id="inter-rows-per-page"
                  value={rowsPerPage}
                  onChange={(event) => {
                    setRowsPerPage(Number(event.target.value));
                    setCurrentPage(1);
                  }}
                  aria-label="Số quy tắc mỗi trang"
                >
                  <option value={10}>10</option>
                  <option value={25}>25</option>
                  <option value={50}>50</option>
                </select>
              </div>
            </div>

            <div className="medication-pages">
              <button
                type="button"
                disabled={safePage === 1}
                onClick={() => setCurrentPage(1)}
                title="Trang đầu"
                aria-label="Trang đầu"
              >
                <ChevronsLeft size={16} />
              </button>
              <button
                type="button"
                disabled={safePage === 1}
                onClick={() => setCurrentPage((page) => Math.max(1, page - 1))}
                title="Trang trước"
                aria-label="Trang trước"
              >
                <ChevronLeft size={16} />
              </button>

              {getPageNumbers().map((page, index) =>
                page === "..." ? (
                  <span key={`ellipsis-${index}`} className="medication-pages__ellipsis">
                    …
                  </span>
                ) : (
                  <button
                    key={`page-${page}`}
                    type="button"
                    className={page === safePage ? "is-active" : ""}
                    onClick={() => setCurrentPage(Number(page))}
                    aria-label={`Trang ${page}`}
                    aria-current={page === safePage ? "page" : undefined}
                  >
                    {page}
                  </button>
                )
              )}

              <button
                type="button"
                disabled={safePage === totalPages}
                onClick={() => setCurrentPage((page) => Math.min(totalPages, page + 1))}
                title="Trang sau"
                aria-label="Trang sau"
              >
                <ChevronRight size={16} />
              </button>
              <button
                type="button"
                disabled={safePage === totalPages}
                onClick={() => setCurrentPage(totalPages)}
                title="Trang cuối"
                aria-label="Trang cuối"
              >
                <ChevronsRight size={16} />
              </button>
            </div>
          </div>
        ) : null}
      </section>

      <Modal
        isOpen={Boolean(deleteConfirmTarget)}
        onClose={() => setDeleteConfirmTarget(null)}
        title="Xác nhận xóa quy tắc tương tác"
        size="sm"
        footer={
          <div className="interaction-confirm-actions">
            <button
              type="button"
              className="dashboard-action dashboard-action--secondary"
              onClick={() => setDeleteConfirmTarget(null)}
            >
              Hủy bỏ
            </button>
            <button
              type="button"
              className="dashboard-action dashboard-action--danger"
              onClick={handleConfirmDelete}
            >
              Xóa quy tắc
            </button>
          </div>
        }
      >
        <div className="interaction-confirm-content">
          <Trash2 size={28} aria-hidden="true" />
          <p>
            Bạn có chắc chắn muốn xóa quy tắc tương tác giữa{" "}
            <strong>{deleteConfirmTarget?.drugA}</strong> và{" "}
            <strong>{deleteConfirmTarget?.drugB}</strong>?
          </p>
          <span>
            Hệ thống thực hiện xóa mềm để bảo toàn lịch sử kê đơn y tế. Bạn có thể hoàn tác trong
            vòng 6 giây thông qua thông báo phản hồi.
          </span>
        </div>
      </Modal>
    </>
  );
}
