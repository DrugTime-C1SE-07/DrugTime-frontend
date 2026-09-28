import type { MetadataRoute } from 'next';
import { siteConfig } from '@/lib/seo/metadata';

const ROUTES = ['', '/features', '/download', '/privacy-policy', '/terms'];

export default function sitemap(): MetadataRoute.Sitemap {
  return ROUTES.map((path) => ({
    url: `${siteConfig.url}${path}`,
    lastModified: new Date(),
    changeFrequency: 'monthly',
    priority: path === '' ? 1 : 0.6,
  }));
}
