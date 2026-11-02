"use client";

import { useRef, useState } from "react";
import type { Interaction } from "../../lib/types/interaction";
import { ruleKey, ruleNames } from "../../lib/api/interactions";
import { Modal } from "../ui/Modal";

export default function InteractionTable({ items, disabled, onSelect, onDelete }: { items: Interaction[]; disabled?: boolean; onSelect: (rule: Interaction) => void; onDelete: (rule: Interaction) => Promise<void> }) {
  const [target, setTarget] = useState<Interaction | null>(null);
  const [error, setError] = useState(""); const [saving, setSaving] = useState(false); const busy = useRef(false);
  const close = () => { if (!busy.current) { setTarget(null); setError(""); } };
  const remove = async () => {
    if (!target || busy.current) return;
    busy.current = true; setSaving(true); setError("");
    try { await onDelete(target); setTarget(null); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Không thể xóa quy tắc."); }
    finally { busy.current = false; setSaving(false); }
  };
  return <><div className="live-table-wrap"><table className="live-table"><caption>Quy tắc tương tác</caption><thead><tr><th>ID</th><th>Hoạt chất / đối tượng</th><th>Mức độ</th><th>Nội dung</th><th>Phiên bản</th><th>Thao tác</th></tr></thead><tbody>
    {items.map(rule => <tr key={ruleKey(rule)}><td>{rule.id}</td><td>{ruleNames(rule).join(" ↔ ")}</td><td>{rule.severity_level}</td><td>{rule.kind === "drug_drug" ? rule.description : rule.reason}</td><td>{rule.version}</td><td><div className="live-actions"><button type="button" onClick={() => onSelect(rule)} disabled={disabled}>Chi tiết / sửa</button><button type="button" onClick={() => { setTarget(rule); setError(""); }} disabled={disabled}>Xóa</button></div></td></tr>)}
  </tbody></table></div><Modal isOpen={target !== null} onClose={close} title="Xóa mềm quy tắc" footer={<><button type="button" onClick={close} disabled={saving}>Hủy</button><button type="button" onClick={remove} disabled={saving}>{saving ? "Đang xóa…" : "Xác nhận xóa"}</button></>}>
    <p>{target && ruleNames(target).join(" ↔ ")} — phiên bản {target?.version}.</p>{error && <p role="alert" className="live-error">{error} Đóng cửa sổ và tải lại danh sách nếu phiên bản đã thay đổi.</p>}
  </Modal></>;
}
