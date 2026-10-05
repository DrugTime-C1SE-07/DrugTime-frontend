"use client";

import React, { useMemo } from "react";
import Link from "next/link";
import {
  AlertCircle,
  AlertTriangle,
  Building2,
  Check,
  CheckCircle2,
  Clock3,
  Globe2,
  Package,
  Pencil,
  Pill,
  ShieldAlert,
  Tag,
} from "lucide-react";
import { Modal } from "../ui/Modal";
import { Medication } from "../../lib/types/medication";
import { initialInteractions } from "../../lib/data/mock-interactions";

interface MedicationDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  medication: Medication | null;
  onEdit?: (medication: Medication) => void;
  onApprove?: (medication: Medication) => void;
}

const qualityConfig = {
  verified: {
    label: "Đã xác thực",
    icon: CheckCircle2,
    badgeClass: "medication-quality-badge--verified",
  },
  pending: {
    label: "Cần duyệt",
    icon: Clock3,
    badgeClass: "medication-quality-badge--pending",
  },
  missing: {
    label: "Thiếu thông tin",
    icon: AlertCircle,
    badgeClass: "medication-quality-badge--missing",
  },
};

export default function MedicationDetailModal({
  isOpen,
  onClose,
  medication,
  onEdit,
  onApprove,
}: MedicationDetailModalProps) {
  const relatedInteractions = useMemo(() => {
    if (!medication) return [];
    const ingWords = medication.ingredient.toLowerCase().split(/[\s+,/]+/).filter((w) => w.length > 3);
    const nameWords = medication.name.toLowerCase().split(/[\s+,/]+/).filter((w) => w.length > 3);
    const searchTerms = [...ingWords, ...nameWords];

    return initialInteractions.filter((item) => {
      if (item.isDeleted) return false;
      const da = item.drugA.toLowerCase();
      const db = item.drugB.toLowerCase();
      return searchTerms.some((term) => da.includes(term) || db.includes(term));
    });
  }, [medication]);

  if (!medication) return null;

  const qualityInfo = qualityConfig[medication.quality];
  const QualityIcon = qualityInfo.icon;
  const firstIngredientTerm = medication.ingredient.split(/[\s+,/]+/)[0] || medication.name;

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Chi tiết bản ghi biệt dược"
      subtitle="Hồ sơ dữ liệu định danh Dược thư Quốc gia & Cục Quản lý Dược"
      size="lg"
      footer={
        <>
          <button
            type="button"
            className="dashboard-action dashboard-action--secondary"
            onClick={onClose}
          >
            Đóng
          </button>
          {relatedInteractions.length > 0 ? (
            <Link
              href={`/dashboard/interactions?search=${encodeURIComponent(firstIngredientTerm)}`}
              className="dashboard-action dashboard-action--secondary"
              style={{ display: "inline-flex", alignItems: "center", gap: 6 }}
              onClick={onClose}
            >
              <ShieldAlert size={15} strokeWidth={2.2} />
              Tra cứu {relatedInteractions.length} tương tác
            </Link>
          ) : null}
          {medication.quality === "pending" && onApprove ? (
            <button
              type="button"
              className="dashboard-action dashboard-action--primary"
              style={{ background: "var(--color-success)" }}
              onClick={() => {
                onApprove(medication);
                onClose();
              }}
            >
              <Check size={16} strokeWidth={2.4} aria-hidden="true" />
              Duyệt bản ghi ngay
            </button>
          ) : null}
          {onEdit ? (
            <button
              type="button"
              className="dashboard-action dashboard-action--primary"
              onClick={() => {
                onClose();
                onEdit(medication);
              }}
            >
              <Pencil size={16} strokeWidth={2.2} aria-hidden="true" />
              Chỉnh sửa thông tin
            </button>
          ) : null}
        </>
      }
    >
      <div className="medication-detail-card">
        <div className="medication-detail-banner">
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <h3>{medication.name}</h3>
              {medication.noteBadge ? (
                <span
                  style={{
                    display: "inline-flex",
                    alignItems: "center",
                    justifyContent: "center",
                    width: 22,
                    height: 22,
                    borderRadius: 4,
                    background: "#fee2e2",
                    color: "#b91c1c",
                    fontWeight: 800,
                    fontSize: 13,
                  }}
                  title="Thuốc cần kiểm soát đặc biệt theo quy định Bộ Y tế"
                >
                  {medication.noteBadge}
                </span>
              ) : null}
            </div>
            <p>{medication.description || "Chưa có ghi chú mô tả lâm sàng chi tiết."}</p>
          </div>

          <span className={`medication-quality-badge ${qualityInfo.badgeClass}`}>
            <QualityIcon size={14} strokeWidth={2.4} aria-hidden="true" />
            {qualityInfo.label}
          </span>
        </div>

        {medication.formWarning || medication.isRegNoMissing ? (
          <div
            style={{
              padding: "10px 14px",
              background: "var(--color-danger-soft)",
              borderRadius: 8,
              border: "1px solid #ffb4ab",
              color: "var(--color-danger-dark)",
              fontSize: 13,
              display: "flex",
              alignItems: "center",
              gap: 8,
            }}
          >
            <AlertTriangle size={18} strokeWidth={2.2} />
            <span>
              <strong>Cảnh báo dữ liệu:</strong>{" "}
              {medication.formWarning || "Bản ghi thiếu số đăng ký lưu hành hợp lệ (SĐK DAV). Cần bổ sung trước khi đồng bộ."}
            </span>
          </div>
        ) : null}

        {/* Cảnh báo tương tác thuốc tự động liên kết với UI Interaction */}
        {relatedInteractions.length > 0 ? (
          <div className="medication-interaction-alert-box">
            <div className="medication-interaction-alert-head">
              <ShieldAlert size={18} strokeWidth={2.4} />
              <span>Cảnh báo Dược lâm sàng: Đã ghi nhận {relatedInteractions.length} quy tắc tương tác liên quan</span>
            </div>
            <div className="medication-interaction-list">
              {relatedInteractions.map((rule) => (
                <div key={rule.id} className="medication-interaction-item">
                  <div className="medication-interaction-item-head">
                    <span className={`interaction-severity-badge interaction-severity-badge--${rule.severity}`}>
                      {rule.severity === "contraindicated"
                        ? "Chống chỉ định"
                        : rule.severity === "major"
                        ? "Nghiêm trọng"
                        : "Thận trọng"}
                    </span>
                    <span className="medication-interaction-pair">
                      {rule.drugA} ↔ {rule.drugB}
                    </span>
                  </div>
                  <span className="medication-interaction-effect">{rule.clinicalEffect}</span>
                </div>
              ))}
            </div>
            <Link
              href={`/dashboard/interactions?search=${encodeURIComponent(firstIngredientTerm)}`}
              className="medication-interaction-btn"
              onClick={onClose}
            >
              <ShieldAlert size={15} strokeWidth={2.2} />
              Xem chi tiết trên Bàn Thẩm định Tương tác Thuốc ➔
            </Link>
          </div>
        ) : null}

        <div className="medication-detail-grid">
          <div className="medication-detail-item">
            <label>Hoạt chất chính</label>
            <span style={{ color: "var(--color-primary)", fontWeight: 700 }}>
              {medication.ingredient}
            </span>
          </div>

          <div className="medication-detail-item">
            <label>Hàm lượng / Nồng độ</label>
            <span>{medication.strength}</span>
          </div>

          <div className="medication-detail-item">
            <label>Số đăng ký (SĐK DAV)</label>
            <span
              className={medication.isRegNoMissing ? "medication-regno--missing" : ""}
            >
              {medication.regNo}
            </span>
          </div>

          <div className="medication-detail-item">
            <label>Dạng bào chế</label>
            <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <Pill size={14} strokeWidth={2} />
              {medication.form || "Chưa cập nhật"}
            </span>
          </div>

          <div className="medication-detail-item">
            <label>Nhóm điều trị</label>
            <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <Tag size={14} strokeWidth={2} />
              {medication.group}
            </span>
          </div>

          <div className="medication-detail-item">
            <label>Nguồn dữ liệu</label>
            <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <span className="medication-source-tag">{medication.sourceTag}</span>
              {medication.source}
            </span>
          </div>

          <div className="medication-detail-item">
            <label>Nhà sản xuất</label>
            <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <Building2 size={14} strokeWidth={2} />
              {medication.manufacturer || "Chưa cập nhật"}
            </span>
          </div>

          <div className="medication-detail-item">
            <label>Nước sản xuất</label>
            <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <Globe2 size={14} strokeWidth={2} />
              {medication.country || "Chưa cập nhật"}
            </span>
          </div>

          <div className="medication-detail-item" style={{ gridColumn: "span 2" }}>
            <label>Quy cách đóng gói</label>
            <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <Package size={14} strokeWidth={2} />
              {medication.packaging || "Chưa cập nhật quy cách đóng gói"}
            </span>
          </div>
        </div>

        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            fontSize: 12,
            color: "var(--color-muted)",
            paddingTop: 8,
            borderTop: "1px solid var(--color-border)",
          }}
        >
          <span>Mã định danh hệ thống: <code>{medication.id}</code></span>
          <span>Cập nhật gần nhất: {medication.updatedAt || "2026-03-24"}</span>
        </div>
      </div>
    </Modal>
  );
}
