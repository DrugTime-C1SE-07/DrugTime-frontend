'use client';

import { useEffect, useRef, useState, type CSSProperties } from 'react';
import Icon, { type IconName } from '@/components/ui/Icon';
import { orbitPoint } from '@/lib/motion/orbit';

type Feature = { icon: IconName; name: string; text: string; tone?: 'caution' };

// Copy follows the business decisions listed in 01-requirement (QD-27/28, 40/41, 42, 43).
const FEATURES: Feature[] = [
  { icon: 'bell', name: 'Nhắc đúng giờ', text: 'Chuông reo cả khi mất mạng' },
  { icon: 'scan', name: 'Quét vỉ thuốc', text: 'Camera đọc tên thuốc trên vỉ' },
  { icon: 'alert-triangle', name: 'Cảnh báo tương tác', text: 'Thuốc với thuốc và thức ăn', tone: 'caution' },
  { icon: 'users', name: 'Người nhà theo dõi', text: 'Báo người nhà khi được chia sẻ' },
  { icon: 'chart-column', name: 'Báo cáo tuân thủ', text: 'Uống đúng giờ theo từng tuần' },
  { icon: 'utensils', name: 'Gợi ý món ăn', text: 'Món hợp thuốc, chỉ tham khảo' },
  { icon: 'a-large-small', name: 'Chế độ đơn giản', text: 'Chữ lớn, nút to, dễ bấm' },
];

/**
 * Feature icons orbiting the hero phone. An icon expands into a pill with its name and a short
 * line on mouse hover, keyboard focus or tap; one is open at a time and Escape or a tap outside
 * closes it. The text is always in the DOM, only visually collapsed.
 */
export default function FeatureOrbit() {
  const rootRef = useRef<HTMLUListElement>(null);
  const pointerType = useRef('');
  const [open, setOpen] = useState<number | null>(null);

  useEffect(() => {
    if (open === null) return;
    const onDown = (e: PointerEvent) => {
      if (e.target instanceof Node && !rootRef.current?.contains(e.target)) setOpen(null);
    };
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(null); };
    document.addEventListener('pointerdown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('pointerdown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const closeIf = (i: number) => setOpen((cur) => (cur === i ? null : cur));

  return (
    <ul ref={rootRef} className="feature-orbit" aria-label="Tính năng chính" role="list">
      {FEATURES.map((f, i) => {
        const { x, y, side } = orbitPoint(i, FEATURES.length);
        const isOpen = open === i;
        const style = { '--x': `${x}%`, '--y': `${y}%`, '--i': i } as CSSProperties;
        return (
          <li key={f.name} className={`orbit-item orbit-item--${side}`} style={style} data-depth={(1 + (i % 3) * 0.25).toFixed(2)}>
            <button
              type="button"
              className={f.tone ? `orbit-btn orbit-btn--${f.tone}` : 'orbit-btn'}
              aria-expanded={isOpen}
              onPointerDown={(e) => { pointerType.current = e.pointerType; }}
              onPointerEnter={(e) => { if (e.pointerType === 'mouse') setOpen(i); }}
              onPointerLeave={(e) => { if (e.pointerType === 'mouse') closeIf(i); }}
              onFocus={(e) => { if (e.currentTarget.matches(':focus-visible')) setOpen(i); }}
              onBlur={() => closeIf(i)}
              onClick={() => {
                // A mouse already opened it on hover; taps and keyboard toggle.
                if (pointerType.current !== 'mouse') setOpen((cur) => (cur === i ? null : i));
                pointerType.current = '';
              }}
            >
              <span className="orbit-btn__icon"><Icon name={f.icon} /></span>
              <span className="orbit-btn__text">
                <strong>{f.name}</strong>
                <small>{f.text}</small>
              </span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}
