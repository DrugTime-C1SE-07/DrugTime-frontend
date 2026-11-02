"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { Medication, MedicationInput } from "../lib/types/medication";
import { createMedication, deleteMedication, listMedications, patchMedication } from "../lib/api/medications";

export function useMedications() {
  const [medications, setMedications] = useState<Medication[]>([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState("");
  const [skip, setSkip] = useState(0);
  const [revision, setRevision] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [pending, setPending] = useState(false);
  const busy = useRef(false);
  const reload = useCallback(() => setRevision(value => value + 1), []);
  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError("");
    listMedications(search, skip, controller.signal).then(page => {
      if (controller.signal.aborted) return;
      if (skip > 0 && skip >= page.total) { setSkip(Math.max(0, Math.ceil(page.total / 20 - 1) * 20)); return; }
      setMedications(page.items);
      setTotal(page.total);
    }).catch(reason => {
      if (!controller.signal.aborted) setError(reason instanceof Error ? reason.message : "Không tải được danh mục thuốc.");
    }).finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [search, skip, revision]);

  const save = async (input: MedicationInput, original?: Medication) => {
    if (busy.current) throw new Error("Một thao tác đang được xử lý.");
    busy.current = true;
    setPending(true);
    setNotice("");
    try {
      if (original) await patchMedication(original, input);
      else await createMedication(input);
      setNotice("Đã lưu thuốc trên máy chủ. Đang tải lại danh sách.");
      reload();
    } finally { busy.current = false; setPending(false); }
  };
  const softDelete = async (medication: Medication) => {
    if (busy.current) throw new Error("Một thao tác đang được xử lý.");
    busy.current = true;
    setPending(true);
    setNotice("");
    try {
      await deleteMedication(medication.id);
      setNotice("Đã xóa mềm thuốc trên máy chủ.");
      reload();
    } finally { busy.current = false; setPending(false); }
  };
  return {
    medications, total, search, skip, loading, error, notice, pending, reload, save, softDelete,
    setSkip,
    setSearch: (value: string) => { setSkip(0); setSearch(value); setNotice(""); },
  };
}
