'use client';

import { useEffect, useRef, useState } from 'react';
import Icon, { type IconName } from '@/components/ui/Icon';
import { MEDIA } from '@/lib/motion/capabilities';
import { loadGsapWhenReady } from '@/lib/motion/gsap';

type ChapterKey = 'remind' | 'scan' | 'interaction' | 'family';

const CHAPTERS: { key: ChapterKey; icon: IconName; title: string; text: string; tag: string }[] = [
  {
    key: 'remind', icon: 'bell', tag: 'Báo thức ngay trên máy',
    title: 'Nhắc đúng giờ, kể cả offline',
    text: 'Chuông reo to, rõ ngay trên máy, không cần 4G hay Wi-Fi.',
  },
  {
    key: 'scan', icon: 'scan', tag: 'Nhận diện trên thiết bị',
    title: 'Quét vỉ, thêm thuốc nhanh',
    text: 'Camera đọc tên thuốc trên vỉ ngay trên máy, bớt gõ tay, bớt sai sót.',
  },
  {
    key: 'interaction', icon: 'alert-triangle', tag: 'Theo dữ liệu Bộ Y Tế',
    title: 'Cảnh báo tương tác thuốc',
    text: 'Kiểm tra thuốc với thuốc và thức ăn theo QĐ 5948/QĐ-BYT, báo trước khi uống.',
  },
  {
    key: 'family', icon: 'users', tag: 'Kết nối bằng mã QR',
    title: 'Người nhà cùng theo dõi',
    text: 'Mời con cháu bằng mã QR. Lỡ liều là người nhà nhận báo để gọi nhắc.',
  },
];

/** Decorative app screens; the chapter text carries the meaning, so these are hidden from AT. */
function Screen({ kind }: { kind: ChapterKey }) {
  switch (kind) {
    case 'remind':
      return (
        <div className="screen screen--remind" aria-hidden="true">
          <span className="mock-time">08:30</span>
          <span className="mock-bell"><span className="tile"><Icon name="bell" size="lg" /></span></span>
          <span className="mock-pill"><Icon name="pill" size="sm" />Metformin 500 mg</span>
          <span className="mock-btn"><Icon name="check" size="sm" />Tôi đã uống</span>
        </div>
      );
    case 'scan':
      return (
        <div className="screen screen--scan" aria-hidden="true">
          <span className="mock-found"><Icon name="check-circle" size="sm" />Metformin 500 mg</span>
          <span className="mock-frame">
            {Array.from({ length: 9 }, (_, i) => <i key={i} />)}
            <span className="mock-beam" />
          </span>
        </div>
      );
    case 'interaction':
      return (
        <div className="screen screen--interaction" aria-hidden="true">
          <span className="mock-row">
            <span className="mock-chip">Thuốc A</span>
            <span className="mock-chip mock-chip--x">×</span>
            <span className="mock-chip">Sữa</span>
          </span>
          <span className="mock-alert">
            <strong><Icon name="alert-triangle" size="sm" />Cần chú ý</strong>
            Uống cách bữa nhiều canxi 2 giờ.
          </span>
        </div>
      );
    case 'family':
      return (
        <div className="screen screen--family" aria-hidden="true">
          <span className="mock-notif">
            <span className="tile tile--sm tile--danger"><Icon name="bell" size="sm" /></span>
            <span><strong>Mẹ chưa uống liều 08:30</strong><small>Gọi nhắc mẹ nhé</small></span>
          </span>
          <span className="mock-notif">
            <span className="tile tile--sm tile--safe"><Icon name="check-circle" size="sm" /></span>
            <span><strong>Bố đã uống liều sáng</strong><small>Lúc 07:45</small></span>
          </span>
          <span className="mock-qr" />
        </div>
      );
  }
}

/**
 * Four-chapter feature story. Desktop with motion: the section pins and the phone screen and
 * chapter text crossfade with scroll progress. Everywhere else: stacked cards (CSS default).
 */
