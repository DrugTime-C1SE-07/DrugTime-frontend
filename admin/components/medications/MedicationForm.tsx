"use client";

import { useEffect, useRef, useState } from "react";
import { Modal } from "../ui/Modal";
import type { Medication, MedicationInput, MedicationSource } from "../../lib/types/medication";

const empty: MedicationInput = { name: "", raw_active_ingredient: null, strength_text: null, dosage_form: null, manufacturer_name: null, manufacturer_country: null, packaging_spec: null, source: null, source_ref: null };
const textFields = [
  ["name", "Tên thuốc", 255], ["raw_active_ingredient", "Hoạt chất ghi trên thuốc", 500],
  ["strength_text", "Hàm lượng", 100], ["dosage_form", "Dạng bào chế", 100],
  ["manufacturer_name", "Nhà sản xuất", 255], ["manufacturer_country", "Quốc gia sản xuất", 100],
  ["packaging_spec", "Quy cách đóng gói", 255],
] as const;
type Props = { isOpen: boolean; initialData: Medication | null; onClose: () => void; onSubmit: (input: MedicationInput) => Promise<void> };

export default function MedicationForm({ isOpen, initialData, onClose, onSubmit }: Props) {
  const [values, setValues] = useState<MedicationInput>(empty);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const busy = useRef(false);
  useEffect(() => { setValues(initialData ? { ...initialData } : { ...empty }); setError(""); }, [initialData, isOpen]);
  const close = () => { if (!busy.current) onClose(); };
  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (busy.current) return;
    if (!values.name.trim()) { setError("Vui lòng nhập tên thuốc."); return; }
    if (Boolean(values.source) !== Boolean(values.source_ref?.trim())) { setError("Nguồn và mã tham chiếu phải cùng có giá trị hoặc cùng để trống."); return; }
    busy.current = true; setSaving(true); setError("");
    try { await onSubmit({ ...values, name: values.name.trim(), source_ref: values.source_ref?.trim() || null }); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Không thể lưu thuốc."); }
    finally { busy.current = false; setSaving(false); }
  };
  return <Modal isOpen={isOpen} onClose={close} title={initialData ? "Sửa thuốc" : "Thêm thuốc"} size="lg" footer={<>
    <button type="button" className="dashboard-action dashboard-action--secondary" onClick={close} disabled={saving}>Hủy</button>
    <button type="submit" form="medication-editor" className="dashboard-action dashboard-action--primary" disabled={saving}>{saving ? "Đang lưu…" : "Lưu thuốc"}</button>
  </>}><form id="medication-editor" onSubmit={submit}>
    {error && <p className="live-error" role="alert">{error}</p>}
    <fieldset disabled={saving} className="live-form">
      {textFields.map(([field, label, max]) => <label key={field}>{label}{field === "name" ? " *" : ""}<input required={field === "name"} maxLength={max} value={values[field] ?? ""} onChange={event => setValues(previous => ({ ...previous, [field]: field === "name" ? event.target.value : event.target.value || null }))} /></label>)}
      <label>Nguồn<select value={values.source ?? ""} onChange={event => setValues(previous => ({ ...previous, source: event.target.value as MedicationSource || null }))}>
        <option value="">Không có nguồn tham chiếu</option><option value="dav_drugbank">DAV / DrugBank</option><option value="qd_5948">Quyết định 5948</option><option value="duoc_thu_qg">Dược thư Quốc gia</option>
      </select></label>
      <label>Mã tham chiếu nguồn<input maxLength={255} value={values.source_ref ?? ""} onChange={event => setValues(previous => ({ ...previous, source_ref: event.target.value || null }))} /></label>
    </fieldset>
  </form></Modal>;
}
