'use client';

import { useId, useState } from 'react';
import Image from 'next/image';
import Icon from '@/components/ui/Icon';
import { assets, siteConfig } from '@/lib/seo/metadata';

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

/** Accordion (WAI-ARIA pattern): one answer open at a time, height animated with grid rows. */
export default function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);
  const baseId = useId();

  return (
    <section className="section faq-section" id="hoi-dap" aria-labelledby="faq-title">
      <div className="container faq-layout">
        <div className="faq-aside">
          <p className="kicker">Hỏi đáp</p>
          <h2 className="section__title" id="faq-title" data-split>Câu hỏi thường gặp</h2>
          <Image className="faq-mascot" src={assets.mascotThinking} alt="" width={521} height={479} sizes="168px" />
          <a className="help-card" href={siteConfig.links.contactEmail} data-spotlight>
            <span className="tile tile--brand"><Icon name="mail" /></span>
            <span>
              <strong>Vẫn còn thắc mắc?</strong>
              <span className="help-card__link">Liên hệ với chúng tôi <Icon name="arrow-right" size="sm" /></span>
            </span>
          </a>
        </div>

        <div className="faq">
          {FAQS.map((item, i) => {
            const open = openIndex === i;
            const triggerId = `${baseId}-q${i}`;
            const panelId = `${baseId}-a${i}`;
            return (
              <div className={open ? 'faq__item is-open' : 'faq__item'} key={item.q} data-reveal>
                <h3 className="faq__q">
                  <button
                    type="button"
                    className="faq__trigger"
                    id={triggerId}
                    aria-expanded={open}
                    aria-controls={panelId}
                    onClick={() => setOpenIndex(open ? null : i)}
                  >
                    <span>{item.q}</span>
                    <span className="faq__toggle" aria-hidden="true"><Icon name="plus" size="sm" /></span>
                  </button>
                </h3>
                <div className="faq__panel" id={panelId} role="region" aria-labelledby={triggerId} inert={!open}>
                  <div><p className="faq__answer">{item.a}</p></div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
