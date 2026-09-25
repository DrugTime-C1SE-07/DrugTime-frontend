'use client';

import { useMemo, useState } from 'react';
import {
  Activity,
  AlertTriangle,
  ArrowUpRight,
  BarChart3,
  Bell,
  Check,
  ChevronDown,
  ChevronRight,
  Clock3,
  Heart,
  LayoutDashboard,
  LockKeyhole,
  Pill,
  RefreshCw,
  ScanLine,
  Search,
  Settings,
  ShieldAlert,
  ShieldCheck,
  Smartphone,
  Users,
  UsersRound,
  Wifi,
  WifiOff,
  Zap,
} from 'lucide-react';

/* =========================================================
   1. LANDING PAGE
   ========================================================= */
const features = [
  {
    icon: ScanLine,
    title: 'Quét vỉ thuốc',
    text: 'Nhận diện chữ trên vỉ thuốc ngay trên thiết bị để thêm thuốc nhanh và giảm thiểu sai sót khi nhập liệu thủ công.',
    note: 'Hỗ trợ camera & offline',
  },
  {
    icon: Bell,
    title: 'Nhắc nhở thông minh',
    text: 'Thông báo liều uống cục bộ trên thiết bị, âm lượng rõ ràng và tùy chỉnh linh hoạt theo thói quen hằng ngày.',
    note: 'Nhắc uống không cần mạng/Wifi',
  },
  {
    icon: ShieldCheck,
    title: 'Cảnh báo tương tác',
    text: 'Kiểm tra tương tác thuốc, thức ăn theo danh mục thuốc quốc gia và Quyết định 5948/QĐ-BYT của Bộ Y tế.',
    note: 'Cập nhật theo dữ liệu Bộ Y tế',
  },
  {
    icon: Zap,
    title: 'Hỗ trợ AI',
    text: 'Gợi ý bữa ăn phù hợp hồ sơ thuốc để giúp người bệnh dễ dàng hơn mà không thay thế thăm khám hay kê đơn.',
    note: 'Được cố vấn bởi Dược sĩ',
  },
  {
    icon: UsersRound,
    title: 'Kết nối người nhà',
    text: 'Mời người thân chăm sóc mà không làm lộ dữ liệu gia đình; bệnh nhân toàn quyền cấp hoặc thu hồi quyền.',
    note: 'Đồng hành cùng cha mẹ mỗi ngày',
  },
];

const questions = [
  [
    'DrugTime có thay bác sĩ không?',
    'Không. Ứng dụng chỉ hỗ trợ nhắc nhở và tham khảo thông tin tương tác thuốc dựa trên Dược thư Quốc gia. Mọi chỉ định chẩn đoán và điều chỉnh liều lượng bắt buộc phải tuân theo chỉ dẫn của bác sĩ hoặc chuyên gia y tế.',
  ],
  [
    'Người nhà xem được gì khi kết nối?',
    'Người chăm sóc chỉ xem được trạng thái liều uống, cảnh báo bỏ lỡ liều và lịch uống mà người bệnh đã cấp quyền. Người bệnh có thể thay đổi quyền chia sẻ bất cứ lúc nào.',
  ],
  [
    'Có dùng được cho người lớn tuổi không?',
    'Có. Chế độ đơn giản có cỡ chữ lớn, nút xác nhận rõ ràng, độ tương phản cao và giảm các thao tác chạm không cần thiết.',
  ],
  [
    'Nhắc thuốc có cần mạng không?',
    'Không cần. Lịch nhắc được lưu trên thiết bị và dùng thông báo cục bộ, nên vẫn hoạt động khi không có Wi-Fi hoặc 4G.',
  ],
];

function StoreButton({ store, light = false }) {
  return (
    <a
      className={`store-button${light ? ' store-button-light' : ''}`}
      href="#tai-ung-dung"
      onClick={(event) => {
        event.preventDefault();
        document.getElementById('tai-ung-dung')?.scrollIntoView({ behavior: 'smooth' });
      }}
      aria-label={`Tải DrugTime trên ${store}`}
    >
      <span className="store-icon">{store === 'App Store' ? '●' : '▶'}</span>
      <span>
        <small>Tải về từ</small>
        <strong>{store}</strong>
      </span>
    </a>
  );
}

