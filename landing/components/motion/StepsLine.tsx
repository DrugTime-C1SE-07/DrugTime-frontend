'use client';

import { useEffect, useRef } from 'react';
import { MEDIA } from '@/lib/motion/capabilities';
import { loadGsapWhenReady } from '@/lib/motion/gsap';

const WAVE = 'M0 40 C 130 0, 230 80, 333 40 S 540 0, 666 40 S 870 80, 1000 40';

/** Wavy connector between the three steps; draws itself as the section scrolls by (desktop). */
export default function StepsLine() {
  const ref = useRef<SVGSVGElement>(null);

  useEffect(() => {
    const svg = ref.current;
    if (!svg || window.matchMedia(MEDIA.reduce).matches) return;

    let cancelled = false;
    let revert: (() => void) | undefined;
    loadGsapWhenReady()
      .then(({ gsap }) => {
        if (cancelled) return;
        const ctx = gsap.context(() => {
          gsap.fromTo(svg, { '--draw': 1 }, {
            '--draw': 0, ease: 'none',
            scrollTrigger: { trigger: svg.parentElement, start: 'top 75%', end: 'bottom 60%', scrub: 0.8 },
          });
        });
        revert = () => ctx.revert();
      })
      .catch((error: unknown) => console.warn('[steps] motion unavailable; line shown in full.', error));

    return () => {
      cancelled = true;
      revert?.();
    };
  }, []);

  return (
    <svg ref={ref} className="steps__line" viewBox="0 0 1000 80" preserveAspectRatio="none" aria-hidden="true">
      <path className="steps__line-ghost" d={WAVE} pathLength={1} />
      <path d={WAVE} pathLength={1} />
    </svg>
  );
}
