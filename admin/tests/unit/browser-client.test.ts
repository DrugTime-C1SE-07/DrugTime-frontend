import test from "node:test";
import assert from "node:assert/strict";
import { browserRequest, BrowserApiError } from "../../lib/api/browser-client";

test("JSON success uses no-store and forwards cancellation", async context => {
  const controller = new AbortController();
  context.mock.method(globalThis, "fetch", async (_path: string, options: RequestInit) => {
    assert.equal(options.cache, "no-store"); assert.equal(options.signal, controller.signal);
    return Response.json({ items: [], total: 0 });
  });
  assert.deepEqual(await browserRequest("/api/session/medications", { signal: controller.signal }), { items: [], total: 0 });
});
test("DELETE 204 has no JSON body", async context => {
  context.mock.method(globalThis, "fetch", async () => new Response(null, { status: 204 }));
  assert.equal(await browserRequest("/resource/1", { method: "DELETE" }), undefined);
});
for (const status of [401, 403, 404, 409, 422, 429, 500, 503]) {
  test(`HTTP ${status} never becomes success or leaks server text`, async context => {
    context.mock.method(globalThis, "fetch", async () => new Response("secret-upstream-error", { status }));
    await assert.rejects(browserRequest("/resource"), (error: unknown) => {
      assert.ok(error instanceof BrowserApiError); assert.equal(error.status, status); assert.ok(!error.message.includes("secret-upstream-error")); return true;
    });
  });
}
test("POST network failure warns result may already be saved", async context => {
  context.mock.method(globalThis, "fetch", async () => { throw new TypeError("private-network-details"); });
  await assert.rejects(browserRequest("/resource", { method: "POST" }), /Chưa xác định/);
});
test("abort while JSON is being read cannot return stale response", async context => {
  const controller = new AbortController();
  context.mock.method(globalThis, "fetch", async () => ({ ok: true, status: 200, json: async () => { controller.abort(); return { old: true }; } }));
  await assert.rejects(browserRequest("/resource", { signal: controller.signal }), { name: "AbortError" });
});
test("malformed successful body is an error", async context => {
  context.mock.method(globalThis, "fetch", async () => new Response("not-json"));
  await assert.rejects(browserRequest("/resource"), (error: unknown) => error instanceof BrowserApiError && error.status === 502);
});
