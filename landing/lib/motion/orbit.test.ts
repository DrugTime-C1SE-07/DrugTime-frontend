import { describe, expect, it } from 'vitest';
import { orbitPoint } from './orbit';

const points = (n: number) => Array.from({ length: n }, (_, i) => orbitPoint(i, n));

describe('orbitPoint', () => {
  it('keeps every point inside the stage', () => {
    for (const p of points(7)) {
      expect(p.x).toBeGreaterThanOrEqual(0);
      expect(p.x).toBeLessThanOrEqual(100);
      expect(p.y).toBeGreaterThanOrEqual(0);
      expect(p.y).toBeLessThanOrEqual(100);
    }
  });

  it('spreads seven points without collisions', () => {
    const keys = new Set(points(7).map((p) => `${p.x},${p.y}`));
    expect(keys.size).toBe(7);
  });

  it('puts four points on the right and three on the left, top to bottom', () => {
    const ps = points(7);
    const right = ps.filter((p) => p.side === 'right');
    const left = ps.filter((p) => p.side === 'left');
    expect(right).toHaveLength(4);
    expect(left).toHaveLength(3);
    for (const side of [right, left]) {
      for (let i = 1; i < side.length; i++) expect(side[i].y).toBeGreaterThan(side[i - 1].y);
    }
  });

  it('keeps points off the phone in the middle column', () => {
    for (const p of points(7)) expect(Math.abs(p.x - 50)).toBeGreaterThan(30);
  });

  it('centres a lone point on its arc', () => {
    expect(orbitPoint(0, 1)).toEqual({ x: 100, y: 50, side: 'right' });
  });

  it('assigns the side from the horizontal position', () => {
    expect(orbitPoint(0, 2).side).toBe('right');
    expect(orbitPoint(1, 2).side).toBe('left');
  });
});
