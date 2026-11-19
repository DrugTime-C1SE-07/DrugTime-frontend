import type { Metadata, Viewport } from 'next';
import { Inter } from 'next/font/google';
import Navbar from '@/components/layout/Navbar';
import Footer from '@/components/layout/Footer';
import IconSprite from '@/components/ui/IconSprite';
import Grain from '@/components/motion/Grain';
import MotionRoot from '@/components/motion/MotionRoot';
import { assets, buildMetadata, siteConfig } from '@/lib/seo/metadata';
import './tokens.css';
import './globals.css';
import './styles/backdrop.css';
import './styles/hero.css';
import './styles/proof.css';
import './styles/features.css';
import './styles/more.css';
import './styles/steps.css';
import './styles/safety.css';
import './styles/faq.css';
import './styles/cta.css';

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
  icons: { icon: assets.favicon, apple: assets.favicon },
};

export const viewport: Viewport = {
  themeColor: siteConfig.themeColor,
};

// Runs before first paint: lets CSS hold reveal targets in their start state (see globals.css).
const MOTION_FLAG = "if(!matchMedia('(prefers-reduced-motion: reduce)').matches)document.documentElement.classList.add('motion-ok')";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi" className={inter.variable} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: MOTION_FLAG }} />
      </head>
      <body>
        <IconSprite />
        <Grain />
        <a className="skip-link" href="#main">Bỏ qua điều hướng</a>
        <Navbar />
        <main id="main">{children}</main>
        <Footer />
        <MotionRoot />
      </body>
    </html>
  );
}
