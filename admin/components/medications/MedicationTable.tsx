"use client";

import { useRef, useState } from "react";
import type { Medication } from "../../lib/types/medication";
import { Modal } from "../ui/Modal";

type Props = { medications: Medication[]; disabled?: boolean; onEdit: (item: Medication) => void; onViewDetail: (item: Medication) => void; onDelete: (item: Medication) => Promise<void> };
export default function MedicationTable({ medications, disabled, onEdit, onViewDetail, onDelete }: Props) {
  const [target, setTarget] = useState<Medication | null>(null);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const busy = useRef(false);
  const close = () => { if (!busy.current) { setTarget(null); setError(""); } };
  const remove = async () => {
    if (!target || busy.current) return;
    busy.current = true; setSaving(true); setError("");
    try { await onDelete(target); setTarget(null); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Không thể xóa thuốc."); }
    finally { busy.current = false; setSaving(false); }
  };
  return <><div className="live-table-wrap"><table className="live-table"><caption>Danh mục thuốc</caption><thead><tr><th>ID</th><th>Tên thuốc</th><th>Hoạt chất</th><th>Hàm lượng</th><th>Nguồn</th><th>Thao tác</th></tr></thead><tbody>
    {medications.map(item => <tr key={item.id}><td>{item.id}</td><td>{item.name}</td><td>{item.raw_active_ingredient ?? "—"}</td><td>{item.strength_text ?? "—"}</td><td>{item.source ?? "—"}</td><td><div className="live-actions">
      <button type="button" onClick={() => onViewDetail(item)} disabled={disabled}>Chi tiết</button><button type="button" onClick={() => onEdit(item)} disabled={disabled}>Sửa</button><button type="button" onClick={() => { setTarget(item); setError(""); }} disabled={disabled}>Xóa</button>
    </div></td></tr>)}
  </tbody></table></div><Modal isOpen={target !== null} onClose={close} title="Xác nhận xóa mềm" footer={<><button type="button" onClick={close} disabled={saving}>Hủy</button><button type="button" onClick={remove} disabled={saving}>{saving ? "Đang xóa…" : "Xóa thuốc"}</button></>}>
    <p>Xóa thuốc “{target?.name}” khỏi danh mục đang sử dụng?</p>{error && <p role="alert" className="live-error">{error}</p>}
  </Modal></>;
}
