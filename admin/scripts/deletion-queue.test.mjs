// Test logic hàng chờ yêu cầu xóa dữ liệu (lib/deletion-requests/queue.ts). Chạy: npm run test:deletion-queue
// Cần Node ≥ 22.18 để import trực tiếp file .ts (type stripping, không cần build).

import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  PAGE_SIZE,
  formatRequestedAt,
  overflowTarget,
  pageCount,
  parsePage,
  queueErrorView,
  skipFor,
} from "../lib/deletion-requests/queue.ts";

describe("parsePage", () => {
  it("falls back to page 1 for missing or invalid values", () => {
    for (const raw of [undefined, "", "0", "-1", "abc", "2.5", "1e2", ["3"]]) {
      assert.equal(parsePage(raw), 1, `raw=${JSON.stringify(raw)}`);
    }
  });

  it("accepts positive integers", () => {
    assert.equal(parsePage("1"), 1);
    assert.equal(parsePage("3"), 3);
  });
});

describe("skipFor", () => {
  it("maps page to offset with PAGE_SIZE 20", () => {
    assert.equal(PAGE_SIZE, 20);
    assert.equal(skipFor(1), 0);
    assert.equal(skipFor(3), 40);
  });
});

describe("pageCount", () => {
  it("is at least 1 and rounds up", () => {
    assert.equal(pageCount(0), 1);
    assert.equal(pageCount(20), 1);
    assert.equal(pageCount(21), 2);
    assert.equal(pageCount(45), 3);
  });
});

describe("overflowTarget", () => {
  it("returns the last valid page when the current page is past the end", () => {
    assert.equal(overflowTarget(3, 30, 0), 2);
    assert.equal(overflowTarget(9, 1, 0), 1);
  });

  it("returns null when no redirect is needed", () => {
    assert.equal(overflowTarget(3, 45, 5), null);
    assert.equal(overflowTarget(2, 0, 0), null);
    assert.equal(overflowTarget(1, 0, 0), null);
  });
});

describe("formatRequestedAt", () => {
  it("renders in Asia/Ho_Chi_Minh as dd/MM/yyyy HH:mm", () => {
    assert.equal(formatRequestedAt("2026-11-18T17:30:00Z"), "19/11/2026 00:30");
    assert.equal(formatRequestedAt("2026-11-19T08:05:00+07:00"), "19/11/2026 08:05");
  });
});

describe("queueErrorView", () => {
  it("maps API status to a view without data", () => {
    assert.equal(queueErrorView(401), "session_expired");
    assert.equal(queueErrorView(403), "forbidden");
    for (const status of [422, 500, 503]) {
      assert.equal(queueErrorView(status), "unavailable");
    }
  });
});
