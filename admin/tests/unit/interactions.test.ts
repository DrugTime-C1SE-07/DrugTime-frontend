import test from "node:test";
import assert from "node:assert/strict";
import { rulePayload, ruleQuery, ruleKey, deleteInteraction, saveInteraction } from "../../lib/api/interactions";
import type { DrugInput, Interaction } from "../../lib/types/interaction";

const input: DrugInput = { ingredient_a_id: 1, ingredient_b_id: 2, interaction_type: "phu_thuoc_lieu", severity_level: 2, handling_type: "can_theo_doi", min_interval_hours: null, description: "Description", source: "Reference", dose_thresholds: [{ ingredient_ref: "A", min_dose: 1, max_dose: null, dose_unit: "mg", severity_level: 3, warning_text: "Warning" }] };
const original = { ...input, kind: "drug_drug", id: 7, version: 4, dose_thresholds: input.dose_thresholds.map(value => ({ ...value, id: 99 })) } as unknown as Interaction;
test("PATCH preserves untouched thresholds and excludes ingredient pair", () => {
  assert.deepEqual(rulePayload("drug_drug", { ...input, description: "Changed" }, original), { description: "Changed", expected_version: 4 });
});
test("editing thresholds strips database IDs and retains null bounds", () => {
  const changed = { ...input, dose_thresholds: [{ ...input.dose_thresholds[0], warning_text: "Changed", id: 999 }] };
  const payload = rulePayload("drug_drug", changed, original);
  assert.equal((payload.dose_thresholds as object[])[0].hasOwnProperty("id"), false);
  assert.equal((payload.dose_thresholds as { max_dose: null }[])[0].max_dose, null);
  assert.equal(payload.expected_version, 4);
});
test("create sends external B without fabricated ingredient ID", () => {
  const external = { ...input, ingredient_b_id: undefined, ingredient_b_external_name: "External" };
  const result = rulePayload("drug_drug", external);
  assert.equal(result.ingredient_b_id, undefined); assert.equal(result.ingredient_b_external_name, "External");
});
test("food rule never sends DDI fields", () => {
  assert.deepEqual(rulePayload("drug_food", { ingredient_id: 1, food_to_avoid: "Food", severity_level: 3, reason: "Reason", source: "Ref" }), { ingredient_id: 1, food_to_avoid: "Food", severity_level: 3, reason: "Reason", source: "Ref" });
});
test("kind differentiates same numeric ID and food query excludes DDI type", () => {
  assert.notEqual(ruleKey(original), ruleKey({ ...original, kind: "drug_food" } as Interaction));
  const query = new URLSearchParams(ruleQuery({ kind: "drug_food", search: "", severity: "4", interactionType: "chong_chi_dinh" }, 20, 12));
  assert.equal(query.has("interaction_type"), false); assert.equal(query.get("medication_id"), "12"); assert.equal(query.get("skip"), "20");
});
test("create rejects two B choices and identical ingredients", () => {
  assert.throws(() => rulePayload("drug_drug", { ...input, ingredient_b_external_name: "External" }), /đúng một/);
  assert.throws(() => rulePayload("drug_drug", { ...input, ingredient_b_id: 1 }), /khác nhau/);
});
test("contraindication cannot silently erase thresholds or change severity", () => {
  assert.throws(() => rulePayload("drug_drug", { ...input, interaction_type: "chong_chi_dinh", severity_level: 4 }), /không có ngưỡng/);
  assert.throws(() => rulePayload("drug_drug", { ...input, interaction_type: "chong_chi_dinh", dose_thresholds: [] }), /mức độ 4/);
});
test("threshold bounds and external B references are validated", () => {
  assert.throws(() => rulePayload("drug_drug", { ...input, dose_thresholds: [{ ...input.dose_thresholds[0], min_dose: null }] }), /phải có liều/);
  assert.throws(() => rulePayload("drug_drug", { ...input, dose_thresholds: [{ ...input.dose_thresholds[0], max_dose: 0 }] }), /lớn hơn/);
  assert.throws(() => rulePayload("drug_drug", { ...input, ingredient_b_id: undefined, ingredient_b_external_name: "External", dose_thresholds: [{ ...input.dose_thresholds[0], ingredient_ref: "B" }] }), /trong danh mục/);
});
test("interval can only accompany spacing", () => {
  assert.throws(() => rulePayload("drug_drug", { ...input, min_interval_hours: 2 }), /cách giờ/);
  assert.equal(rulePayload("drug_drug", { ...input, handling_type: "cach_gio", min_interval_hours: 2 }).min_interval_hours, 2);
});
test("spacing uses contract bounds, including small positive intervals", () => {
  for (const min_interval_hours of [0, -1, 168.1, Number.NaN]) {
    assert.throws(() => rulePayload("drug_drug", { ...input, handling_type: "cach_gio", min_interval_hours }), /lớn hơn 0/);
  }
  assert.equal(rulePayload("drug_drug", { ...input, handling_type: "cach_gio", min_interval_hours: 0.001 }).min_interval_hours, 0.001);
  assert.equal(rulePayload("drug_drug", { ...input, handling_type: "cach_gio", min_interval_hours: 168 }).min_interval_hours, 168);
});
test("DELETE sends version and uses resource kind", async context => {
  context.mock.method(globalThis, "fetch", async (path: string, options: RequestInit) => {
    assert.equal(path, "/api/session/drug-interactions/7?expected_version=4"); assert.equal(options.method, "DELETE");
    return new Response(null, { status: 204 });
  });
  await deleteInteraction(original);
});
test("unchanged edit rereads current rule instead of invalid version-only PATCH", async context => {
  context.mock.method(globalThis, "fetch", async (path: string, options: RequestInit) => {
    assert.equal(path, "/api/session/drug-interactions/7"); assert.equal(options.method, undefined);
    return Response.json(original);
  });
  await saveInteraction("drug_drug", input, original);
});
