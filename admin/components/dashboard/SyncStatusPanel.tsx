"use client";

import { Clock } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import { areaPath, layoutPoints, monotonePath, niceTicks, type ChartBox } from "../../lib/chart/geometry";

type SyncDay = {
  label: string;
  short: string;
  success: number;
  errors: number;
};

// Dữ liệu mẫu 7 ngày; tổng khớp dải thống kê (14,210 bản ghi, 185 lỗi, 98.7%).
const syncDays: SyncDay[] = [
  { label: "Thứ 2 (24/02)", short: "T2 24/02", success: 1880, errors: 31 },
  { label: "Thứ 3 (25/02)", short: "T3 25/02", success: 1935, errors: 28 },
  { label: "Thứ 4 (26/02)", short: "T4 26/02", success: 1990, errors: 26 },
  { label: "Thứ 5 (27/02)", short: "T5 27/02", success: 2020, errors: 27 },
  { label: "Thứ 6 (28/02)", short: "T6 28/02", success: 2065, errors: 25 },
  { label: "Thứ 7 (01/03)", short: "T7 01/03", success: 2110, errors: 24 },
  { label: "Hôm nay", short: "Hôm nay", success: 2210, errors: 24 },
];

const CHART_HEIGHT = 300;
const PADDING = { top: 16, right: 52, bottom: 40, left: 56 };
const POINT_RADIUS = 4.5;
// Nhãn đầy đủ "Thứ 2 (24/02)" ở 12px rộng khoảng 90px; cần cột ≥ 112px để còn khoảng hở, hẹp hơn thì dùng nhãn ngắn.
const FULL_LABEL_MIN_COLUMN = 112;

const formatNumber = (value: number) => value.toLocaleString("en-US");

