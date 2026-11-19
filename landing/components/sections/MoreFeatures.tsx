'use client';

import { useEffect, useState } from 'react';
import Icon, { type IconName } from '@/components/ui/Icon';
import { MEDIA } from '@/lib/motion/capabilities';

type Tone = 'ocean' | 'sun' | 'rose' | 'teal' | 'indigo';
type Item = { icon: IconName; tone: Tone; title: string; text: string; tag?: string };

// Copy follows the business decisions listed in 01-requirement:
// QD-42 (no adherence figures), QD-40/41 (curated menu, no "AI", reference only),
// QD-27/28 (relatives only view, with consent), QD-43, QD-36.
const ITEMS: Item[] = [
  { icon: 'chart-column', tone: 'ocean', title: 'Báo cáo tuân thủ', text: 'Xem tỷ lệ uống thuốc và uống đúng giờ theo từng tuần.' },
  { icon: 'utensils', tone: 'sun', title: 'Gợi ý món ăn hợp thuốc', text: 'Thực đơn đã kiểm duyệt, hợp hồ sơ thuốc và dị ứng.', tag: 'Chỉ tham khảo' },
  { icon: 'users', tone: 'rose', title: 'Theo dõi nhiều người thân', text: 'Xem lịch uống của bố, mẹ khi họ đồng ý chia sẻ.' },
  { icon: 'a-large-small', tone: 'teal', title: 'Chế độ đơn giản', text: 'Chữ lớn, nút to cho người lớn tuổi tự dùng.' },
  { icon: 'search', tone: 'indigo', title: 'Tra cứu thuốc', text: 'Tìm và chọn thuốc từ danh mục khi thêm thuốc mới.' },
];

/**
 * "More features" row. Desktop: expanding cards — the active one widens and reveals its text;
 * hover, keyboard focus or a tap changes it. Below 1024px every card is open (no toggling).
 */
export default function MoreFeatures() {
  const [active, setActive] = useState(0);
  const [desktop, setDesktop] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia(MEDIA.desktop);
    const sync = () => setDesktop(mq.matches);
    sync();
    mq.addEventListener('change', sync);
    return () => mq.removeEventListener('change', sync);
  }, []);

  return (
    <section className="section more" aria-labelledby="more-title">
      <div className="ambient" aria-hidden="true">
        <span className="ambient__dots" />
      </div>
      <div className="container">
        <header className="section__head section__head--center">
          <p className="kicker">Còn nhiều hơn thế</p>
          <h2 className="section__title" id="more-title" data-split>Thêm tiện ích cho cả nhà</h2>
        </header>

        <ul className="more-cards" role="list">
          {ITEMS.map((item, i) => {
            const open = !desktop || active === i;
            return (
              <li
                key={item.title}
                className={`more-card more-card--${item.tone}${open ? ' is-open' : ''}`}
                data-reveal
                data-spotlight
                onPointerEnter={(e) => { if (desktop && e.pointerType === 'mouse') setActive(i); }}
              >
                <span className="more-card__art" aria-hidden="true"><Icon name={item.icon} /></span>
                <h3 className="more-card__heading">
                  <button
                    type="button"
                    className="more-card__trigger"
                    aria-expanded={desktop ? open : undefined}
                    onClick={() => { if (desktop) setActive(i); }}
                    onFocus={() => { if (desktop) setActive(i); }}
                  >
                    <span className="more-card__icon"><Icon name={item.icon} size="md" /></span>
                    <span className="more-card__title">{item.title}</span>
                  </button>
                </h3>
                <div className="more-card__body">
                  <p>{item.text}</p>
                  {item.tag && <span className="chapter__tag">{item.tag}</span>}
                </div>
              </li>
            );
          })}
        </ul>
      </div>
    </section>
  );
}
