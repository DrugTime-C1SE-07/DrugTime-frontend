import test from "node:test";
import assert from "node:assert/strict";
import { syncQuery, syncTime } from "../../lib/api/catalog-sync";

test("sync uses offset and only provided filters", () => {
  const query = new URLSearchParams(syncQuery("dav_drugbank", "that_bai", 40));
  assert.equal(query.get("offset"), "40"); assert.equal(query.has("skip"), false); assert.equal(query.get("status"), "that_bai"); assert.equal(query.get("source"), "dav_drugbank");
  assert.equal(new URLSearchParams(syncQuery()).has("source"), false);
});
test("unfinished timestamp is not fabricated", () => {
  assert.equal(syncTime(null), "Chưa kết thúc");
  assert.match(syncTime("2026-10-28T00:00:00Z"), /7:00:00|07:00:00/);
});
