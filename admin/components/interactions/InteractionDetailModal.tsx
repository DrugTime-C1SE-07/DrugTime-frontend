"use client";

import React from "react";
import Link from "next/link";
import {
  AlertOctagon,
  AlertTriangle,
  BookOpen,
  Check,
  CheckCircle2,
  Clock3,
  ExternalLink,
  Flame,
  Info,
  Pencil,
  Pill,
  ShieldAlert,
  Stethoscope,
} from "lucide-react";
import { Modal } from "../ui/Modal";
import { Interaction } from "../../lib/types/interaction";

interface InteractionDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  interaction: Interaction | null;
  onEdit?: (interaction: Interaction) => void;
  onApprove?: (interaction: Interaction) => void;
}

const severityConfig = {
  contraindicated: {
    label: "Chống chỉ định tuyệt đối",
    badgeClass: "interaction-severity-badge--contraindicated",
    icon: AlertOctagon,
  },
  major: {
    label: "Nghiêm trọng (Major)",
    badgeClass: "interaction-severity-badge--major",
    icon: ShieldAlert,
  },
  moderate: {
    label: "Trung bình (Moderate)",
    badgeClass: "interaction-severity-badge--moderate",
    icon: AlertTriangle,
  },
  minor: {
    label: "Nhẹ (Minor)",
    badgeClass: "interaction-severity-badge--minor",
    icon: Info,
  },
};

const mechLabels = {
  pk: "Dược động học (Pharmacokinetics - PK)",
  pd: "Dược lực học (Pharmacodynamics - PD)",
  both: "Cả Dược động học & Dược lực học (PK/PD)",
  unknown: "Cơ chế khác / Chưa rõ",
};

