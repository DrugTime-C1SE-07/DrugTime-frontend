import type { ReactNode } from "react";

import { areaPath, gaugeArc, linePath, peakIndex, scale, smoothPath } from "../../lib/dashboard/metrics";

/*
 * Biểu đồ SVG thuần cho trang Tổng quan. Đường/vùng vẽ trong viewBox 100×100 co giãn theo thẻ
 * (preserveAspectRatio="none" + non-scaling-stroke); chấm và nhãn là HTML đặt theo %, nên không bị méo.
 */

const FRAME = 100;
const PAD = 8;

/** Màu biểu đồ trỏ về token trong dashboard-theme.css. */
export const palette = {
  primary: "var(--bento-primary)",
  secondary: "var(--bento-secondary)",
  accent: "var(--bento-accent)",
  violet: "var(--bento-violet)",
  navy: "var(--bento-navy)",
  lilac: "var(--bento-lilac)",
};

export const NOT_ENOUGH_RUNS = "Cần ít nhất 2 lượt đồng bộ để vẽ biểu đồ.";

export type ChartSeries = {
  values: number[];
  color: string;
  smooth?: boolean;
  area?: boolean;
  dots?: boolean;
  faint?: boolean;
};

type LineChartProps = {
  /** Tiền tố id cho gradient; duy nhất trong trang. */
  id: string;
  label: string;
  series: ChartSeries[];
  xLabels?: string[];
  peak?: { series: number; text: (value: number) => string };
};

export function LineChart({ id, label, series, xLabels, peak }: LineChartProps) {
  const ceiling = Math.max(0, ...series.flatMap(s => s.values));
  const plotted = series.map(s => {
    const points = scale(s.values, FRAME, FRAME, PAD, ceiling);
    const path = s.smooth ? smoothPath(points) : linePath(points);
    return { ...s, points, path, area: s.area ? areaPath(path, points, FRAME) : "" };
  });
  const peakSeries = peak ? plotted[peak.series] : undefined;
  const peakAt = peakSeries ? peakIndex(peakSeries.values) : -1;
  const peakPoint = peakSeries && peakAt >= 0 ? peakSeries.points[peakAt] : undefined;

  return (
    <figure className="bento-chart">
      <div className="bento-chart__plot" role="img" aria-label={label}>
        <svg viewBox={`0 0 ${FRAME} ${FRAME}`} preserveAspectRatio="none" aria-hidden="true" focusable="false">
          <defs>
            {plotted.map((s, index) => (
              <linearGradient key={index} id={`${id}-fill-${index}`} x1="0" x2="0" y1="0" y2="1">
                <stop offset="0%" style={{ stopColor: s.color, stopOpacity: s.faint ? 0.12 : 0.32 }} />
                <stop offset="100%" style={{ stopColor: s.color, stopOpacity: 0 }} />
              </linearGradient>
            ))}
          </defs>
          {[25, 50, 75].map(y => <line key={y} className="bento-chart__grid" x1="0" x2={FRAME} y1={y} y2={y} />)}
          {plotted.map((s, index) => (
            <g key={index}>
              {s.area ? <path d={s.area} fill={`url(#${id}-fill-${index})`} /> : null}
              <path className={`bento-chart__line${s.faint ? " bento-chart__line--faint" : ""}`} d={s.path} style={{ stroke: s.color }} />
            </g>
          ))}
        </svg>
        {plotted.filter(s => s.dots).flatMap((s, si) =>
          s.points.map((p, index) => <span key={`${si}-${index}`} className="bento-chart__dot" style={{ left: `${p.x}%`, top: `${p.y}%`, background: s.color }} />),
        )}
        {peak && peakPoint && peakSeries ? (
          <>
            <span className="bento-chart__dot bento-chart__dot--peak" style={{ left: `${peakPoint.x}%`, top: `${peakPoint.y}%`, background: peakSeries.color }} />
            <span className="bento-chart__badge" style={{ left: `${peakPoint.x}%`, top: `${peakPoint.y}%` }}>{peak.text(peakSeries.values[peakAt])}</span>
          </>
        ) : null}
      </div>
      {xLabels ? (
        <figcaption className="bento-chart__axis" aria-hidden="true">
          {xLabels.map((text, index) => <span key={index}>{text}</span>)}
        </figcaption>
      ) : null}
    </figure>
  );
}

