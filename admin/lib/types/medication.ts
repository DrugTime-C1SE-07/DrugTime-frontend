export type MedicationQuality = "verified" | "pending" | "missing";

export interface Medication {
  id: string;
  name: string;
  form?: string;
  formWarning?: string;
  noteBadge?: string;
  ingredient: string;
  strength: string;
  regNo: string;
  isRegNoMissing?: boolean;
  source: string;
  sourceTag: string;
  group: string;
  quality: MedicationQuality;
  manufacturer?: string;
  packaging?: string;
  country?: string;
  description?: string;
  updatedAt?: string;
  isDeleted?: boolean;
}

export type MedicationFilterState = {
  search: string;
  source: string;
  quality: string;
  group: string;
};