function LandingView({ onOpenAdmin }) {
  const [activeQuestion, setActiveQuestion] = useState(0);
  const [taken, setTaken] = useState(false);
  return (
    <>
      <header className="site-header">
        <a className="brand" href="#top" aria-label="DrugTime - Trang chủ">
          <span className="brand-mark">DT</span>
          <b>DrugTime</b>
        </a>
        <nav aria-label="Điều hướng chính">
          <a href="#tinh-nang">Tính năng</a>
          <a href="#cach-hoat-dong">Cách hoạt động</a>
          <a href="#an-toan-y-khoa">
            An toàn &amp; Pháp lý <i />
          </a>
          <a href="#cau-hoi">Liên hệ &amp; Hỏi đáp</a>
        </nav>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <button
            onClick={onOpenAdmin}
            style={{
              background: '#f0faff',
              color: '#078bc9',
              border: '1px solid #cde9f8',
              padding: '9px 15px',
              borderRadius: 20,
              fontSize: 12,
              fontWeight: 700,
              cursor: 'pointer',
            }}
          >
            Vào Bảng Admin →
          </button>
          <a className="header-cta" href="#tai-ung-dung">
            Tải ứng dụng <ArrowUpRight size={15} />
          </a>
        </div>
      </header>

      <main id="top">
        <section className="hero section-wrap">
          <div className="hero-copy">
            <span className="eyebrow">
              <span className="pulse-dot" />
              Dành cho bệnh nhân Việt Nam và người chăm sóc
            </span>
            <h1>
              Quản lý thuốc <em>an toàn</em> và <em>đúng giờ</em> cho người Việt
            </h1>
            <p>
              DrugTime giúp gia đình theo dõi lịch uống thuốc, phát hiện tương tác thuốc và nhận gợi ý chăm sóc phù
              hợp với hồ sơ thuốc hằng ngày.
            </p>
            <div className="store-row">
              <StoreButton store="App Store" />
              <StoreButton store="Google Play" />
            </div>
            <div className="proof-row">
              <span>
                <Check />
                Giao diện lớn dễ đọc
              </span>
              <span>
                <Check />
                Cảnh báo cho người nhà
              </span>
              <span>
                <Check />
                Dữ liệu phân quyền
              </span>
            </div>
          </div>
          <div className="hero-art" aria-label="Xem trước ứng dụng DrugTime">
            <div className="halo" />
            <div className="phone-float">
              <div className="phone-frame">
                <div className="phone-notch" />
                <div className="phone-screen">
                  <div className="phone-status">
                    <span>08:30</span>
                    <span>Chế độ đơn giản</span>
                  </div>
                  <div className="dose-card">
                    <span className="dose-symbol">
                      <Pill size={25} />
                    </span>
                    <strong>{taken ? 'Liều thuốc đã hoàn tất' : 'Đã đến giờ uống thuốc'}</strong>
                    <small>Metformin 500 mg sau bữa sáng</small>
                    <button onClick={() => setTaken(!taken)}>{taken ? 'Đã uống ✓' : 'Tôi đã uống'}</button>
                  </div>
                  <div className="phone-stats">
                    <div>
                      <b>3</b>
                      <span>liều hôm nay</span>
                    </div>
                    <div>
                      <b>1</b>
                      <span>người nhà kết nối</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <aside className="alert-float">
              <div>
                <span className="alert-dot" />
                Cảnh báo trước khi uống chung
              </div>
              <p>Kiểm tra tương tác thuốc và thực phẩm theo Dược thư Quốc gia Việt Nam.</p>
              <small>
                <b>Cần kiểm tra</b>Thuốc A có thể tương tác với bữa ăn nhiều canxi.
              </small>
            </aside>
            <div className="orbit orbit-one" />
            <div className="orbit orbit-two" />
          </div>
        </section>

        <section className="promise-band">
          <div>
            <span className="section-kicker">Chăm sóc an tâm hơn, mỗi ngày</span>
            <h2>
              Nhắc đúng lúc để người bệnh yên tâm hơn.
              <br />
              <em>Báo đúng người khi một liều thuốc bị bỏ quên.</em>
            </h2>
            <p>Cầu nối chăm sóc tin cậy giữa người lớn tuổi, người bệnh mạn tính và con cái trong gia đình.</p>
          </div>
        </section>

        <section className="features section-wrap" id="tinh-nang">
          <div className="section-heading">
            <span className="section-kicker">Tính năng cốt lõi</span>
            <h2>
              Thiết kế cho lịch thuốc phức tạp
              <br className="desktop-break" /> và gia đình cần theo dõi sát sao
            </h2>
            <p>Mọi công cụ cần thiết để việc chăm sóc mỗi ngày trở nên nhẹ nhàng hơn.</p>
          </div>
          <div className="feature-grid">
            {features.map(({ icon: Icon, title, text, note }, index) => (
              <article className={`feature-card feature-${index + 1}`} key={title}>
                <span className="feature-icon">
                  <Icon size={21} />
                </span>
                <h3>{title}</h3>
                <p>{text}</p>
                <div className="feature-note">
                  {note}
                  <ArrowUpRight size={14} />
                </div>
              </article>
            ))}
          </div>
        </section>

        <section className="steps-section" id="cach-hoat-dong">
          <div className="section-wrap">
            <div className="section-heading">
              <span className="section-kicker">Dễ bắt đầu, dễ duy trì</span>
              <h2>Bắt đầu trong ba bước</h2>
              <p>Đơn giản, trực quan, người cao tuổi hoàn toàn có thể tự thao tác hoặc con cháu cài đặt chỉ trong 2 phút.</p>
            </div>
            <div className="steps-grid">
              <article>
                <b>01</b>
                <h3>Quét hoặc nhập thuốc</h3>
                <p>Thêm thuốc bằng camera tự động nhận diện tên thuốc, hoặc gõ tên đơn thuốc đang dùng.</p>
              </article>
              <article>
                <b>02</b>
                <h3>Xác nhận lịch uống</h3>
                <p>Chọn giờ, liều lượng và kích hoạt chế độ hiển thị đơn giản với cỡ chữ lớn.</p>
              </article>
              <article>
                <b>03</b>
                <h3>Người nhà cùng theo dõi</h3>
                <p>Khi người bệnh bỏ lỡ liều, người chăm sóc nhận tín hiệu kịp thời để gọi điện nhắc nhở.</p>
              </article>
            </div>
          </div>
        </section>

        <section className="safety-section" id="an-toan-y-khoa">
          <div className="section-wrap">
            <div className="section-heading">
              <span className="section-kicker">
                <ShieldCheck size={14} /> An toàn y khoa &amp; Bảo vệ quyền riêng tư
              </span>
              <h2>
                Cảnh báo rõ ràng trước khi
                <br className="desktop-break" /> người bệnh ra quyết định
              </h2>
              <p>DrugTime đặt an toàn sức khỏe lên hàng đầu, giới hạn vai trò AI và tôn trọng quyền bảo mật thông tin cá nhân.</p>
            </div>
            <div className="medical-note">
              <span>
                <Activity size={20} />
              </span>
              <div>
                <b>
                  Lưu ý y khoa bắt buộc <i /> Cấp cứu 115
                </b>
                <p>
                  Thông tin tương tác và gợi ý AI chỉ mang tính chất tham khảo, <strong>không thay thế</strong> chẩn đoán
                  hay chỉ định của bác sĩ điều trị. Khi có dấu hiệu bất thường, hãy liên hệ ngay cơ sở y tế gần nhất.
                </p>
              </div>
            </div>
            <div className="safety-grid">
              <article>
                <ShieldCheck />
                <h3>Bác sĩ là quyết định cuối cùng</h3>
                <p>Chuẩn hóa cơ sở dữ liệu theo Dược thư Quốc gia Việt Nam và Quyết định 5948/QĐ-BYT. Bệnh nhân không tự ý đổi liều lượng.</p>
              </article>
              <article>
                <LockKeyhole />
                <h3>Bảo mật &amp; Tuân thủ PDPL 2025</h3>
                <p>Bảo vệ dữ liệu y tế nhạy cảm. Phân quyền minh bạch và có thể ngắt kết nối bất cứ lúc nào.</p>
              </article>
              <article>
                <WifiOff />
                <h3>Báo thức cục bộ (Offline Alarm)</h3>
                <p>Chuông nhắc nhở lưu trực tiếp trên thiết bị, bảo đảm luôn reo đúng giờ kể cả khi không có mạng.</p>
              </article>
            </div>
          </div>
        </section>

        <section className="faq-section section-wrap" id="cau-hoi">
          <div className="section-heading">
            <span className="section-kicker">DrugTime luôn sẵn sàng giải đáp</span>
            <h2>Câu hỏi thường gặp</h2>
            <p>Giải đáp thắc mắc phổ biến của người bệnh và người chăm sóc khi sử dụng DrugTime.</p>
          </div>
          <div className="faq-list">
            {questions.map(([question, answer], index) => (
              <article className={`faq-item${activeQuestion === index ? ' is-open' : ''}`} key={question}>
                <button
                  aria-expanded={activeQuestion === index}
                  onClick={() => setActiveQuestion(activeQuestion === index ? -1 : index)}
                >
                  <span>{question}</span>
                  <ChevronDown size={18} />
                </button>
                {activeQuestion === index && <p>{answer}</p>}
              </article>
            ))}
          </div>
        </section>

        <section className="download-section" id="tai-ung-dung">
          <div className="download-orb orb-a" />
          <div className="download-orb orb-b" />
          <div className="download-content">
            <span className="download-mark">
              <Smartphone size={19} />
            </span>
            <h2>Tải DrugTime để cả nhà cùng nhớ đúng giờ uống thuốc</h2>
            <p>Hoàn toàn miễn phí trên iOS &amp; Android. Bắt đầu chăm sóc sức khỏe người thân ngay hôm nay.</p>
            <div className="store-row store-row-centered">
              <StoreButton store="App Store" light />
              <StoreButton store="Google Play" light />
            </div>
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <a className="brand" href="#top">
          <span className="brand-mark">DT</span>
          <b>DrugTime</b>
        </a>
        <span>© 2025 DrugTime Vietnam. Bản quyền được bảo hộ.</span>
        <nav>
          <a href="#tinh-nang">Chính sách riêng tư</a>
          <a href="#an-toan-y-khoa">Điều khoản sử dụng</a>
          <a href="#cau-hoi">Thông tin y tế</a>
        </nav>
        <div className="footer-stores">
          <a href="#tai-ung-dung">App Store</a>
          <a href="#tai-ung-dung">Google Play</a>
        </div>
      </footer>
    </>
  );
}

