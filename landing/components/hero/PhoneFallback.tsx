import Image from 'next/image';
import { assets } from '@/lib/seo/metadata';

/**
 * CSS iPhone showing the real app home screen. It is the hero's LCP image and stays in place
 * whenever the Spline scene is not shown (mobile, reduced motion, data saver, load failure).
 */
export default function PhoneFallback() {
  return (
    <div className="iphone">
      <span className="iphone__island" aria-hidden="true" />
      <div className="iphone__screen">
        <Image
          src={assets.appHome}
          alt="Màn hình trang chủ DrugTime: tiến độ uống thuốc hôm nay và lịch các liều"
          width={754}
          height={1628}
          sizes="(min-width: 1024px) 300px, 260px"
          priority
        />
      </div>
      <span className="iphone__glare" aria-hidden="true" />
    </div>
  );
}
