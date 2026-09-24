'use client';

import { useState } from 'react';
import { Activity, ArrowUpRight, Bell, Check, ChevronDown, LockKeyhole, Pill, ScanLine, ShieldCheck, Smartphone, UsersRound, WifiOff, Zap } from 'lucide-react';

const features = [
  { icon: ScanLine, title: 'Quét vỉ thuốc', text: 'Nhận diện chữ trên vỉ thuốc ngay trên thiết bị để thêm thuốc nhanh và giảm thiểu sai sót khi nhập liệu thủ công.', note: 'Hỗ trợ camera & offline' },
  { icon: Bell, title: 'Nhắc nhở thông minh', text: 'Thông báo liều uống cục bộ trên thiết bị, âm lượng rõ ràng và tùy chỉnh linh hoạt theo thói quen hằng ngày.', note: 'Nhắc uống không cần mạng/Wifi' },
  { icon: ShieldCheck, title: 'Cảnh báo tương tác', text: 'Kiểm tra tương tác thuốc, thức ăn theo danh mục thuốc quốc gia và Quyết định 5948/QĐ-BYT của Bộ Y tế.', note: 'Cập nhật theo dữ liệu Bộ Y tế' },
  { icon: Zap, title: 'Hỗ trợ AI', text: 'Gợi ý bữa ăn phù hợp hồ sơ thuốc để giúp người bệnh dễ dàng hơn mà không thay thế thăm khám hay kê đơn.', note: 'Được cố vấn bởi Dược sĩ' },
  { icon: UsersRound, title: 'Kết nối người nhà', text: 'Mời người thân chăm sóc mà không làm lộ dữ liệu gia đình; bệnh nhân toàn quyền cấp hoặc thu hồi quyền.', note: 'Đồng hành cùng cha mẹ mỗi ngày' },
];

const questions = [
  ['DrugTime có thay bác sĩ không?', 'Không. Ứng dụng chỉ hỗ trợ nhắc nhở và tham khảo thông tin tương tác thuốc dựa trên Dược thư Quốc gia. Mọi chỉ định chẩn đoán và điều chỉnh liều lượng bắt buộc phải tuân theo chỉ dẫn của bác sĩ hoặc chuyên gia y tế.'],
  ['Người nhà xem được gì khi kết nối?', 'Người chăm sóc chỉ xem được trạng thái liều uống, cảnh báo bỏ lỡ liều và lịch uống mà người bệnh đã cấp quyền. Người bệnh có thể thay đổi quyền chia sẻ bất cứ lúc nào.'],
  ['Có dùng được cho người lớn tuổi không?', 'Có. Chế độ đơn giản có cỡ chữ lớn, nút xác nhận rõ ràng, độ tương phản cao và giảm các thao tác chạm không cần thiết.'],
  ['Nhắc thuốc có cần mạng không?', 'Không cần. Lịch nhắc được lưu trên thiết bị và dùng thông báo cục bộ, nên vẫn hoạt động khi không có Wi-Fi hoặc 4G.'],
];

function StoreButton({ store, light = false }) {
  return <a className={`store-button${light ? ' store-button-light' : ''}`} href="#tai-ung-dung" onClick={(event) => { event.preventDefault(); document.getElementById('tai-ung-dung')?.scrollIntoView({ behavior: 'smooth' }); }} aria-label={`Tải DrugTime trên ${store}`}>
    <span className="store-icon">{store === 'App Store' ? '●' : '▶'}</span><span><small>Tải về từ</small><strong>{store}</strong></span>
  </a>;
}

