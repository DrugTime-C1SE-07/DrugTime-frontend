import StoreButtons from '@/components/ui/StoreButtons';
import FeatureOrbit from '@/components/hero/FeatureOrbit';
import HeroMotion from '@/components/hero/HeroMotion';
import SplinePhone from '@/components/hero/SplinePhone';

export default function Hero() {
  return (
    <section className="hero" aria-labelledby="hero-title" data-nav-dark data-ambient>
      <div className="aurora" aria-hidden="true">
        <span className="aurora__blob aurora__blob--1" />
        <span className="aurora__blob aurora__blob--2" />
        <span className="aurora__blob aurora__blob--3" />
        <span className="aurora__blob aurora__blob--4" />
        <span className="aurora__cursor" />
        <span className="aurora__grid" />
      </div>

      <div className="container hero__inner">
        <div className="hero__copy" data-hero-copy>
          <p className="chip-glass"><span className="pulse-dot" aria-hidden="true" />Miễn phí trên iOS &amp; Android</p>
          <h1 className="hero__title" id="hero-title" data-split="load">
            Uống thuốc đúng giờ. <span className="hero__accent">Cả nhà yên tâm.</span>
          </h1>
          <p className="hero__lead">
            Nhắc liều đúng lúc, cảnh báo tương tác thuốc và báo người nhà khi lỡ một liều.
          </p>
          <StoreButtons onDark />
        </div>

        <HeroMotion>
          <div className="stage__orbit" aria-hidden="true" data-depth="0.3">
            <span className="orbit orbit--lg"><span className="orbit__dot" /></span>
            <span className="orbit orbit--sm"><span className="orbit__dot" /></span>
          </div>
          <div className="stage__phone" data-depth="0.6">
            <SplinePhone />
          </div>
          <FeatureOrbit />
        </HeroMotion>
      </div>
    </section>
  );
}