/* =========================================================
   2. ADMIN DASHBOARD
   ========================================================= */
const patients = [
  {
    name: 'Nguyễn Thị Mai',
    id: 'HS 01298',
    medicine: 'Metformin, Amlodipine',
    state: 'Đang theo dõi',
    tone: 'red',
    risk: 'Cao',
    update: '14:34',
  },
  {
    name: 'Trần Văn Phúc',
    id: 'HS 01291',
    medicine: 'Losartan, Aspirin',
    state: 'Bỏ liều',
    tone: 'amber',
    risk: 'Vừa',
    update: '14:33',
  },
  {
    name: 'Lê Minh An',
    id: 'HS 01270',
    medicine: 'Insulin, Atorvastatin',
    state: 'Ổn định',
    tone: 'green',
    risk: 'Thấp',
    update: '14:30',
  },
  {
    name: 'Phạm Thu Hà',
    id: 'HS 01277',
    medicine: 'Warfarin, Omeprazole',
    state: 'Cần gọi lại',
    tone: 'red',
    risk: 'Cao',
    update: '14:31',
  },
];
const alerts = [
  {
    title: 'Tương tác thuốc mới',
    note: 'Có mối cảnh báo Metformin với bệnh nhân dùng thuốc.',
    tone: 'red',
    level: 'Cao',
    icon: ShieldAlert,
  },
  {
    title: 'Bỏ lỡ 2 liều',
    note: 'Ông Phúc chưa xác nhận thuốc huyết áp từ 12:00.',
    tone: 'amber',
    level: 'Vừa',
    icon: Clock3,
  },
  {
    title: 'Gia đình chưa phản hồi',
    note: 'Người nhà chưa xem cảnh báo nguy cơ trong 4 giờ.',
    tone: 'red',
    level: 'Cao',
    icon: Heart,
  },
];
const bars = [74, 84, 61, 91, 79, 54, 86];

