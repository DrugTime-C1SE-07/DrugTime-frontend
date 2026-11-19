import FeatureStory from '@/components/sections/FeatureStory';
import MoreFeatures from '@/components/sections/MoreFeatures';
import HowItWorks from '@/components/sections/HowItWorks';
import CTADownload from '@/components/sections/CTADownload';
import { buildMetadata } from '@/lib/seo/metadata';

export const metadata = buildMetadata({
  title: 'Tính năng',
  description: 'Quét vỉ thuốc, nhắc nhở không cần mạng, cảnh báo tương tác và kết nối người nhà.',
  path: '/features',
});

export default function FeaturesPage() {
  return (
    <>
      <FeatureStory />
      <MoreFeatures />
      <HowItWorks />
      <CTADownload />
    </>
  );
}