/** Vòng tròn tiến độ (0–100) với icon ở giữa. */
export function Donut({ value, color, icon, label, caption }: { value: number; color: string; icon: ReactNode; label: string; caption: string }) {
  return (
    <div className="bento-donut">
      <div className="bento-donut__ring" role="img" aria-label={`${label}: ${value}%`}>
        <svg viewBox="0 0 36 36" aria-hidden="true" focusable="false">
          <circle className="bento-donut__track" cx="18" cy="18" r="15.9155" />
          {value > 0 ? <circle className="bento-donut__value" cx="18" cy="18" r="15.9155" style={{ stroke: color }} strokeDasharray={`${value} 100`} /> : null}
        </svg>
        <span className="bento-donut__icon" aria-hidden="true">{icon}</span>
      </div>
      <span className="bento-donut__label">{label}</span>
      <strong>{value}%</strong>
      <span className="bento-donut__caption">{caption}</span>
    </div>
  );
}

/** Đồng hồ bán nguyệt; `value` là phần trăm 0–100. */
export function Gauge({ value, label }: { value: number; label: string }) {
  const ratio = value / 100;
  const angle = Math.PI - ratio * Math.PI;
  const needleX = 100 + 58 * Math.cos(angle);
  const needleY = 100 - 58 * Math.sin(angle);
  return (
    <div className="bento-gauge">
      <svg viewBox="0 0 200 112" role="img" aria-label={`${label}: ${value}%`}>
        <path className="bento-gauge__track" d={gaugeArc(1, 100, 100, 80)} />
        <path className="bento-gauge__value" d={gaugeArc(ratio, 100, 100, 80)} />
        <line className="bento-gauge__needle" x1="100" y1="100" x2={needleX} y2={needleY} />
        <circle className="bento-gauge__hub" cx="100" cy="100" r="7" />
      </svg>
      <div className="bento-gauge__scale" aria-hidden="true">
        <span>0%</span>
        <strong>{value}%</strong>
        <span>100%</span>
      </div>
    </div>
  );
}

export function ProgressBar({ label, value, color, detail }: { label: string; value: number; color: string; detail: string }) {
  return (
    <div className="bento-progress">
      <div className="bento-progress__row">
        <span><i style={{ background: color }} aria-hidden="true" />{label}</span>
        <strong>{value}%</strong>
      </div>
      <div className="bento-progress__track" role="progressbar" aria-label={label} aria-valuenow={value} aria-valuemin={0} aria-valuemax={100} aria-valuetext={`${value}% (${detail})`}>
        <div style={{ width: `${value}%`, background: color }} />
      </div>
    </div>
  );
}

export type Segment = { label: string; value: number; color: string };

export function SegmentBar({ segments, label }: { segments: Segment[]; label: string }) {
  const total = segments.reduce((sum, s) => sum + s.value, 0);
  return (
    <div className="bento-segments" role="img" aria-label={label}>
      {segments.filter(s => s.value > 0).map(s => (
        <span key={s.label} style={{ flexGrow: s.value, background: s.color }} title={`${s.label}: ${s.value.toLocaleString("vi-VN")}`} />
      ))}
      {total === 0 ? <span className="bento-segments__empty" /> : null}
    </div>
  );
}

/** Cột dạng viên nang; chiều cao theo giá trị lớn nhất của dãy. */
export function CapsuleBars({ values, labels, colors, label }: { values: number[]; labels: string[]; colors: string[]; label: string }) {
  const max = Math.max(1, ...values);
  return (
    <div className="bento-capsules" role="img" aria-label={label}>
      {values.map((value, index) => (
        <div key={index} className="bento-capsules__item">
          <div className="bento-capsules__track">
            <div style={{ height: `${Math.max(4, (value / max) * 100)}%`, background: colors[index % colors.length] }} />
          </div>
          <span aria-hidden="true">{labels[index]}</span>
        </div>
      ))}
    </div>
  );
}
