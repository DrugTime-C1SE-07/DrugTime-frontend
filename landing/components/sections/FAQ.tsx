'use client';

import { useState } from 'react';
import Icon from '@/components/ui/Icon';
import { siteConfig } from '@/lib/seo/metadata';

// Only the first answer comes from Figma; the other three were written from facts elsewhere
// on the page — confirm with the product team.
const FAQS = [
  {
    q: 'DrugTime có thay bác sĩ không?',
    a: 'Không. Ứng dụng chỉ hỗ trợ nhắc nhở và tham khảo thông tin tương tác thuốc dựa trên Dược thư Quốc gia. Mọi chỉ định chẩn đoán và điều chỉnh liều lượng bắt buộc phải tuân theo chỉ dẫn của Bác sĩ.',
  },
  {
    q: 'Người nhà xem được gì khi kết nối?',
    a: 'Người chăm sóc nhận tín hiệu khi người bệnh bỏ lỡ liều để kịp gọi điện nhắc nhở. Quyền xem dữ liệu được phân quyền minh bạch, và người bệnh có thể ngắt kết nối bất cứ lúc nào.',
  },
  {
    q: 'Có dùng được cho người lớn tuổi không?',
    a: 'Có. Chế độ hiển thị đơn giản dùng cỡ chữ lớn, nút bấm rõ ràng. Người cao tuổi có thể tự thao tác, hoặc nhờ con cháu cài đặt chỉ trong 2 phút.',
  },
  {
    q: 'Nhắc thuốc có cần mạng không?',
    a: 'Không. Chuông nhắc được lưu và kích hoạt trực tiếp từ hệ thống thiết bị, luôn reo đúng giờ kể cả khi mất sóng hay không có 4G/Wifi.',
  },
];

export default function FAQ() {
  // One item open at a time.
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <section className="section" id="hoi-dap" aria-labelledby="faq-title">
      <div className="container split split--faq">
        <div className="split__main">
          <h2 className="section__title" id="faq-title">Câu hỏi thường gặp</h2>
          <p className="section__lead">Giải đáp thắc mắc phổ biến của người bệnh và người chăm sóc khi dùng DrugTime.</p>
          <a className="help-card" href={siteConfig.links.contactEmail}>
            <span className="tile tile--md tile--brand"><Icon name="mail" /></span>
            <span>
              <strong>Vẫn còn thắc mắc?</strong>
              <span className="help-card__link">Liên hệ &amp; Hỏi đáp <Icon name="arrow-right" size="sm" /></span>
            </span>
          </a>
        </div>
        <div className="faq">
          {FAQS.map((item, i) => (
            <details
              key={item.q}
              className="faq__item"
              open={openIndex === i}
              onToggle={(e) => {
                const isOpen = e.currentTarget.open;
                setOpenIndex((cur) => (isOpen ? i : cur === i ? null : cur));
              }}
            >
              <summary
                onClick={(e) => {
                  e.preventDefault();
                  setOpenIndex((cur) => (cur === i ? null : i));
                }}
              >
                <span>{item.q}</span>
                <span className="faq__toggle" aria-hidden="true"><Icon name="plus" size="sm" /></span>
              </summary>
              <div className="faq__answer"><p>{item.a}</p></div>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
