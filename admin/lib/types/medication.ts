export type MedicationSource = "dav_drugbank" | "qd_5948" | "duoc_thu_qg";

export interface MedicationInput {
  name: string;
  raw_active_ingredient: string | null;
  strength_text: string | null;
  dosage_form: string | null;
  manufacturer_name: string | null;
  manufacturer_country: string | null;
  packaging_spec: string | null;
  source: MedicationSource | null;
  source_ref: string | null;
}

export interface Medication extends MedicationInput {
  id: number;
  deleted_at: string | null;
}

export type MedicationPage = { items: Medication[]; total: number };
export type MedicationFilterState = { search: string };
