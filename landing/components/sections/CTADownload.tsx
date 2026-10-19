import Image from 'next/image';
import StoreButtons from '@/components/ui/StoreButtons';
import { assets } from '@/lib/seo/metadata';

export default function CTADownload() {
  return (
    <section className="cta-wrap" id="tai-app" aria-labelledby="cta-title">
      <div className="cta" data-spotlight data-zoom data-ambient>
        <div className="aurora" aria-hidden="true">
          <span className="aurora__blob aurora__blob--1" />
          <span className="aurora__blob aurora__blob--3" />
          <span className="aurora__grid" />
        </div>
        <Image className="cta__mascot cta__mascot--left" src={assets.mascotProtect} alt="" width={1315} height={1197} sizes="130px" />
        <Image className="cta__mascot" src={assets.mascotHappy} alt="" width={1303} height={1207} sizes="180px" />
        <div className="cta__copy">
          <h2 className="cta__title" id="cta-title" data-split>Bắt đầu nhắc thuốc cho cả nhà</h2>
          <p className="cta__lead">Miễn phí trên iOS &amp; Android.</p>
          <StoreButtons center onDark />
        </div>
      </div>
    </section>
  );
}
