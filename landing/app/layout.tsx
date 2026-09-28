import type { Metadata, Viewport } from 'next';
import { Inter } from 'next/font/google';
import Navbar from '@/components/layout/Navbar';
import Footer from '@/components/layout/Footer';
import IconSprite from '@/components/ui/IconSprite';
import ScrollEffects from '@/components/ui/ScrollEffects';
import { assets, buildMetadata, siteConfig } from '@/lib/seo/metadata';
import './tokens.css';
import './globals.css';

// Self-hosted at build time — no runtime request to Google Fonts.
const inter = Inter({
  subsets: ['latin', 'vietnamese'],
  weight: ['400', '500', '600', '700'],
  display: 'swap',
  variable: '--font-inter',
});

export const metadata: Metadata = {
  metadataBase: new URL(siteConfig.url),
  ...buildMetadata(),
  icons: { icon: assets.logo, apple: assets.logo },
};

export const viewport: Viewport = {
  themeColor: siteConfig.themeColor,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi" className={inter.variable}>
      <body>
        <IconSprite />
        <a className="skip-link" href="#main">Bỏ qua điều hướng</a>
        <Navbar />
        <main id="main">{children}</main>
        <Footer />
        <ScrollEffects />
      </body>
    </html>
  );
}
