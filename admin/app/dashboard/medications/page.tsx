"use client";

import { useRef, useState } from "react";
import MedicationHeader from "../../../components/medications/MedicationHeader";
import MedicationStatsGrid from "../../../components/medications/MedicationStatsGrid";
import MedicationFilters from "../../../components/medications/MedicationFilters";
import MedicationTable from "../../../components/medications/MedicationTable";
import MedicationForm from "../../../components/medications/MedicationForm";
import MedicationDetailModal from "../../../components/medications/MedicationDetailModal";
import MedicationSyncBanner from "../../../components/medications/MedicationSyncBanner";
import Pagination from "../../../components/ui/Pagination";
import { useMedications } from "../../../hooks/useMedications";
import { getMedication } from "../../../lib/api/medications";
import type { Medication, MedicationInput } from "../../../lib/types/medication";

export default function MedicationsPage() {
  const data = useMedications();
  const [isOpen, setIsOpen] = useState(false);
  const [editing, setEditing] = useState<Medication | null>(null);
  const [selected, setSelected] = useState<Medication | null>(null);
  const [error, setError] = useState("");
  const [opening, setOpening] = useState(false);
  const request = useRef(0);
  const edit = async (item: Medication) => {
    const sequence = ++request.current; setError(""); setOpening(true);
    try { const current = await getMedication(item.id); if (request.current === sequence) { setSelected(null); setEditing(current); setIsOpen(true); } }
    catch (reason) { if (request.current === sequence) setError(reason instanceof Error ? reason.message : "Không tải được thuốc."); }
    finally { if (request.current === sequence) setOpening(false); }
  };
  const save = async (input: MedicationInput) => { await data.save(input, editing ?? undefined); setIsOpen(false); setEditing(null); };
  const exportPage = () => {
    const url = URL.createObjectURL(new Blob([JSON.stringify(data.medications, null, 2)], { type: "application/json" }));
    const anchor = document.createElement("a"); anchor.href = url; anchor.download = "drugtime-medications-page.json"; anchor.click(); URL.revokeObjectURL(url);
  };
  return <section className="medications-page">
    <MedicationHeader onOpenCreateModal={() => { setEditing(null); setIsOpen(true); }} onExportData={exportPage} disabled={data.pending || data.loading || Boolean(data.error) || opening} />
    <MedicationFilters search={data.search} onChange={data.setSearch} />
    <MedicationStatsGrid total={data.loading || data.error ? null : data.total} />
    {data.notice && <p role="status">{data.notice}</p>}{error && <p role="alert">{error}</p>}
    {data.loading ? <p role="status">Đang tải thuốc…</p> : data.error ? <div role="alert" className="live-error">{data.error} {data.notice && "Thao tác trước đã được xác nhận; lỗi này xảy ra khi tải lại danh sách."} <button type="button" onClick={data.reload}>Thử tải lại</button></div> : <>
      {data.medications.length ? <MedicationTable medications={data.medications} onEdit={edit} onViewDetail={setSelected} onDelete={data.softDelete} disabled={data.pending || opening} /> : <p>Không có thuốc khớp tìm kiếm.</p>}
      <Pagination offset={data.skip} total={data.total} onChange={data.setSkip} disabled={data.pending} />
    </>}
    <MedicationSyncBanner />
    <MedicationForm isOpen={isOpen} initialData={editing} onClose={() => { if (!data.pending) setIsOpen(false); }} onSubmit={save} />
    <MedicationDetailModal key={selected?.id ?? "closed"} medication={selected} onClose={() => setSelected(null)} onEdit={edit} />
  </section>;
}
