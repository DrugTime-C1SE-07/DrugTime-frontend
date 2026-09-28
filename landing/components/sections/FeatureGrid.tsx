import Image from 'next/image';
import Icon from '@/components/ui/Icon';
import { assets } from '@/lib/seo/metadata';

/** Features — Bento grid. */
export default function FeatureGrid() {
  return (
    <section className="section section--surface" id="tinh-nang" aria-labelledby="features-title">
      <div className="container">
        <h2 className="section__title section__title--center" id="features-title">
          Thiết kế cho lịch thuốc phức tạp<br className="br-desktop" /> và gia đình cần theo dõi sát sao
        </h2>

        <div className="bento">
          <article className="cell cell--scan">
            <span className="tile tile--lg tile--glass"><Icon name="scan" /></span>
            <h3 className="cell__title cell__title--lg">Quét vỉ thuốc</h3>
            <p className="cell__text">Nhận diện chữ trên vỉ thuốc ngay trên thiết bị để thêm thuốc nhanh và giảm thiểu sai sót khi nhập liệu thủ công.</p>
            <span className="tag tag--glass">Hỗ trợ camera AI offline</span>
            <div className="scan-mock" aria-hidden="true">
              <span className="scan-mock__recognized"><Icon name="check-circle" size="sm" />Metformin 500 mg</span>
              <div className="scan-mock__frame">
                {Array.from({ length: 8 }, (_, i) => <i key={i} />)}
                <span className="scan-mock__beam" />
              </div>
            </div>
          </article>

          <article className="cell cell--reminder">
            <div className="cell__body">
              <h3 className="cell__title">Nhắc nhở thông minh</h3>
              <p className="cell__text">Thông báo liều uống cục bộ, âm lượng rõ ràng, thích ứng với thói quen sinh hoạt hằng ngày.</p>
              <span className="tag tag--brand">Nhắc không cần mạng 4G/Wifi</span>
            </div>
            <div className="clock" aria-hidden="true">
              <Icon name="calendar-clock" size="md" />
              <span>08:30</span>
            </div>
          </article>

          <article className="cell cell--interaction">
            <span className="tile tile--lg tile--on-caution"><Icon name="alert-triangle" /></span>
            <h3 className="cell__title">Cảnh báo tương tác</h3>
            <p className="cell__text">Kiểm tra tương tác thuốc, thức ăn theo Quyết định 5948/QĐ-BYT của Bộ Y Tế.</p>
          </article>

          <article className="cell cell--ai">
            <span className="mascot-slot mascot-slot--sm" aria-hidden="true">
              <Image src={assets.mascotCooking} alt="" width={160} height={146} sizes="88px" />
            </span>
            <h3 className="cell__title">Gợi ý bữa ăn</h3>
            <p className="cell__text">AI gợi ý món ăn phù hợp hồ sơ thuốc, tránh làm giảm hiệu lực thuốc.</p>
          </article>

          <article className="cell cell--family">
            <div className="cell__body">
              <span className="tile tile--lg tile--brand"><Icon name="users" /></span>
              <h3 className="cell__title">Kết nối người nhà</h3>
              <p className="cell__text">Mời người chăm sóc bằng mã QR hoặc mã gia đình để nhận cảnh báo kịp thời mỗi khi người thân bỏ lỡ liều.</p>
            </div>
            <ul className="notifs" role="list" aria-label="Ví dụ thông báo cho người nhà">
              <li className="notif notif--raised">
                <span className="tile tile--sm tile--danger"><Icon name="alert-triangle" size="sm" /></span>
                <span><strong>Mẹ chưa uống liều 08:30</strong><small>Gọi điện nhắc mẹ nhé</small></span>
              </li>
              <li className="notif">
                <span className="tile tile--sm tile--safe"><Icon name="check-circle" size="sm" /></span>
                <span><strong>Bố đã uống liều buổi sáng</strong><small>Đồng hành cùng cha mẹ mỗi ngày</small></span>
              </li>
            </ul>
          </article>

          <article className="cell cell--pharmacist">
            <span className="cell__glow" aria-hidden="true" />
            <span className="tile tile--lg tile--glass"><Icon name="stethoscope" /></span>
            <h3 className="cell__title">Được cố vấn bởi Dược sĩ</h3>
            <p className="cell__text">Dữ liệu tương tác chuẩn hóa theo Dược thư Quốc gia Việt Nam và cập nhật theo dữ liệu Bộ Y Tế.</p>
          </article>
        </div>
      </div>
    </section>
  );
}
