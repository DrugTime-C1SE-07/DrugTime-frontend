"use client";

import { useState, useMemo, useCallback, useEffect } from "react";
import { Interaction, InteractionFilterState } from "../lib/types/interaction";
import { initialInteractions } from "../lib/data/mock-interactions";
import { useToast } from "../components/ui/Toast";

export function useInteractions() {
  const { showToast } = useToast();
  const [interactions, setInteractions] = useState<Interaction[]>(initialInteractions);
  const [filters, setFilters] = useState<InteractionFilterState>({
    search: "",
    severity: "all",
    targetType: "all",
    mechanismType: "all",
    status: "all",
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

  // Filtered interactions
  const filteredInteractions = useMemo(() => {
    return interactions.filter((item) => {
      if (item.isDeleted) return false;

      // Search keyword filter (case-insensitive)
      if (filters.search) {
        const query = filters.search.toLowerCase().trim();
        const matchDrugA = item.drugA.toLowerCase().includes(query);
        const matchDrugB = item.drugB.toLowerCase().includes(query);
        const matchAtcA = item.atcCodeA?.toLowerCase().includes(query);
        const matchAtcB = item.atcCodeB?.toLowerCase().includes(query);
        const matchRule = item.ruleCode?.toLowerCase().includes(query);
        const matchMech = item.mechanism.toLowerCase().includes(query);
        const matchClinical = item.clinicalEffect.toLowerCase().includes(query);
        const matchManagement = item.management.toLowerCase().includes(query);
        if (
          !matchDrugA &&
          !matchDrugB &&
          !matchAtcA &&
          !matchAtcB &&
          !matchRule &&
          !matchMech &&
          !matchClinical &&
          !matchManagement
        ) {
          return false;
        }
      }

      // Severity filter
      if (filters.severity !== "all" && item.severity !== filters.severity) {
        return false;
      }

      // Target Type filter (drug_drug or drug_food)
      if (filters.targetType !== "all" && item.targetType !== filters.targetType) {
        return false;
      }

      // Mechanism filter
      if (filters.mechanismType !== "all" && item.mechanismType !== filters.mechanismType) {
        return false;
      }

      // Status filter
      if (filters.status !== "all" && item.status !== filters.status) {
        return false;
      }

      return true;
    });
  }, [interactions, filters]);

  // Dynamic statistics consistently derived from the catalog currently in memory.
  const stats = useMemo(() => {
    const activeItems = interactions.filter((i) => !i.isDeleted);
    const total = activeItems.length;
    const contraindicated = activeItems.filter((i) => i.severity === "contraindicated").length;
    const major = activeItems.filter((i) => i.severity === "major").length;
    const moderate = activeItems.filter((i) => i.severity === "moderate").length;
    const minor = activeItems.filter((i) => i.severity === "minor").length;
    const pendingCount = activeItems.filter((i) => i.status === "pending").length;

    return { total, contraindicated, major, moderate, minor, pendingCount };
  }, [interactions]);

  const resetFilters = useCallback(() => {
    setFilters({
      search: "",
      severity: "all",
      targetType: "all",
      mechanismType: "all",
      status: "all",
    });
  }, []);

  const addInteraction = useCallback(
    (newItem: Partial<Interaction>) => {
      const id = `inter-${Date.now()}`;
      const count = interactions.length + 1;
      const ruleCode = newItem.ruleCode || `RULE-INT-0${430 + count}`;

      const interaction: Interaction = {
        id,
        ruleCode,
        drugA: newItem.drugA || "Thuốc A",
        drugB: newItem.drugB || "Thuốc B",
        drugAClass: newItem.drugAClass,
        drugBClass: newItem.drugBClass,
        atcCodeA: newItem.atcCodeA,
        atcCodeB: newItem.atcCodeB,
        targetType: newItem.targetType || "drug_drug",
        severity: newItem.severity || "contraindicated",
        mechanismType: newItem.mechanismType || "both",
        mechanism: newItem.mechanism || "",
        clinicalEffect: newItem.clinicalEffect || "",
        management: newItem.management || "",
        evidenceLevel: newItem.evidenceLevel || "clinical",
        source: newItem.source || "QĐ 5948/QĐ-BYT & DrugBank",
        originSource: newItem.originSource || "QĐ 5948/QĐ-BYT",
        crossReference: newItem.crossReference || "DrugBank",
        verifiedBy: newItem.verifiedBy,
        status: newItem.status || "verified",
        notes: newItem.notes,
        updatedAt: new Date().toISOString().split("T")[0],
      };

      setInteractions((prev) => [interaction, ...prev]);

      showToast({
        type: "success",
        title: "Lưu quy tắc tương tác thành công",
        message: `Quy tắc ${interaction.ruleCode} (${interaction.drugA} ↔ ${interaction.drugB}) đã được cập nhật vào CSDL.`,
      });
      return interaction;
    },
    [interactions.length, showToast]
  );

  const updateInteraction = useCallback(
    (updatedItem: Partial<Interaction>) => {
      if (!updatedItem.id) return;

      setInteractions((prev) =>
        prev.map((item) => {
          if (item.id === updatedItem.id) {
            return {
              ...item,
              ...updatedItem,
              updatedAt: new Date().toISOString().split("T")[0],
            } as Interaction;
          }
          return item;
        })
      );

      showToast({
        type: "success",
        title: "Cập nhật quy tắc thành công",
        message: `Đã lưu thay đổi cho quy tắc "${updatedItem.drugA} ↔ ${updatedItem.drugB}".`,
      });
    },
    [showToast]
  );

  const quickApprove = useCallback(
    (item: Interaction) => {
      setInteractions((prev) =>
        prev.map((i) =>
          i.id === item.id
            ? {
                ...i,
                status: "verified" as const,
                updatedAt: new Date().toISOString().split("T")[0],
              }
            : i
        )
      );

      showToast({
        type: "success",
        title: "Đã phê duyệt quy tắc",
        message: `Quy tắc tương tác "${item.drugA} ↔ ${item.drugB}" đã được đưa vào hệ thống cảnh báo kê đơn.`,
      });
    },
    [showToast]
  );

  const undoDelete = useCallback(
    (id: string, label: string) => {
      setInteractions((prev) =>
        prev.map((i) => (i.id === id ? { ...i, isDeleted: false } : i))
      );
      showToast({
        type: "info",
        title: "Đã hoàn tác xóa quy tắc",
        message: `Đã khôi phục quy tắc "${label}" vào danh mục.`,
      });
    },
    [showToast]
  );

  const softDelete = useCallback(
    (item: Interaction) => {
      setInteractions((prev) =>
        prev.map((i) => (i.id === item.id ? { ...i, isDeleted: true } : i))
      );

      const label = `${item.drugA} ↔ ${item.drugB}`;
      showToast({
        type: "warning",
        title: "Đã xóa quy tắc tương tác",
        message: `Quy tắc "${label}" đã được đưa vào thùng rác tạm thời.`,
        duration: 6000,
        action: {
          label: "Hoàn tác",
          onClick: () => undoDelete(item.id, label),
        },
      });
    },
    [showToast, undoDelete]
  );

  const exportData = useCallback(() => {
    const activeItems = interactions.filter((i) => !i.isDeleted);
    const dataStr =
      "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(activeItems, null, 2));
    const downloadAnchor = document.createElement("a");
    downloadAnchor.setAttribute("href", dataStr);
    downloadAnchor.setAttribute(
      "download",
      `drugtime-interactions-${new Date().toISOString().split("T")[0]}.json`
    );
    document.body.appendChild(downloadAnchor);
    downloadAnchor.click();
    downloadAnchor.remove();

    showToast({
      type: "info",
      title: "Xuất dữ liệu thành công",
      message: `Đã xuất ${activeItems.length} quy tắc tương tác thuốc dưới định dạng JSON ma trận đối soát chuẩn.`,
    });
  }, [interactions, showToast]);

  return {
    interactions: filteredInteractions,
    allInteractions: interactions,
    filters,
    setFilters,
    resetFilters,
    stats,
    addInteraction,
    updateInteraction,
    quickApprove,
    softDelete,
    exportData,
  };
}
