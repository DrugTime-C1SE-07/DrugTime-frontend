'use client';

import { useMemo, useState } from 'react';
import { AlertTriangle, ChartNoAxesColumnIncreasing, Check, ChevronRight, Clock3, Heart, LayoutDashboard, Pill, RefreshCw, Search, Settings, ShieldAlert, Users, Wifi } from 'lucide-react';

const patients = [
  { name: 'Nguyễn Thị Mai', id: 'HS 01298', medicine: 'Metformin, Amlodipine', state: 'Đang theo dõi', tone: 'red', risk: 'Cao', update: '14:34' },
  { name: 'Trần Văn Phúc', id: 'HS 01291', medicine: 'Losartan, Aspirin', state: 'Bỏ liều', tone: 'amber', risk: 'Vừa', update: '14:33' },
  { name: 'Lê Minh An', id: 'HS 01270', medicine: 'Insulin, Atorvastatin', state: 'Ổn định', tone: 'green', risk: 'Thấp', update: '14:30' },
  { name: 'Phạm Thu Hà', id: 'HS 01277', medicine: 'Warfarin, Omeprazole', state: 'Cần gọi lại', tone: 'red', risk: 'Cao', update: '14:31' },
];
const alerts = [
  { title: 'Tương tác thuốc mới', note: 'Có mối cảnh báo Metformin với bệnh nhân dùng thuốc.', tone: 'red', level: 'Cao', icon: ShieldAlert },
  { title: 'Bỏ lỡ 2 liều', note: 'Ông Phúc chưa xác nhận thuốc huyết áp từ 12:00.', tone: 'amber', level: 'Vừa', icon: Clock3 },
  { title: 'Gia đình chưa phản hồi', note: 'Người nhà chưa xem cảnh báo nguy cơ trong 4 giờ.', tone: 'red', level: 'Cao', icon: Heart },
];
const bars = [74, 84, 61, 91, 79, 54, 86];

function Badge({ children, tone = '' }) { return <span className={`pill ${tone}`}>{children}</span>; }
function Metric({ icon: Icon, value, label, tag, tone = '' }) { return <article className="card metric"><div className="metric-top"><span className={`metric-icon ${tone}`}><Icon size={12}/></span><span className={`metric-tag ${tone}`}>{tag}</span></div><strong>{value}</strong><span className="label">{label}</span></article>; }
function Person({ patient, compact = false }) { return <div className="person"><span className="avatar">{patient.name.slice(0, 1)}</span><span><span className="patient-name">{patient.name}</span>{!compact && <span className="patient-meta">{patient.id}</span>}</span></div>; }

