import { describe, expect, it } from 'vitest';
import { canHover, DESKTOP_MIN_WIDTH, type MotionEnv, shouldLoad3D } from './capabilities';

const desktop: MotionEnv = { width: 1440, reducedMotion: false, saveData: false, hover: true, finePointer: true };

describe('shouldLoad3D', () => {
  it('loads on desktop without reduced motion or data saver', () => {
    expect(shouldLoad3D(desktop)).toBe(true);
  });

  it('switches exactly at the desktop breakpoint', () => {
    expect(shouldLoad3D({ ...desktop, width: DESKTOP_MIN_WIDTH - 1 })).toBe(false);
    expect(shouldLoad3D({ ...desktop, width: DESKTOP_MIN_WIDTH })).toBe(true);
  });

  it('never loads on a phone', () => {
    expect(shouldLoad3D({ ...desktop, width: 375 })).toBe(false);
  });

  it('respects prefers-reduced-motion', () => {
    expect(shouldLoad3D({ ...desktop, reducedMotion: true })).toBe(false);
  });

  it('respects data saver', () => {
    expect(shouldLoad3D({ ...desktop, saveData: true })).toBe(false);
  });
});

describe('canHover', () => {
  it('is true for a mouse', () => {
    expect(canHover(desktop)).toBe(true);
  });

  it('is false for touch-only or coarse pointers', () => {
    expect(canHover({ ...desktop, hover: false })).toBe(false);
    expect(canHover({ ...desktop, finePointer: false })).toBe(false);
  });
});
