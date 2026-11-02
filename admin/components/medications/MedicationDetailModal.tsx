"use client";

import { useEffect, useState } from "react";
import type { Medication } from "../../lib/types/medication";
import type { Interaction, RuleKind } from "../../lib/types/interaction";
import { getMedication } from "../../lib/api/medications";
import { listInteractions, ruleKey, ruleNames } from "../../lib/api/interactions";
import { Modal } from "../ui/Modal";
import Pagination from "../ui/Pagination";

export default function MedicationDetailModal({ medication, onClose, onEdit }: { medication: Medication | null; onClose: () => void; onEdit: (item: Medication) => void }) {
  const [detail, setDetail] = useState<Medication | null>(null);
  const [rules, setRules] = useState<Interaction[]>([]);
  const [kind, setKind] = useState<RuleKind>("drug_drug");
  const [skip, setSkip] = useState(0);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState("");
  const [ruleError, setRuleError] = useState("");
  const [loading, setLoading] = useState(false);
  const [revision, setRevision] = useState(0);
  const id = medication?.id;
  useEffect(() => { setSkip(0); setKind("drug_drug"); }, [id]);
  useEffect(() => {
    if (id === undefined) return;
    const controller = new AbortController(); setDetail(null); setError("");
    getMedication(id, controller.signal).then(value => { if (!controller.signal.aborted) setDetail(value); }).catch(reason => { if (!controller.signal.aborted) setError(reason.message); });
    return () => controller.abort();
  }, [id, revision]);
  useEffect(() => {
    if (id === undefined) return;
    const controller = new AbortController(); setLoading(true); setRules([]); setRuleError("");
    listInteractions({ kind, search: "", severity: "", interactionType: "" }, skip, controller.signal, id).then(page => {
      if (!controller.signal.aborted) { setRules(page.items); setTotal(page.total); }
    }).catch(reason => { if (!controller.signal.aborted) setRuleError(reason.message); }).finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [id, kind, skip, revision]);
  return <Modal isOpen={medication !== null} onClose={onClose} title="Chi tiết thuốc" size="lg" footer={detail ? <button type="button" onClick={() => onEdit(detail)}>Sửa thuốc</button> : undefined}>
    {error ? <p role="alert">{error} <button type="button" onClick={() => setRevision(value => value + 1)}>Thử lại</button></p> : !detail ? <p role="status">Đang tải chi tiết…</p> : <dl className="live-details">
      <dt>ID</dt><dd>{detail.id}</dd><dt>Tên</dt><dd>{detail.name}</dd><dt>Hoạt chất</dt><dd>{detail.raw_active_ingredient ?? "—"}</dd><dt>Hàm lượng</dt><dd>{detail.strength_text ?? "—"}</dd><dt>Dạng bào chế</dt><dd>{detail.dosage_form ?? "—"}</dd><dt>Nhà sản xuất</dt><dd>{detail.manufacturer_name ?? "—"}</dd><dt>Quốc gia</dt><dd>{detail.manufacturer_country ?? "—"}</dd><dt>Đóng gói</dt><dd>{detail.packaging_spec ?? "—"}</dd><dt>Nguồn</dt><dd>{detail.source ?? "—"}</dd><dt>Mã nguồn</dt><dd>{detail.source_ref ?? "—"}</dd>
    </dl>}
    <h3>Quy tắc tương tác liên quan</h3><select aria-label="Loại tương tác" value={kind} onChange={event => { setKind(event.target.value as RuleKind); setSkip(0); }}><option value="drug_drug">Thuốc – thuốc</option><option value="drug_food">Thuốc – thực phẩm</option></select>
    {loading ? <p role="status">Đang tải tương tác…</p> : ruleError ? <p role="alert">{ruleError} <button type="button" onClick={() => setRevision(value => value + 1)}>Thử lại</button></p> : <>
      {rules.length === 0 ? <p>Chưa có quy tắc liên quan trong danh mục. Đây không phải kết luận an toàn khi phối hợp thuốc.</p> : <ul>{rules.map(rule => <li key={ruleKey(rule)}>{ruleNames(rule).join(" ↔ ")} — Mức {rule.severity_level}: {rule.kind === "drug_drug" ? rule.description : rule.reason}</li>)}</ul>}
      <Pagination offset={skip} total={total} onChange={setSkip} />
    </>}
  </Modal>;
}
