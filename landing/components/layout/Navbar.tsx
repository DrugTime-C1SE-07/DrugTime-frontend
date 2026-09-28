'use client';

import { useEffect, useRef, useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import Icon from '@/components/ui/Icon';
import { assets } from '@/lib/seo/metadata';

// Absolute "/#…" so the links also work from sub-pages.
const NAV_LINKS = [
  { href: '/#tinh-nang', label: 'Tính năng' },
  { href: '/#cach-hoat-dong', label: 'Cách hoạt động' },
  { href: '/#an-toan', label: 'An toàn & Pháp lý' },
  { href: '/#hoi-dap', label: 'Hỏi đáp' },
];

/** N12 — banner + nav. Banner retracts on scroll-down, returns on scroll-up. */
export default function Navbar() {
  const [open, setOpen] = useState(false);
  const [compact, setCompact] = useState(false);
  const headerRef = useRef<HTMLElement>(null);
  const bannerRef = useRef<HTMLDivElement>(null);
  const toggleRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const header = headerRef.current;
    const banner = bannerRef.current;
    if (!header || !banner) return;
    const syncBannerHeight = () => header.style.setProperty('--banner-h', `${banner.offsetHeight}px`);
    syncBannerHeight();

    let lastY = window.scrollY;
    let ticking = false;
    const onScroll = () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => {
        const y = window.scrollY;
        if (y < 48) setCompact(false);
        else if (y > lastY + 4) setCompact(true);
        else if (y < lastY - 4) setCompact(false);
        lastY = y;
        ticking = false;
      });
    };
    window.addEventListener('resize', syncBannerHeight, { passive: true });
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      window.removeEventListener('resize', syncBannerHeight);
      window.removeEventListener('scroll', onScroll);
    };
  }, []);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { setOpen(false); toggleRef.current?.focus(); }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open]);

  const close = () => setOpen(false);

  return (
    <header ref={headerRef} className={compact ? 'site-header is-compact' : 'site-header'} id="top">
      <div className="banner" ref={bannerRef}>
        <p className="banner__text">
          <span className="banner__dot" aria-hidden="true" />
          Miễn phí trên iOS &amp; Android<span className="banner__more"> · Chuông nhắc vẫn reo khi mất mạng</span>
          <Link className="banner__link" href="/#tai-app">Tải ngay <Icon name="arrow-right" size="sm" /></Link>
        </p>
      </div>
      <div className={open ? 'nav is-open' : 'nav'}>
        <div className="nav__inner">
          <Link className="brand" href="/#top" aria-label="DrugTime — về đầu trang">
            <Image className="brand__logo" src={assets.logo} alt="" width={40} height={40} priority />
            <span className="brand__name">DrugTime</span>
          </Link>
          <nav className="nav__links" id="nav-links" aria-label="Điều hướng chính">
            {NAV_LINKS.map((l) => (
              <Link key={l.href} href={l.href} onClick={close}>{l.label}</Link>
            ))}
            <Link className="btn btn--primary nav__cta-mobile" href="/#tai-app" onClick={close}>Tải ngay</Link>
          </nav>
          <Link className="btn btn--primary nav__cta" href="/#tai-app">Tải ngay</Link>
          <button
            ref={toggleRef}
            className="icon-btn nav__toggle"
            type="button"
            aria-expanded={open}
            aria-controls="nav-links"
            aria-label={open ? 'Đóng menu' : 'Mở menu'}
            onClick={() => setOpen((v) => !v)}
          >
            <Icon name="menu" className="icon--open" />
            <Icon name="x" className="icon--close" />
          </button>
        </div>
      </div>
    </header>
  );
}
