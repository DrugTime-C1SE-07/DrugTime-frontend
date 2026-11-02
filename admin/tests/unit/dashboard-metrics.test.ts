import test from "node:test";
import assert from "node:assert/strict";
import type { SyncRun } from "../../lib/types/catalog-sync";
import {
  areaPath, chronological, cleanRate, countBySource, durationMinutes, gaugeArc, latestRun, linePath,
  peakIndex, percent, recordTotals, runLabel, scale, seriesByRun, smoothPath, statusShare,
} from "../../lib/dashboard/metrics";

const run = (id: number, startedAt: string, patch: Partial<SyncRun> = {}): SyncRun => ({
  id, source: "dav_drugbank", status: "thanh_cong", started_at: startedAt, finished_at: null,
  records_inserted: 0, records_updated: 0, records_failed: 0, error_details: null, triggered_by: "scheduler", ...patch,
});
const runs = [
  run(2, "2026-10-28T02:00:00Z", { records_inserted: 30, records_updated: 5, records_failed: 5, status: "that_bai", finished_at: "2026-10-28T02:12:00Z" }),
  run(1, "2026-10-27T02:00:00Z", { records_inserted: 10, records_updated: 40, records_failed: 0, finished_at: "2026-10-27T02:30:00Z", source: "duoc_thu_qg" }),
  run(3, "2026-10-29T02:00:00Z", { records_inserted: 20, records_updated: 10, status: "dang_chay" }),
];

test("runs are ordered oldest first and limited to the newest", () => {
  assert.deepEqual(chronological(runs).map(r => r.id), [1, 2, 3]);
  assert.deepEqual(chronological(runs, 2).map(r => r.id), [2, 3]);
  assert.deepEqual(chronological(runs, 0), []);
  assert.equal(latestRun(runs)?.id, 3);
  assert.equal(latestRun([]), null);
});
test("status share counts each status and sums to 100", () => {
  const share = statusShare(runs);
  assert.deepEqual([share.thanh_cong.count, share.that_bai.count, share.dang_chay.count], [1, 1, 1]);
  assert.equal(share.thanh_cong.percent, 33.3);
  assert.deepEqual(statusShare([]).thanh_cong, { count: 0, percent: 0 });
  assert.deepEqual(countBySource(runs), { dav_drugbank: 2, duoc_thu_qg: 1 });
});
test("series and totals come from the records, in run order", () => {
  assert.deepEqual(seriesByRun(runs, "records_inserted"), [10, 30, 20]);
  assert.deepEqual(seriesByRun(runs, "records_failed", 2), [5, 0]);
  assert.deepEqual(recordTotals(runs), { inserted: 60, updated: 55, failed: 5, total: 120 });
});
test("unfinished runs get no fabricated duration", () => {
  assert.deepEqual(durationMinutes(runs), [30, 12]);
  assert.deepEqual(durationMinutes([run(9, "2026-10-29T00:00:00Z")]), []);
});
test("clean rate is null without records and handles failures", () => {
  assert.equal(cleanRate([]), null);
  assert.equal(cleanRate([run(9, "2026-10-29T00:00:00Z")]), null);
  assert.equal(cleanRate(runs), 95.8);
});
test("percent and peak guard empty input", () => {
  assert.equal(percent(1, 0), 0);
  assert.equal(percent(1, 3), 33.3);
  assert.equal(peakIndex([3, 9, 9, 1]), 1);
  assert.equal(peakIndex([]), -1);
});
test("scaled points stay inside the frame, flat series does not divide by zero", () => {
  const points = scale([0, 50, 100], 200, 100, 10);
  assert.deepEqual(points, [{ x: 0, y: 90 }, { x: 100, y: 50 }, { x: 200, y: 10 }]);
  for (const p of scale([0, 0, 0], 200, 100)) assert.ok(Number.isFinite(p.y) && p.y >= 0 && p.y <= 100);
  assert.deepEqual(scale([], 200, 100), []);
  assert.deepEqual(scale([50], 100, 100, 0, 100), [{ x: 0, y: 50 }]);
});
test("run label uses the Vietnam day", () => {
  assert.equal(runLabel(run(1, "2026-10-28T18:30:00Z")), "29/10");
});
test("paths need at least two points", () => {
  const points = scale([0, 2], 100, 50);
  assert.equal(linePath(points), "M 0 50 L 100 0");
  assert.match(smoothPath(points), /^M 0 50 C 50 50, 50 0, 100 0$/);
  assert.equal(areaPath(linePath(points), points, 50), "M 0 50 L 100 0 L 100 50 L 0 50 Z");
  assert.equal(linePath(scale([5], 100, 50)), "");
  assert.equal(smoothPath([]), "");
  assert.equal(areaPath("", [], 50), "");
});
test("gauge arc runs from the left end to the ratio", () => {
  assert.equal(gaugeArc(0, 100, 100, 80), "");
  assert.equal(gaugeArc(1, 100, 100, 80), "M 20 100 A 80 80 0 0 1 180 100");
  assert.equal(gaugeArc(0.5, 100, 100, 80), "M 20 100 A 80 80 0 0 1 100 20");
  assert.equal(gaugeArc(2, 100, 100, 80), gaugeArc(1, 100, 100, 80));
});
