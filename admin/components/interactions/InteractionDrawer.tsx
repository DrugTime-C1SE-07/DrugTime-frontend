"use client";

import { useEffect, useRef, useState } from "react";
import type { DrugInput, FoodInput, HandlingType, Ingredient, Interaction, InteractionType, RuleKind, Threshold } from "../../lib/types/interaction";
import { listIngredients, ruleNames, thresholdInput } from "../../lib/api/interactions";
import { Modal } from "../ui/Modal";
import Pagination from "../ui/Pagination";

function IngredientPicker({ label, value, onChange }: { label: string; value: Ingredient | null; onChange: (item: Ingredient | null) => void }) {
  const [search, setSearch] = useState(""); const [skip, setSkip] = useState(0);
  const [items, setItems] = useState<Ingredient[]>([]); const [total, setTotal] = useState(0);
  const [error, setError] = useState(""); const [loading, setLoading] = useState(true); const [revision, setRevision] = useState(0);
  useEffect(() => {
    const controller = new AbortController(); setLoading(true); setError("");
    listIngredients(search, skip, controller.signal).then(page => { if (!controller.signal.aborted) { setItems(page.items); setTotal(page.total); } })
      .catch(reason => { if (!controller.signal.aborted) setError(reason.message); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [search, skip, revision]);
  return <div className="live-picker"><label>{label}<input type="search" value={search} maxLength={100} placeholder="Tìm hoạt chất" onChange={event => { setSearch(event.target.value); setSkip(0); onChange(null); }} /></label>
    <p>{value ? `Đã chọn: ${value.standard_name} (ID ${value.id})` : "Chưa chọn hoạt chất"}</p>
    {loading ? <p role="status">Đang tìm…</p> : error ? <p role="alert">{error} <button type="button" onClick={() => setRevision(n => n + 1)}>Thử lại</button></p> : <>
      {items.length ? <ul>{items.map(item => <li key={item.id}><button type="button" aria-pressed={value?.id === item.id} onClick={() => onChange(item)}>{item.standard_name} — ID {item.id}</button></li>)}</ul> : <p>Không có hoạt chất khớp.</p>}
      <Pagination offset={skip} total={total} onChange={setSkip} />
    </>}
  </div>;
}

type Props = { isOpen: boolean; kind: RuleKind; interaction: Interaction | null; onClose: () => void; onSave: (input: DrugInput | FoodInput) => Promise<void>; onReload: () => Promise<void> };
export default function InteractionDrawer({ isOpen, kind, interaction, onClose, onSave, onReload }: Props) {
  const [a, setA] = useState<Ingredient | null>(null); const [b, setB] = useState<Ingredient | null>(null);
  const [bMode, setBMode] = useState("catalog"); const [external, setExternal] = useState("");
  const [food, setFood] = useState(""); const [source, setSource] = useState(""); const [description, setDescription] = useState("");
  const [severity, setSeverity] = useState(4); const [interactionType, setInteractionType] = useState<InteractionType>("chong_chi_dinh");
  const [handling, setHandling] = useState<HandlingType>("tranh_phoi_hop"); const [interval, setInterval] = useState("");
  const [thresholds, setThresholds] = useState<Threshold[]>([]);
  const [saving, setSaving] = useState(false); const [error, setError] = useState(""); const busy = useRef(false);
  useEffect(() => {
    if (!isOpen) return;
    setError(""); setSource(interaction?.source ?? ""); setSeverity(interaction?.severity_level ?? 4);
    setA(interaction ? interaction.kind === "drug_drug" ? interaction.ingredient_a : interaction.ingredient : null);
    if (interaction?.kind === "drug_drug") {
      setB(interaction.ingredient_b); setBMode(interaction.ingredient_b ? "catalog" : "external"); setExternal(interaction.ingredient_b_external_name ?? "");
      setInteractionType(interaction.interaction_type); setHandling(interaction.handling_type); setInterval(interaction.min_interval_hours === null ? "" : String(interaction.min_interval_hours));
      setDescription(interaction.description); setThresholds(interaction.dose_thresholds.map(thresholdInput)); setFood("");
    } else {
      setB(null); setBMode("catalog"); setExternal(""); setInteractionType("chong_chi_dinh"); setHandling("tranh_phoi_hop"); setInterval(""); setThresholds([]);
      setDescription(interaction?.reason ?? ""); setFood(interaction?.food_to_avoid ?? "");
    }
  }, [interaction, isOpen]);
  const close = () => { if (!busy.current) onClose(); };
  const submit = async (event: React.FormEvent) => {
    event.preventDefault(); if (busy.current) return;
    if (!a || !description.trim() || !source.trim()) { setError("Chọn hoạt chất, nhập nội dung và nguồn chứng cứ."); return; }
    if (kind === "drug_drug" && (bMode === "catalog" ? !b : !external.trim())) { setError("Chọn hoạt chất B hoặc nhập tên ngoài danh mục."); return; }
    if (kind === "drug_food" && !food.trim()) { setError("Nhập thực phẩm cần tránh."); return; }
    const input: DrugInput | FoodInput = kind === "drug_drug" ? {
      ingredient_a_id: a.id,
      ...(bMode === "catalog" && b ? { ingredient_b_id: b.id } : { ingredient_b_external_name: external.trim() }),
      interaction_type: interactionType, severity_level: severity, handling_type: handling,
      min_interval_hours: interval === "" ? null : Number(interval), description: description.trim(), source: source.trim(), dose_thresholds: thresholds,
    } : { ingredient_id: a.id, food_to_avoid: food.trim(), severity_level: severity, reason: description.trim(), source: source.trim() };
    busy.current = true; setSaving(true); setError("");
    try { await onSave(input); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Không thể lưu quy tắc."); }
    finally { busy.current = false; setSaving(false); }
  };
  const reload = async () => {
    if (busy.current) return; busy.current = true; setSaving(true); setError("");
    try { await onReload(); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Không tải được phiên bản mới."); }
    finally { busy.current = false; setSaving(false); }
  };
  const changeThreshold = (index: number, patch: Partial<Threshold>) => setThresholds(previous => previous.map((item, position) => position === index ? { ...item, ...patch } : item));
  return <Modal isOpen={isOpen} onClose={close} title={interaction ? `Quy tắc #${interaction.id} — phiên bản ${interaction.version}` : kind === "drug_drug" ? "Thêm tương tác thuốc – thuốc" : "Thêm tương tác thuốc – thực phẩm"} size="xl" footer={<>
    <button type="button" onClick={close} disabled={saving}>Hủy</button><button type="submit" form="interaction-editor" className="dashboard-action dashboard-action--primary" disabled={saving}>{saving ? "Đang xử lý…" : "Lưu quy tắc"}</button>
  </>}>
    {interaction && <><p>{ruleNames(interaction).join(" ↔ ")}. Cặp hoạt chất không đổi khi sửa.</p><p>Người cập nhật: {interaction.updated_by?.email ?? "Chưa có thông tin"}</p><button type="button" disabled={saving} onClick={reload}>Tải bản hiện tại, bỏ thay đổi chưa lưu</button></>}
    <form id="interaction-editor" onSubmit={submit}>{error && <p role="alert" className="live-error">{error}</p>}
      <fieldset disabled={saving} className="live-form">
        {!interaction && <IngredientPicker label="Hoạt chất A *" value={a} onChange={setA} />}
        {!interaction && kind === "drug_drug" && <><label>Đối tượng B<select value={bMode} onChange={event => setBMode(event.target.value)}><option value="catalog">Hoạt chất trong danh mục</option><option value="external">Tên ngoài danh mục</option></select></label>
          {bMode === "catalog" ? <IngredientPicker label="Hoạt chất B *" value={b} onChange={setB} /> : <label>Tên đối tượng B *<input required maxLength={200} value={external} onChange={event => setExternal(event.target.value)} /></label>}
        </>}
        {kind === "drug_food" && <label>Thực phẩm cần tránh *<input required maxLength={200} value={food} onChange={event => setFood(event.target.value)} /></label>}
        <label>Mức độ (1–4) *<input required type="number" min={1} max={4} step={1} value={severity} onChange={event => setSeverity(Number(event.target.value))} /></label>
        {kind === "drug_drug" && <><label>Phân loại<select value={interactionType} onChange={event => setInteractionType(event.target.value as InteractionType)}><option value="chong_chi_dinh">Chống chỉ định</option><option value="phu_thuoc_lieu">Phụ thuộc liều</option></select></label>
          <label>Cách xử trí<select value={handling} onChange={event => setHandling(event.target.value as HandlingType)}><option value="tranh_phoi_hop">Tránh phối hợp</option><option value="can_theo_doi">Cần theo dõi</option><option value="cach_gio">Cách giờ</option><option value="giam_lieu">Giảm liều</option></select></label>
          <label>Khoảng cách giờ (chỉ khi xử trí cách giờ)<input type="number" min={0} max={168} step="any" value={interval} onChange={event => setInterval(event.target.value)} /></label>
        </>}
        <label>{kind === "drug_drug" ? "Mô tả tương tác" : "Lý do cần tránh"} *<textarea required maxLength={4000} rows={5} value={description} onChange={event => setDescription(event.target.value)} /></label>
        <label>Nguồn chứng cứ *<textarea required maxLength={500} value={source} onChange={event => setSource(event.target.value)} /></label>
        {kind === "drug_drug" && <section className="live-thresholds"><h3>Ngưỡng liều</h3><p>Chống chỉ định không có ngưỡng liều; mức độ phải là 4. Mỗi ngưỡng có ít nhất một giới hạn.</p>
          {thresholds.map((threshold, index) => <fieldset key={index}><legend>Ngưỡng {index + 1}</legend>
            <label>Hoạt chất<select value={threshold.ingredient_ref} onChange={event => changeThreshold(index, { ingredient_ref: event.target.value as "A" | "B" })}><option value="A">A</option>{bMode === "catalog" && <option value="B">B</option>}</select></label>
            <label>Liều tối thiểu<input type="number" min={0} step="any" value={threshold.min_dose ?? ""} onChange={event => changeThreshold(index, { min_dose: event.target.value === "" ? null : Number(event.target.value) })} /></label>
            <label>Liều tối đa<input type="number" min={0} step="any" value={threshold.max_dose ?? ""} onChange={event => changeThreshold(index, { max_dose: event.target.value === "" ? null : Number(event.target.value) })} /></label>
            <label>Đơn vị *<input required maxLength={50} value={threshold.dose_unit} onChange={event => changeThreshold(index, { dose_unit: event.target.value })} /></label>
            <label>Mức độ ngưỡng *<input required type="number" min={1} max={4} step={1} value={threshold.severity_level} onChange={event => changeThreshold(index, { severity_level: Number(event.target.value) })} /></label>
            <label>Cảnh báo *<textarea required maxLength={1000} value={threshold.warning_text} onChange={event => changeThreshold(index, { warning_text: event.target.value })} /></label>
            <button type="button" onClick={() => setThresholds(previous => previous.filter((_, position) => position !== index))}>Bỏ ngưỡng {index + 1}</button>
          </fieldset>)}
          <button type="button" disabled={thresholds.length >= 20} onClick={() => setThresholds(previous => [...previous, { ingredient_ref: "A", min_dose: null, max_dose: null, dose_unit: "", severity_level: 1, warning_text: "" }])}>Thêm ngưỡng</button>
        </section>}
      </fieldset>
    </form>
  </Modal>;
}