export default function SyncStatusPanel() {
  const chartRef = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState<number | null>(null);
  const [activeIndex, setActiveIndex] = useState<number | null>(null);

  useEffect(() => {
    const node = chartRef.current;
    if (!node) return;
    const observer = new ResizeObserver(([entry]) => setWidth(Math.round(entry.contentRect.width)));
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  const totals = useMemo(() => {
    const success = syncDays.reduce((sum, day) => sum + day.success, 0);
    const errors = syncDays.reduce((sum, day) => sum + day.errors, 0);
    const rate = success + errors > 0 ? (success / (success + errors)) * 100 : 0;
    return { success, errors, rate };
  }, []);

  const chart = useMemo(() => {
    if (width === null || syncDays.length === 0) return null;
    const box: ChartBox = { width, height: CHART_HEIGHT, padding: PADDING };
    const successValues = syncDays.map((day) => day.success);
    const errorValues = syncDays.map((day) => day.errors);
    const leftTicks = niceTicks(Math.min(...successValues), Math.max(...successValues), 4);
    // Chuỗi lỗi dùng trục phải; nhân đôi trần để đường lỗi nằm ở nửa dưới, không cắt đường chính.
    const rightTicks = niceTicks(0, Math.max(...errorValues) * 2, 4);
    const leftDomain: [number, number] = [leftTicks[0], leftTicks[leftTicks.length - 1]];
    const rightDomain: [number, number] = [rightTicks[0], rightTicks[rightTicks.length - 1]];
    const success = layoutPoints(successValues, { ...box, domain: leftDomain });
    const errors = layoutPoints(errorValues, { ...box, domain: rightDomain });
    const plotBottom = CHART_HEIGHT - PADDING.bottom;
    const plotWidth = width - PADDING.left - PADDING.right;
    const tickY = (value: number, [d0, d1]: [number, number]) =>
      plotBottom - ((value - d0) / (d1 - d0)) * (plotBottom - PADDING.top);
    return {
      success,
      errors,
      successPath: monotonePath(success),
      successArea: areaPath(success, plotBottom),
      errorPath: monotonePath(errors),
      leftTicks: leftTicks.map((value) => ({ value, y: tickY(value, leftDomain) })),
      rightTicks: rightTicks.map((value) => ({ value, y: tickY(value, rightDomain) })),
      columnWidth: plotWidth / syncDays.length,
      plotBottom,
      useShortLabels: plotWidth / syncDays.length < FULL_LABEL_MIN_COLUMN,
    };
  }, [width]);

  const active = chart && activeIndex !== null ? chart.success[activeIndex] : null;
  const activeDay = activeIndex !== null ? syncDays[activeIndex] : null;
  // Giữ tooltip trong khung biểu đồ khi rê tới cột đầu/cuối.
  const tooltipLeft = active && width ? Math.min(Math.max(active.x, 92), width - 92) : 0;

  return (
    <section className="dashboard-panel dashboard-sync">
      <div className="dashboard-panel__header">
        <div>
          <div className="dashboard-title-row">
            <h2>Trạng thái đồng bộ</h2>
            <span>LIVE</span>
          </div>
          <p>Bóc tách tự động từ dichvucong.dav.gov.vn & CSDL Dược Quốc gia</p>
        </div>
        <div className="dashboard-tabs" role="tablist" aria-label="Khoảng thời gian">
          <button type="button" className="dashboard-tabs__active">
            7 ngày qua
          </button>
          <button type="button">30 ngày qua</button>
        </div>
      </div>

      <div className="dashboard-sync__stats">
        <div>
          <span>Tỷ lệ thành công</span>
          <strong className="text-green">{totals.rate.toFixed(1)}%</strong>
        </div>
        <div>
          <span>Bản ghi thu nạp</span>
          <strong className="text-blue">{formatNumber(totals.success)}</strong>
        </div>
        <div>
          <span>Lỗi DOM / Phản hồi chậm</span>
          <strong className="text-red">{formatNumber(totals.errors)}</strong>
        </div>
      </div>

      <div className="dashboard-chart" ref={chartRef}>
        {syncDays.length === 0 ? (
          <div className="dashboard-chart__empty">Chưa có dữ liệu đồng bộ trong khoảng thời gian này.</div>
        ) : !chart || width === null ? (
          <div className="dashboard-chart__placeholder" aria-hidden="true" />
        ) : (
          <svg
            width={width}
            height={CHART_HEIGHT}
            viewBox={`0 0 ${width} ${CHART_HEIGHT}`}
            role="group"
            aria-labelledby="sync-chart-title"
          >
            <title id="sync-chart-title">
              Bản ghi thu nạp 7 ngày qua tăng từ {formatNumber(syncDays[0].success)} lên{" "}
              {formatNumber(syncDays[syncDays.length - 1].success)}; lỗi giữ ở mức {Math.min(...syncDays.map((d) => d.errors))}–
              {Math.max(...syncDays.map((d) => d.errors))} mỗi ngày
            </title>
            <defs>
              <linearGradient id="sync-area-fill" x1="0" x2="0" y1="0" y2="1">
                <stop offset="0%" stopColor="var(--color-accent)" stopOpacity="0.22" />
                <stop offset="100%" stopColor="var(--color-accent)" stopOpacity="0" />
              </linearGradient>
            </defs>

            {chart.leftTicks.map((tick) => (
              <g key={`l-${tick.value}`}>
                <line className="chart-grid" x1={PADDING.left} x2={width - PADDING.right} y1={tick.y} y2={tick.y} />
                <text className="chart-axis-label" x={PADDING.left - 10} y={tick.y} textAnchor="end" dominantBaseline="middle">
                  {formatNumber(tick.value)}
                </text>
              </g>
            ))}
            {chart.rightTicks.map((tick) => (
              <text
                key={`r-${tick.value}`}
                className="chart-axis-label chart-axis-label--error"
                x={width - PADDING.right + 10}
                y={tick.y}
                textAnchor="start"
                dominantBaseline="middle"
              >
                {tick.value}
              </text>
            ))}

            {active ? (
              <line className="chart-crosshair" x1={active.x} x2={active.x} y1={PADDING.top} y2={chart.plotBottom} />
            ) : null}

            <path className="chart-area" d={chart.successArea} fill="url(#sync-area-fill)" />
            <path className="chart-line chart-line--error" d={chart.errorPath} />
            <path className="chart-line chart-line--success" d={chart.successPath} pathLength={1} />

            {chart.errors.map((point) => (
              <circle
                key={`e-${point.index}`}
                className={`chart-point chart-point--error${activeIndex === point.index ? " is-active" : ""}`}
                cx={point.x}
                cy={point.y}
                r={POINT_RADIUS - 1}
              />
            ))}
            {chart.success.map((point) => (
              <circle
                key={`s-${point.index}`}
                className={`chart-point chart-point--success${activeIndex === point.index ? " is-active" : ""}`}
                cx={point.x}
                cy={point.y}
                r={POINT_RADIUS}
              />
            ))}

            {chart.success.map((point) => {
              const day = syncDays[point.index];
              const isToday = point.index === syncDays.length - 1;
              return (
                <text
                  key={`x-${point.index}`}
                  className={`chart-x-label${isToday ? " chart-x-label--today" : ""}${activeIndex === point.index ? " is-active" : ""}`}
                  x={point.x}
                  y={CHART_HEIGHT - 12}
                  textAnchor="middle"
                >
                  {chart.useShortLabels ? day.short : day.label}
                </text>
              );
            })}

            {/* Cột bắt chuột/bàn phím cho từng ngày: hover hoặc Tab để xem giá trị */}
            {chart.success.map((point) => {
              const day = syncDays[point.index];
              return (
                <rect
                  key={`hit-${point.index}`}
                  className="chart-hit"
                  x={point.x - chart.columnWidth / 2}
                  y={PADDING.top}
                  width={chart.columnWidth}
                  height={chart.plotBottom - PADDING.top}
                  tabIndex={0}
                  aria-label={`${day.label}: ${formatNumber(day.success)} bản ghi, ${day.errors} lỗi`}
                  onMouseEnter={() => setActiveIndex(point.index)}
                  onMouseLeave={() => setActiveIndex(null)}
                  onFocus={() => setActiveIndex(point.index)}
                  onBlur={() => setActiveIndex(null)}
                />
              );
            })}
          </svg>
        )}

        {active && activeDay ? (
          <div className="dashboard-chart__tooltip" style={{ left: tooltipLeft, top: active.y }} role="status">
            <strong>{activeDay.label}</strong>
            <span>
              Bản ghi thu nạp <b>{formatNumber(activeDay.success)}</b>
            </span>
            <span>
              Lỗi DOM / Timeout <b>{activeDay.errors}</b>
            </span>
          </div>
        ) : null}
      </div>

      <div className="dashboard-sync__legend">
        <span>
          <i className="legend-dot" aria-hidden="true" />
          Bản ghi thu nạp (trục trái)
        </span>
        <span>
          <i className="legend-line" aria-hidden="true" />
          Lỗi DOM / Timeout (trục phải)
        </span>
        <span>
          <Clock size={18} strokeWidth={2.2} aria-hidden="true" />
          Chu kỳ cào: 04:00 hằng ngày
        </span>
      </div>
    </section>
  );
}
