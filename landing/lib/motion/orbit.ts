export type OrbitSide = 'left' | 'right';
export type OrbitPoint = { x: number; y: number; side: OrbitSide };

type OrbitOptions = {
  /** Horizontal radius in % of the container width. */
  rx?: number;
  /** Vertical radius in % of the container height. */
  ry?: number;
  /** Half-width of each side arc in degrees; keeps points off the top and bottom of the phone. */
  spread?: number;
};

const round = (v: number) => Math.round(v * 100) / 100;
const clamp = (v: number) => Math.min(100, Math.max(0, v));

/**
 * Position of icon `i` of `n` around the hero phone, as percentages of the stage (0–100).
 * Icons sit on two arcs of an ellipse — ceil(n/2) on the right, the rest on the left — both
 * running top to bottom, so none lands on top of the phone's screen. `side` tells the icon
 * which way to expand (towards the phone).
 */
export function orbitPoint(i: number, n: number, { rx = 54, ry = 42, spread = 50 }: OrbitOptions = {}): OrbitPoint {
  const rightCount = Math.ceil(n / 2);
  const onRight = i < rightCount;
  const count = onRight ? rightCount : n - rightCount;
  const k = onRight ? i : i - rightCount;
  const t = count === 1 ? 0.5 : k / (count - 1); // 0 = top of the arc, 1 = bottom
  // Screen coordinates: 0° points right, angles grow clockwise (downwards).
  const deg = onRight ? -spread + t * 2 * spread : 180 + spread - t * 2 * spread;
  const rad = (deg * Math.PI) / 180;
  const x = clamp(round(50 + rx * Math.cos(rad)));
  const y = clamp(round(50 + ry * Math.sin(rad)));
  return { x, y, side: x < 50 ? 'left' : 'right' };
}
