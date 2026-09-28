import Hero from '@/components/sections/Hero';
import Statement from '@/components/sections/Statement';
import FeatureGrid from '@/components/sections/FeatureGrid';
import HowItWorks from '@/components/sections/HowItWorks';
import Safety from '@/components/sections/Safety';
import FAQ from '@/components/sections/FAQ';
import CTADownload from '@/components/sections/CTADownload';

export default function HomePage() {
  return (
    <>
      <Hero />
      <Statement />
      <FeatureGrid />
      <HowItWorks />
      <Safety />
      <FAQ />
      <CTADownload />
    </>
  );
}
