import Icon, { type IconName } from '@/components/ui/Icon';
import StepsLine from '@/components/motion/StepsLine';

const STEPS: { icon: IconName; title: string; text: string }[] = [
  { icon: 'scan', title: 'Quét hoặc nhập thuốc', text: 'Quét vỉ bằng camera hoặc gõ tên thuốc.' },
  { icon: 'calendar-clock', title: 'Chọn giờ uống', text: 'Đặt giờ, liều và bật chế độ chữ lớn.' },
  { icon: 'users', title: 'Mời người nhà', text: 'Gửi mã QR để con cháu cùng theo dõi.' },
];

export default function HowItWorks() {
  return (
    <section className="section steps-section" id="cach-hoat-dong" aria-labelledby="steps-title">
      <div className="container">
        <header className="section__head section__head--center">
          <p className="kicker">Cách hoạt động</p>
          <h2 className="section__title" id="steps-title" data-split>Bắt đầu trong 3 bước</h2>
          <p className="section__lead">Bố mẹ tự làm được, hoặc con cháu cài giúp trong 2 phút.</p>
        </header>
        <div className="steps-wrap">
          <StepsLine />
          <ol className="steps" role="list">
            {STEPS.map((s, i) => (
              <li className="step" key={s.title} data-reveal>
                <span className="step__num" aria-hidden="true">{i + 1}</span>
                <div className="step__card" data-spotlight>
                  <span className="tile tile--lg tile--brand"><Icon name={s.icon} /></span>
                  <h3 className="step__title">{s.title}</h3>
                  <p className="step__text">{s.text}</p>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  );
}