function Badge({ children, tone = '' }) {
  return <span className={`pill ${tone}`}>{children}</span>;
}
function Metric({ icon: Icon, value, label, tag, tone = '' }) {
  return (
    <article className="card metric">
      <div className="metric-top">
        <span className={`metric-icon ${tone}`}>
          <Icon size={12} />
        </span>
        <span className={`metric-tag ${tone}`}>{tag}</span>
      </div>
      <strong>{value}</strong>
      <span className="label">{label}</span>
    </article>
  );
}
function Person({ patient, compact = false }) {
  return (
    <div className="person">
      <span className="avatar">{patient.name.slice(0, 1)}</span>
      <span>
        <span className="patient-name">{patient.name}</span>
        {!compact && <span className="patient-meta">{patient.id}</span>}
      </span>
    </div>
  );
}

function AdminDashboardView({ onOpenLanding }) {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState('Tất cả');
  const visiblePatients = useMemo(
    () =>
      patients.filter(
        (patient) =>
          patient.name.toLowerCase().includes(query.toLowerCase()) &&
          (filter === 'Tất cả' || patient.risk === filter)
      ),
    [query, filter]
  );

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand" style={{ cursor: 'pointer' }} onClick={onOpenLanding}>
          <span className="brand-mark">DT</span>
          <span>
            <span className="brand-name">DrugTime</span>
            <span className="brand-sub">← Về Landing Page</span>
          </span>
        </div>
        <nav className="nav" aria-label="Điều hướng chính">
          <button className="active">
            <LayoutDashboard />
            Tổng quan
          </button>
          <button>
            <Users />
            Người bệnh
          </button>
          <button>
            <Pill />
            Lịch thuốc
          </button>
          <button>
            <AlertTriangle />
            Cảnh báo
          </button>
          <button>
            <Heart />
            Gia đình
          </button>
          <button>
            <BarChart3 />
            Báo cáo
          </button>
          <button>
            <Settings />
            Cài đặt
          </button>
        </nav>
        <div className="sync">
          <div className="sync-label">Đồng bộ dữ liệu</div>
          <div className="sync-card">
            <RefreshCw size={14} />
            <span>
              2 phút trước<small>28 thiết bị hoạt động</small>
            </span>
          </div>
        </div>
      </aside>

      <main className="main">
        <div className="mobile-top">
          <div className="brand" onClick={onOpenLanding}>
            <span className="brand-mark">DT</span>
            <span className="brand-name">DrugTime</span>
          </div>
          <button className="count-button" aria-label="3 thông báo">
            3
          </button>
        </div>
        <header className="topline">
          <div className="heading">
            <h1>Bảng điều phối chăm sóc</h1>
            <p>Theo dõi người bệnh, cảnh báo tương tác thuốc và tuân thủ trong hôm nay.</p>
          </div>
          <div className="top-actions">
            <label className="search">
              <Search size={12} />
              <input
                aria-label="Tìm người bệnh"
                placeholder="Tìm người bệnh, thuốc, người nhà"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
              />
            </label>
            <button className="count-button" aria-label="3 cảnh báo">
              3
            </button>
            <button className="icon-button" aria-label="Trạng thái kết nối">
              <Wifi size={13} />
            </button>
          </div>
        </header>
        <div className="mobile-heading heading">
          <h1>Điều phối hôm nay</h1>
          <p>Ưu tiên người bệnh cần nhắc thuốc và cảnh báo tương tác.</p>
        </div>
        <div className="chip-row">
          {['Hôm nay', 'Rủi ro cao', 'Có người nhà', 'Cần xử lý'].map((item, index) => (
            <button
              key={item}
              className={`chip ${index === 1 ? 'red' : index === 2 ? 'green' : index === 3 ? 'amber' : ''}`}
              onClick={() => {
                setFilter(index === 1 ? 'Cao' : 'Tất cả');
              }}
            >
              {item}
            </button>
          ))}
          <span className="spacer" />
          <button className="chip">Thêm người bệnh</button>
        </div>
        <section className="dashboard">
          <div className="metrics">
            <Metric icon={Users} value="284" label="Người bệnh" tag="+12" />
            <Metric icon={BarChart3} value="87.4%" label="Liều đúng giờ" tag="7 ngày" tone="green" />
            <Metric icon={Clock3} value="36" label="Liều bỏ lỡ" tag="Hôm nay" tone="amber" />
            <Metric icon={AlertTriangle} value="9" label="Cảnh báo cao" tag="Ưu tiên" tone="red" />
          </div>
          <section className="card chart-card">
            <div className="section-head">
              <div>
                <h2>Tuân thủ uống thuốc 7 ngày</h2>
                <div className="section-sub">Tỷ lệ xác nhận đúng giờ theo từng ngày</div>
              </div>
              <Badge tone="green">Dữ liệu gần realtime</Badge>
            </div>
            <div className="chart">
              <div className="bars">
                {bars.map((height, index) => (
                  <span
                    key={index}
                    className="bar"
                    style={{
                      height: `${height}%`,
                      background: ['#2674bc', '#16845f', '#a87a10', '#16845f', '#2674bc', '#bc3431', '#16845f'][
                        index
                      ],
                    }}
                  />
                ))}
              </div>
              <div className="chart-days">
                {['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((day) => (
                  <span key={day}>{day}</span>
                ))}
              </div>
            </div>
            <div className="chip-row" style={{ margin: '8px 0 0' }}>
              <Badge tone="green">Đúng giờ</Badge>
              <Badge tone="amber">Trễ liều</Badge>
              <Badge tone="red">Bỏ lỡ</Badge>
            </div>
          </section>
          <section className="card alerts-card">
            <div className="section-head">
              <h2>Cảnh báo cần xử lý</h2>
              <Badge tone="red">9 mục</Badge>
            </div>
            <div className="alert-list">
              {alerts.map(({ title, note, tone, level, icon: Icon }) => (
                <article className="alert" key={title}>
                  <span className={`alert-symbol ${tone === 'amber' ? 'amber' : ''}`}>
                    <Icon size={13} />
                  </span>
                  <span>
                    <strong>{title}</strong>
                    <small>{note}</small>
                  </span>
                  <Badge tone={tone}>{level}</Badge>
                </article>
              ))}
            </div>
          </section>
          <section className="card patients">
            <div className="section-head">
              <div>
                <h2>Người bệnh ưu tiên</h2>
                <div className="section-sub">Sắp xếp theo mức rủi ro và thời điểm cập nhật</div>
              </div>
              <div className="chip-row" style={{ margin: 0 }}>
                {['Tất cả', 'Cao', 'Vừa'].map((item) => (
                  <button
                    key={item}
                    className={`chip ${item === 'Cao' ? 'red' : item === 'Vừa' ? 'amber' : ''}`}
                    onClick={() => setFilter(item)}
                  >
                    {item}
                  </button>
                ))}
              </div>
            </div>
            <table className="table">
              <thead>
                <tr>
                  <th>Người bệnh</th>
                  <th>Thuốc chính</th>
                  <th>Trạng thái</th>
                  <th>Rủi ro</th>
                  <th>Cập nhật</th>
                  <th>Tác vụ</th>
                </tr>
              </thead>
              <tbody>
                {visiblePatients.map((patient) => (
                  <tr key={patient.id}>
                    <td>
                      <Person patient={patient} />
                    </td>
                    <td>{patient.medicine}</td>
                    <td>
                      <Badge tone={patient.tone}>{patient.state}</Badge>
                    </td>
                    <td>
                      <Badge tone={patient.tone}>{patient.risk}</Badge>
                    </td>
                    <td>{patient.update}</td>
                    <td>
                      <button className="detail">Mở</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
          <div className="side-column">
            <section className="card care-card">
              <div className="section-head">
                <h2>Chi tiết nhanh</h2>
                <Badge>Đang mở</Badge>
              </div>
              <div className="care-person">
                <Person patient={patients[0]} />
              </div>
              <div className="section-sub">Dòng thời gian hôm nay</div>
              <div className="timeline" style={{ marginTop: 8 }}>
                <div className="timeline-row">
                  <span className="time">08:00</span>
                  <Check size={12} />
                  Đã xác nhận Metformin
                </div>
                <div className="timeline-row">
                  <span className="time" style={{ background: 'var(--amber-soft)', color: 'var(--amber)' }}>
                    12:00
                  </span>
                  <Clock3 size={12} />
                  Chưa xác nhận Amlodipine
                </div>
                <div className="timeline-row">
                  <span className="time" style={{ background: '#edf1f3', color: 'var(--ink)' }}>
                    18:00
                  </span>
                  <ChevronRight size={12} />
                  Nhắc liều tiếp theo
                </div>
              </div>
              <button className="call">Gọi người nhà</button>
              <div className="motion-note">
                <b>Motion spec</b>
                <br />
                Thời gian card 4px · Drawer trượt tối đa 280ms · Skeleton theo nhịp
              </div>
            </section>
            <section className="card status-card">
              <div className="section-head">
                <h2>Trạng thái</h2>
              </div>
              <div className="status-track">
                <span className="status-segment" />
                <span className="status-segment" />
                <span className="status-segment" />
              </div>
              <div className="status-error">
                Không tải được cảnh báo. Thử lại{' '}
                <button className="detail" onClick={() => location.reload()}>
                  Thử lại
                </button>
              </div>
            </section>
          </div>
        </section>
        <section className="mobile-grid">
          <section className="card">
            <div className="section-head">
              <h2>Cần xử lý trước</h2>
              <Badge tone="red">9 mục</Badge>
            </div>
            <div className="alert-list">
              {alerts.slice(0, 2).map(({ title, note, tone, level, icon: Icon }) => (
                <article className="alert" key={title}>
                  <span className={`alert-symbol ${tone === 'amber' ? 'amber' : ''}`}>
                    <Icon size={13} />
                  </span>
                  <span>
                    <strong>{title}</strong>
                    <small>{note}</small>
                  </span>
                  <Badge tone={tone}>{level}</Badge>
                </article>
              ))}
            </div>
          </section>
          <section className="card">
            <div className="section-head">
              <h2>Người bệnh ưu tiên</h2>
              <button className="detail">Xem tất cả</button>
            </div>
            <div className="mobile-priorities">
              {patients.slice(0, 2).map((patient) => (
                <div className="priority-person" key={patient.id}>
                  <span className="avatar">{patient.name.slice(0, 1)}</span>
                  <span>
                    <span className="patient-name">{patient.name}</span>
                    <span className="patient-meta">{patient.medicine}</span>
                  </span>
                  <span className="spacer" />
                  <Badge tone={patient.tone}>{patient.risk}</Badge>
                  <button className="detail">Chi tiết</button>
                </div>
              ))}
            </div>
          </section>
          <section className="card mobile-status">
            <div className="section-head">
              <h2>Trạng thái</h2>
            </div>
            <div className="status-track">
              <span className="status-segment" />
              <span className="status-segment" />
              <span className="status-segment" />
            </div>
            <div className="status-error">
              Không tải được cảnh báo. Thử lại{' '}
              <button className="detail" onClick={() => location.reload()}>
                Thử lại
              </button>
            </div>
          </section>
        </section>
      </main>
    </div>
  );
}

/* =========================================================
   3. MAIN EXPORT
   ========================================================= */
export default function Page() {
  const [currentView, setCurrentView] = useState('landing');

  return (
    <>
      {currentView === 'landing' ? (
        <LandingView onOpenAdmin={() => setCurrentView('admin')} />
      ) : (
        <AdminDashboardView onOpenLanding={() => setCurrentView('landing')} />
      )}

      {/* Floating Toggle Controls */}
      <div
        style={{
          position: 'fixed',
          bottom: 18,
          right: 18,
          zIndex: 9999,
          display: 'flex',
          gap: 6,
          background: '#101b2c',
          padding: '6px 8px',
          borderRadius: 20,
          boxShadow: '0 8px 24px rgba(0,0,0,0.28)',
        }}
      >
        <button
          onClick={() => setCurrentView('landing')}
          style={{
            border: 0,
            background: currentView === 'landing' ? '#078bc9' : 'transparent',
            color: '#fff',
            padding: '6px 14px',
            borderRadius: 14,
            fontSize: 12,
            fontWeight: 700,
            cursor: 'pointer',
          }}
        >
          Landing Page
        </button>
        <button
          onClick={() => setCurrentView('admin')}
          style={{
            border: 0,
            background: currentView === 'admin' ? '#078bc9' : 'transparent',
            color: '#fff',
            padding: '6px 14px',
            borderRadius: 14,
            fontSize: 12,
            fontWeight: 700,
            cursor: 'pointer',
          }}
        >
          Admin Dashboard
        </button>
      </div>
    </>
  );
}