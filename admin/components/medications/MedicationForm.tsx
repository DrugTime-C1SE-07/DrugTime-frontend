"use client";

import React, { useState, useEffect } from "react";
import { Modal } from "../ui/Modal";
import { Medication, MedicationQuality } from "../../lib/types/medication";

interface MedicationFormProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (medication: Partial<Medication>) => void;
  initialData?: Medication | null;
}

export default function MedicationForm({
  isOpen,
  onClose,
  onSubmit,
  initialData,
}: MedicationFormProps) {
  const isEdit = Boolean(initialData);

  const [name, setName] = useState("");
  const [form, setForm] = useState("");
  const [ingredient, setIngredient] = useState("");
  const [strength, setStrength] = useState("");
  const [regNo, setRegNo] = useState("");
  const [source, setSource] = useState("Cục QLD");
  const [sourceTag, setSourceTag] = useState("DAV");
  const [group, setGroup] = useState("Kháng sinh");
  const [quality, setQuality] = useState<MedicationQuality>("verified");
  const [manufacturer, setManufacturer] = useState("");
  const [packaging, setPackaging] = useState("");
  const [country, setCountry] = useState("Việt Nam");
  const [description, setDescription] = useState("");
  const [isSpecialControl, setIsSpecialControl] = useState(false);
  const [formWarning, setFormWarning] = useState("");

  const [errors, setErrors] = useState<Record<string, string>>({});

  useEffect(() => {
    if (initialData) {
      setName(initialData.name || "");
      setForm(initialData.form || "");
      setIngredient(initialData.ingredient || "");
      setStrength(initialData.strength || "");
      setRegNo(initialData.regNo || "");
      setSource(initialData.source || "Cục QLD");
      setSourceTag(initialData.sourceTag || "DAV");
      setGroup(initialData.group || "Kháng sinh");
      setQuality(initialData.quality || "verified");
      setManufacturer(initialData.manufacturer || "");
      setPackaging(initialData.packaging || "");
      setCountry(initialData.country || "Việt Nam");
      setDescription(initialData.description || "");
      setIsSpecialControl(Boolean(initialData.noteBadge));
      setFormWarning(initialData.formWarning || "");
    } else {
      setName("");
      setForm("Viên nén bao phim");
      setIngredient("");
      setStrength("");
      setRegNo("");
      setSource("Cục QLD");
      setSourceTag("DAV");
      setGroup("Kháng sinh");
      setQuality("verified");
      setManufacturer("");
      setPackaging("");
      setCountry("Việt Nam");
      setDescription("");
      setIsSpecialControl(false);
      setFormWarning("");
    }
    setErrors({});
  }, [initialData, isOpen]);

  const handleSourceChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const val = e.target.value;
    setSource(val);
    if (val === "Cục QLD") setSourceTag("DAV");
    else if (val === "DrugBank") setSourceTag("DB");
    else if (val === "Cào web") setSourceTag("Web");
    else setSourceTag("Manual");
  };

  const validate = () => {
    const newErrors: Record<string, string> = {};
    if (!name.trim()) newErrors.name = "Vui lòng nhập tên biệt dược";
    if (!ingredient.trim()) newErrors.ingredient = "Vui lòng nhập hoạt chất chính";
    if (!strength.trim()) newErrors.strength = "Vui lòng nhập hàm lượng / nồng độ";
    if (quality === "verified" && (!regNo.trim() || regNo.includes("Thiếu"))) {
      newErrors.regNo = "Thuốc đã xác thực bắt buộc phải có số đăng ký DAV";
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;

    const data: Partial<Medication> = {
      ...(initialData?.id ? { id: initialData.id } : {}),
      name: name.trim(),
      form: form.trim() || undefined,
      ingredient: ingredient.trim(),
      strength: strength.trim(),
      regNo: regNo.trim() || "Thiếu SĐK",
      isRegNoMissing: !regNo.trim() || regNo.includes("Thiếu"),
      source,
      sourceTag,
      group,
      quality,
      manufacturer: manufacturer.trim() || undefined,
      packaging: packaging.trim() || undefined,
      country: country.trim() || undefined,
      description: description.trim() || undefined,
      noteBadge: isSpecialControl ? "△" : undefined,
      formWarning: formWarning.trim() || undefined,
      updatedAt: new Date().toISOString().split("T")[0],
    };

    onSubmit(data);
    onClose();
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={isEdit ? `Chỉnh sửa thuốc: ${initialData?.name}` : "Thêm thuốc mới vào danh mục"}
      subtitle="Nhập thông tin định danh biệt dược, hoạt chất và số đăng ký lưu hành theo chuẩn Cục Quản lý Dược"
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
            {isEdit ? "Cập nhật thay đổi" : "Lưu vào danh mục"}
          </button>
        </>
      }
    >
      <form onSubmit={handleSubmit} noValidate>
        <div className="form-row">
          <div className="form-group">
            <label className="form-label form-label--required" htmlFor="med-name">
              Tên biệt dược
            </label>
            <input
              id="med-name"
              className="form-control"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="VD: Glucophage 850mg, Augmentin 1g"
            />
            {errors.name ? <span className="form-error">{errors.name}</span> : null}
          </div>

          <div className="form-group">
            <label className="form-label form-label--required" htmlFor="med-form">
              Dạng bào chế
            </label>
            <input
              id="med-form"
              className="form-control"
              value={form}
              onChange={(e) => setForm(e.target.value)}
              placeholder="VD: Viên nén bao phim, Cốm sủi, Hỗn dịch..."
            />
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label className="form-label form-label--required" htmlFor="med-ingredient">
              Hoạt chất chính
            </label>
            <input
              id="med-ingredient"
              className="form-control"
              value={ingredient}
              onChange={(e) => setIngredient(e.target.value)}
              placeholder="VD: Metformin hydrochloride, Paracetamol"
            />
            {errors.ingredient ? (
              <span className="form-error">{errors.ingredient}</span>
            ) : null}
          </div>

          <div className="form-group">
            <label className="form-label form-label--required" htmlFor="med-strength">
              Hàm lượng / Nồng độ
            </label>
            <input
              id="med-strength"
              className="form-control"
              value={strength}
              onChange={(e) => setStrength(e.target.value)}
              placeholder="VD: 850 mg / viên, 875mg + 125mg"
            />
            {errors.strength ? <span className="form-error">{errors.strength}</span> : null}
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label className="form-label" htmlFor="med-regno">
              Số đăng ký (SĐK DAV)
            </label>
            <input
              id="med-regno"
              className="form-control"
              value={regNo}
              onChange={(e) => setRegNo(e.target.value)}
              placeholder="VD: VN-18234-14, VD-24750-16"
            />
            {errors.regNo ? <span className="form-error">{errors.regNo}</span> : null}
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="med-source">
              Nguồn dữ liệu
            </label>
            <select
              id="med-source"
              className="form-select"
              value={source}
              onChange={handleSourceChange}
            >
              <option value="Cục QLD">Cục Quản lý Dược (DAV)</option>
              <option value="DrugBank">DrugBank Quốc tế</option>
              <option value="Thủ công">Nhập thủ công</option>
              <option value="Cào web">Cào dữ liệu web tự động</option>
            </select>
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label className="form-label" htmlFor="med-group">
              Nhóm điều trị
            </label>
            <select
              id="med-group"
              className="form-select"
              value={group}
              onChange={(e) => setGroup(e.target.value)}
            >
              <option value="Kháng sinh">Kháng sinh</option>
              <option value="Đái tháo đường">Đái tháo đường</option>
              <option value="Giảm đau hạ sốt">Giảm đau hạ sốt</option>
              <option value="Tim mạch">Tim mạch</option>
              <option value="Hướng thần">Hướng thần</option>
              <option value="Dạ dày - Tiêu hóa">Dạ dày - Tiêu hóa</option>
              <option value="Chống viêm - Corticoid">Chống viêm - Corticoid</option>
              <option value="Hô hấp">Hô hấp</option>
              <option value="Khác">Khác</option>
            </select>
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="med-quality">
              Trạng thái xác thực dữ liệu
            </label>
            <select
              id="med-quality"
              className="form-select"
              value={quality}
              onChange={(e) => setQuality(e.target.value as MedicationQuality)}
            >
              <option value="verified">Đã xác thực (Verified)</option>
              <option value="pending">Cần duyệt (Pending)</option>
              <option value="missing">Thiếu thông tin (Missing)</option>
            </select>
          </div>
        </div>

        <div className="form-row">
          <div className="form-group">
            <label className="form-label" htmlFor="med-manufacturer">
              Nhà sản xuất
            </label>
            <input
              id="med-manufacturer"
              className="form-control"
              value={manufacturer}
              onChange={(e) => setManufacturer(e.target.value)}
              placeholder="VD: GlaxoSmithKline, Dược Hậu Giang..."
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="med-country">
              Nước sản xuất
            </label>
            <input
              id="med-country"
              className="form-control"
              value={country}
              onChange={(e) => setCountry(e.target.value)}
              placeholder="VD: Việt Nam, Pháp, Thụy Sĩ..."
            />
          </div>
        </div>

        <div className="form-group">
          <label className="form-label" htmlFor="med-packaging">
            Quy cách đóng gói
          </label>
          <input
            id="med-packaging"
            className="form-control"
            value={packaging}
            onChange={(e) => setPackaging(e.target.value)}
            placeholder="VD: Hộp 3 vỉ x 10 viên nén"
          />
        </div>

        <div className="form-group">
          <label className="form-label" htmlFor="med-description">
            Ghi chú / Chỉ định lâm sàng tóm tắt
          </label>
          <textarea
            id="med-description"
            className="form-textarea"
            rows={2}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Mô tả tác dụng, cơ chế hoặc lưu ý quan trọng khi dùng..."
          />
        </div>

        <div className="form-row" style={{ alignItems: "center" }}>
          <div className="form-group" style={{ marginBottom: 0 }}>
            <label
              style={{
                display: "flex",
                alignItems: "center",
                gap: 8,
                cursor: "pointer",
                fontSize: 13,
                fontWeight: 600,
              }}
            >
              <input
                type="checkbox"
                checked={isSpecialControl}
                onChange={(e) => setIsSpecialControl(e.target.checked)}
                style={{ width: 16, height: 16, cursor: "pointer" }}
              />
              <span>Thuốc kiểm soát đặc biệt (kèm nhãn △)</span>
            </label>
            <span className="form-hint">
              Áp dụng cho thuốc hướng thần, gây nghiện, tiền chất theo quy định Bộ Y tế.
            </span>
          </div>

          {quality === "missing" ? (
            <div className="form-group" style={{ marginBottom: 0 }}>
              <label className="form-label" htmlFor="med-formWarning">
                Cảnh báo thông tin thiếu
              </label>
              <input
                id="med-formWarning"
                className="form-control"
                value={formWarning}
                onChange={(e) => setFormWarning(e.target.value)}
                placeholder="VD: Dạng bào chế chưa rõ, Thiếu SĐK..."
              />
            </div>
          ) : null}
        </div>
      </form>
    </Modal>
  );
}
