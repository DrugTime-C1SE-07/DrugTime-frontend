"use client";

import React from "react";
import { Info } from "lucide-react";

export default function InteractionGuidelineCard() {
  return (
    <article className="interaction-guideline-card" aria-label="Lưu ý bóc tách quy tắc tương tác">
      <div className="interaction-guideline-card__icon" aria-hidden="true">
        <Info size={18} strokeWidth={2.4} />
      </div>
      <div className="interaction-guideline-card__content">
        <h4>Lưu ý bóc tách quy tắc tương tác</h4>
        <p>
          Dữ liệu cào từ <strong>QĐ 5948/QĐ-BYT</strong> ưu tiên số một cho danh mục Chống chỉ định. Khi đối soát với cơ sở dữ liệu quốc tế (DrugBank/FDA), các chuyên gia Dược cần giữ nguyên mã ATC chuẩn hóa và chú giải lâm sàng bằng tiếng Việt phổ thông để bệnh nhân dễ hiểu.
        </p>
      </div>
    </article>
  );
}
