"use client";

import React, { useState } from "react";
import InteractionHeader from "../../../components/interactions/InteractionHeader";
import InteractionStatsGrid from "../../../components/interactions/InteractionStatsGrid";
import InteractionFilters from "../../../components/interactions/InteractionFilters";
import InteractionTable from "../../../components/interactions/InteractionTable";
import InteractionDrawer from "../../../components/interactions/InteractionDrawer";
import InteractionGuidelineCard from "../../../components/interactions/InteractionGuidelineCard";
import { useInteractions } from "../../../hooks/useInteractions";
import { Interaction } from "../../../lib/types/interaction";

export default function InteractionsPage() {
  const {
    interactions,
    filters,
    setFilters,
    resetFilters,
    stats,
    addInteraction,
    updateInteraction,
    softDelete,
    exportData,
  } = useInteractions();

  // Separate Editor state (Modal opens independently without squishing the table)
  const [selectedInteraction, setSelectedInteraction] = useState<Interaction | null>(null);
  const [isEditorOpen, setIsEditorOpen] = useState(false);

  const handleOpenCreate = () => {
    setSelectedInteraction(null);
    setIsEditorOpen(true);
  };

  const handleSelectInteraction = (item: Interaction) => {
    setSelectedInteraction(item);
    setIsEditorOpen(true);
  };

  const handleCloseEditor = () => {
    setIsEditorOpen(false);
    setSelectedInteraction(null);
  };

  const handleSaveEditor = (data: Partial<Interaction>) => {
    if (data.id) {
      updateInteraction(data);
    } else {
      addInteraction(data);
    }
    setIsEditorOpen(false);
    setSelectedInteraction(null);
  };

  const handleDelete = (item: Interaction) => {
    softDelete(item);
    if (selectedInteraction?.id === item.id) {
      setIsEditorOpen(false);
      setSelectedInteraction(null);
    }
  };

  return (
    <section className="interactions-page" aria-label="Trang quản trị quy tắc tương tác thuốc">
      {/* 1. Header with Breadcrumbs, Title & Top Actions */}
      <InteractionHeader
        onOpenCreateModal={handleOpenCreate}
        onExportData={exportData}
      />

      {/* 2. Key Metrics Bar (4 KPI Cards) */}
      <InteractionStatsGrid stats={stats} />

      {/* 3. Full-Width Main List Container (No side-by-side crushing) */}
      <div className="interactions-main-container">
        <InteractionFilters
          filters={filters}
          onFilterChange={setFilters}
          onReset={resetFilters}
          totalFiltered={interactions.length}
        />

        <InteractionTable
          interactions={interactions}
          selectedId={selectedInteraction?.id}
          onSelect={handleSelectInteraction}
          onDelete={handleDelete}
          onResetFilters={resetFilters}
        />

        <InteractionGuidelineCard />
      </div>

      {/* 4. Dedicated Editor Modal (Spacious, Accessible, Independent) */}
      <InteractionDrawer
        isOpen={isEditorOpen}
        interaction={selectedInteraction}
        onClose={handleCloseEditor}
        onSave={handleSaveEditor}
        onDelete={handleDelete}
      />
    </section>
  );
}
