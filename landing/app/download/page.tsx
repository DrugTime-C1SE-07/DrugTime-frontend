import CTADownload from '@/components/sections/CTADownload';
import { buildMetadata } from '@/lib/seo/metadata';

export const metadata = buildMetadata({
  title: 'Tải ứng dụng',
  description: 'Tải DrugTime miễn phí trên iOS và Android.',
  path: '/download',
});

export default function DownloadPage() {
  return <CTADownload />;
}