export default function LandingPage() {
  const [activeQuestion, setActiveQuestion] = useState(0);
  const [taken, setTaken] = useState(false);
  return <>
    <header className="site-header">
      <a className="brand" href="#top" aria-label="DrugTime - Trang chủ"><span className="brand-mark">DT</span><b>DrugTime</b></a>
      <nav aria-label="Điều hướng chính"><a href="#tinh-nang">Tính năng</a><a href="#cach-hoat-dong">Cách hoạt động</a><a href="#an-toan-y-khoa">An toàn &amp; Pháp lý <i /></a><a href="#cau-hoi">Liên hệ &amp; Hỏi đáp</a></nav>
      <a className="header-cta" href="#tai-ung-dung">Tải ứng dụng <ArrowUpRight size={15} /></a>
    </header>

    <main id="top">
      <section className="hero section-wrap">
        <div className="hero-copy">
          <span className="eyebrow"><span className="pulse-dot" />Dành cho bệnh nhân Việt Nam và người chăm sóc</span>
          <h1>Quản lý thuốc <em>an toàn</em> và <em>đúng giờ</em> cho người Việt</h1>
          <p>DrugTime giúp gia đình theo dõi lịch uống thuốc, phát hiện tương tác thuốc và nhận gợi ý chăm sóc phù hợp với hồ sơ thuốc hằng ngày.</p>
          <div className="store-row"><StoreButton store="App Store" /><StoreButton store="Google Play" /></div>
          <div className="proof-row"><span><Check />Giao diện lớn dễ đọc</span><span><Check />Cảnh báo cho người nhà</span><span><Check />Dữ liệu phân quyền</span></div>
        </div>
        <div className="hero-art" aria-label="Xem trước ứng dụng DrugTime">
          <div className="halo" />
          <div className="phone-float"><div className="phone-frame"><div className="phone-notch" /><div className="phone-screen">
            <div className="phone-status"><span>08:30</span><span>Chế độ đơn giản</span></div>
            <div className="dose-card"><span className="dose-symbol"><Pill size={25} /></span><strong>{taken ? 'Liều thuốc đã hoàn tất' : 'Đã đến giờ uống thuốc'}</strong><small>Metformin 500 mg sau bữa sáng</small><button onClick={() => setTaken(!taken)}>{taken ? 'Đã uống ✓' : 'Tôi đã uống'}</button></div>
            <div className="phone-stats"><div><b>3</b><span>liều hôm nay</span></div><div><b>1</b><span>người nhà kết nối</span></div></div>
          </div></div></div>
          <aside className="alert-float"><div><span className="alert-dot" />Cảnh báo trước khi uống chung</div><p>Kiểm tra tương tác thuốc và thực phẩm theo Dược thư Quốc gia Việt Nam.</p><small><b>Cần kiểm tra</b>Thuốc A có thể tương tác với bữa ăn nhiều canxi.</small></aside>
          <div className="orbit orbit-one" /><div className="orbit orbit-two" />
        </div>
      </section>

      <section className="promise-band"><div><span className="section-kicker">Chăm sóc an tâm hơn, mỗi ngày</span><h2>Nhắc đúng lúc để người bệnh yên tâm hơn.<br /><em>Báo đúng người khi một liều thuốc bị bỏ quên.</em></h2><p>Cầu nối chăm sóc tin cậy giữa người lớn tuổi, người bệnh mạn tính và con cái trong gia đình.</p></div></section>

      <section className="features section-wrap" id="tinh-nang"><div className="section-heading"><span className="section-kicker">Tính năng cốt lõi</span><h2>Thiết kế cho lịch thuốc phức tạp<br className="desktop-break" /> và gia đình cần theo dõi sát sao</h2><p>Mọi công cụ cần thiết để việc chăm sóc mỗi ngày trở nên nhẹ nhàng hơn.</p></div>
        <div className="feature-grid">{features.map(({ icon: Icon, title, text, note }, index) => <article className={`feature-card feature-${index + 1}`} key={title}><span className="feature-icon"><Icon size={21} /></span><h3>{title}</h3><p>{text}</p><div className="feature-note">{note}<ArrowUpRight size={14} /></div></article>)}</div>
      </section>

      <section className="steps-section" id="cach-hoat-dong"><div className="section-wrap"><div className="section-heading"><span className="section-kicker">Dễ bắt đầu, dễ duy trì</span><h2>Bắt đầu trong ba bước</h2><p>Đơn giản, trực quan, người cao tuổi hoàn toàn có thể tự thao tác hoặc con cháu cài đặt chỉ trong 2 phút.</p></div><div className="steps-grid"><article><b>01</b><h3>Quét hoặc nhập thuốc</h3><p>Thêm thuốc bằng camera tự động nhận diện tên thuốc, hoặc gõ tên đơn thuốc đang dùng.</p></article><article><b>02</b><h3>Xác nhận lịch uống</h3><p>Chọn giờ, liều lượng và kích hoạt chế độ hiển thị đơn giản với cỡ chữ lớn.</p></article><article><b>03</b><h3>Người nhà cùng theo dõi</h3><p>Khi người bệnh bỏ lỡ liều, người chăm sóc nhận tín hiệu kịp thời để gọi điện nhắc nhở.</p></article></div></div></section>

      <section className="safety-section" id="an-toan-y-khoa"><div className="section-wrap"><div className="section-heading"><span className="section-kicker"><ShieldCheck size={14} /> An toàn y khoa &amp; Bảo vệ quyền riêng tư</span><h2>Cảnh báo rõ ràng trước khi<br className="desktop-break" /> người bệnh ra quyết định</h2><p>DrugTime đặt an toàn sức khỏe lên hàng đầu, giới hạn vai trò AI và tôn trọng quyền bảo mật thông tin cá nhân.</p></div>
        <div className="medical-note"><span><Activity size={20} /></span><div><b>Lưu ý y khoa bắt buộc <i /> Cấp cứu 115</b><p>Thông tin tương tác và gợi ý AI chỉ mang tính chất tham khảo, <strong>không thay thế</strong> chẩn đoán hay chỉ định của bác sĩ điều trị. Khi có dấu hiệu bất thường, hãy liên hệ ngay cơ sở y tế gần nhất.</p></div></div>
        <div className="safety-grid"><article><ShieldCheck /><h3>Bác sĩ là quyết định cuối cùng</h3><p>Chuẩn hóa cơ sở dữ liệu theo Dược thư Quốc gia Việt Nam và Quyết định 5948/QĐ-BYT. Bệnh nhân không tự ý đổi liều lượng.</p></article><article><LockKeyhole /><h3>Bảo mật &amp; Tuân thủ PDPL 2025</h3><p>Bảo vệ dữ liệu y tế nhạy cảm. Phân quyền minh bạch và có thể ngắt kết nối bất cứ lúc nào.</p></article><article><WifiOff /><h3>Báo thức cục bộ (Offline Alarm)</h3><p>Chuông nhắc nhở lưu trực tiếp trên thiết bị, bảo đảm luôn reo đúng giờ kể cả khi không có mạng.</p></article></div>
      </div></section>

      <section className="faq-section section-wrap" id="cau-hoi"><div className="section-heading"><span className="section-kicker">DrugTime luôn sẵn sàng giải đáp</span><h2>Câu hỏi thường gặp</h2><p>Giải đáp thắc mắc phổ biến của người bệnh và người chăm sóc khi sử dụng DrugTime.</p></div><div className="faq-list">{questions.map(([question, answer], index) => <article className={`faq-item${activeQuestion === index ? ' is-open' : ''}`} key={question}><button aria-expanded={activeQuestion === index} onClick={() => setActiveQuestion(activeQuestion === index ? -1 : index)}><span>{question}</span><ChevronDown size={18} /></button>{activeQuestion === index && <p>{answer}</p>}</article>)}</div></section>

      <section className="download-section" id="tai-ung-dung"><div className="download-orb orb-a" /><div className="download-orb orb-b" /><div className="download-content"><span className="download-mark"><Smartphone size={19} /></span><h2>Tải DrugTime để cả nhà cùng nhớ đúng giờ uống thuốc</h2><p>Hoàn toàn miễn phí trên iOS &amp; Android. Bắt đầu chăm sóc sức khỏe người thân ngay hôm nay.</p><div className="store-row store-row-centered"><StoreButton store="App Store" light /><StoreButton store="Google Play" light /></div></div></section>
    </main>

    <footer className="site-footer"><a className="brand" href="#top"><span className="brand-mark">DT</span><b>DrugTime</b></a><span>© 2025 DrugTime Vietnam. Bản quyền được bảo hộ.</span><nav><a href="#tinh-nang">Chính sách riêng tư</a><a href="#an-toan-y-khoa">Điều khoản sử dụng</a><a href="#cau-hoi">Thông tin y tế</a></nav><div className="footer-stores"><a href="#tai-ung-dung">App Store</a><a href="#tai-ung-dung">Google Play</a></div></footer>
  </>;
}
