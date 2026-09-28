import Image from 'next/image';
import StoreButtons from '@/components/ui/StoreButtons';
import { assets } from '@/lib/seo/metadata';

export default function CTADownload() {
  return (
    <section className="cta-wrap" id="tai-app" aria-labelledby="cta-title">
      <div className="cta">
        <span className="cta__orb cta__orb--1" aria-hidden="true" />
        <span className="cta__orb cta__orb--2" aria-hidden="true" />
        <span className="cta__ring cta__ring--lg" aria-hidden="true" />
        <span className="cta__ring cta__ring--sm" aria-hidden="true" />
        <span className="mascot-slot mascot-slot--lg cta__mascot" aria-hidden="true">
          <Image src={assets.mascotHappy} alt="" width={360} height={331} sizes="168px" />
        </span>
        <div className="cta__copy">
          <h2 className="cta__title" id="cta-title">
            Tải DrugTime để cả nhà cùng<br className="br-desktop" /> nhớ đúng giờ uống thuốc
          </h2>
          <p className="cta__lead">Hoàn toàn miễn phí trên iOS &amp; Android. Bắt đầu chăm sóc sức khỏe người thân ngay hôm nay.</p>
          <StoreButtons center />
        </div>
      </div>
    </section>
  );
}
