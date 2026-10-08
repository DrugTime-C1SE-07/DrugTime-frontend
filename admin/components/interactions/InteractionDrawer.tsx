"use client";

import React, { useEffect, useState } from "react";
import {
  AlertOctagon,
  AlertTriangle,
  CheckCircle2,
  FileCheck2,
  Info,
  Save,
  ShieldAlert,
  Trash2,
} from "lucide-react";
import {
  Interaction,
  InteractionEvidenceLevel,
  InteractionMechanismType,
  InteractionSeverity,
  InteractionStatus,
  InteractionTargetType,
} from "../../lib/types/interaction";
import { Modal } from "../ui/Modal";

interface InteractionDrawerProps {
  interaction: Interaction | null;
  isOpen: boolean;
  onClose: () => void;
  onSave: (data: Partial<Interaction>) => void;
  onDelete?: (interaction: Interaction) => void;
}

type FormErrors = Partial<
  Record<
    | "drugA"
    | "drugB"
    | "mechanism"
    | "clinicalEffect"
    | "management"
    | "source",
    string
  >
>;

export default function InteractionDrawer({
  interaction,
  isOpen,
  onClose,
  onSave,
  onDelete,
}: InteractionDrawerProps) {
  const isEdit = Boolean(interaction && interaction.id);

  const [form, setForm] = useState({
    drugA: "",
    drugB: "",
    drugAClass: "",
    drugBClass: "",
    atcCodeA: "",
    atcCodeB: "",
    targetType: "drug_drug" as InteractionTargetType,
    severity: "contraindicated" as InteractionSeverity,
    mechanismType: "both" as InteractionMechanismType,
    mechanism: "",
    clinicalEffect: "",
    management: "",
    evidenceLevel: "clinical" as InteractionEvidenceLevel,
    source: "",
    originSource: "",
    crossReference: "",
    verifiedBy: "",
    isVerified: true,
  });

  const [errors, setErrors] = useState<FormErrors>({});
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

  useEffect(() => {
    if (interaction) {
      setForm({
        drugA: interaction.drugA || "",
        drugB: interaction.drugB || "",
        drugAClass: interaction.drugAClass || "",
        drugBClass: interaction.drugBClass || "",
        atcCodeA: interaction.atcCodeA || "",
        atcCodeB: interaction.atcCodeB || "",
        targetType: interaction.targetType || "drug_drug",
        severity: interaction.severity || "contraindicated",
        mechanismType: interaction.mechanismType || "both",
        mechanism: interaction.mechanism || "",
        clinicalEffect: interaction.clinicalEffect || "",
        management: interaction.management || "",
        evidenceLevel: interaction.evidenceLevel || "clinical",
        source: interaction.source || "QĐ 5948/QĐ-BYT & DrugBank",
        originSource: interaction.originSource || "QĐ 5948/QĐ-BYT (Mục 4.2)",
        crossReference: interaction.crossReference || "DrugBank: DB00682",
        verifiedBy: interaction.verifiedBy || "DS. Lê Minh Trí",
        isVerified: interaction.status === "verified",
      });
    } else {
      setForm({
        drugA: "",
        drugB: "",
        drugAClass: "",
        drugBClass: "",
        atcCodeA: "",
        atcCodeB: "",
        targetType: "drug_drug",
        severity: "contraindicated",
        mechanismType: "both",
        mechanism: "",
        clinicalEffect: "",
        management: "",
        evidenceLevel: "clinical",
        source: "QĐ 5948/QĐ-BYT & Dược thư Quốc gia",
        originSource: "QĐ 5948/QĐ-BYT",
        crossReference: "DrugBank",
        verifiedBy: "DS. Quản trị viên",
        isVerified: true,
      });
    }
    setErrors({});
    setShowDeleteConfirm(false);
  }, [interaction, isOpen]);

  if (!isOpen) return null;

  const ruleCode = interaction?.ruleCode || "RULE-INT-NEW";

  const update = <Key extends keyof typeof form>(key: Key, value: (typeof form)[Key]) => {
    setForm((prev) => ({ ...prev, [key]: value }));
    if (errors[key as keyof FormErrors]) {
      setErrors((prev) => ({ ...prev, [key]: undefined }));
    }
  };

  const validate = (): boolean => {
    const nextErrors: FormErrors = {};
    if (!form.drugA.trim()) nextErrors.drugA = "Vui lòng nhập tên thuốc / hoạt chất A";
    if (!form.drugB.trim()) nextErrors.drugB = "Vui lòng nhập tên thuốc / nhóm tương tác B";
    if (!form.mechanism.trim()) nextErrors.mechanism = "Vui lòng mô tả cơ chế tác động dược lý";
    if (!form.clinicalEffect.trim())
      nextErrors.clinicalEffect = "Vui lòng mô tả hậu quả / biểu hiện lâm sàng";
    if (!form.management.trim())
      nextErrors.management = "Vui lòng nhập khuyến cáo xử trí lâm sàng & lời dặn";
    if (!form.source.trim()) nextErrors.source = "Vui lòng nhập nguồn chứng cứ y khoa";

    setErrors(nextErrors);
    return Object.keys(nextErrors).length === 0;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;

    onSave({
      ...(interaction?.id ? { id: interaction.id } : {}),
      ...interaction,
      ruleCode,
      drugA: form.drugA.trim(),
      drugB: form.drugB.trim(),
      drugAClass: form.drugAClass.trim() || undefined,
      drugBClass: form.drugBClass.trim() || undefined,
      atcCodeA: form.atcCodeA.trim() || undefined,
      atcCodeB: form.atcCodeB.trim() || undefined,
      targetType: form.targetType,
      severity: form.severity,
      mechanismType: form.mechanismType,
      mechanism: form.mechanism.trim(),
      clinicalEffect: form.clinicalEffect.trim(),
      management: form.management.trim(),
      evidenceLevel: form.evidenceLevel,
      source: form.source.trim(),
      originSource: form.originSource.trim() || undefined,
      crossReference: form.crossReference.trim() || undefined,
      verifiedBy: form.isVerified ? form.verifiedBy.trim() || undefined : undefined,
      status: (form.isVerified ? "verified" : "pending") as InteractionStatus,
    });
    onClose();
  };

  const handleDeleteCurrent = () => {
    if (interaction && onDelete) {
      onDelete(interaction);
      setShowDeleteConfirm(false);
      onClose();
    }
  };

  const radioOptions = [
    {
      value: "contraindicated" as InteractionSeverity,
      title: "Chống chỉ định (Contraindicated)",
      badge: "KHÓA ĐƠN",
      description:
        "Khóa đơn lập tức trong hệ thống kê đơn điện tử & cảnh báo đỏ an toàn cho bệnh nhân.",
      tone: "contraindicated",
      icon: AlertOctagon,
    },
    {
      value: "major" as InteractionSeverity,
      title: "Nghiêm trọng (Serious)",
      badge: "THEO DÕI",
      description:
        "Yêu cầu theo dõi lâm sàng chặt chẽ hoặc chỉ định xét nghiệm bổ sung trước khi cấp phát.",
      tone: "serious",
      icon: ShieldAlert,
    },
    {
      value: "moderate" as InteractionSeverity,
      title: "Thận trọng (Caution)",
      badge: "CẢNH BÁO",
      description:
        "Cảnh báo về khoảng thời gian uống thuốc hoặc tác động nhẹ đến hấp thu dược chất.",
      tone: "caution",
      icon: AlertTriangle,
    },
  ];

  return (
    <>
      <Modal
        isOpen={isOpen}
        onClose={onClose}
        title={
          isEdit
            ? `Hiệu chỉnh quy tắc tương tác: ${ruleCode}`
            : "Thêm mới quy tắc tương tác thuốc"
        }
        subtitle={
          form.drugA && form.drugB
            ? `Cặp tác nhân: ${form.drugA} ⇄ ${form.drugB}`
            : "Thiết lập thông số phân loại, cơ chế dược lý và khuyến cáo xử trí lâm sàng CDSS"
        }
        size="xl"
        footer={
          <div className="interaction-modal-footer">
            <div className="interaction-modal-footer__left">
              {isEdit && onDelete && interaction ? (
                <button
                  type="button"
                  className="dashboard-action dashboard-action--danger"
                  onClick={() => setShowDeleteConfirm(true)}
                >
                  <Trash2 size={16} aria-hidden="true" />
                  Xóa quy tắc
                </button>
              ) : null}
            </div>
            <div className="interaction-modal-footer__right">
              <button
                type="button"
                className="dashboard-action dashboard-action--secondary"
                onClick={onClose}
              >
                Hủy bỏ
              </button>
              <button
                type="button"
                className="dashboard-action dashboard-action--primary"
                onClick={handleSubmit}
              >
                <Save size={16} aria-hidden="true" />
                {isEdit ? "Cập nhật quy tắc" : "Lưu quy tắc"}
              </button>
            </div>
          </div>
        }
      >
        <form onSubmit={handleSubmit} noValidate className="interaction-editor-form">
          {/* Header Meta Status Card */}
          <div className="interaction-editor-meta-banner">
            <div className="interaction-editor-meta-item">
              <span className="label">Mã quy tắc:</span>
              <code className="interaction-drawer-rule-code">{ruleCode}</code>
            </div>
            <div className="interaction-editor-meta-item">
              <span className="label">Trạng thái:</span>
              {form.isVerified ? (
                <span className="interaction-drawer-verified-badge">
                  <CheckCircle2 size={14} aria-hidden="true" />
                  Đã duyệt bởi {form.verifiedBy || "Dược sĩ"}
                </span>
              ) : (
                <span className="interaction-drawer-pending-badge">Chờ thẩm định</span>
              )}
            </div>
            <div className="interaction-editor-meta-item interaction-editor-meta-item--right">
              <FileCheck2 size={15} aria-hidden="true" />
              <span>Chuẩn hóa QĐ 5948/QĐ-BYT</span>
            </div>
          </div>

          {/* Section 1: Identification */}
          <div className="interaction-editor-section">
            <h3 className="interaction-editor-section__title">
              1. Định danh cặp tác nhân tương tác
            </h3>

            <div className="form-row">
              <div className="form-group">
                <label className="form-label form-label--required" htmlFor="inter-drugA">
                  Tác nhân A (Hoạt chất / Thuốc)
                </label>
                <input
                  id="inter-drugA"
                  className="form-control"
                  value={form.drugA}
                  onChange={(e) => update("drugA", e.target.value)}
                  placeholder="VD: Warfarin, Simvastatin, Metformin..."
                  aria-required="true"
                  aria-invalid={Boolean(errors.drugA)}
                  aria-describedby={errors.drugA ? "inter-drugA-error" : undefined}
                />
                {errors.drugA ? (
                  <span id="inter-drugA-error" className="form-error" role="alert">
                    {errors.drugA}
                  </span>
                ) : null}
              </div>

              <div className="form-group">
                <label className="form-label" htmlFor="inter-atcA">
                  Mã ATC tác nhân A (WHO ATC/DDD)
                </label>
                <input
                  id="inter-atcA"
                  className="form-control form-control--mono"
                  value={form.atcCodeA}
                  onChange={(e) => update("atcCodeA", e.target.value.toUpperCase())}
                  placeholder="VD: B01AA03, C10AA01..."
                />
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label className="form-label form-label--required" htmlFor="inter-drugB">
                  Tác nhân B (Thuốc / Nhóm tương tác / Thực phẩm)
                </label>
                <input
                  id="inter-drugB"
                  className="form-control"
                  value={form.drugB}
                  onChange={(e) => update("drugB", e.target.value)}
                  placeholder="VD: Aspirin, Nước bưởi chùm, Rượu..."
                  aria-required="true"
                  aria-invalid={Boolean(errors.drugB)}
                  aria-describedby={errors.drugB ? "inter-drugB-error" : undefined}
                />
                {errors.drugB ? (
                  <span id="inter-drugB-error" className="form-error" role="alert">
                    {errors.drugB}
                  </span>
                ) : null}
              </div>

              <div className="form-group">
                <label className="form-label" htmlFor="inter-atcB">
                  Mã ATC tác nhân B (Nếu có)
                </label>
                <input
                  id="inter-atcB"
                  className="form-control form-control--mono"
                  value={form.atcCodeB}
                  onChange={(e) => update("atcCodeB", e.target.value.toUpperCase())}
                  placeholder="VD: M01AE01, B01AC06..."
                />
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label className="form-label form-label--required" htmlFor="inter-targetType">
                  Phân loại đối tượng tương tác
                </label>
                <select
                  id="inter-targetType"
                  className="form-select"
                  value={form.targetType}
                  onChange={(e) =>
                    update("targetType", e.target.value as InteractionTargetType)
                  }
                >
                  <option value="drug_drug">Thuốc - Thuốc (Drug - Drug)</option>
                  <option value="drug_food">Thuốc - Thực phẩm (Drug - Food)</option>
                </select>
              </div>

              <div className="form-group">
                <label className="form-label form-label--required" htmlFor="inter-mechanismType">
                  Bản chất cơ chế tương tác
                </label>
                <select
                  id="inter-mechanismType"
                  className="form-select"
                  value={form.mechanismType}
                  onChange={(e) =>
                    update("mechanismType", e.target.value as InteractionMechanismType)
                  }
                >
                  <option value="pk">Dược động học (PK - Pharmacokinetic)</option>
                  <option value="pd">Dược lực học (PD - Pharmacodynamic)</option>
                  <option value="both">Phối hợp cả PK và PD</option>
                  <option value="unknown">Chưa rõ cơ chế</option>
                </select>
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label className="form-label" htmlFor="inter-classA">
                  Nhóm dược lý tác nhân A
                </label>
                <input
                  id="inter-classA"
                  className="form-control"
                  value={form.drugAClass}
                  onChange={(e) => update("drugAClass", e.target.value)}
                  placeholder="VD: Thuốc chống đông máu kháng Vitamin K"
                />
              </div>

              <div className="form-group">
                <label className="form-label" htmlFor="inter-classB">
                  Nhóm dược lý tác nhân B
                </label>
                <input
                  id="inter-classB"
                  className="form-control"
                  value={form.drugBClass}
                  onChange={(e) => update("drugBClass", e.target.value)}
                  placeholder="VD: Thuốc chống viêm không steroid (NSAIDs)"
                />
              </div>
            </div>
          </div>

          {/* Section 2: Severity alert radio cards */}
          <div className="interaction-editor-section">
            <h3 className="interaction-editor-section__title">
              2. Mức độ cảnh báo lâm sàng CDSS
            </h3>

            <div className="interaction-editor-radio-group">
              {radioOptions.map((opt) => {
                const isSelected =
                  form.severity === opt.value ||
                  (opt.value === "moderate" && form.severity === "minor");
                return (
                  <label
                    key={opt.value}
                    className={`interaction-editor-radio-card interaction-editor-radio-card--${
                      opt.tone
                    } ${isSelected ? "is-selected" : ""}`}
                  >
                    <input
                      type="radio"
                      name="editor-severity"
                      checked={isSelected}
                      onChange={() => update("severity", opt.value)}
                    />
                    <div className="interaction-editor-radio-body">
                      <strong className="interaction-editor-radio-title">{opt.title}</strong>
                      <span className="interaction-editor-radio-desc">{opt.description}</span>
                    </div>
                    <span className="interaction-editor-radio-badge">{opt.badge}</span>
                  </label>
                );
              })}
            </div>
          </div>

          {/* Section 3: Mechanism & Clinical Handling */}
          <div className="interaction-editor-section">
            <h3 className="interaction-editor-section__title">
              3. Cơ chế dược lý & Hướng dẫn xử trí lâm sàng
            </h3>

            <div className="form-group">
              <label className="form-label form-label--required" htmlFor="inter-mech">
                Cơ chế tác động dược lực / dược động học
              </label>
              <textarea
                id="inter-mech"
                className="form-control form-textarea"
                rows={3}
                value={form.mechanism}
                onChange={(e) => update("mechanism", e.target.value)}
                placeholder="Mô tả cụ thể cơ chế tác động enzym CYP450, cạnh tranh gắn kết protein huyết tương, hoặc hiệp đồng tác dụng..."
                aria-required="true"
                aria-invalid={Boolean(errors.mechanism)}
                aria-describedby={errors.mechanism ? "inter-mech-error" : undefined}
              />
              {errors.mechanism ? (
                <span id="inter-mech-error" className="form-error" role="alert">
                  {errors.mechanism}
                </span>
              ) : null}
            </div>

            <div className="form-group">
              <label className="form-label form-label--required" htmlFor="inter-effect">
                Hậu quả / Biểu hiện lâm sàng trên người bệnh
              </label>
              <textarea
                id="inter-effect"
                className="form-control form-textarea"
                rows={3}
                value={form.clinicalEffect}
                onChange={(e) => update("clinicalEffect", e.target.value)}
                placeholder="Gia tăng nồng độ thuốc trong huyết tương, nguy cơ xuất huyết tiêu hóa nghiêm trọng, suy thận cấp, tiêu cơ vân..."
                aria-required="true"
                aria-invalid={Boolean(errors.clinicalEffect)}
                aria-describedby={errors.clinicalEffect ? "inter-effect-error" : undefined}
              />
              {errors.clinicalEffect ? (
                <span id="inter-effect-error" className="form-error" role="alert">
                  {errors.clinicalEffect}
                </span>
              ) : null}
            </div>

            <div className="form-group">
              <label className="form-label form-label--required" htmlFor="inter-manage">
                Khuyến cáo xử trí lâm sàng & Lời dặn bệnh nhân
              </label>
              <textarea
                id="inter-manage"
                className="form-control form-textarea"
                rows={3}
                value={form.management}
                onChange={(e) => update("management", e.target.value)}
                placeholder="Tránh phối hợp; thay thế bằng thuốc khác; điều chỉnh liều hoặc theo dõi chỉ số xét nghiệm INR / creatinin máu định kỳ..."
                aria-required="true"
                aria-invalid={Boolean(errors.management)}
                aria-describedby={errors.management ? "inter-manage-error" : undefined}
              />
              {errors.management ? (
                <span id="inter-manage-error" className="form-error" role="alert">
                  {errors.management}
                </span>
              ) : null}
            </div>
          </div>

          {/* Section 4: Clinical Evidence & Curation */}
          <div className="interaction-editor-section">
            <h3 className="interaction-editor-section__title">
              4. Chứng cứ y khoa & Thẩm định đối soát
            </h3>

            <div className="form-row">
              <div className="form-group">
                <label className="form-label form-label--required" htmlFor="inter-source">
                  Nguồn chứng cứ y khoa
                </label>
                <input
                  id="inter-source"
                  className="form-control"
                  value={form.source}
                  onChange={(e) => update("source", e.target.value)}
                  placeholder="VD: Dược thư Quốc gia Việt Nam, QĐ 5948/QĐ-BYT"
                  aria-required="true"
                  aria-invalid={Boolean(errors.source)}
                  aria-describedby={errors.source ? "inter-source-error" : undefined}
                />
                {errors.source ? (
                  <span id="inter-source-error" className="form-error" role="alert">
                    {errors.source}
                  </span>
                ) : null}
              </div>

              <div className="form-group">
                <label className="form-label" htmlFor="inter-crossRef">
                  Mã đối soát CSDL quốc tế
                </label>
                <input
                  id="inter-crossRef"
                  className="form-control form-control--mono"
                  value={form.crossReference}
                  onChange={(e) => update("crossReference", e.target.value)}
                  placeholder="VD: DrugBank: DB00682, Stockley's Interactions"
                />
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label className="form-label" htmlFor="inter-origin">
                  Nguồn bóc tách văn bản quy phạm
                </label>
                <input
                  id="inter-origin"
                  className="form-control"
                  value={form.originSource}
                  onChange={(e) => update("originSource", e.target.value)}
                  placeholder="VD: QĐ 5948/QĐ-BYT (Mục 4.2)"
                />
              </div>

              <div className="form-group">
                <label className="form-label" htmlFor="inter-verifiedBy">
                  Dược sĩ thẩm định chuyên môn
                </label>
                <input
                  id="inter-verifiedBy"
                  className="form-control"
                  value={form.verifiedBy}
                  onChange={(e) => update("verifiedBy", e.target.value)}
                  placeholder="VD: DS. Lê Minh Trí, DS. Nguyễn Văn An"
                />
              </div>
            </div>

            <div className="interaction-editor-verify-box">
              <label className="interaction-drawer-check-box">
                <input
                  type="checkbox"
                  checked={form.isVerified}
                  onChange={(e) => update("isVerified", e.target.checked)}
                />
                <span>
                  Đã thẩm định và chuẩn hóa dữ liệu theo chuẩn Quyết định 5948/QĐ-BYT Bộ Y tế
                </span>
              </label>
            </div>
          </div>
        </form>
      </Modal>

      {/* Delete Confirmation Modal */}
      <Modal
        isOpen={showDeleteConfirm}
        onClose={() => setShowDeleteConfirm(false)}
        title="Xác nhận xóa quy tắc tương tác"
        size="sm"
        footer={
          <div className="interaction-confirm-actions">
            <button
              type="button"
              className="dashboard-action dashboard-action--secondary"
              onClick={() => setShowDeleteConfirm(false)}
            >
              Hủy bỏ
            </button>
            <button
              type="button"
              className="dashboard-action dashboard-action--danger"
              onClick={handleDeleteCurrent}
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
            <strong>{interaction?.drugA}</strong> và <strong>{interaction?.drugB}</strong>?
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
