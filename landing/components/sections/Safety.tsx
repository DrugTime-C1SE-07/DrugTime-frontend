import Icon, { type IconName } from '@/components/ui/Icon';

const PILLARS: { icon: IconName; title: string; text: string }[] = [
  {
    icon: 'stethoscope',
    title: 'Bác sĩ là quyết định cuối cùng',
    text: 'Chuẩn hóa dữ liệu theo Dược thư Quốc gia Việt Nam & Quyết định 5948/QĐ-BYT. Bệnh nhân không tự ý đổi liều lượng.',
  },
  {
    icon: 'lock',
    title: 'Bảo mật & Tuân thủ PDPL 2025',
    text: 'Bảo vệ dữ liệu y tế nhạy cảm theo Nghị định bảo vệ dữ liệu cá nhân. Phân quyền minh bạch, có thể ngắt kết nối bất cứ lúc nào.',
  },
  {
    icon: 'bell',
    title: 'Báo thức cục bộ (Offline Alarm)',
    text: 'Chuông nhắc được lưu và kích hoạt trực tiếp từ hệ thống thiết bị, luôn reo đúng giờ kể cả khi mất sóng hay không có mạng.',
  },
];

export default function Safety() {
  return (
    <section className="section section--surface" id="an-toan" aria-labelledby="safety-title">
      <div className="container split">
        <div className="split__main">
          <p className="eyebrow eyebrow--brand"><Icon name="shield-check" size="sm" />An toàn y khoa &amp; Bảo vệ quyền riêng tư</p>
          <h2 className="section__title" id="safety-title">Cảnh báo rõ ràng trước khi người bệnh ra quyết định</h2>
          <p className="section__lead">DrugTime đặt an toàn sức khỏe lên hàng đầu, giới hạn vai trò AI và tôn trọng tuyệt đối quyền bảo mật thông tin cá nhân.</p>
          <aside className="medical-note" aria-label="Lưu ý y khoa bắt buộc">
            <span className="tile tile--md tile--danger-solid"><Icon name="alert-triangle" /></span>
            <div>
              <p className="medical-note__head"><strong>Lưu ý y khoa bắt buộc</strong> <a className="badge-115" href="tel:115">Cấp cứu 115</a></p>
              <p>Thông tin tương tác và gợi ý AI chỉ mang tính tham khảo, không thay thế chẩn đoán hay chỉ định của Bác sĩ điều trị. Khi có dấu hiệu bất thường, hãy liên hệ ngay cơ sở y tế gần nhất.</p>
            </div>
          </aside>
        </div>
        <ul className="pillars" role="list">
          {PILLARS.map((p) => (
            <li className="pillar" key={p.title}>
              <span className="tile tile--lg tile--brand"><Icon name={p.icon} /></span>
              <div>
                <h3 className="pillar__title">{p.title}</h3>
                <p>{p.text}</p>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
