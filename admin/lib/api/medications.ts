import type { Medication, MedicationInput, MedicationPage } from "../types/medication";
import { browserRequest, jsonOptions } from "./browser-client";

const endpoint = "/api/session/medications";
const fields: (keyof MedicationInput)[] = ["name", "raw_active_ingredient", "strength_text", "dosage_form", "manufacturer_name", "manufacturer_country", "packaging_spec", "source", "source_ref"];

export function medicationPayload(input: MedicationInput, original?: Medication): Partial<MedicationInput> {
  const output: Record<string, unknown> = {};
  for (const field of fields) {
    if (!original || original[field] !== input[field]) output[field] = input[field];
  }
  if ("source" in output || "source_ref" in output) {
    output.source = input.source;
    output.source_ref = input.source_ref;
  }
  return output;
}

export function medicationQuery(search: string, skip: number, limit = 20): string {
  const query = new URLSearchParams({ skip: String(skip), limit: String(limit) });
  if (search.trim()) query.set("q", search.trim());
  return query.toString();
}

export const listMedications = (search: string, skip: number, signal?: AbortSignal) =>
  browserRequest<MedicationPage>(`${endpoint}?${medicationQuery(search, skip)}`, { signal });
export const getMedication = (id: number, signal?: AbortSignal) => browserRequest<Medication>(`${endpoint}/${id}`, { signal });
export const createMedication = (input: MedicationInput) => browserRequest<Medication>(endpoint, jsonOptions("POST", medicationPayload(input)));
export const patchMedication = (original: Medication, input: MedicationInput) => browserRequest<Medication>(`${endpoint}/${original.id}`, jsonOptions("PATCH", medicationPayload(input, original)));
export const deleteMedication = (id: number) => browserRequest<void>(`${endpoint}/${id}`, { method: "DELETE" });