export default function FeatureStory() {
  const ref = useRef<HTMLElement>(null);
  const [active, setActive] = useState(0);

  useEffect(() => {
    const section = ref.current;
    if (!section || window.matchMedia(MEDIA.reduce).matches) return;

    let cancelled = false;
    let revert: (() => void) | undefined;
    loadGsapWhenReady()
      .then(({ gsap }) => {
        if (cancelled) return;
        const ctx = gsap.context(() => {
          const mm = gsap.matchMedia();
          mm.add({ reduce: MEDIA.reduce, desktop: MEDIA.desktop }, (c) => {
            const { reduce, desktop } = c.conditions as Record<string, boolean>;
            if (reduce || !desktop) return;

            const chapters = gsap.utils.toArray<HTMLElement>('.chapter', section);
            const screens = gsap.utils.toArray<HTMLElement>('.device .screen', section);
            const fill = section.querySelector<HTMLElement>('.progress__fill');
            section.classList.add('is-pinned');

            gsap.set(chapters.slice(1), { opacity: 0, y: 60 });
            gsap.set(screens.slice(1), { opacity: 0, yPercent: 12, scale: 0.94 });

            const tl = gsap.timeline({
              defaults: { ease: 'power2.inOut', duration: 1 },
              scrollTrigger: {
                trigger: section,
                start: 'top top',
                end: () => `+=${window.innerHeight * (CHAPTERS.length - 1) * 0.9}`,
                pin: true,
                scrub: 0.8,
                anticipatePin: 1,
                invalidateOnRefresh: true,
                onUpdate: (self) => {
                  fill?.style.setProperty('--p', self.progress.toFixed(3));
                  setActive(Math.min(CHAPTERS.length - 1, Math.round(self.progress * (CHAPTERS.length - 1))));
                },
              },
            });

            for (let i = 1; i < CHAPTERS.length; i++) {
              tl.to(chapters[i - 1], { opacity: 0, y: -60 }, i)
                .to(chapters[i], { opacity: 1, y: 0 }, i)
                .to(screens[i - 1], { opacity: 0, yPercent: -10, scale: 0.94 }, i)
                .to(screens[i], { opacity: 1, yPercent: 0, scale: 1 }, i);
            }

            return () => {
              section.classList.remove('is-pinned');
              fill?.style.removeProperty('--p');
            };
          });
        }, section);
        revert = () => ctx.revert();
      })
      .catch((error: unknown) => console.warn('[features] motion unavailable; showing stacked chapters.', error));

    return () => {
      cancelled = true;
      revert?.();
    };
  }, []);

  return (
    <section ref={ref} className="section story" id="tinh-nang" aria-labelledby="features-title">
      <div className="ambient" aria-hidden="true">
        <span className="ambient__dots" />
        <span className="ambient__orb ambient__orb--brand" style={{ left: '-8%', top: '10%' }} />
        <span className="ambient__orb ambient__orb--accent" style={{ right: '-6%', bottom: '0%' }} />
      </div>
      <div className="container">
        <header className="section__head">
          <p className="kicker">Tính năng</p>
          <h2 className="section__title" id="features-title" data-split>Mọi thứ bố mẹ cần, trong một ứng dụng</h2>
        </header>

        <div className="story__layout">
          <div className="story__device">
            <span className="story__glow" aria-hidden="true" />
            <div className="device" data-tilt>
              <span className="device__island" aria-hidden="true" />
              <div className="device__screens">
                {CHAPTERS.map((c) => <Screen key={c.key} kind={c.key} />)}
              </div>
            </div>
            <div className="progress" aria-hidden="true">
              <span className="progress__rail"><span className="progress__fill" /></span>
              <span className="progress__dots">
                {CHAPTERS.map((c, i) => <span key={c.key} className={i === active ? 'progress__dot is-active' : 'progress__dot'} />)}
              </span>
            </div>
          </div>

          <ol className="chapters" role="list">
            {CHAPTERS.map((c, i) => (
              <li className="chapter" key={c.key} data-reveal="mobile">
                <div>
                  <span className="chapter__index">0{i + 1} / 0{CHAPTERS.length}</span>
                  <h3 className="chapter__title">{c.title}</h3>
                  <p className="chapter__text">{c.text}</p>
                  <span className="chapter__tag"><Icon name={c.icon} size="sm" />{c.tag}</span>
                </div>
                <div className="chapter__mini device">
                  <div className="device__screens"><Screen kind={c.key} /></div>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  );
}
