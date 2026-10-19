import Hero from '@/components/sections/Hero';
import ProofStrip from '@/components/sections/ProofStrip';
import FeatureStory from '@/components/sections/FeatureStory';
import MoreFeatures from '@/components/sections/MoreFeatures';
import HowItWorks from '@/components/sections/HowItWorks';
import Safety from '@/components/sections/Safety';
import FAQ from '@/components/sections/FAQ';
import CTADownload from '@/components/sections/CTADownload';

export default function HomePage() {
  return (
    <>
      <Hero />
      <ProofStrip />
      <FeatureStory />
      <MoreFeatures />
      <HowItWorks />
      <Safety />
      <FAQ />
      <CTADownload />
    </>
  );
}
