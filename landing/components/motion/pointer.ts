import type { GsapCore } from '@/lib/motion/gsap';

type Gsap = GsapCore['gsap'];
type Magnet = { x: gsap.QuickToFunc; y: gsap.QuickToFunc };

const TILT_X = 7; // max rotateX in degrees
const TILT_Y = 9; // max rotateY in degrees
const MAGNET_PULL = 0.28; // share of the cursor offset the element follows

/**
 * Delegated mouse effects for the whole page, driven by data attributes:
 *  - [data-spotlight]  writes --mx / --my (px) for the CSS radial glow
 *  - [data-tilt]       writes --rx / --ry (deg) for the CSS 3D tilt
 *  - [data-magnetic]   pulls the element towards the cursor with gsap.quickTo
 * Only bound for fine pointers (see MotionRoot); gsap is passed in because it is lazy-loaded.
 * Returns a cleanup function.
 */
export function bindPointerEffects(gsap: Gsap, root: HTMLElement = document.body): () => void {
  const magnets = new Map<HTMLElement, Magnet>();

  const magnetFor = (el: HTMLElement): Magnet => {
    let m = magnets.get(el);
    if (!m) {
      m = {
        x: gsap.quickTo(el, 'x', { duration: 0.6, ease: 'power3.out' }),
        y: gsap.quickTo(el, 'y', { duration: 0.6, ease: 'power3.out' }),
      };
      magnets.set(el, m);
    }
    return m;
  };

  const onMove = (e: PointerEvent) => {
    if (e.pointerType !== 'mouse') return;
    const target = e.target instanceof Element ? e.target : null;
    if (!target) return;

    const spot = target.closest<HTMLElement>('[data-spotlight]');
    if (spot) {
      const r = spot.getBoundingClientRect();
      spot.style.setProperty('--mx', `${e.clientX - r.left}px`);
      spot.style.setProperty('--my', `${e.clientY - r.top}px`);
    }

    const tilt = target.closest<HTMLElement>('[data-tilt]');
    if (tilt) {
      const r = tilt.getBoundingClientRect();
      const px = (e.clientX - r.left) / r.width - 0.5;
      const py = (e.clientY - r.top) / r.height - 0.5;
      tilt.style.setProperty('--rx', `${(-py * TILT_X * 2).toFixed(2)}deg`);
      tilt.style.setProperty('--ry', `${(px * TILT_Y * 2).toFixed(2)}deg`);
    }

    const mag = target.closest<HTMLElement>('[data-magnetic]');
    if (mag) {
      const r = mag.getBoundingClientRect();
      const m = magnetFor(mag);
      m.x((e.clientX - (r.left + r.width / 2)) * MAGNET_PULL);
      m.y((e.clientY - (r.top + r.height / 2)) * MAGNET_PULL);
    }
  };

  const onOut = (e: PointerEvent) => {
    const from = e.target instanceof Element ? e.target : null;
    const to = e.relatedTarget instanceof Element ? e.relatedTarget : null;
    if (!from) return;

    const tilt = from.closest<HTMLElement>('[data-tilt]');
    if (tilt && !(to && tilt.contains(to))) {
      tilt.style.setProperty('--rx', '0deg');
      tilt.style.setProperty('--ry', '0deg');
    }
    const mag = from.closest<HTMLElement>('[data-magnetic]');
    if (mag && !(to && mag.contains(to))) {
      const m = magnetFor(mag);
      m.x(0);
      m.y(0);
    }
  };

  root.addEventListener('pointermove', onMove, { passive: true });
  root.addEventListener('pointerout', onOut, { passive: true });

  return () => {
    root.removeEventListener('pointermove', onMove);
    root.removeEventListener('pointerout', onOut);
    magnets.forEach((_, el) => gsap.set(el, { clearProps: 'x,y,transform' }));
    magnets.clear();
  };
}
