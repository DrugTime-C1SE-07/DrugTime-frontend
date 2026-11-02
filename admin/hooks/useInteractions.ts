"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { DrugInput, FoodInput, Interaction, InteractionFilterState } from "../lib/types/interaction";
import { deleteInteraction, listInteractions, saveInteraction } from "../lib/api/interactions";

export function useInteractions() {
  const [filters, setFilters] = useState<InteractionFilterState>({ kind: "drug_drug", search: "", severity: "", interactionType: "" });
  const [skip, setSkip] = useState(0);
  const [items, setItems] = useState<Interaction[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [revision, setRevision] = useState(0);
  const busy = useRef(false);
  const reload = useCallback(() => setRevision(value => value + 1), []);
  useEffect(() => {
    const controller = new AbortController(); setLoading(true); setError("");
    listInteractions(filters, skip, controller.signal).then(page => {
      if (controller.signal.aborted) return;
      if (skip > 0 && skip >= page.total) { setSkip(Math.max(0, Math.ceil(page.total / 20 - 1) * 20)); return; }
      setItems(page.items); setTotal(page.total);
    }).catch(reason => { if (!controller.signal.aborted) setError(reason instanceof Error ? reason.message : "Không tải được tương tác."); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [filters, skip, revision]);
  const save = async (input: DrugInput | FoodInput, original?: Interaction) => {
    if (busy.current) throw new Error("Một thao tác đang được xử lý.");
    busy.current = true; setPending(true); setNotice("");
    try { await saveInteraction(original?.kind ?? filters.kind, input, original); setNotice("Đã xác nhận dữ liệu quy tắc trên máy chủ. Đang tải lại danh sách."); reload(); }
    finally { busy.current = false; setPending(false); }
  };
  const softDelete = async (rule: Interaction) => {
    if (busy.current) throw new Error("Một thao tác đang được xử lý.");
    busy.current = true; setPending(true); setNotice("");
    try { await deleteInteraction(rule); setNotice("Đã xóa mềm quy tắc trên máy chủ."); reload(); }
    finally { busy.current = false; setPending(false); }
  };
  return { items, total, filters, skip, setSkip, loading, pending, error, notice, reload, save, softDelete,
    setFilters: (value: InteractionFilterState) => { setFilters(value); setSkip(0); setNotice(""); },
  };
}
