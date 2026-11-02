export type RuleKind = "drug_drug" | "drug_food";
export type InteractionType = "chong_chi_dinh" | "phu_thuoc_lieu";
export type HandlingType = "tranh_phoi_hop" | "can_theo_doi" | "cach_gio" | "giam_lieu";
export type Ingredient = { id: number; standard_name: string; atc_code?: string | null };
export type Threshold = {
  ingredient_ref: "A" | "B";
  min_dose?: number | null;
  max_dose?: number | null;
  dose_unit: string;
  severity_level: number;
  warning_text: string;
};
export type DrugInput = {
  ingredient_a_id: number;
  ingredient_b_id?: number;
  ingredient_b_external_name?: string;
  interaction_type: InteractionType;
  severity_level: number;
  handling_type: HandlingType;
  min_interval_hours: number | null;
  description: string;
  source: string;
  dose_thresholds: Threshold[];
};
export type FoodInput = {
  ingredient_id: number;
  food_to_avoid: string;
  severity_level: number;
  reason: string;
  source: string;
};
type Metadata = {
  id: number;
  version: number;
  version_id: number;
  state: "current" | "superseded" | "deleted";
  source: string;
  verification_status: "da_xac_minh";
  updated_at: string;
  updated_by: { id: string; email: string | null } | null;
};
export type DrugInteraction = Metadata & Omit<DrugInput, "ingredient_a_id" | "ingredient_b_id" | "ingredient_b_external_name" | "dose_thresholds"> & {
  ingredient_a: Ingredient;
  ingredient_b: Ingredient | null;
  ingredient_b_external_name: string | null;
  dose_thresholds: (Threshold & { id: number })[];
};
export type FoodInteraction = Metadata & Omit<FoodInput, "ingredient_id"> & { ingredient: Ingredient };
export type Interaction = (DrugInteraction & { kind: "drug_drug" }) | (FoodInteraction & { kind: "drug_food" });
export type InteractionFilterState = { search: string; kind: RuleKind; severity: string; interactionType: string };
export type Page<T> = { items: T[]; total: number };
