"use client";

import { useState, useMemo, useCallback, useEffect } from "react";
import { Medication, MedicationFilterState } from "../lib/types/medication";
import { initialMedications } from "../lib/data/mock-medications";
import { useToast } from "../components/ui/Toast";

export function useMedications() {
  const { showToast } = useToast();
  const [medications, setMedications] = useState<Medication[]>(initialMedications);
  const [filters, setFilters] = useState<MedicationFilterState>({
    search: "",
    source: "all",
    quality: "all",
    group: "all",
  });

  // Automatically sync search keyword from URL query param if present
  useEffect(() => {
    if (typeof window !== "undefined") {
      const params = new URLSearchParams(window.location.search);
      const query = params.get("search");
      if (query) {
        setFilters((prev) => ({ ...prev, search: query }));
      }
    }
  }, []);

  // Extract unique sources and groups
  const sources = useMemo(() => {
    const set = new Set<string>();
    medications.forEach((m) => {
      if (!m.isDeleted && m.source) set.add(m.source);
    });
    return Array.from(set);
  }, [medications]);

  const groups = useMemo(() => {
    const set = new Set<string>();
    medications.forEach((m) => {
      if (!m.isDeleted && m.group) set.add(m.group);
    });
    return Array.from(set);
  }, [medications]);

  // Filtered medications
  const filteredMedications = useMemo(() => {
    return medications.filter((med) => {
      if (med.isDeleted) return false;

      // Search keyword filter (case-insensitive)
      if (filters.search) {
        const query = filters.search.toLowerCase().trim();
        const matchName = med.name.toLowerCase().includes(query);
        const matchIngredient = med.ingredient.toLowerCase().includes(query);
        const matchRegNo = med.regNo.toLowerCase().includes(query);
        const matchGroup = med.group.toLowerCase().includes(query);
        if (!matchName && !matchIngredient && !matchRegNo && !matchGroup) {
          return false;
        }
      }

      // Source filter
      if (filters.source !== "all" && med.source !== filters.source) {
        return false;
      }

      // Quality filter
      if (filters.quality !== "all" && med.quality !== filters.quality) {
        return false;
      }

      // Group filter
      if (filters.group !== "all" && med.group !== filters.group) {
        return false;
      }

      return true;
    });
  }, [medications, filters]);

  // Dynamic statistics
  const stats = useMemo(() => {
    const activeMeds = medications.filter((m) => !m.isDeleted);
    const total = activeMeds.length;
    const verified = activeMeds.filter((m) => m.quality === "verified").length;
    const pending = activeMeds.filter((m) => m.quality === "pending").length;
    const missing = activeMeds.filter((m) => m.quality === "missing").length;

    return { total, verified, pending, missing };
  }, [medications]);

  const resetFilters = useCallback(() => {
    setFilters({
      search: "",
      source: "all",
      quality: "all",
      group: "all",
    });
  }, []);

  const addMedication = useCallback(
    (newMed: Partial<Medication>) => {
      const id = `med-${Date.now()}`;
      const medication: Medication = {
        id,
        name: newMed.name || "Thuốc mới",
        ingredient: newMed.ingredient || "",
        strength: newMed.strength || "",
        regNo: newMed.regNo || "Thiếu SĐK",
        source: newMed.source || "Thủ công",
        sourceTag: newMed.sourceTag || "Manual",
        group: newMed.group || "Khác",
        quality: newMed.quality || "verified",
        form: newMed.form,
        formWarning: newMed.formWarning,
        noteBadge: newMed.noteBadge,
        isRegNoMissing: newMed.isRegNoMissing,
        manufacturer: newMed.manufacturer,
        packaging: newMed.packaging,
        country: newMed.country,
        description: newMed.description,
        updatedAt: new Date().toISOString().split("T")[0],
      };

      setMedications((prev) => [medication, ...prev]);

      showToast({
        type: "success",
        title: "Thêm thuốc thành công",
        message: `Bản ghi "${medication.name}" đã được bổ sung vào danh mục CSDL.`,
      });
    },
    [showToast]
  );

  const updateMedication = useCallback(
    (updatedMed: Partial<Medication>) => {
      if (!updatedMed.id) return;

      setMedications((prev) =>
        prev.map((med) => {
          if (med.id === updatedMed.id) {
            return {
              ...med,
              ...updatedMed,
              updatedAt: new Date().toISOString().split("T")[0],
            } as Medication;
          }
          return med;
        })
      );

      showToast({
        type: "success",
        title: "Cập nhật thành công",
        message: `Thông tin biệt dược "${updatedMed.name}" đã được cập nhật.`,
      });
    },
    [showToast]
  );

  const quickApprove = useCallback(
    (med: Medication) => {
      setMedications((prev) =>
        prev.map((item) =>
          item.id === med.id
            ? {
                ...item,
                quality: "verified" as const,
                formWarning: undefined,
                updatedAt: new Date().toISOString().split("T")[0],
              }
            : item
        )
      );

      showToast({
        type: "success",
        title: "Đã duyệt thuốc thành công",
        message: `Biệt dược "${med.name}" đã được chuyển sang trạng thái "Đã xác thực".`,
      });
    },
    [showToast]
  );

  const undoDelete = useCallback(
    (id: string, name: string) => {
      setMedications((prev) =>
        prev.map((item) => (item.id === id ? { ...item, isDeleted: false } : item))
      );
      showToast({
        type: "info",
        title: "Đã hoàn tác xóa",
        message: `Đã khôi phục biệt dược "${name}" vào danh mục.`,
      });
    },
    [showToast]
  );

  const softDelete = useCallback(
    (med: Medication) => {
      setMedications((prev) =>
        prev.map((item) => (item.id === med.id ? { ...item, isDeleted: true } : item))
      );

      showToast({
        type: "warning",
        title: "Đã xóa thuốc",
        message: `Bản ghi "${med.name}" đã được đưa vào thùng rác tạm thời.`,
        duration: 6000,
        action: {
          label: "Hoàn tác",
          onClick: () => undoDelete(med.id, med.name),
        },
      });
    },
    [showToast, undoDelete]
  );

  const exportData = useCallback(() => {
    const activeMeds = medications.filter((m) => !m.isDeleted);
    const dataStr =
      "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(activeMeds, null, 2));
    const downloadAnchor = document.createElement("a");
    downloadAnchor.setAttribute("href", dataStr);
    downloadAnchor.setAttribute(
      "download",
      `drugtime-medications-${new Date().toISOString().split("T")[0]}.json`
    );
    document.body.appendChild(downloadAnchor);
    downloadAnchor.click();
    downloadAnchor.remove();

    showToast({
      type: "info",
      title: "Xuất dữ liệu thành công",
      message: `Đã xuất ${activeMeds.length} bản ghi thuốc dưới định dạng JSON chuẩn.`,
    });
  }, [medications, showToast]);

  return {
    medications: filteredMedications,
    allMedications: medications,
    filters,
    setFilters,
    resetFilters,
    sources,
    groups,
    stats,
    addMedication,
    updateMedication,
    quickApprove,
    softDelete,
    exportData,
  };
}
