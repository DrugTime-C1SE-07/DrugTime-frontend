'use client';

import { useEffect } from 'react';
import { usePathname } from 'next/navigation';
import { MEDIA } from '@/lib/motion/capabilities';
import { formatCount } from '@/lib/motion/format';
import { loadGsapWhenReady, loadSplitText } from '@/lib/motion/gsap';
import { bindPointerEffects } from './pointer';

const showCount = (el: HTMLElement) => {
  el.textContent = formatCount(Number(el.dataset.count), el.dataset.suffix ?? '', el.dataset.grouping !== 'false');
};

/**
 * Page-wide motion, attached through data attributes so sections stay server components:
 *  [data-reveal]  fade + rise in batches when scrolled into view ("mobile" = below 1024px only)
 *  [data-split]   heading words rise from a line mask ("load" = on page load, desktop only)
 *  [data-count]   number counts up (data-suffix, data-grouping="false")
 *  [data-zoom]    panel scales up while entering
 *  [data-fill]    footer wordmark fills while scrolling (--fill)
 *  [data-ambient] looping CSS backgrounds pause while off-screen
 * GSAP is loaded after hydration (see lib/motion/gsap.ts). Nothing runs under
 * prefers-reduced-motion; CSS defaults are the final, readable state. Hidden-before-reveal
 * elements only get opacity 0 (never visibility: hidden), so they stay in the tab order and
 * the accessibility tree, and focusing one reveals it at once.
 */
export default function MotionRoot() {
  const pathname = usePathname();

  useEffect(() => {
    const html = document.documentElement;
    let cancelled = false;
    let revert: (() => void) | undefined;
    let refresh: (() => void) | undefined;

    // Pause looping backgrounds while they are off-screen (CSS only, no GSAP needed).
    const ambientIo = new IntersectionObserver((entries) => {
      entries.forEach((entry) => entry.target.classList.toggle('is-paused', !entry.isIntersecting));
    });
    document.querySelectorAll('[data-ambient]').forEach((el) => ambientIo.observe(el));

    if (window.matchMedia(MEDIA.reduce).matches) {
      html.classList.add('motion-ready');
      return () => ambientIo.disconnect();
    }

    const desktopAtLoad = window.matchMedia(MEDIA.desktop).matches;
    Promise.all([loadGsapWhenReady(), desktopAtLoad ? loadSplitText() : Promise.resolve(null)])
      .then(([{ gsap, ScrollTrigger }, SplitText]) => {
        if (cancelled) return;
        const ctx = gsap.context(() => {
          const mm = gsap.matchMedia();
          mm.add({ reduce: MEDIA.reduce, desktop: MEDIA.desktop, finePointer: MEDIA.finePointer }, (c) => {
            const { reduce, desktop, finePointer } = c.conditions as Record<string, boolean>;
            if (reduce) return;

            // data-reveal="mobile": the element has its own desktop choreography (pinned story).
            const reveals = gsap.utils
              .toArray<HTMLElement>('[data-reveal]')
              .filter((el) => !(desktop && el.dataset.reveal === 'mobile'));
            const reveal = (targets: Element | Element[], stagger = 0) =>
              gsap.to(targets, {
                opacity: 1, y: 0, duration: 1, ease: 'expo.out', stagger, overwrite: true,
                clearProps: 'transform,opacity',
              });
            if (reveals.length) gsap.set(reveals, { opacity: 0, y: 48 });
            ScrollTrigger.batch(reveals, { start: 'top 90%', once: true, onEnter: (batch) => reveal(batch, 0.08) });
            // Keyboard / screen-reader focus must never land on something invisible.
            const onFocusIn = (e: FocusEvent) => {
              const el = e.target instanceof Element ? e.target.closest('[data-reveal]') : null;
              if (el && reveals.includes(el as HTMLElement)) reveal(el);
            };
            document.addEventListener('focusin', onFocusIn);

            if (desktop && SplitText) {
              gsap.utils.toArray<HTMLElement>('[data-split]').forEach((el) => {
                const onLoad = el.dataset.split === 'load';
                SplitText.create(el, {
                  type: 'words,lines',
                  mask: 'lines',
                  autoSplit: true,
                  onSplit: (self) => {
                    return gsap.from(self.words, {
                      yPercent: 115, rotate: 4, duration: 1.1, ease: 'expo.out', stagger: 0.05,
                      delay: onLoad ? 0.15 : 0,
                      scrollTrigger: onLoad ? undefined : { trigger: el, start: 'top 88%', once: true },
                    });
                  },
                });
              });
            }

            if (desktop) {
              gsap.utils.toArray<HTMLElement>('[data-zoom]').forEach((el) => {
                gsap.fromTo(el, { scale: 0.9, borderRadius: '72px' }, {
                  scale: 1, borderRadius: '36px', ease: 'none',
                  scrollTrigger: { trigger: el, start: 'top bottom', end: 'top 35%', scrub: 0.6 },
                });
              });
              gsap.utils.toArray<HTMLElement>('[data-fill]').forEach((el) => {
                gsap.fromTo(el, { '--fill': '0%' }, {
                  '--fill': '100%', ease: 'none',
                  scrollTrigger: { trigger: el, start: 'top bottom', end: 'bottom bottom', scrub: true },
                });
              });
            }

            gsap.utils.toArray<HTMLElement>('[data-count]').forEach((el) => {
              const target = Number(el.dataset.count);
              const suffix = el.dataset.suffix ?? '';
              const grouping = el.dataset.grouping !== 'false';
              const state = { v: 0 };
              el.textContent = formatCount(0, suffix, grouping);
              gsap.to(state, {
                v: target, duration: 1.8, ease: 'power3.out',
                scrollTrigger: { trigger: el, start: 'top 92%', once: true },
                onUpdate: () => { el.textContent = formatCount(state.v, suffix, grouping); },
                onComplete: () => showCount(el),
              });
            });

            let unbindPointer: (() => void) | undefined;
            if (finePointer) {
              html.classList.add('motion-hover');
              unbindPointer = bindPointerEffects(gsap);
            }

            return () => {
              document.removeEventListener('focusin', onFocusIn);
              unbindPointer?.();
              html.classList.remove('motion-hover');
              // Leave counters on their real value when the context is reverted.
              gsap.utils.toArray<HTMLElement>('[data-count]').forEach(showCount);
            };
          });
        });
        revert = () => ctx.revert();

        // Layout settles once fonts and images are in; recompute pin/scrub positions.
        refresh = () => ScrollTrigger.refresh();
        void document.fonts.ready.then(refresh);
        window.addEventListener('load', refresh);
        html.classList.add('motion-ready');
      })
      .catch((error: unknown) => {
        // The page is fully readable without motion; just make sure nothing stays hidden.
        console.warn('[motion] animation libraries failed to load; showing static page.', error);
        html.classList.add('motion-ready');
      });

    return () => {
      cancelled = true;
      revert?.();
      if (refresh) window.removeEventListener('load', refresh);
      ambientIo.disconnect();
    };
  }, [pathname]);

  return null;
}
