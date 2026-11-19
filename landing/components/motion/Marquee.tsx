import type { ReactNode } from 'react';

/**
 * Infinite horizontal scroller. The list is rendered twice (copy hidden from assistive tech) so
 * the CSS loop is seamless. It never pauses (product decision, see 01 §9); under
 * prefers-reduced-motion it stands still as a wrapped list.
 */
export default function Marquee({ children, label }: { children: ReactNode; label: string }) {
  return (
    <div className="marquee" role="region" aria-label={label}>
      <div className="marquee__track">
        <ul className="marquee__list" role="list">{children}</ul>
        <ul className="marquee__list" role="list" aria-hidden="true">{children}</ul>
      </div>
    </div>
  );
}
