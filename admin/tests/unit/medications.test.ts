import test from "node:test";
import assert from "node:assert/strict";
import { medicationPayload, medicationQuery } from "../../lib/api/medications";
import type { Medication, MedicationInput } from "../../lib/types/medication";

const input: MedicationInput = { name: "Test", raw_active_ingredient: "Ingredient", strength_text: null, dosage_form: null, manufacturer_name: null, manufacturer_country: null, packaging_spec: null, source: "dav_drugbank", source_ref: "REF" };
const original: Medication = { ...input, id: 21, deleted_at: null };
test("create payload only sends schema fields", () => {
  assert.deepEqual(medicationPayload({ ...original, quality: "verified" } as MedicationInput), input);
});
test("PATCH contains only actual changes and permits explicit clear", () => {
  assert.deepEqual(medicationPayload({ ...input, raw_active_ingredient: null }, original), { raw_active_ingredient: null });
  assert.deepEqual(medicationPayload(input, original), {});
});
test("source pair is sent together when changed or cleared", () => {
  assert.deepEqual(medicationPayload({ ...input, source_ref: "NEW" }, original), { source: "dav_drugbank", source_ref: "NEW" });
  assert.deepEqual(medicationPayload({ ...input, source: null, source_ref: null }, original), { source: null, source_ref: null });
});
test("search is encoded and pagination is server-side", () => {
  const query = new URLSearchParams(medicationQuery(" A&B ", 20));
  assert.equal(query.get("q"), "A&B"); assert.equal(query.get("skip"), "20"); assert.equal(query.get("limit"), "20");
  assert.equal(new URLSearchParams(medicationQuery(" ", 0)).has("q"), false);
});