export default function AdminDashboard() {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState('Tất cả');
  const visiblePatients = useMemo(() => patients.filter((patient) => patient.name.toLowerCase().includes(query.toLowerCase()) && (filter === 'Tất cả' || patient.risk === filter)), [query, filter]);

  return <div className="shell">
    <aside className="sidebar">
      <div className="brand"><span className="brand-mark">DT</span><span><span className="brand-name">DrugTime</span><span className="brand-sub">Điều phối chăm sóc</span></span></div>
      <nav className="nav" aria-label="Điều hướng chính">
        <button className="active"><LayoutDashboard/>Tổng quan</button><button><Users/>Người bệnh</button><button><Pill/>Lịch thuốc</button><button><AlertTriangle/>Cảnh báo</button><button><Heart/>Gia đình</button><button><ChartNoAxesColumnIncreasing/>Báo cáo</button><button><Settings/>Cài đặt</button>
      </nav>
      <div className="sync"><div className="sync-label">Đồng bộ dữ liệu</div><div className="sync-card"><RefreshCw size={14}/><span>2 phút trước<small>28 thiết bị hoạt động</small></span></div></div>
    </aside>

    <main className="main">
      <div className="mobile-top"><div className="brand"><span className="brand-mark">DT</span><span className="brand-name">DrugTime</span></div><button className="count-button" aria-label="3 thông báo">3</button></div>
      <header className="topline"><div className="heading"><h1>Bảng điều phối chăm sóc</h1><p>Theo dõi người bệnh, cảnh báo tương tác thuốc và tuân thủ trong hôm nay.</p></div><div className="top-actions"><label className="search"><Search size={12}/><input aria-label="Tìm người bệnh" placeholder="Tìm người bệnh, thuốc, người nhà" value={query} onChange={(event) => setQuery(event.target.value)}/></label><button className="count-button" aria-label="3 cảnh báo">3</button><button className="icon-button" aria-label="Trạng thái kết nối"><Wifi size={13}/></button></div></header>
      <div className="mobile-heading heading"><h1>Điều phối hôm nay</h1><p>Ưu tiên người bệnh cần nhắc thuốc và cảnh báo tương tác.</p></div>
      <div className="chip-row">{['Hôm nay', 'Rủi ro cao', 'Có người nhà', 'Cần xử lý'].map((item, index) => <button key={item} className={`chip ${index === 1 ? 'red' : index === 2 ? 'green' : index === 3 ? 'amber' : ''}`} onClick={() => { setFilter(index === 1 ? 'Cao' : 'Tất cả'); }}>{item}</button>)}<span className="spacer"/><button className="chip">Thêm người bệnh</button></div>
      <section className="dashboard">
        <div className="metrics"><Metric icon={Users} value="284" label="Người bệnh" tag="+12"/><Metric icon={ChartNoAxesColumnIncreasing} value="87.4%" label="Liều đúng giờ" tag="7 ngày" tone="green"/><Metric icon={Clock3} value="36" label="Liều bỏ lỡ" tag="Hôm nay" tone="amber"/><Metric icon={AlertTriangle} value="9" label="Cảnh báo cao" tag="Ưu tiên" tone="red"/></div>
        <section className="card chart-card"><div className="section-head"><div><h2>Tuân thủ uống thuốc 7 ngày</h2><div className="section-sub">Tỷ lệ xác nhận đúng giờ theo từng ngày</div></div><Badge tone="green">Dữ liệu gần realtime</Badge></div><div className="chart"><div className="bars">{bars.map((height, index) => <span key={index} className="bar" style={{height: `${height}%`, background: ['#2674bc','#16845f','#a87a10','#16845f','#2674bc','#bc3431','#16845f'][index]}}/>)}</div><div className="chart-days">{['T2','T3','T4','T5','T6','T7','CN'].map(day => <span key={day}>{day}</span>)}</div></div><div className="chip-row" style={{margin:'8px 0 0'}}><Badge tone="green">Đúng giờ</Badge><Badge tone="amber">Trễ liều</Badge><Badge tone="red">Bỏ lỡ</Badge></div></section>
        <section className="card alerts-card"><div className="section-head"><h2>Cảnh báo cần xử lý</h2><Badge tone="red">9 mục</Badge></div><div className="alert-list">{alerts.map(({title,note,tone,level,icon:Icon}) => <article className="alert" key={title}><span className={`alert-symbol ${tone === 'amber' ? 'amber' : ''}`}><Icon size={13}/></span><span><strong>{title}</strong><small>{note}</small></span><Badge tone={tone}>{level}</Badge></article>)}</div></section>
        <section className="card patients"><div className="section-head"><div><h2>Người bệnh ưu tiên</h2><div className="section-sub">Sắp xếp theo mức rủi ro và thời điểm cập nhật</div></div><div className="chip-row" style={{margin:0}}>{['Tất cả','Cao','Vừa'].map(item => <button key={item} className={`chip ${item === 'Cao' ? 'red' : item === 'Vừa' ? 'amber' : ''}`} onClick={() => setFilter(item)}>{item}</button>)}</div></div><table className="table"><thead><tr><th>Người bệnh</th><th>Thuốc chính</th><th>Trạng thái</th><th>Rủi ro</th><th>Cập nhật</th><th>Tác vụ</th></tr></thead><tbody>{visiblePatients.map((patient) => <tr key={patient.id}><td><Person patient={patient}/></td><td>{patient.medicine}</td><td><Badge tone={patient.tone}>{patient.state}</Badge></td><td><Badge tone={patient.tone}>{patient.risk}</Badge></td><td>{patient.update}</td><td><button className="detail">Mở</button></td></tr>)}</tbody></table></section>
        <div className="side-column"><section className="card care-card"><div className="section-head"><h2>Chi tiết nhanh</h2><Badge>Đang mở</Badge></div><div className="care-person"><Person patient={patients[0]}/></div><div className="section-sub">Dòng thời gian hôm nay</div><div className="timeline" style={{marginTop:8}}><div className="timeline-row"><span className="time">08:00</span><Check size={12}/>Đã xác nhận Metformin</div><div className="timeline-row"><span className="time" style={{background:'var(--amber-soft)',color:'var(--amber)'}}>12:00</span><Clock3 size={12}/>Chưa xác nhận Amlodipine</div><div className="timeline-row"><span className="time" style={{background:'#edf1f3',color:'var(--ink)'}}>18:00</span><ChevronRight size={12}/>Nhắc liều tiếp theo</div></div><button className="call">Gọi người nhà</button><div className="motion-note"><b>Motion spec</b><br/>Thời gian card 4px · Drawer trượt tối đa 280ms · Skeleton theo nhịp</div></section><section className="card status-card"><div className="section-head"><h2>Trạng thái</h2></div><div className="status-track"><span className="status-segment"/><span className="status-segment"/><span className="status-segment"/></div><div className="status-error">Không tải được cảnh báo. Thử lại <button className="detail" onClick={() => location.reload()}>Thử lại</button></div></section></div>
      </section>
      <section className="mobile-grid"><section className="card"><div className="section-head"><h2>Cần xử lý trước</h2><Badge tone="red">9 mục</Badge></div><div className="alert-list">{alerts.slice(0,2).map(({title,note,tone,level,icon:Icon}) => <article className="alert" key={title}><span className={`alert-symbol ${tone === 'amber' ? 'amber' : ''}`}><Icon size={13}/></span><span><strong>{title}</strong><small>{note}</small></span><Badge tone={tone}>{level}</Badge></article>)}</div></section><section className="card"><div className="section-head"><h2>Người bệnh ưu tiên</h2><button className="detail">Xem tất cả</button></div><div className="mobile-priorities">{patients.slice(0,2).map(patient => <div className="priority-person" key={patient.id}><span className="avatar">{patient.name.slice(0,1)}</span><span><span className="patient-name">{patient.name}</span><span className="patient-meta">{patient.medicine}</span></span><span className="spacer"/><Badge tone={patient.tone}>{patient.risk}</Badge><button className="detail">Chi tiết</button></div>)}</div></section><section className="card mobile-status"><div className="section-head"><h2>Trạng thái</h2></div><div className="status-track"><span className="status-segment"/><span className="status-segment"/><span className="status-segment"/></div><div className="status-error">Không tải được cảnh báo. Thử lại <button className="detail" onClick={() => location.reload()}>Thử lại</button></div></section></section>
    </main>
  </div>;
}
