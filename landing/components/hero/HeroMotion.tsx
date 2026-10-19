'use client';

import { useEffect, useRef, type ReactNode } from 'react';
import { MEDIA } from '@/lib/motion/capabilities';
import { loadGsapWhenReady } from '@/lib/motion/gsap';

const PARALLAX_X = 36; // px at depth 1
const PARALLAX_Y = 26;

/**
 * Hero stage choreography (GSAP is lazy-loaded, the stage renders without it):
 *  - feature icons and orbits pop in on load (the phone itself stays visible: it is the LCP element)
 *  - desktop: scrolling away fades the copy up while the phone shrinks and turns (scrub)
 *  - fine pointer: layers marked [data-depth] follow the mouse, and the aurora glow tracks it
 * Only opacity is animated (never visibility), so nothing leaves the tab order.
 */
export default function HeroMotion({ children }: { children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const stage = ref.current;
    const hero = stage?.closest<HTMLElement>('.hero');
    if (!stage || !hero || window.matchMedia(MEDIA.reduce).matches) return;

    let cancelled = false;
    let revert: (() => void) | undefined;

    loadGsapWhenReady()
      .then(({ gsap }) => {
        if (cancelled) return;
        const ctx = gsap.context(() => {
          const mm = gsap.matchMedia();
          mm.add({ reduce: MEDIA.reduce, desktop: MEDIA.desktop, fine: MEDIA.finePointer }, (c) => {
            const { reduce, desktop, fine } = c.conditions as Record<string, boolean>;
            if (reduce) return;

            gsap.from(stage.querySelectorAll('.orbit-item'), {
              opacity: 0, scale: 0.6, duration: 0.8, ease: 'back.out(1.6)', stagger: 0.07, delay: 0.1,
            });
            gsap.from(stage.querySelectorAll('.orbit'), {
              opacity: 0, scale: 0.7, duration: 1.6, ease: 'expo.out', stagger: 0.1,
            });

            if (desktop) {
              gsap.timeline({ scrollTrigger: { trigger: hero, start: 'top top', end: 'bottom top', scrub: 0.6 } })
                .to(hero.querySelector('[data-hero-copy]'), { yPercent: -20, opacity: 0, ease: 'none' }, 0)
                .to(stage.querySelector('.stage__phone'), { yPercent: 14, scale: 0.84, rotate: -8, ease: 'none' }, 0)
                .to(stage.querySelectorAll('.orbit-item'), { yPercent: -80, opacity: 0, stagger: 0.04, ease: 'none' }, 0);
            }

            if (fine) {
              const layers = gsap.utils.toArray<HTMLElement>('[data-depth]', stage).map((el) => ({
                depth: Number(el.dataset.depth) || 1,
                x: gsap.quickTo(el, 'x', { duration: 0.9, ease: 'power3.out' }),
                y: gsap.quickTo(el, 'y', { duration: 0.9, ease: 'power3.out' }),
              }));
              const onMove = (e: PointerEvent) => {
                const r = hero.getBoundingClientRect();
                const px = (e.clientX - r.left) / r.width - 0.5;
                const py = (e.clientY - r.top) / r.height - 0.5;
                layers.forEach((l) => { l.x(px * PARALLAX_X * l.depth); l.y(py * PARALLAX_Y * l.depth); });
                hero.style.setProperty('--gx', `${((px + 0.5) * 100).toFixed(1)}%`);
                hero.style.setProperty('--gy', `${((py + 0.5) * 100).toFixed(1)}%`);
              };
              hero.addEventListener('pointermove', onMove, { passive: true });
              return () => hero.removeEventListener('pointermove', onMove);
            }
          });
        }, stage);
        revert = () => ctx.revert();
      })
      .catch((error: unknown) => console.warn('[hero] motion unavailable; showing static hero.', error));

    return () => {
      cancelled = true;
      revert?.();
    };
  }, []);

  return <div ref={ref} className="stage">{children}</div>;
}
