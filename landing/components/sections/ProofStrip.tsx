import Icon, { type IconName } from '@/components/ui/Icon';
import Marquee from '@/components/motion/Marquee';
import { formatCount } from '@/lib/motion/format';

const BADGES: { icon: IconName; label: string }[] = [
  { icon: 'stethoscope', label: 'Cố vấn bởi Dược sĩ' },
  { icon: 'shield-check', label: 'Theo Dược thư Quốc gia' },
  { icon: 'check-circle', label: 'QĐ 5948/QĐ-BYT' },
  { icon: 'wifi-off', label: 'Nhắc không cần mạng' },
  { icon: 'lock', label: 'Bảo vệ dữ liệu theo PDPL' },
];

// Only figures already stated elsewhere on the site: free, 2-minute setup, decree number.
const STATS: { value: number; suffix?: string; grouping?: boolean; label: string }[] = [
  { value: 0, suffix: 'đ', label: 'Chi phí sử dụng' },
  { value: 2, suffix: ' phút', label: 'Để cài cho bố mẹ' },
  { value: 5948, grouping: false, label: 'Chuẩn tương tác của Bộ Y Tế' },
];

export default function ProofStrip() {
  return (
    <section className="proof" aria-label="Cơ sở tin cậy">
      <Marquee label="Cơ sở dữ liệu và cam kết">
        {BADGES.map((b) => (
          <li className="badge" key={b.label}><Icon name={b.icon} size="sm" />{b.label}</li>
        ))}
      </Marquee>

      <ul className="container stats" role="list">
        {STATS.map((s) => (
          <li className="stat" key={s.label} data-reveal>
            <span
              className="stat__value"
              data-count={s.value > 0 ? s.value : undefined}
              data-suffix={s.suffix}
              data-grouping={s.grouping === false ? 'false' : undefined}
            >
              {formatCount(s.value, s.suffix, s.grouping !== false)}
            </span>
            <span className="stat__label">{s.label}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
