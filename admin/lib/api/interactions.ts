import type { DrugInput, DrugInteraction, FoodInput, FoodInteraction, Ingredient, Interaction, InteractionFilterState, Page, RuleKind, Threshold } from "../types/interaction";
import { browserRequest, jsonOptions } from "./browser-client";

export const ruleEndpoint = (kind: RuleKind) => `/api/session/${kind === "drug_drug" ? "drug-interactions" : "drug-food-interactions"}`;
export const ruleKey = (rule: Interaction) => `${rule.kind}:${rule.id}`;
export const ruleNames = (rule: Interaction): [string, string] => rule.kind === "drug_drug"
  ? [rule.ingredient_a.standard_name, rule.ingredient_b?.standard_name ?? rule.ingredient_b_external_name ?? "—"]
  : [rule.ingredient.standard_name, rule.food_to_avoid];

export function ruleQuery(filters: InteractionFilterState, skip: number, medicationId?: number): string {
  const q = new URLSearchParams({ skip: String(skip), limit: "20" });
  if (filters.search.trim()) q.set("q", filters.search.trim());
  if (filters.severity) q.set("severity_level", filters.severity);
  if (filters.kind === "drug_drug" && filters.interactionType) q.set("interaction_type", filters.interactionType);
  if (medicationId !== undefined) q.set("medication_id", String(medicationId));
  return q.toString();
}

export function thresholdInput(t: Threshold): Threshold {
  return { ingredient_ref: t.ingredient_ref, min_dose: t.min_dose ?? null, max_dose: t.max_dose ?? null, dose_unit: t.dose_unit, severity_level: t.severity_level, warning_text: t.warning_text };
}

export function rulePayload(kind: RuleKind, input: DrugInput | FoodInput, original?: Interaction): Record<string, unknown> {
  if (kind === "drug_drug") {
    const rule = input as DrugInput;
    const hasId = rule.ingredient_b_id !== undefined;
    const hasName = Boolean(rule.ingredient_b_external_name?.trim());
    if (hasId === hasName) throw new Error("Chọn đúng một hoạt chất B hoặc tên ngoài danh mục.");
    if (hasId && rule.ingredient_a_id === rule.ingredient_b_id) throw new Error("Hai hoạt chất phải khác nhau.");
    if (rule.interaction_type === "chong_chi_dinh" && (rule.severity_level !== 4 || rule.dose_thresholds.length)) throw new Error("Chống chỉ định cần mức độ 4 và không có ngưỡng liều.");
    if (rule.min_interval_hours !== null && rule.handling_type !== "cach_gio") throw new Error("Chỉ nhập khoảng cách giờ khi chọn xử trí cách giờ.");
    if (rule.min_interval_hours !== null && (!Number.isFinite(rule.min_interval_hours) || rule.min_interval_hours <= 0 || rule.min_interval_hours > 168)) throw new Error("Khoảng cách giờ phải lớn hơn 0 và không quá 168.");
    for (const threshold of rule.dose_thresholds) {
      if (threshold.ingredient_ref === "B" && !hasId) throw new Error("Ngưỡng B cần hoạt chất B trong danh mục.");
      if (threshold.min_dose == null && threshold.max_dose == null) throw new Error("Mỗi ngưỡng phải có liều tối thiểu hoặc tối đa.");
      if (threshold.min_dose != null && threshold.max_dose != null && threshold.min_dose > threshold.max_dose) throw new Error("Liều tối thiểu không được lớn hơn tối đa.");
    }
  }
  const output: Record<string, unknown> = {};
  const keys = kind === "drug_drug"
    ? ["ingredient_a_id", "ingredient_b_id", "ingredient_b_external_name", "interaction_type", "severity_level", "handling_type", "min_interval_hours", "description", "source", "dose_thresholds"]
    : ["ingredient_id", "food_to_avoid", "severity_level", "reason", "source"];
  const data = input as unknown as Record<string, unknown>;
  const previous = original as unknown as Record<string, unknown> | undefined;
  for (const key of keys) {
    if (original && key.startsWith("ingredient_")) continue;
    if (data[key] === undefined) continue;
    const value = key === "dose_thresholds" ? (data[key] as Threshold[]).map(thresholdInput) : data[key];
    const old = key === "dose_thresholds" && original?.kind === "drug_drug" ? original.dose_thresholds.map(thresholdInput) : previous?.[key];
    if (!original || JSON.stringify(value) !== JSON.stringify(old)) output[key] = value;
  }
  if (original) output.expected_version = original.version;
  return output;
}

export async function listInteractions(filters: InteractionFilterState, skip: number, signal?: AbortSignal, medicationId?: number): Promise<Page<Interaction>> {
  const result = await browserRequest<Page<DrugInteraction | FoodInteraction>>(`${ruleEndpoint(filters.kind)}?${ruleQuery(filters, skip, medicationId)}`, { signal });
  return { total: result.total, items: result.items.map(item => ({ ...item, kind: filters.kind } as Interaction)) };
}
export async function getInteraction(rule: Interaction): Promise<Interaction> {
  const value = await browserRequest<DrugInteraction | FoodInteraction>(`${ruleEndpoint(rule.kind)}/${rule.id}`);
  return { ...value, kind: rule.kind } as Interaction;
}
export const saveInteraction = (kind: RuleKind, input: DrugInput | FoodInput, original?: Interaction) => {
  const payload = rulePayload(kind, input, original);
  if (original && Object.keys(payload).length === 1) return getInteraction(original);
  return browserRequest<DrugInteraction | FoodInteraction>(original ? `${ruleEndpoint(kind)}/${original.id}` : ruleEndpoint(kind), jsonOptions(original ? "PATCH" : "POST", payload));
};
export const deleteInteraction = (rule: Interaction) => browserRequest<void>(`${ruleEndpoint(rule.kind)}/${rule.id}?expected_version=${rule.version}`, { method: "DELETE" });
export const listIngredients = (search: string, skip: number, signal?: AbortSignal) => {
  const query = new URLSearchParams({ skip: String(skip), limit: "20" });
  if (search.trim()) query.set("q", search.trim());
  return browserRequest<Page<Ingredient>>(`/api/session/active-ingredients?${query}`, { signal });
};
