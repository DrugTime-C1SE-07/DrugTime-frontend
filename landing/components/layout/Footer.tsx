import Image from 'next/image';
import Link from 'next/link';
import { assets, siteConfig } from '@/lib/seo/metadata';

export default function Footer() {
  return (
    <footer className="footer">
      <div className="container">
        <div className="footer__top">
          <p className="footer__line">Nhớ đúng giờ, cả nhà yên tâm.</p>
          <nav className="footer__links" aria-label="Liên kết pháp lý">
            <Link href="/privacy-policy">Chính sách riêng tư</Link>
            <Link href="/terms">Điều khoản sử dụng</Link>
            <Link href="/privacy-policy#dong-y">Thông tin đồng ý theo mục đích</Link>
            <a href={siteConfig.links.appStore}>App Store</a>
            <a href={siteConfig.links.googlePlay}>Google Play</a>
          </nav>
        </div>
        <span className="footer__mark" aria-hidden="true" data-fill>DrugTime</span>
        <p className="footer__copy">
          <Image className="brand__logo brand__logo--sm" src={assets.logo} alt="" width={32} height={32} />
          © 2026 DrugTime Vietnam. Bản quyền được bảo hộ.
        </p>
      </div>
    </footer>
  );
}
