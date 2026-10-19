'use client';

import { useEffect, useRef, useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import Icon from '@/components/ui/Icon';
import { assets } from '@/lib/seo/metadata';

// Absolute "/#…" so the links also work from sub-pages.
const NAV_LINKS = [
  { href: '/#tinh-nang', label: 'Tính năng' },
  { href: '/#cach-hoat-dong', label: 'Cách hoạt động' },
  { href: '/#an-toan', label: 'An toàn' },
  { href: '/#hoi-dap', label: 'Hỏi đáp' },
];

const SHOW_ALWAYS_ABOVE = 120; // px from the top where the bar never hides

/**
 * Floating pill navbar. Hides while scrolling down, returns on scroll up, and switches to its
 * glass-on-dark look while it sits over a section marked [data-nav-dark] (the hero).
 */
export default function Navbar() {
  const [open, setOpen] = useState(false);
  const [hidden, setHidden] = useState(false);
  const [onDark, setOnDark] = useState(false);
  const toggleRef = useRef<HTMLButtonElement>(null);
  const pathname = usePathname();

  useEffect(() => {
    let lastY = window.scrollY;
    let ticking = false;
    const update = () => {
      const y = window.scrollY;
      if (y < SHOW_ALWAYS_ABOVE) setHidden(false);
      else if (y > lastY + 4) setHidden(true);
      else if (y < lastY - 4) setHidden(false);
      lastY = y;

      const dark = document.querySelector('[data-nav-dark]');
      setOnDark(dark ? dark.getBoundingClientRect().bottom > 48 : false);
      ticking = false;
    };
    const onScroll = () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(update);
    };
    update();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, [pathname]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { setOpen(false); toggleRef.current?.focus(); }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open]);

  const close = () => setOpen(false);
  const cls = ['site-header', hidden && !open && 'is-hidden', onDark && !open && 'is-dark'].filter(Boolean).join(' ');

  return (
    <header className={cls} id="top">
      <div className={open ? 'nav is-open' : 'nav'}>
        <Link className="brand" href="/#top" aria-label="DrugTime — về đầu trang">
          <Image className="brand__logo" src={assets.logo} alt="" width={36} height={36} priority />
          <span className="brand__name">DrugTime</span>
        </Link>
        <nav className="nav__links" id="nav-links" aria-label="Điều hướng chính">
          {NAV_LINKS.map((l) => (
            <Link key={l.href} href={l.href} onClick={close}>{l.label}</Link>
          ))}
          <Link className="btn btn--primary nav__cta-mobile" href="/#tai-app" onClick={close}>Tải ngay</Link>
        </nav>
        <Link className="btn btn--primary shine nav__cta" href="/#tai-app" data-magnetic>
          Tải ngay <Icon name="arrow-right" size="sm" />
        </Link>
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
    </header>
  );
}
