import './globals.css';

export const metadata = {
  title: 'DrugTime | Bảng điều phối chăm sóc',
  description: 'Theo dõi người bệnh, lịch thuốc và cảnh báo chăm sóc.',
};

export default function RootLayout({ children }) {
  return (
    <html lang="vi">
      <body>{children}</body>
    </html>
  );
}
