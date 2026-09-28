import LegalPage from '@/components/sections/LegalPage';
import { buildMetadata } from '@/lib/seo/metadata';

export const metadata = buildMetadata({ title: 'Điều khoản sử dụng', path: '/terms' });

export default function TermsPage() {
  return <LegalPage title="Điều khoản sử dụng" />;
}
