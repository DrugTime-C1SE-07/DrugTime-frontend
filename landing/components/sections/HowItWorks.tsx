import Icon, { type IconName } from '@/components/ui/Icon';

const STEPS: { icon: IconName; title: string; text: string }[] = [
  { icon: 'scan', title: 'Quét hoặc nhập thuốc', text: 'Thêm thuốc bằng camera tự động nhận diện tên thuốc, hoặc gõ tên đơn thuốc đang dùng.' },
  { icon: 'calendar-clock', title: 'Xác nhận lịch uống', text: 'Chọn giờ, liều lượng và bật chế độ hiển thị đơn giản với cỡ chữ lớn cho người lớn tuổi.' },
  { icon: 'users', title: 'Người nhà cùng theo dõi', text: 'Khi người bệnh bỏ lỡ liều, người chăm sóc nhận tín hiệu kịp thời để gọi điện nhắc nhở.' },
];

export default function HowItWorks() {
  return (
    <section className="section section--steps" id="cach-hoat-dong" aria-labelledby="steps-title">
      <div className="container">
        <header className="section__head section__head--center">
          <h2 className="section__title" id="steps-title">Bắt đầu trong ba bước</h2>
          <p className="section__lead">Người cao tuổi có thể tự thao tác, hoặc nhờ con cháu cài đặt chỉ trong 2 phút.</p>
        </header>
        <ol className="steps" role="list">
          {STEPS.map((s, i) => (
            <li className="step" key={s.title}>
              <span className="step__num" aria-hidden="true">{i + 1}</span>
              <div className="step__card">
                <span className="tile tile--lg tile--brand"><Icon name={s.icon} /></span>
                <h3 className="step__title">{s.title}</h3>
                <p className="step__text">{s.text}</p>
              </div>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
