// Test hình học biểu đồ (lib/chart/geometry.ts). Chạy: npm run test:chart
// Cần Node ≥ 22.18 để import trực tiếp file .ts (type stripping, không cần build).

import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { areaPath, layoutPoints, monotonePath, niceTicks, scaleLinear } from "../lib/chart/geometry.ts";

const BOX = { width: 720, height: 240, padding: { top: 16, right: 48, bottom: 32, left: 48 } };
const SUCCESS = [1880, 1935, 1990, 2020, 2065, 2110, 2210];
const RADIUS = 5;
const STROKE = 3;

// Tách path "M x y C x1 y1 x2 y2 x y C ..." thành các điểm đầu mút đoạn (bỏ điểm điều khiển).
function endpoints(d) {
  const nums = d.match(/-?\d+(\.\d+)?/g).map(Number);
  const pts = [{ x: nums[0], y: nums[1] }];
  for (let i = 2; i + 5 < nums.length; i += 6) pts.push({ x: nums[i + 4], y: nums[i + 5] });
  return pts;
}

function controls(d) {
  const nums = d.match(/-?\d+(\.\d+)?/g).map(Number);
  const out = [];
  for (let i = 2; i + 5 < nums.length; i += 6) out.push([{ x: nums[i], y: nums[i + 1] }, { x: nums[i + 2], y: nums[i + 3] }]);
  return out;
}

describe("niceTicks", () => {
  it("cho vạch tròn số bao phủ min và max", () => {
    const ticks = niceTicks(1880, 2210, 4);
    assert.ok(ticks[0] <= 1880, `vạch đầu ${ticks[0]} phải ≤ 1880`);
    assert.ok(ticks.at(-1) >= 2210, `vạch cuối ${ticks.at(-1)} phải ≥ 2210`);
    const step = ticks[1] - ticks[0];
    for (let i = 1; i < ticks.length; i++) assert.equal(ticks[i] - ticks[i - 1], step);
    assert.match(String(step), /^(1|2|5)0*$/, `bước ${step} phải là 1/2/5 × 10^n`);
  });

  it("dữ liệu phẳng (min = max) không chia cho 0", () => {
    const ticks = niceTicks(24, 24, 4);
    assert.ok(ticks.length >= 2);
    assert.ok(ticks.every(Number.isFinite));
    assert.ok(ticks[0] <= 24 && ticks.at(-1) >= 24);
  });
});

describe("scaleLinear", () => {
  it("ánh xạ hai đầu domain vào hai đầu range (trục y ngược)", () => {
    const y = scaleLinear([0, 100], [200, 0]);
    assert.equal(y(0), 200);
    assert.equal(y(100), 0);
    assert.equal(y(50), 100);
  });
});

describe("layoutPoints", () => {
  const pts = layoutPoints(SUCCESS, { ...BOX, domain: [1800, 2300] });
  const plotW = BOX.width - BOX.padding.left - BOX.padding.right;

  it("đặt điểm i tại tâm cột i (khớp tâm nhãn ngày)", () => {
    assert.equal(pts.length, 7);
    pts.forEach((p, i) => assert.equal(p.x, BOX.padding.left + ((i + 0.5) * plotW) / 7));
  });

  it("điểm đầu/cuối cách mép SVG ≥ bán kính + nửa nét, y nằm trong vùng vẽ", () => {
    const margin = RADIUS + STROKE / 2;
    for (const p of pts) {
      assert.ok(p.x >= margin && p.x <= BOX.width - margin, `x=${p.x} bị cắt mép`);
      assert.ok(p.y >= BOX.padding.top && p.y <= BOX.height - BOX.padding.bottom, `y=${p.y} ra ngoài vùng vẽ`);
    }
  });

  it("giữ giá trị gốc để tooltip đọc", () => {
    assert.deepEqual(pts.map((p) => p.value), SUCCESS);
  });

  it("mảng rỗng trả [] (nhánh lỗi)", () => {
    assert.deepEqual(layoutPoints([], { ...BOX, domain: [0, 1] }), []);
  });
});

describe("monotonePath", () => {
  const pts = layoutPoints(SUCCESS, { ...BOX, domain: [1800, 2300] });
  const d = monotonePath(pts);

  it("đi qua đúng mọi điểm (lệch 0)", () => {
    const ends = endpoints(d);
    assert.equal(ends.length, pts.length);
    ends.forEach((e, i) => {
      assert.ok(Math.abs(e.x - pts[i].x) < 1e-6, `x đoạn ${i} lệch`);
      assert.ok(Math.abs(e.y - pts[i].y) < 1e-6, `y đoạn ${i} lệch`);
    });
  });

  it("không vọt quá: điểm điều khiển nằm trong khoảng y của hai điểm kề với dữ liệu đơn điệu", () => {
    controls(d).forEach(([c1, c2], i) => {
      const lo = Math.min(pts[i].y, pts[i + 1].y) - 1e-6;
      const hi = Math.max(pts[i].y, pts[i + 1].y) + 1e-6;
      assert.ok(c1.y >= lo && c1.y <= hi, `c1 đoạn ${i} vọt ra ngoài`);
      assert.ok(c2.y >= lo && c2.y <= hi, `c2 đoạn ${i} vọt ra ngoài`);
    });
  });

  it("dữ liệu có đỉnh: không vọt quá đỉnh", () => {
    const peak = layoutPoints([10, 30, 20, 25, 5], { ...BOX, domain: [0, 40] });
    controls(monotonePath(peak)).forEach(([c1, c2], i) => {
      const lo = Math.min(peak[i].y, peak[i + 1].y) - 1e-6;
      const hi = Math.max(peak[i].y, peak[i + 1].y) + 1e-6;
      assert.ok(c1.y >= lo && c1.y <= hi && c2.y >= lo && c2.y <= hi, `đoạn ${i} vọt quá`);
    });
  });

  it("một điểm hoặc rỗng không lỗi", () => {
    assert.equal(monotonePath([]), "");
    assert.match(monotonePath([{ x: 10, y: 20, value: 1 }]), /^M10 20$/);
  });
});

describe("areaPath", () => {
  it("khép kín về đường đáy", () => {
    const pts = layoutPoints(SUCCESS, { ...BOX, domain: [1800, 2300] });
    const d = areaPath(pts, 208);
    assert.ok(d.startsWith(monotonePath(pts)));
    assert.ok(d.endsWith("Z"));
    assert.equal(areaPath([], 208), "");
  });
});
