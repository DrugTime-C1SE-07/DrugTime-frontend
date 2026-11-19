import { siteConfig } from '@/lib/seo/metadata';

type Props = { center?: boolean; onDark?: boolean };

export default function StoreButtons({ center = false, onDark = false }: Props) {
  const cls = ['stores', center && 'stores--center', onDark && 'stores--on-dark'].filter(Boolean).join(' ');
  return (
    <div className={cls}>
      <a className="store store--dark shine" href={siteConfig.links.appStore} data-magnetic>
        <svg className="store__logo" aria-hidden="true"><use href="#logo-apple" /></svg>
        <span className="store__text"><small>Tải về trên </small><strong>App Store</strong></span>
      </a>
      <a className="store store--light shine" href={siteConfig.links.googlePlay} data-magnetic>
        <svg className="store__logo" aria-hidden="true"><use href="#logo-google-play" /></svg>
        <span className="store__text"><small>Tải nội dung trên </small><strong>Google Play</strong></span>
      </a>
    </div>
  );
}
