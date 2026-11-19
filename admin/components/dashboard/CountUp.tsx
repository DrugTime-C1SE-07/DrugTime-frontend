"use client";

import { useEffect, useLayoutEffect, useRef, useState } from "react";

const DURATION_MS = 800;
const REDUCED_MOTION = "(prefers-reduced-motion: reduce)";

// useLayoutEffect chỉ chạy ở client; trên server dùng useEffect để tránh cảnh báo SSR.
const useIsomorphicLayoutEffect = typeof window === "undefined" ? useEffect : useLayoutEffect;

type CountUpProps = {
  /** Số đã định dạng, ví dụ "14,850"; dấu phân cách và tiền tố/hậu tố được giữ nguyên. */
  value: string;
};

const easeOutCubic = (t: number) => 1 - (1 - t) ** 3;

/**
 * Số KPI đếm từ 0 lên một lần khi tải. Server render giá trị cuối (đúng khi không có JS);
 * bỏ qua hiệu ứng khi người dùng bật prefers-reduced-motion.
 */
export default function CountUp({ value }: CountUpProps) {
  const match = value.match(/^(\D*)([\d,.]+)(\D*)$/);
  const target = match ? Number(match[2].replace(/,/g, "")) : NaN;
  const [display, setDisplay] = useState(value);
  const frame = useRef<number>();

  useIsomorphicLayoutEffect(() => {
    if (!match || !Number.isFinite(target) || window.matchMedia(REDUCED_MOTION).matches) return;
    const [, prefix, digits, suffix] = match;
    // Giữ số chữ số thập phân của giá trị đích ("98.7%" đếm 0.0 → 98.7, không làm tròn thành 99)
    const decimals = digits.split(".")[1]?.length ?? 0;
    const format = (n: number) =>
      `${prefix}${n.toLocaleString("en-US", { minimumFractionDigits: decimals, maximumFractionDigits: decimals })}${suffix}`;
    const start = performance.now();
    setDisplay(format(0));
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / DURATION_MS);
      setDisplay(t < 1 ? format(target * easeOutCubic(t)) : value);
      if (t < 1) frame.current = requestAnimationFrame(tick);
    };
    frame.current = requestAnimationFrame(tick);
    return () => {
      if (frame.current) cancelAnimationFrame(frame.current);
    };
    // Chỉ chạy lại khi giá trị đích đổi.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value]);

  // Trình đọc màn hình chỉ đọc giá trị cuối, không đọc các số trung gian.
  return (
    <span className="count-up">
      <span aria-hidden="true">{display}</span>
      <span className="visually-hidden">{value}</span>
    </span>
  );
}