export default function InteractionDetailModal({
  isOpen,
  onClose,
  interaction,
  onEdit,
  onApprove,
}: InteractionDetailModalProps) {
  if (!interaction) return null;

  const sevInfo = severityConfig[interaction.severity];
  const SevIcon = sevInfo.icon;

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Chi tiết quy tắc tương tác thuốc lâm sàng"
      subtitle="Phân tích cơ chế dược lý học và chiến lược quản lý tương tác trên bệnh nhân"
      size="xl"
      footer={
        <>
          <button
            type="button"
            className="dashboard-action dashboard-action--secondary"
            onClick={onClose}
          >
            Đóng
          </button>
          <Link
            href={`/dashboard/medications?search=${encodeURIComponent(interaction.drugA.split(/[\s+,/]+/)[0])}`}
            className="dashboard-action dashboard-action--secondary"
            style={{ display: "inline-flex", alignItems: "center", gap: 6 }}
            onClick={onClose}
          >
            <Pill size={15} strokeWidth={2.2} />
            Tra cứu kho biệt dược {interaction.drugA.split(/[\s+,/]+/)[0]}
          </Link>
          {interaction.status === "pending" && onApprove ? (
            <button
              type="button"
              className="dashboard-action dashboard-action--primary"
              style={{ background: "var(--color-success)" }}
              onClick={() => {
                onApprove(interaction);
                onClose();
              }}
            >
              <Check size={16} strokeWidth={2.4} aria-hidden="true" />
              Duyệt đưa vào cảnh báo
            </button>
          ) : null}
          {onEdit ? (
            <button
              type="button"
              className="dashboard-action dashboard-action--primary"
              onClick={() => {
                onClose();
                onEdit(interaction);
              }}
            >
              <Pencil size={16} strokeWidth={2.2} aria-hidden="true" />
              Chỉnh sửa quy tắc
            </button>
          ) : null}
        </>
      }
    >
      <div className="interaction-detail-card">
        {/* Đối chiếu 2 thuốc */}
        <div className="interaction-detail-vs">
          <div className="interaction-detail-drug-box">
            <span className="drug-tag">Thuốc / Tác nhân 1</span>
            <strong>{interaction.drugA}</strong>
            <p>{interaction.drugAClass || "Chưa phân nhóm dược lý"}</p>
            <Link
              href={`/dashboard/medications?search=${encodeURIComponent(interaction.drugA.split(/[\s+,/]+/)[0])}`}
              className="interaction-find-med-link"
              onClick={onClose}
            >
              <Pill size={12} strokeWidth={2.4} />
              Tra cứu chế phẩm DAV ➔
            </Link>
          </div>

          <div className="interaction-detail-vs-badge" title="Tương tác đối kháng / hiệp đồng">
            VS
          </div>

          <div className="interaction-detail-drug-box" style={{ textAlign: "right" }}>
            <span className="drug-tag">Thuốc / Tác nhân 2</span>
            <strong>{interaction.drugB}</strong>
            <p>{interaction.drugBClass || "Chưa phân nhóm dược lý"}</p>
            {!interaction.drugB.toLowerCase().includes("rượu") &&
            !interaction.drugB.toLowerCase().includes("bưởi") &&
            !interaction.drugB.toLowerCase().includes("sữa") &&
            !interaction.drugB.toLowerCase().includes("thực phẩm") ? (
              <Link
                href={`/dashboard/medications?search=${encodeURIComponent(interaction.drugB.split(/[\s+,/]+/)[0])}`}
                className="interaction-find-med-link"
                onClick={onClose}
              >
                <Pill size={12} strokeWidth={2.4} />
                Tra cứu chế phẩm DAV ➔
              </Link>
            ) : (
              <span style={{ fontSize: 11, color: "var(--color-muted)", marginTop: 4, display: "inline-block" }}>
                (Tác nhân thực phẩm / đồ uống)
              </span>
            )}
          </div>
        </div>

        {/* Trạng thái & Mức độ nghiêm trọng banner */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            flexWrap: "wrap",
            gap: 12,
            padding: "12px 18px",
            background: "#ffffff",
            border: "1px solid #e2e8f0",
            borderRadius: 10,
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <span className={`interaction-severity-badge ${sevInfo.badgeClass}`}>
              <SevIcon size={16} strokeWidth={2.4} />
              {sevInfo.label}
            </span>
            <span className={`interaction-mech-badge interaction-mech-badge--${interaction.mechanismType}`}>
              {interaction.mechanismType.toUpperCase()}
            </span>
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 13 }}>
            <span style={{ color: "var(--color-muted)" }}>Trạng thái:</span>
            {interaction.status === "verified" ? (
              <span
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  gap: 4,
                  color: "var(--color-success)",
                  fontWeight: 700,
                }}
              >
                <CheckCircle2 size={16} strokeWidth={2.4} />
                Đã thẩm định
              </span>
            ) : (
              <span
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  gap: 4,
                  color: "var(--color-primary)",
                  fontWeight: 700,
                }}
              >
                <Clock3 size={16} strokeWidth={2.4} />
                Chờ hội đồng duyệt
              </span>
            )}
          </div>
        </div>

        {/* Khối Cơ chế Dược lý */}
        <div className="interaction-detail-section">
          <div className="interaction-detail-section__header">
            <BookOpen size={16} strokeWidth={2.2} style={{ color: "var(--color-primary)" }} />
            <span>Cơ chế Dược lý ({mechLabels[interaction.mechanismType]})</span>
          </div>
          <div className="interaction-detail-section__body">{interaction.mechanism}</div>
        </div>

        {/* Khối Hậu quả lâm sàng */}
        <div className="interaction-detail-section interaction-detail-section--alert">
          <div className="interaction-detail-section__header">
            <Flame size={16} strokeWidth={2.2} />
            <span>Biểu hiện lâm sàng & Nguy cơ biến chứng đe dọa an toàn</span>
          </div>
          <div className="interaction-detail-section__body" style={{ fontWeight: 500 }}>
            {interaction.clinicalEffect}
          </div>
        </div>

        {/* Khối Khuyến cáo xử trí */}
        <div className="interaction-detail-section interaction-detail-section--guide">
          <div className="interaction-detail-section__header">
            <Stethoscope size={16} strokeWidth={2.2} />
            <span>Khuyến cáo Dược lâm sàng & Hướng dẫn xử trí</span>
          </div>
          <div className="interaction-detail-section__body">{interaction.management}</div>
        </div>

        {/* Metadata */}
        <div className="interaction-detail-grid-meta">
          <div>
            <strong>Mức độ bằng chứng</strong>
            <span>
              {interaction.evidenceLevel === "clinical"
                ? "Thử nghiệm lâm sàng có kiểm chứng"
                : interaction.evidenceLevel === "case_report"
                ? "Báo cáo ca lâm sàng (Case Report)"
                : interaction.evidenceLevel === "in_vitro"
                ? "Nghiên cứu in-vitro tiền lâm sàng"
                : "Dự đoán lý thuyết / Dược lý học"}
            </span>
          </div>

          <div>
            <strong>Nguồn tài liệu y văn</strong>
            <span style={{ display: "flex", alignItems: "center", gap: 4 }}>
              {interaction.source}
              <ExternalLink size={12} strokeWidth={2} style={{ opacity: 0.7 }} />
            </span>
          </div>

          <div>
            <strong>Cập nhật lần cuối</strong>
            <span>{interaction.updatedAt}</span>
          </div>
        </div>

        {interaction.notes ? (
          <div
            style={{
              padding: "10px 14px",
              background: "var(--color-shell)",
              borderRadius: 8,
              border: "1px dashed #cbd5e1",
              fontSize: 12.5,
              color: "var(--color-secondary-text)",
            }}
          >
            <strong>Ghi chú chuyên môn:</strong> {interaction.notes}
          </div>
        ) : null}
      </div>
    </Modal>
  );
}
