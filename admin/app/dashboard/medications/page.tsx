"use client";

import React, { useState } from "react";
import MedicationHeader from "../../../components/medications/MedicationHeader";
import MedicationStatsGrid from "../../../components/medications/MedicationStatsGrid";
import MedicationFilters from "../../../components/medications/MedicationFilters";
import MedicationTable from "../../../components/medications/MedicationTable";
import MedicationForm from "../../../components/medications/MedicationForm";
import MedicationDetailModal from "../../../components/medications/MedicationDetailModal";
import MedicationSyncBanner from "../../../components/medications/MedicationSyncBanner";
import { useMedications } from "../../../hooks/useMedications";
import { Medication } from "../../../lib/types/medication";

export default function MedicationsPage() {
  const {
    medications,
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
  } = useMedications();

  // Modal states
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [editingMedication, setEditingMedication] = useState<Medication | null>(null);

  const [isDetailOpen, setIsDetailOpen] = useState(false);
  const [selectedMedication, setSelectedMedication] = useState<Medication | null>(null);

  const handleOpenCreateModal = () => {
    setEditingMedication(null);
    setIsFormOpen(true);
  };

  const handleOpenEditModal = (medication: Medication) => {
    setEditingMedication(medication);
    setIsFormOpen(true);
  };

  const handleOpenDetailModal = (medication: Medication) => {
    setSelectedMedication(medication);
    setIsDetailOpen(true);
  };

  const handleFormSubmit = (data: Partial<Medication>) => {
    if (editingMedication) {
      updateMedication(data);
    } else {
      addMedication(data);
    }
    setIsFormOpen(false);
    setEditingMedication(null);
  };

  return (
    <section className="medications-page">
      <MedicationHeader
        onOpenCreateModal={handleOpenCreateModal}
        onExportData={exportData}
      />

      <MedicationStatsGrid stats={stats} />

      <MedicationFilters
        filters={filters}
        onFilterChange={setFilters}
        onReset={resetFilters}
        sources={sources}
        groups={groups}
        totalFiltered={medications.length}
      />

      <MedicationTable
        medications={medications}
        onQuickApprove={quickApprove}
        onEdit={handleOpenEditModal}
        onViewDetail={handleOpenDetailModal}
        onDelete={softDelete}
        onResetFilters={resetFilters}
      />

      <MedicationSyncBanner />

      {/* Form Modal (Add / Edit) */}
      <MedicationForm
        isOpen={isFormOpen}
        onClose={() => {
          setIsFormOpen(false);
          setEditingMedication(null);
        }}
        onSubmit={handleFormSubmit}
        initialData={editingMedication}
      />

      {/* View Detail Modal */}
      <MedicationDetailModal
        isOpen={isDetailOpen}
        onClose={() => {
          setIsDetailOpen(false);
          setSelectedMedication(null);
        }}
        medication={selectedMedication}
        onEdit={handleOpenEditModal}
        onApprove={quickApprove}
      />
    </section>
  );
}
