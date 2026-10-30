// Hình học biểu đồ đường: hàm thuần, không phụ thuộc React, test bằng scripts/chart-geometry.test.mjs.
// Điểm và đường sinh từ cùng một mảng dữ liệu nên điểm luôn nằm đúng trên đường.

export type ChartPadding = { top: number; right: number; bottom: number; left: number };

export type ChartBox = {
  width: number;
  height: number;
  padding: ChartPadding;
};

export type ChartPoint = { x: number; y: number; value: number; index: number };

/** Hàm ánh xạ tuyến tính domain → range; domain suy biến (d0 = d1) trả về giữa range. */
export function scaleLinear(domain: [number, number], range: [number, number]): (v: number) => number {
  const [d0, d1] = domain;
  const [r0, r1] = range;
  if (d0 === d1) return () => (r0 + r1) / 2;
  return (v) => r0 + ((v - d0) / (d1 - d0)) * (r1 - r0);
}

/** Vạch trục tròn số (bước 1/2/5 × 10^n) bao phủ [min, max]. */
export function niceTicks(min: number, max: number, count: number): number[] {
  let lo = min;
  let hi = max;
  if (lo === hi) {
    const pad = Math.abs(lo) * 0.1 || 1;
    lo -= pad;
    hi += pad;
  }
  const raw = (hi - lo) / Math.max(1, count);
  const magnitude = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 2, 5, 10].map((m) => m * magnitude).find((s) => s >= raw) ?? 10 * magnitude;
  const decimals = Math.max(0, -Math.floor(Math.log10(step)));
  const start = Math.floor(lo / step) * step;
  const end = Math.ceil(hi / step) * step;
  const ticks: number[] = [];
  for (let v = start; v <= end + step / 2; v += step) ticks.push(Number(v.toFixed(decimals)));
  return ticks;
}

/** Điểm i nằm ở tâm cột i: x = left + (i + 0.5) · plotW / n — trùng tâm nhãn ngày bên dưới. */
export function layoutPoints(
  values: number[],
  { width, height, padding, domain }: ChartBox & { domain: [number, number] },
): ChartPoint[] {
  if (values.length === 0) return [];
  const plotW = width - padding.left - padding.right;
  const y = scaleLinear(domain, [height - padding.bottom, padding.top]);
  return values.map((value, index) => ({
    x: padding.left + ((index + 0.5) * plotW) / values.length,
    y: y(value),
    value,
    index,
  }));
}

/** Hệ số góc tại điểm giữa theo Fritsch–Carlson (giống d3 curveMonotoneX): không vọt quá điểm kề. */
function interiorSlope(s0: number, s1: number, h0: number, h1: number): number {
  const p = (s0 * h1 + s1 * h0) / (h0 + h1);
  return (Math.sign(s0) + Math.sign(s1)) * Math.min(Math.abs(s0), Math.abs(s1), 0.5 * Math.abs(p)) || 0;
}

/** Đường cong cubic đi qua đúng từng điểm, đơn điệu giữa hai điểm kề. */
export function monotonePath(points: ChartPoint[]): string {
  if (points.length === 0) return "";
  const [first] = points;
  if (points.length === 1) return `M${first.x} ${first.y}`;

  const n = points.length;
  const h: number[] = [];
  const s: number[] = [];
  for (let i = 0; i < n - 1; i++) {
    h.push(points[i + 1].x - points[i].x);
    s.push((points[i + 1].y - points[i].y) / h[i]);
  }
  const m = points.map((_, i) => {
    if (i === 0) return s[0];
    if (i === n - 1) return s[n - 2];
    return interiorSlope(s[i - 1], s[i], h[i - 1], h[i]);
  });

  let d = `M${first.x} ${first.y}`;
  for (let i = 0; i < n - 1; i++) {
    const a = points[i];
    const b = points[i + 1];
    const t = h[i] / 3;
    d += ` C${a.x + t} ${a.y + m[i] * t}, ${b.x - t} ${b.y - m[i + 1] * t}, ${b.x} ${b.y}`;
  }
  return d;
}

/** Vùng tô dưới đường: đường cong rồi khép về đường đáy baseY. */
export function areaPath(points: ChartPoint[], baseY: number): string {
  if (points.length === 0) return "";
  const first = points[0];
  const last = points[points.length - 1];
  return `${monotonePath(points)} L${last.x} ${baseY} L${first.x} ${baseY} Z`;
}
