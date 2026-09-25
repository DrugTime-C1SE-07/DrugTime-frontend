import './globals.css';

export const metadata = {
  title: 'DrugTime — Quản lý thuốc an toàn & đúng giờ',
  description: 'Theo dõi lịch uống thuốc, nhận cảnh báo tương tác và kết nối người thân chăm sóc.',
};

export default function RootLayout({ children }) {
  return (
    <html lang="vi">
      <body>{children}</body>
    </html>
  );
}