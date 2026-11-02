"use client";

import { useRef, useState } from "react";
import InteractionHeader from "../../../components/interactions/InteractionHeader";
import InteractionFilters from "../../../components/interactions/InteractionFilters";
import InteractionStatsGrid from "../../../components/interactions/InteractionStatsGrid";
import InteractionTable from "../../../components/interactions/InteractionTable";
import InteractionDrawer from "../../../components/interactions/InteractionDrawer";
import InteractionGuidelineCard from "../../../components/interactions/InteractionGuidelineCard";
import Pagination from "../../../components/ui/Pagination";
import { useInteractions } from "../../../hooks/useInteractions";
import { getInteraction } from "../../../lib/api/interactions";
import type { DrugInput, FoodInput, Interaction } from "../../../lib/types/interaction";

export default function InteractionsPage() {
  const data = useInteractions();
  const [open, setOpen] = useState(false); const [editing, setEditing] = useState<Interaction | null>(null);
  const [error, setError] = useState(""); const [opening, setOpening] = useState(false); const sequence = useRef(0);
  const edit = async (rule: Interaction) => {
    const current = ++sequence.current; setError(""); setOpening(true);
    try { const detail = await getInteraction(rule); if (sequence.current === current) { setEditing(detail); setOpen(true); } }
    catch (reason) { if (sequence.current === current) setError(reason instanceof Error ? reason.message : "Không tải được quy tắc."); }
    finally { if (sequence.current === current) setOpening(false); }
  };
  const save = async (input: DrugInput | FoodInput) => { await data.save(input, editing ?? undefined); setOpen(false); setEditing(null); };
  const reloadEditor = async () => { if (editing) setEditing(await getInteraction(editing)); };
  const exportPage = () => {
    const url = URL.createObjectURL(new Blob([JSON.stringify(data.items, null, 2)], { type: "application/json" }));
    const anchor = document.createElement("a"); anchor.href = url; anchor.download = "drugtime-interactions-page.json"; anchor.click(); URL.revokeObjectURL(url);
  };
  return <section className="interactions-page">
    <InteractionHeader onOpenCreateModal={() => { setEditing(null); setOpen(true); }} onExportData={exportPage} disabled={data.loading || data.pending || Boolean(data.error) || opening} />
    <InteractionFilters filters={data.filters} onChange={data.setFilters} />
    <InteractionStatsGrid total={data.loading || data.error ? null : data.total} />
    {data.notice && <p role="status">{data.notice}</p>}{error && <p role="alert">{error}</p>}
    <button type="button" onClick={data.reload} disabled={data.loading || data.pending}>Tải lại danh sách</button>
    {data.loading ? <p role="status">Đang tải tương tác…</p> : data.error ? <div role="alert" className="live-error">{data.error} {data.notice && "Thao tác trước đã được xác nhận; danh sách chưa tải lại được."}</div> : <>
      {data.items.length ? <InteractionTable items={data.items} disabled={data.pending || opening} onSelect={edit} onDelete={data.softDelete} /> : <p>Không có quy tắc khớp bộ lọc.</p>}
      <Pagination offset={data.skip} total={data.total} disabled={data.pending} onChange={data.setSkip} />
    </>}
    <InteractionGuidelineCard />
    <InteractionDrawer isOpen={open} interaction={editing} kind={editing?.kind ?? data.filters.kind} onClose={() => { if (!data.pending) setOpen(false); }} onSave={save} onReload={reloadEditor} />
  </section>;
}
