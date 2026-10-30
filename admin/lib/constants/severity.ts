import type { InteractionSeverity } from "../types/interaction";

/** Nhãn mức độ tương tác dùng chung cho bảng, modal chi tiết và ô lọc (AC16). */
export const SEVERITY_LABELS: Record<InteractionSeverity, string> = {
  contraindicated: "Chống chỉ định",
  major: "Nghiêm trọng",
  moderate: "Trung bình",
  minor: "Nhẹ",
};

/** Thứ tự từ nặng tới nhẹ, dùng cho danh sách lựa chọn. */
export const SEVERITY_ORDER: InteractionSeverity[] = ["contraindicated", "major", "moderate", "minor"];
