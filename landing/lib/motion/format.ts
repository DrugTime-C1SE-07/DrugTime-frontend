const formatter = new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 0 });

/**
 * Text for a count-up frame: the rounded number in vi-VN grouping plus an optional suffix.
 * `formatCount(5948)` → "5.948", `formatCount(2, ' phút')` → "2 phút".
 */
export function formatCount(value: number, suffix = '', grouping = true): string {
  const n = Math.round(Number.isFinite(value) ? Math.max(0, value) : 0);
  return `${grouping ? formatter.format(n) : String(n)}${suffix}`;
}
