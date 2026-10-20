import type { Metadata } from 'next';
import InviteLink from '@/components/invite/InviteLink';
import { buildMetadata } from '@/lib/seo/metadata';

// Trang đích của link mời người thân. Mã nằm sau dấu # nên server không bao giờ thấy;
// thẻ preview chỉ có nội dung chung, không có mã hay tên ai.
export const metadata: Metadata = {
  ...buildMetadata({
    title: 'Lời mời theo dõi',
    description: 'Mở DrugTime và nhập mã liên kết để theo dõi lịch uống thuốc của người thân.',
    path: '/link',
  }),
  robots: { index: false, follow: false },
};

export default function LinkPage() {
  return <InviteLink />;
}
