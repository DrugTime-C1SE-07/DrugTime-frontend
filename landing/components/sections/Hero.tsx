import Icon from '@/components/ui/Icon';
import StoreButtons from '@/components/ui/StoreButtons';

export default function Hero() {
  return (
    <section className="hero" aria-labelledby="hero-title">
      <div className="hero__decor" aria-hidden="true">
        <span className="blob blob--1" /><span className="blob blob--2" /><span className="blob blob--3" />
        <span className="capsule capsule--1" /><span className="capsule capsule--2" />
        <span className="capsule capsule--3" /><span className="capsule capsule--4" />
        <span className="spark spark--1" /><span className="spark spark--2" />
        <span className="spark spark--3" /><span className="spark spark--4" />
      </div>

      <div className="hero__copy">
        <p className="eyebrow"><Icon name="heart-pulse" size="sm" />Dành cho bệnh nhân Việt Nam và người chăm sóc</p>
        <h1 className="hero__title" id="hero-title">
          <span className="hero__line">Quản lý thuốc an toàn và</span>
          <span className="hero__line"><mark className="hl">đúng giờ</mark> cho người Việt</span>
        </h1>
        <p className="hero__lead">
          DrugTime giúp gia đình theo dõi lịch uống thuốc, phát hiện tương tác thuốc và nhận gợi ý chăm sóc phù hợp với hồ sơ thuốc hằng ngày.
        </p>

        <StoreButtons />

        <ul className="checks" role="list">
          {['Giao diện lớn dễ đọc', 'Cảnh báo cho người nhà', 'Dữ liệu được phân quyền'].map((t) => (
            <li key={t}><span className="checks__dot"><Icon name="check" size="xs" /></span>{t}</li>
          ))}
        </ul>
      </div>

      {/* Product stage: the reminder screen + floating proof cards */}
      <div className="stage" aria-label="Minh hoạ màn hình nhắc thuốc của DrugTime">
        <svg className="stage__ecg" viewBox="0 0 1152 440" preserveAspectRatio="none" aria-hidden="true">
          <polyline className="ecg ecg--1" points="0,330 250,330 280,330 300,296 322,372 344,260 366,330 520,330" />
          <polyline className="ecg ecg--2" points="640,330 790,330 812,300 834,360 856,330 1152,330" />
        </svg>
        <span className="stage__ring stage__ring--lg" aria-hidden="true" />
        <span className="stage__ring stage__ring--sm" aria-hidden="true" />

        <article className="float-card float-card--alert">
          <header className="float-card__head">
            <span className="tile tile--sm tile--caution"><Icon name="alert-triangle" size="sm" /></span>
            <strong>Cảnh báo trước khi uống chung</strong>
          </header>
          <div className="float-card__note">
            <span className="float-card__label">Cần kiểm tra</span>
            Thuốc A có thể tương tác với bữa ăn nhiều canxi.
          </div>
        </article>

        <div className="phone-card" role="img" aria-label="Màn hình: Đã đến giờ uống thuốc — Metformin 500 mg sau bữa sáng">
          <div className="phone-card__top">
            <span className="phone-card__time">08:30</span>
            <span className="pill-tag">Chế độ đơn giản</span>
          </div>
          <div className="bell">
            <span className="bell__halo bell__halo--outer" />
            <span className="bell__halo bell__halo--inner" />
            <span className="tile tile--xl tile--brand bell__tile"><Icon name="bell" size="lg" /></span>
          </div>
          <p className="phone-card__title">Đã đến giờ uống thuốc</p>
          <p className="phone-card__dose"><Icon name="pill" size="sm" />Metformin 500 mg sau bữa sáng</p>
          <span className="taken" aria-hidden="true">
            <Icon name="check" />
            <span className="taken__labels">
              <span className="taken__label taken__label--todo">Tôi đã uống</span>
              <span className="taken__label taken__label--done">Đã uống lúc 08:30</span>
            </span>
          </span>
          <div className="phone-card__stats">
            <span><b>3</b>liều hôm nay</span>
            <span><b>1</b>người nhà kết nối</span>
          </div>
        </div>

        <article className="float-card float-card--family">
          <header className="float-card__head">
            <span className="tile tile--sm tile--brand"><Icon name="users" size="sm" /></span>
            <strong>Người nhà cùng theo dõi</strong>
          </header>
          <p className="float-card__text">Khi bỏ lỡ liều, người chăm sóc nhận tín hiệu kịp thời để gọi điện nhắc nhở.</p>
        </article>

        <span className="chip chip--dark chip--offline"><Icon name="bell" size="sm" />Nhắc không cần 4G/Wifi</span>
        <span className="chip chip--light chip--byt"><Icon name="shield-check" size="sm" />Theo dữ liệu Bộ Y Tế</span>
      </div>
    </section>
  );
}
