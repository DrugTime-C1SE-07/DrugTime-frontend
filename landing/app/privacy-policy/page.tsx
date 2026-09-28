import LegalPage from '@/components/sections/LegalPage';
import { buildMetadata } from '@/lib/seo/metadata';

export const metadata = buildMetadata({ title: 'Chính sách riêng tư', path: '/privacy-policy' });

export default function PrivacyPolicyPage() {
  return (
    <LegalPage title="Chính sách riêng tư">
      <p className="section__lead">Nội dung đang được cập nhật.</p>
      <h2 className="pillar__title" id="dong-y">Thông tin đồng ý theo mục đích</h2>
      <p className="section__lead">Nội dung đang được cập nhật.</p>
    </LegalPage>
  );
}
