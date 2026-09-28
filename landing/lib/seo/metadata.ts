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
  mascotCooking: "/icons/mascot-cooking.png",
  mascotHappy: "/icons/mascot-happy.png",
} as const;

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
