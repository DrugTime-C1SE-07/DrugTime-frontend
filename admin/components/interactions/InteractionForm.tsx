"use client";

import React, { useState, useEffect } from "react";
import { Modal } from "../ui/Modal";
import {
  Interaction,
  InteractionSeverity,
  InteractionMechanismType,
  InteractionEvidenceLevel,
  InteractionStatus,
} from "../../lib/types/interaction";

interface InteractionFormProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (interaction: Partial<Interaction>) => void;
  initialData?: Interaction | null;
}

export default function InteractionForm({
  isOpen,
  onClose,
  onSubmit,
  initialData,
}: InteractionFormProps) {
  const isEdit = Boolean(initialData);

  const [drugA, setDrugA] = useState("");
  const [drugB, setDrugB] = useState("");
  const [drugAClass, setDrugAClass] = useState("");
  const [drugBClass, setDrugBClass] = useState("");
  const [severity, setSeverity] = useState<InteractionSeverity>("major");
  const [mechanismType, setMechanismType] = useState<InteractionMechanismType>("pk");
  const [mechanism, setMechanism] = useState("");
  const [clinicalEffect, setClinicalEffect] = useState("");
  const [management, setManagement] = useState("");
  const [evidenceLevel, setEvidenceLevel] = useState<InteractionEvidenceLevel>("clinical");
  const [source, setSource] = useState("Dược thư Quốc gia Việt Nam");
  const [status, setStatus] = useState<InteractionStatus>("verified");
  const [notes, setNotes] = useState("");

  const [errors, setErrors] = useState<Record<string, string>>({});

  useEffect(() => {
    if (initialData) {
      setDrugA(initialData.drugA || "");
      setDrugB(initialData.drugB || "");
      setDrugAClass(initialData.drugAClass || "");
      setDrugBClass(initialData.drugBClass || "");
      setSeverity(initialData.severity || "major");
      setMechanismType(initialData.mechanismType || "pk");
      setMechanism(initialData.mechanism || "");
      setClinicalEffect(initialData.clinicalEffect || "");
      setManagement(initialData.management || "");
      setEvidenceLevel(initialData.evidenceLevel || "clinical");
      setSource(initialData.source || "Dược thư Quốc gia Việt Nam");
      setStatus(initialData.status || "verified");
      setNotes(initialData.notes || "");
    } else {
      setDrugA("");
      setDrugB("");
      setDrugAClass("");
      setDrugBClass("");
      setSeverity("major");
      setMechanismType("pk");
      setMechanism("");
      setClinicalEffect("");
      setManagement("");
      setEvidenceLevel("clinical");
      setSource("Dược thư Quốc gia Việt Nam");
      setStatus("verified");
      setNotes("");
    }
    setErrors({});
  }, [initialData, isOpen]);

  const validate = () => {
    const newErrors: Record<string, string> = {};
    if (!drugA.trim()) newErrors.drugA = "Vui lòng nhập tên thuốc / hoạt chất A";
    if (!drugB.trim()) newErrors.drugB = "Vui lòng nhập tên thuốc / hoạt chất B";
    if (!mechanism.trim()) newErrors.mechanism = "Vui lòng mô tả cơ chế tương tác dược lý";
    if (!clinicalEffect.trim()) newErrors.clinicalEffect = "Vui lòng mô tả hậu quả / biểu hiện lâm sàng";
    if (!management.trim()) newErrors.management = "Vui lòng nhập khuyến cáo xử trí lâm sàng";
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;

    const data: Partial<Interaction> = {
      ...(initialData?.id ? { id: initialData.id } : {}),
      drugA: drugA.trim(),
      drugB: drugB.trim(),
      drugAClass: drugAClass.trim() || undefined,
      drugBClass: drugBClass.trim() || undefined,
      severity,
      mechanismType,
      mechanism: mechanism.trim(),
      clinicalEffect: clinicalEffect.trim(),
      management: management.trim(),
      evidenceLevel,
      source: source.trim(),
      status,
      notes: notes.trim() || undefined,
      updatedAt: new Date().toISOString().split("T")[0],
    };

    onSubmit(data);
    onClose();
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={
        isEdit
          ? `Chỉnh sửa quy tắc: ${initialData?.drugA} ↔ ${initialData?.drugB}`
          : "Thêm quy tắc tương tác thuốc mới"
      }
      subtitle="Định nghĩa cơ chế tương tác Dược động học / Dược lực học và khuyến cáo xử trí lâm sàng"
      size="lg"
      footer={
        <>
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
            {isEdit ? "Cập nhật quy tắc" : "Lưu quy tắc tương tác"}
          </button>
        </>
      }
    >
      <form onSubmit={handleSubmit} noValidate>
        <div className="form-row">
          <div className="form-group">
            <label className="form-label form-label--required" htmlFor="inter-drugA">
              Thuốc / Hoạt chất A
            </label>
            <input
              id="inter-drugA"
              className="form-control"
              value={drugA}
              onChange={(e) => setDrugA(e.target.value)}
              placeholder="VD: Paracetamol, Warfarin, Simvastatin..."
            />
            {errors.drugA ? <span className="form-error">{errors.drugA}</span> : null}
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="inter-drugAClass">
              Phân nhóm dược lý của Thuốc A
            </label>
            <input
              id="inter-drugAClass"
              className="form-control"
              value={drugAClass}
              onChange={(e) => setDrugAClass(e.target.value)}
              placeholder="VD: Giảm đau hạ sốt, Kháng đông kháng Vit K..."
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label className="form-label form-label--required" htmlFor="inter-drugB">
              Thuốc / Hoạt chất B hoặc Thực phẩm
            </label>
            <input
              id="inter-drugB"
              className="form-control"
              value={drugB}
              onChange={(e) => setDrugB(e.target.value)}
              placeholder="VD: Rượu (Ethanol), Aspirin, Omeprazole..."
            />
            {errors.drugB ? <span className="form-error">{errors.drugB}</span> : null}
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="inter-drugBClass">
              Phân nhóm dược lý của Thuốc B
            </label>
            <input
              id="inter-drugBClass"
              className="form-control"
              value={drugBClass}
              onChange={(e) => setDrugBClass(e.target.value)}
              placeholder="VD: NSAID, Thuốc ức chế bơm proton (PPI)..."
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label className="form-label form-label--required" htmlFor="inter-severity">
              Mức độ nghiêm trọng
            </label>
            <select
              id="inter-severity"
              className="form-select"
              value={severity}
              onChange={(e) => setSeverity(e.target.value as InteractionSeverity)}
            >
              <option value="contraindicated">Chống chỉ định tuyệt đối (Contraindicated)</option>
              <option value="major">Nghiêm trọng (Major - Đe dọa an toàn)</option>
              <option value="moderate">Trung bình (Moderate - Cần theo dõi/điều chỉnh)</option>
              <option value="minor">Nhẹ (Minor - Tương tác tiềm tàng ít nguy cơ)</option>
            </select>
          </div>

          <div className="form-group">
            <label className="form-label form-label--required" htmlFor="inter-mechanismType">
              Bản chất cơ chế tương tác
            </label>
            <select
              id="inter-mechanismType"
              className="form-select"
              value={mechanismType}
              onChange={(e) => setMechanismType(e.target.value as InteractionMechanismType)}
            >
              <option value="pk">Dược động học (PK - Enzym CYP, P-gp, Thải trừ)</option>
              <option value="pd">Dược lực học (PD - Hiệp đồng, Đối kháng thụ thể)</option>
              <option value="both">Phối hợp cả PK và PD</option>
              <option value="unknown">Cơ chế chưa rõ / Khác</option>
            </select>
          </div>
        </div>

        <div className="form-group">
          <label className="form-label form-label--required" htmlFor="inter-mechanism">
            Chi tiết cơ chế tương tác dược lý
          </label>
          <textarea
            id="inter-mechanism"
            className="form-textarea"
            rows={3}
            value={mechanism}
            onChange={(e) => setMechanism(e.target.value)}
            placeholder="Mô tả cụ thể enzym bị ức chế/cảm ứng, cạnh tranh gắn kết protein huyết tương hoặc tạo phức..."
          />
          {errors.mechanism ? <span className="form-error">{errors.mechanism}</span> : null}
        </div>

        <div className="form-group">
          <label className="form-label form-label--required" htmlFor="inter-clinicalEffect">
            Biểu hiện / Hậu quả lâm sàng & Nguy cơ biến chứng
          </label>
          <textarea
            id="inter-clinicalEffect"
            className="form-textarea"
            rows={2}
            value={clinicalEffect}
            onChange={(e) => setClinicalEffect(e.target.value)}
            placeholder="VD: Tăng nguy cơ xuất huyết tiêu hóa ồ ạt; Hoại tử tế bào gan cấp..."
          />
          {errors.clinicalEffect ? (
            <span className="form-error">{errors.clinicalEffect}</span>
          ) : null}
        </div>

        <div className="form-group">
          <label className="form-label form-label--required" htmlFor="inter-management">
            Khuyến cáo xử trí lâm sàng & Hướng dẫn sử dụng
          </label>
          <textarea
            id="inter-management"
            className="form-textarea"
            rows={3}
            value={management}
            onChange={(e) => setManagement(e.target.value)}
            placeholder="Hướng dẫn bác sĩ/dược sĩ: Tránh phối hợp, đổi thuốc thay thế, điều chỉnh liều, giãn cách thời gian uống ít nhất 2-4h..."
          />
          {errors.management ? <span className="form-error">{errors.management}</span> : null}
        </div>

        <div className="form-row">
          <div className="form-group">
            <label className="form-label" htmlFor="inter-evidenceLevel">
              Mức độ bằng chứng y học
            </label>
            <select
              id="inter-evidenceLevel"
              className="form-select"
              value={evidenceLevel}
              onChange={(e) => setEvidenceLevel(e.target.value as InteractionEvidenceLevel)}
            >
              <option value="clinical">Thử nghiệm lâm sàng có kiểm chứng (Clinical)</option>
              <option value="case_report">Báo cáo ca lâm sàng y văn (Case Report)</option>
              <option value="in_vitro">Dữ liệu in-vitro / Tiền lâm sàng</option>
              <option value="theoretical">Dự đoán lý thuyết / Ngoại suy</option>
            </select>
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="inter-source">
              Nguồn trích dẫn tài liệu
            </label>
            <input
              id="inter-source"
              className="form-control"
              value={source}
              onChange={(e) => setSource(e.target.value)}
              placeholder="VD: Dược thư QG VN, DrugBank, FDA..."
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label className="form-label" htmlFor="inter-status">
              Trạng thái kiểm duyệt
            </label>
            <select
              id="inter-status"
              className="form-select"
              value={status}
              onChange={(e) => setStatus(e.target.value as InteractionStatus)}
            >
              <option value="verified">Đã xác thực (Đưa vào hệ thống cảnh báo)</option>
              <option value="pending">Chờ Hội đồng Dược lâm sàng duyệt</option>
            </select>
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="inter-notes">
              Ghi chú nội bộ
            </label>
            <input
              id="inter-notes"
              className="form-control"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Ghi chú thêm về ca lâm sàng hoặc cảnh báo đặc biệt..."
            />
          </div>
        </div>
      </form>
    </Modal>
  );
}
