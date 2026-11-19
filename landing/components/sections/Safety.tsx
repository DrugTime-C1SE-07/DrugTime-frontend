import Icon, { type IconName } from '@/components/ui/Icon';

const PILLARS: { icon: IconName; title: string; text: string }[] = [
  { icon: 'stethoscope', title: 'Bác sĩ quyết định cuối cùng', text: 'Dữ liệu theo Dược thư Quốc gia; không tự ý đổi liều.' },
  { icon: 'lock', title: 'Bảo mật theo PDPL 2025', text: 'Dữ liệu y tế được phân quyền, ngắt kết nối bất cứ lúc nào.' },
  { icon: 'bell', title: 'Báo thức ngay trên máy', text: 'Chuông vẫn reo đúng giờ khi mất sóng.' },
];

export default function Safety() {
  return (
    <section className="section safety" id="an-toan" aria-labelledby="safety-title">
      <div className="container">
        <header className="section__head">
          <p className="kicker">An toàn &amp; quyền riêng tư</p>
          <h2 className="section__title" id="safety-title" data-split>An toàn y khoa đặt lên hàng đầu</h2>
        </header>

        <ul className="pillars" role="list">
          {PILLARS.map((p) => (
            <li className="pillar" key={p.title} data-spotlight data-tilt data-reveal>
              <span className="tile tile--lg tile--ring"><Icon name={p.icon} /></span>
              <h3 className="pillar__title">{p.title}</h3>
              <p>{p.text}</p>
            </li>
          ))}
        </ul>

        <aside className="medical-note" aria-label="Lưu ý y khoa bắt buộc" data-reveal>
          <span className="tile tile--danger-solid"><Icon name="alert-triangle" /></span>
          <div>
            <p className="medical-note__head">
              <strong>Lưu ý y khoa bắt buộc</strong>
              <a className="badge-115" href="tel:115"><Icon name="phone" size="xs" />Cấp cứu 115</a>
            </p>
            <p>Thông tin tương tác và gợi ý AI chỉ mang tính tham khảo, không thay thế chẩn đoán hay chỉ định của Bác sĩ điều trị. Khi có dấu hiệu bất thường, hãy liên hệ ngay cơ sở y tế gần nhất.</p>
          </div>
        </aside>
      </div>
    </section>
  );
}
