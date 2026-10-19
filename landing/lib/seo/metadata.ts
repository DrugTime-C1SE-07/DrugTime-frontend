import type { Metadata } from "next";

/**
 * Cấu hình chung của site. Điền link thật trước khi ra mắt:
 * appStore / googlePlay / contactEmail đang để trống.
 */
export const siteConfig = {
  name: "DrugTime",
  url: process.env.NEXT_PUBLIC_SITE_URL ?? "https://drugtime.vn",
  title: "DrugTime — Nhắc uống thuốc đúng giờ cho người Việt",
  description:
    "DrugTime giúp gia đình theo dõi lịch uống thuốc, phát hiện tương tác thuốc và báo cho người nhà khi một liều bị bỏ quên.",
  themeColor: "#01554F",
  links: {
    appStore:
      "https://apps.apple.com/vn/app/free-fire-x-naruto-shippuden/id1300146617?l=vi",
    googlePlay:
      "https://play.google.com/store/apps/details?id=com.dts.freefireth&hl=vi",
    contactEmail: "mailto:phucnguyenngoc2005@gmail.com",
  },
} as const;

/**
 * Ảnh trong public/icons — gom về một chỗ để đổi tên file chỉ cần sửa tại đây.
 * Tên file phải là ASCII: bộ tối ưu ảnh của Next.js trả 400 với tên có dấu tiếng Việt.
 */
export const assets = {
  logo: "/icons/logo.png",
  /** 192px quantised copy of the logo (~10 KB) for favicon / touch icon; the original is 411 KB. */
  favicon: "/images/logo-192.png",
  mascotHappy: "/icons/mascot-happy.png",
  mascotThinking: "/icons/mascot-thinking.png",
  mascotProtect: "/icons/mascot-protect.png",
  appHome: "/images/trangchu.png",
} as const;

/** iPhone 3D trong hero — scene xuất từ Spline (Export › Code › React). */
export const SPLINE_SCENE_URL = "https://prod.spline.design/HPxIP0ufwvPd0zHS/scene.splinecode";

type PageMeta = { title?: string; description?: string; path?: string };

export function buildMetadata({
  title,
  description,
  path = "/",
}: PageMeta = {}): Metadata {
  const fullTitle = title ? `${title} | ${siteConfig.name}` : siteConfig.title;
  const desc = description ?? siteConfig.description;
  return {
    title: fullTitle,
    description: desc,
    alternates: { canonical: path },
    openGraph: {
      type: "website",
      locale: "vi_VN",
      siteName: siteConfig.name,
      title: fullTitle,
      description: desc,
      url: path,
      images: [{ url: assets.logo }],
    },
  };
}
