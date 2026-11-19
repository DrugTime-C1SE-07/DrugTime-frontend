/**
 * Decides which heavy effects a visitor's device should get. Pure functions over a plain
 * snapshot so they can be unit-tested; `readMotionEnv()` builds the snapshot in the browser.
 */
export type MotionEnv = {
  width: number;
  reducedMotion: boolean;
  saveData: boolean;
  hover: boolean;
  finePointer: boolean;
};

/** Breakpoint from which the Spline scene replaces the static phone. */
export const DESKTOP_MIN_WIDTH = 1024;

export const MEDIA = {
  desktop: `(min-width: ${DESKTOP_MIN_WIDTH}px)`,
  reduce: '(prefers-reduced-motion: reduce)',
  finePointer: '(hover: hover) and (pointer: fine)',
} as const;

export function shouldLoad3D(env: MotionEnv): boolean {
  return env.width >= DESKTOP_MIN_WIDTH && !env.reducedMotion && !env.saveData;
}

export function canHover(env: MotionEnv): boolean {
  return env.hover && env.finePointer;
}

type NetworkInformation = { saveData?: boolean };

export function readMotionEnv(win: Window = window): MotionEnv {
  const connection = (win.navigator as Navigator & { connection?: NetworkInformation }).connection;
  return {
    width: win.innerWidth,
    reducedMotion: win.matchMedia(MEDIA.reduce).matches,
    saveData: connection?.saveData === true,
    hover: win.matchMedia('(hover: hover)').matches,
    finePointer: win.matchMedia('(pointer: fine)').matches,
  };
}
