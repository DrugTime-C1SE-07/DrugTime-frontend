import { siteConfig } from '@/lib/seo/metadata';

export default function StoreButtons({ center = false }: { center?: boolean }) {
  return (
    <div className={center ? 'stores stores--center' : 'stores'}>
      <a className="store store--dark" href={siteConfig.links.appStore} aria-label="Tải về trên App Store">
        <svg className="store__logo" aria-hidden="true"><use href="#logo-apple" /></svg>
        <span className="store__text"><small>Tải về trên</small><strong>App Store</strong></span>
      </a>
      <a className="store store--light" href={siteConfig.links.googlePlay} aria-label="Tải nội dung trên Google Play">
        <svg className="store__logo" aria-hidden="true"><use href="#logo-google-play" /></svg>
        <span className="store__text"><small>TẢI NỘI DUNG TRÊN</small><strong>Google Play</strong></span>
      </a>
    </div>
  );
}
