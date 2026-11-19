/**
 * Lazy GSAP loaders. The animation libraries are not part of the initial bundle: components
 * import them after hydration so they never delay the first paint (Lighthouse LCP / TBT).
 * Each loader registers its plugins once and is shared by every caller.
 */
import { MEDIA } from './capabilities';

type GsapModule = typeof import('gsap');
type ScrollTriggerModule = typeof import('gsap/ScrollTrigger');
type SplitTextModule = typeof import('gsap/SplitText');

export type GsapCore = { gsap: GsapModule['gsap']; ScrollTrigger: ScrollTriggerModule['ScrollTrigger'] };

const IDLE_TIMEOUT_MS = 2_000;

let core: Promise<GsapCore> | undefined;
let split: Promise<SplitTextModule['SplitText']> | undefined;

export function loadGsap(): Promise<GsapCore> {
  core ??= Promise.all([import('gsap'), import('gsap/ScrollTrigger')]).then(([g, st]) => {
    g.gsap.registerPlugin(st.ScrollTrigger);
    return { gsap: g.gsap, ScrollTrigger: st.ScrollTrigger };
  });
  return core;
}

/** Resolves once the page has finished loading and the main thread is idle. */
function afterLoadIdle(): Promise<void> {
  return new Promise((resolve) => {
    const idle = () => {
      if ('requestIdleCallback' in window) window.requestIdleCallback(() => resolve(), { timeout: IDLE_TIMEOUT_MS });
      else setTimeout(resolve, 200);
    };
    if (document.readyState === 'complete') idle();
    else window.addEventListener('load', idle, { once: true });
  });
}

/**
 * GSAP for page effects. Desktop loads it right away (the hero headline animates in on load);
 * phones wait for `load` + idle so the libraries stay out of the LCP window on slow networks.
 */
export function loadGsapWhenReady(): Promise<GsapCore> {
  const wait = window.matchMedia(MEDIA.desktop).matches ? Promise.resolve() : afterLoadIdle();
  return wait.then(loadGsap);
}

/** SplitText is only used for desktop headings; phones never download it. */
export function loadSplitText(): Promise<SplitTextModule['SplitText']> {
  split ??= Promise.all([loadGsap(), import('gsap/SplitText')]).then(([{ gsap }, m]) => {
    gsap.registerPlugin(m.SplitText);
    return m.SplitText;
  });
  return split;
}
