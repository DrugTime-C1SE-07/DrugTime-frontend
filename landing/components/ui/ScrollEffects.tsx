'use client';

import { useEffect } from 'react';

/** Pauses the hero loop off-screen and runs a one-shot reveal on cards. Page works without it. */
export default function ScrollEffects() {
  useEffect(() => {
    if (!('IntersectionObserver' in window)) return;
    const observers: IntersectionObserver[] = [];

    const hero = document.querySelector('.hero');
    if (hero) {
      const heroIo = new IntersectionObserver(([entry]) => hero.classList.toggle('is-paused', !entry.isIntersecting));
      heroIo.observe(hero);
      observers.push(heroIo);
    }

    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!reduceMotion) {
      const targets = document.querySelectorAll<HTMLElement>('.bento .cell, .step, .pillar, .faq__item, .statement > *');
      const io = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          const el = entry.target as HTMLElement;
          el.classList.add('is-in');
          io.unobserve(el);
          // Hand transform back to the hover styles once the reveal has finished.
          setTimeout(() => { el.classList.remove('reveal', 'is-in'); el.style.removeProperty('--delay'); }, 900);
        });
      }, { rootMargin: '0px 0px -10% 0px' });
      targets.forEach((el, i) => {
        el.classList.add('reveal');
        el.style.setProperty('--delay', `${(i % 3) * 80}ms`);
        io.observe(el);
      });
      observers.push(io);
    }

    return () => observers.forEach((o) => o.disconnect());
  }, []);

  return null;
}
