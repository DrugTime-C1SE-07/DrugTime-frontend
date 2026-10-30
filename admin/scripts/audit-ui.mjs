#!/usr/bin/env node
// Kiểm tĩnh giao diện Admin: contrast (WCAG 2.2 AA), mẫu trang trí bị cấm, cỡ chữ tối thiểu, bo góc,
// chuyển động (thuộc tính, thời lượng, prefers-reduced-motion) và bóng đổ trung tính.
// Chạy: npm run audit:ui. Exit 1 khi có vi phạm.
// Giới hạn: màu có alpha được trộn trên nền trắng; nền kế thừa từ phần tử cha không được tính (dùng axe để kiểm phần đó).

import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const CSS_FILES = ["app/globals.css", "app/dashboard/dashboard-theme.css"];
const TSX_DIRS = ["app", "components"];

const TEXT_MIN = 4.5;
const NON_TEXT_MIN = 3;
const MIN_FONT_PX = 12;
const MAX_CARD_RADIUS_PX = 12;
const MAX_MOTION_MS = 240;
const MAX_DATA_MOTION_MS = 900;
// Keyframes vẽ dữ liệu (biểu đồ, vòng chất lượng) được dài hơn, chỉ chạy một lần khi tải.
const DATA_KEYFRAMES = new Set(["chart-draw", "chart-fade", "ring-draw", "bar-grow"]);
// Chỉ animate transform/opacity/màu/nền/viền/bóng; không đổi thuộc tính bố cục.
const LAYOUT_PROPS = /^(all|width|height|min-|max-|top|left|right|bottom|inset|margin|padding|flex|grid|font-size|line-height)/;
// Bóng có blur > 0 phải trung tính: chênh lệch giữa các kênh RGB ≤ 40.
const MAX_SHADOW_CHROMA = 40;

// Cặp token chữ/nền mà mọi trang dùng. [chữ, nền, ngưỡng, mô tả]
const TOKEN_PAIRS = [
  ["--color-text", "--color-surface", TEXT_MIN, "chữ chính / card"],
  ["--color-text", "--color-shell", TEXT_MIN, "chữ chính / nền trang"],
  ["--color-secondary-text", "--color-surface", TEXT_MIN, "chữ phụ / card"],
  ["--color-secondary-text", "--color-shell", TEXT_MIN, "chữ phụ / nền trang"],
  ["--color-muted", "--color-surface", TEXT_MIN, "chữ mờ / card"],
  ["--color-muted", "--color-shell", TEXT_MIN, "chữ mờ / nền trang"],
  ["--color-on-primary", "--color-primary", TEXT_MIN, "chữ trên nút primary"],
  ["--color-on-primary", "--color-primary-strong", TEXT_MIN, "chữ trên nút primary (hover)"],
  ["--color-primary", "--color-surface", TEXT_MIN, "link / card"],
  ["--color-primary", "--color-primary-soft", TEXT_MIN, "primary / nền nhạt"],
  ["--color-primary-strong", "--color-primary-soft", TEXT_MIN, "sidebar link active"],
  ["--color-success", "--color-success-soft", TEXT_MIN, "badge thành công"],
  ["--color-danger", "--color-danger-soft", TEXT_MIN, "badge lỗi"],
  ["--color-danger", "--color-surface", TEXT_MIN, "chữ lỗi / card"],
  ["--color-warning", "--color-warning-soft", TEXT_MIN, "badge cảnh báo"],
  ["--color-info", "--color-info-soft", TEXT_MIN, "badge thông tin"],
  ["--color-neutral-badge", "--color-neutral-badge-soft", TEXT_MIN, "badge trung tính"],
  ["--sev-contraindicated-fg", "--sev-contraindicated-bg", TEXT_MIN, "severity chống chỉ định"],
  ["--sev-major-fg", "--sev-major-bg", TEXT_MIN, "severity major"],
  ["--sev-moderate-fg", "--sev-moderate-bg", TEXT_MIN, "severity moderate"],
  ["--sev-minor-fg", "--sev-minor-bg", TEXT_MIN, "severity minor"],
  ["--color-border-control", "--color-surface", NON_TEXT_MIN, "viền ô nhập / card"],
  ["--color-primary", "--color-surface", NON_TEXT_MIN, "focus ring / card"],
  ["--sev-contraindicated-dot", "--color-surface", NON_TEXT_MIN, "chấm severity chống chỉ định"],
  ["--sev-major-dot", "--color-surface", NON_TEXT_MIN, "chấm severity major"],
  ["--sev-moderate-dot", "--color-surface", NON_TEXT_MIN, "chấm severity moderate"],
  ["--sev-minor-dot", "--color-surface", NON_TEXT_MIN, "chấm severity minor"],
  ["--color-sidebar-text", "--color-sidebar", TEXT_MIN, "chữ link / sidebar"],
  ["--color-sidebar-muted", "--color-sidebar", TEXT_MIN, "chữ phụ / sidebar"],
  ["--color-on-primary", "--color-sidebar-hover", TEXT_MIN, "chữ / link sidebar hover"],
  ["--color-on-primary", "--color-sidebar-active", TEXT_MIN, "chữ / link sidebar đang chọn"],
  ["--color-accent-bright", "--color-sidebar", NON_TEXT_MIN, "chỉ báo accent / sidebar"],
  ["--color-accent-bright", "--color-sidebar-active", NON_TEXT_MIN, "chỉ báo accent / link đang chọn"],
  ["--color-accent", "--color-surface", NON_TEXT_MIN, "nét accent / card"],
  ["--color-accent-strong", "--color-surface", TEXT_MIN, "chữ accent / card"],
  ["--color-accent-strong", "--color-accent-soft", TEXT_MIN, "chữ accent / nền accent nhạt"],
  ["--color-on-primary", "--color-accent-strong", TEXT_MIN, "chữ trắng / accent đậm"],
  ["--color-warning-icon", "--color-surface", NON_TEXT_MIN, "icon cảnh báo / card"],
  ["--chart-error", "--color-surface", NON_TEXT_MIN, "nét lỗi biểu đồ / card"],
  ["--color-on-primary", "--color-tooltip", TEXT_MIN, "chữ tooltip"],
  ["--color-tooltip-muted", "--color-tooltip", TEXT_MIN, "chữ phụ tooltip"],
  ["--color-on-primary", "--color-accent-deep", TEXT_MIN, "chữ trắng / pill thẻ nổi bật"],
  ["--color-on-accent-muted", "--color-accent-strong", TEXT_MIN, "chữ phụ / thẻ nổi bật"],
  ["--color-on-accent-muted", "--color-accent-deep", TEXT_MIN, "chữ phụ / chân thẻ nổi bật"],
  ["--color-on-primary", "--color-success", NON_TEXT_MIN, "icon trắng / ô icon success"],
  ["--color-on-primary", "--color-warning", NON_TEXT_MIN, "icon trắng / ô icon warning"],
  ["--color-on-primary", "--color-danger", NON_TEXT_MIN, "icon trắng / ô icon danger"],
  ["--color-primary-strong", "--color-surface", NON_TEXT_MIN, "ô icon primary / card"],
  ["--color-success", "--color-surface", NON_TEXT_MIN, "ô icon success / card"],
  ["--color-warning", "--color-surface", NON_TEXT_MIN, "ô icon warning / card"],
  ["--color-primary", "--chart-grid", NON_TEXT_MIN, "thanh tỉ lệ primary / rãnh"],
  ["--color-success", "--chart-grid", NON_TEXT_MIN, "thanh tỉ lệ success / rãnh"],
  ["--color-warning-icon", "--chart-grid", NON_TEXT_MIN, "thanh tỉ lệ warning / rãnh"],
  ["--chart-error", "--chart-grid", NON_TEXT_MIN, "thanh tỉ lệ danger / rãnh"],
  // Login panel tối (bản mẫu C). Không có chữ đặt thẳng lên video; tấm tagline có alpha nên được
  // trộn trên nền trắng = pixel sáng nhất của video (trường hợp xấu nhất).
  ["--color-on-primary", "--login-panel", TEXT_MIN, "chữ trắng / panel Login"],
  ["--login-label", "--login-panel", TEXT_MIN, "nhãn ô / panel Login"],
  ["--login-text-muted", "--login-panel", TEXT_MIN, "chữ phụ / panel Login"],
  ["--login-text-subtle", "--login-panel", TEXT_MIN, "chân trang / panel Login"],
  ["--color-on-primary", "--login-field", TEXT_MIN, "chữ ô nhập / nền ô"],
  ["--login-text-subtle", "--login-field", TEXT_MIN, "placeholder / nền ô"],
  ["--login-field-border", "--login-panel", NON_TEXT_MIN, "viền ô / panel"],
  ["--login-field-border", "--login-field", NON_TEXT_MIN, "viền ô / nền ô"],
  ["--color-accent-bright", "--login-panel", NON_TEXT_MIN, "focus ring / panel"],
  ["--color-accent-bright", "--login-field", NON_TEXT_MIN, "focus ring / nền ô"],
  ["--login-panel", "--color-accent-bright", TEXT_MIN, "chữ nút / nút Login"],
  ["--login-panel", "--login-accent-hover", TEXT_MIN, "chữ nút / nút Login hover"],
  ["--login-error", "--login-panel", TEXT_MIN, "lỗi tại ô / panel"],
  ["--color-on-primary", "--login-plate", TEXT_MIN, "chữ trắng / tấm tagline trên video"],
];

const LOGIN_VIDEO = "public/media/login-background.mp4";
const LOGIN_POSTER = "public/media/login-background-poster.jpg";
const MAX_VIDEO_BYTES = 2 * 1024 * 1024;
const MAX_POSTER_BYTES = 120 * 1024;

// Bốn mức severity phải khác nhau và khác màu primary.
const SEVERITY_BG = ["--sev-contraindicated-bg", "--sev-major-bg", "--sev-moderate-bg", "--sev-minor-bg"];
const PRIMARY_TOKENS = ["--color-primary", "--color-primary-strong", "--color-primary-soft"];

// Gradient chỉ được dùng cho dữ liệu (vòng tiến độ chất lượng).
const GRADIENT_ALLOW = /\.quality-ring\b/;
// 999px chỉ dành cho phần tử dạng viên/tròn, không cho nút, tab, input, link.
const PILL_ALLOW = /badge|pill|dot|tag|avatar|profile|status|ring|track|fill|progress|thumb|indicator|spinner|toggle|scrollbar|legend|__icon\b|-icon\b/;
const CARD_SELECTOR =
  /\.(dashboard-kpi|dashboard-panel|dashboard-workers|medication-stat|medication-filters|medication-table-card|interaction-frame3-card|admin-page-placeholder|modal-dialog|toast-item|medication-sync-banner|interaction-guideline-card|interaction-detail-card|admin-login-card|admin-login-shell)(?![\w-])/;

const violations = [];
const fail = (group, msg) => violations.push(`[${group}] ${msg}`);

// ---------- CSS parsing ----------
function parseRules(file) {
  const raw = readFileSync(join(ROOT, file), "utf8");
  const text = raw.replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, " "));
  const rules = [];
  // Vùng nằm trong @media (prefers-reduced-motion: reduce): thời lượng ở đó là để tắt chuyển động, không kiểm.
  const reducedRanges = [];
  for (const rm of text.matchAll(/@media\s*\(\s*prefers-reduced-motion:\s*reduce\s*\)\s*\{/g)) {
    let depth = 1;
    let i = rm.index + rm[0].length;
    while (depth > 0 && i < text.length) {
      if (text[i] === "{") depth++;
      if (text[i] === "}") depth--;
      i++;
    }
    reducedRanges.push([rm.index, i]);
  }
  const re = /([^{}]+)\{([^{}]*)\}/g;
  let m;
  while ((m = re.exec(text))) {
    const selector = m[1].replace(/^[\s\S]*;/, "").trim();
    const decls = {};
    for (const d of m[2].split(";")) {
      const i = d.indexOf(":");
      if (i > 0) decls[d.slice(0, i).trim()] = d.slice(i + 1).trim();
    }
    const start = m.index + m[1].length - m[1].replace(/^[\s\S]*;/, "").trimStart().length;
    const line = text.slice(0, start).split("\n").length;
    const reducedMotion = reducedRanges.some(([a, b]) => m.index > a && m.index < b);
    rules.push({ file, line, selector, decls, reducedMotion });
  }
  return rules;
}

const rules = CSS_FILES.flatMap(parseRules);
const tokens = {};
for (const r of rules) {
  if (r.selector !== ":root") continue;
  for (const [k, v] of Object.entries(r.decls)) if (k.startsWith("--")) tokens[k] = v;
}

// ---------- Color math ----------
function parseColor(value, depth = 0) {
  if (!value || depth > 8) return null;
  const v = value.trim().replace(/\s*!important$/, "");
  const varM = v.match(/^var\((--[\w-]+)(?:\s*,\s*(.+))?\)$/);
  if (varM) return parseColor(tokens[varM[1]] ?? varM[2], depth + 1);
  if (/^(#fff|white)$/i.test(v)) return [255, 255, 255, 1];
  let m = v.match(/^#([0-9a-f]{3})$/i);
  if (m) return [...m[1]].map((c) => parseInt(c + c, 16)).concat(1);
  m = v.match(/^#([0-9a-f]{6})([0-9a-f]{2})?$/i);
  if (m) {
    const n = m[1];
    return [0, 2, 4].map((i) => parseInt(n.slice(i, i + 2), 16)).concat(m[2] ? parseInt(m[2], 16) / 255 : 1);
  }
  m = v.match(/^rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)(?:\s*[,/]\s*([\d.]+%?))?\s*\)$/);
  if (m) {
    const a = m[4] === undefined ? 1 : m[4].endsWith("%") ? parseFloat(m[4]) / 100 : parseFloat(m[4]);
    return [+m[1], +m[2], +m[3], a];
  }
  return null;
}

function flatten([r, g, b, a], under = [255, 255, 255]) {
  return [r, g, b].map((c, i) => Math.round(c * a + under[i] * (1 - a)));
}

function luminance(rgb) {
  const [r, g, b] = rgb.map((c) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrast(fg, bg) {
  const bgFlat = flatten(bg);
  const fgFlat = flatten(fg, bgFlat);
  const [hi, lo] = [luminance(fgFlat), luminance(bgFlat)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

const hex = (c) => (c ? "#" + flatten(c).map((x) => x.toString(16).padStart(2, "0")).join("") : "?");
const where = (r) => `${r.file}:${r.line} ${r.selector.replace(/\s+/g, " ").slice(0, 90)}`;

// ---------- Checks ----------
function checkTokenContrast() {
  for (const [fgT, bgT, min, label] of TOKEN_PAIRS) {
    const fg = parseColor(`var(${fgT})`);
    const bg = parseColor(`var(${bgT})`);
    if (!fg || !bg) {
      fail("token", `thiếu token ${!fg ? fgT : bgT} (${label})`);
      continue;
    }
    const ratio = contrast(fg, bg);
    if (ratio < min) fail("token", `${label}: ${fgT} ${hex(fg)} / ${bgT} ${hex(bg)} = ${ratio.toFixed(2)} < ${min}`);
  }
  const sev = SEVERITY_BG.map((t) => hex(parseColor(`var(${t})`)));
  if (new Set(sev).size !== sev.length) fail("token", `4 mức severity phải có 4 màu nền khác nhau: ${sev.join(", ")}`);
  const primary = PRIMARY_TOKENS.map((t) => hex(parseColor(`var(${t})`)));
  for (const [i, c] of sev.entries()) {
    if (primary.includes(c)) fail("token", `${SEVERITY_BG[i]} trùng màu primary ${c}`);
  }
}

function checkThemeOverrides() {
  for (const r of rules) {
    if (!/^\.admin-theme$/.test(r.selector)) continue;
    for (const k of Object.keys(r.decls)) {
      if (/^--(color-|dt-|severity-|sev-)/.test(k)) fail("token", `${where(r)} định nghĩa lại ${k}; token màu chỉ khai báo ở :root`);
    }
  }
}

function checkSameRulePairs() {
  for (const r of rules) {
    const fg = parseColor(r.decls.color);
    const bg = parseColor(r.decls["background-color"] ?? r.decls.background);
    if (!fg || !bg || bg[3] === 0) continue;
    const size = parseFloat(r.decls["font-size"]);
    const bold = /^(bold|[6-9]00)$/.test(r.decls["font-weight"] ?? "");
    const large = size >= 24 || (bold && size >= 18.66);
    const min = large ? NON_TEXT_MIN : TEXT_MIN;
    const ratio = contrast(fg, bg);
    if (ratio < min) fail("contrast", `${where(r)}: ${hex(fg)} / ${hex(bg)} = ${ratio.toFixed(2)} < ${min}`);
  }
}

// Rule chỉ khai báo màu chữ: giả định nằm trên card trắng. Chữ sáng (lum > 0.4) được bỏ qua vì nó chủ ý nằm trên nền tối.
function checkTextOnSurface() {
  const surface = parseColor("var(--color-surface)") ?? [255, 255, 255, 1];
  for (const r of rules) {
    if (r.decls["background-color"] || r.decls.background || r.selector === ":root") continue;
    const fg = parseColor(r.decls.color);
    if (!fg || luminance(flatten(fg)) > 0.4) continue;
    const ratio = contrast(fg, surface);
    if (ratio < TEXT_MIN) fail("contrast", `${where(r)}: ${hex(fg)} / card ${hex(surface)} = ${ratio.toFixed(2)} < ${TEXT_MIN}`);
  }
}

function checkForbiddenPatterns() {
  for (const r of rules) {
    const body = Object.entries(r.decls).map(([k, v]) => `${k}: ${v}`).join("; ");
    if (/gradient\(/.test(body) && !GRADIENT_ALLOW.test(r.selector)) fail("pattern", `${where(r)}: gradient trang trí`);
    if (/backdrop-filter/.test(body)) fail("pattern", `${where(r)}: backdrop-filter`);
    if (/#2563eb|rgba\(\s*37\s*,\s*99\s*,\s*235/i.test(body)) fail("pattern", `${where(r)}: màu Tailwind #2563eb`);
    // Biểu đồ tự vẽ theo pixel thật; ép height cho svg làm viewBox co lại (điểm nhỏ, lệch nhãn, chừa lề).
    if (/\.dashboard-chart\s+svg/.test(r.selector) && r.decls.height) fail("pattern", `${where(r)}: ép height cho svg biểu đồ`);
  }
}

// Tách danh sách theo dấu phẩy ở mức ngoài cùng (bỏ qua dấu phẩy trong cubic-bezier(), rgba(), var()).
function splitTopLevel(value) {
  const parts = [];
  let depth = 0;
  let cur = "";
  for (const ch of value) {
    if (ch === "(") depth++;
    if (ch === ")") depth--;
    if (ch === "," && depth === 0) {
      parts.push(cur.trim());
      cur = "";
    } else cur += ch;
  }
  if (cur.trim()) parts.push(cur.trim());
  return parts;
}

function msOf(token) {
  const v = token.match(/^var\((--[\w-]+)/) ? tokens[token.match(/^var\((--[\w-]+)/)[1]] ?? "" : token;
  const m = v.trim().match(/^([\d.]+)(ms|s)$/);
  return m ? parseFloat(m[1]) * (m[2] === "s" ? 1000 : 1) : null;
}

function checkMotion() {
  for (const r of rules) {
    if (r.reducedMotion) continue;
    for (const layer of splitTopLevel((r.decls.transition ?? "").replace(/\s*!important$/, ""))) {
      const words = layer.split(/\s+(?![^(]*\))/);
      const prop = words.find((w) => /^[a-z-]+$/.test(w) && !/^(ease|linear|step)/.test(w)) ?? "all";
      if (LAYOUT_PROPS.test(prop)) fail("motion", `${where(r)}: transition "${prop}" (chỉ transform/opacity/màu/nền/viền/bóng)`);
      const dur = words.map(msOf).find((x) => x !== null);
      if (dur !== undefined && dur > MAX_MOTION_MS) fail("motion", `${where(r)}: transition ${dur}ms > ${MAX_MOTION_MS}ms`);
    }
    const prop = r.decls["transition-property"];
    if (prop && splitTopLevel(prop).some((p) => LAYOUT_PROPS.test(p)))
      fail("motion", `${where(r)}: transition-property "${prop}"`);
    for (const layer of splitTopLevel((r.decls.animation ?? "").replace(/\s*!important$/, ""))) {
      const words = layer.split(/\s+(?![^(]*\))/);
      const name = words.find((w) => /^[a-zA-Z][\w-]*$/.test(w) && !/^(ease|linear|step|infinite|both|forwards|backwards|none|normal|reverse|alternate|running|paused)/.test(w));
      const dur = words.map(msOf).find((x) => x !== null);
      const limit = DATA_KEYFRAMES.has(name) ? MAX_DATA_MOTION_MS : MAX_MOTION_MS;
      if (dur !== undefined && dur > limit) fail("motion", `${where(r)}: animation ${name} ${dur}ms > ${limit}ms`);
      if (words.includes("infinite")) fail("motion", `${where(r)}: animation ${name} lặp vô hạn`);
    }
  }
}

function checkReducedMotion() {
  const block = CSS_FILES.map((f) => readFileSync(join(ROOT, f), "utf8"))
    .join("\n")
    .match(/@media\s*\(\s*prefers-reduced-motion:\s*reduce\s*\)\s*\{[\s\S]*?\n\}/g);
  const body = (block ?? []).join("\n");
  if (!/animation-duration/.test(body) || !/transition-duration/.test(body))
    fail("motion", "thiếu @media (prefers-reduced-motion: reduce) đặt animation-duration và transition-duration");
}

function checkShadows() {
  for (const r of rules) {
    const shadow = r.decls["box-shadow"];
    if (!shadow || shadow === "none") continue;
    for (const layer of splitTopLevel(shadow.replace(/\s*!important$/, ""))) {
      const lengths = layer.match(/-?[\d.]+px|(?<![\w.])0(?![\w.%])/g) ?? [];
      const blur = lengths.length >= 3 ? parseFloat(lengths[2]) : 0;
      const colorToken = layer.match(/(rgba?\([^)]*\)|#[0-9a-f]{3,8}\b|var\(--[\w-]+\))/i)?.[1];
      const color = parseColor(colorToken);
      if (!color || blur <= 0) continue;
      const chroma = Math.max(...color.slice(0, 3)) - Math.min(...color.slice(0, 3));
      if (chroma > MAX_SHADOW_CHROMA) fail("shadow", `${where(r)}: bóng màu ${colorToken} (chỉ dùng bóng trung tính)`);
    }
  }
}

function pxOf(value) {
  if (!value) return null;
  const v = value.replace(/\s*!important$/, "").trim();
  const varM = v.match(/^var\((--[\w-]+)/);
  if (varM) return pxOf(tokens[varM[1]]);
  const m = v.match(/^([\d.]+)px$/);
  return m ? parseFloat(m[1]) : null;
}

function checkFontSizes() {
  for (const r of rules) {
    const px = pxOf(r.decls["font-size"]);
    if (px !== null && px < MIN_FONT_PX) fail("font-size", `${where(r)}: ${px}px < ${MIN_FONT_PX}px`);
  }
  for (const file of TSX_DIRS.flatMap((d) => walk(join(ROOT, d)))) {
    const src = readFileSync(file, "utf8");
    for (const m of src.matchAll(/fontSize:\s*["']?([\d.]+)(px)?["']?/g)) {
      const px = parseFloat(m[1]);
      if (px < MIN_FONT_PX) {
        const line = src.slice(0, m.index).split("\n").length;
        fail("font-size", `${relative(ROOT, file)}:${line}: inline fontSize ${px} < ${MIN_FONT_PX}`);
      }
    }
  }
}

function checkRadius() {
  for (const r of rules) {
    const radius = r.decls["border-radius"];
    if (!radius) continue;
    const px = pxOf(radius.split(/\s+/)[0]);
    const isPill = px !== null && px >= 999;
    const last = r.selector.split(",").map((s) => s.trim().split(/\s+/).pop());
    // Phần tử vuông (width = height) bo 999px là hình tròn (chấm, avatar), không phải nút dạng viên.
    const isCircle = r.decls.width !== undefined && r.decls.width === r.decls.height;
    if (isPill && !isCircle && !last.every((s) => PILL_ALLOW.test(s)))
      fail("radius", `${where(r)}: 999px chỉ dành cho badge/chấm tròn`);
    if (!isPill && px !== null && px > MAX_CARD_RADIUS_PX && CARD_SELECTOR.test(r.selector))
      fail("radius", `${where(r)}: card bo ${px}px > ${MAX_CARD_RADIUS_PX}px`);
  }
}

// Ô lọc rộng theo nội dung: không khóa bề rộng bằng !important (chữ bị cắt "Chất lượng: Tất…").
function checkFilterWidths() {
  for (const r of rules) {
    if (!/\.filter-select/.test(r.selector)) continue;
    for (const prop of ["width", "min-width", "max-width", "flex", "flex-basis"]) {
      if (/!important/.test(r.decls[prop] ?? "")) fail("filter", `${where(r)}: ${prop} ${r.decls[prop]}`);
    }
  }
}

// Admin chỉ có một cấp điều hướng, sidebar đã đánh dấu trang hiện tại: không dùng breadcrumb.
function checkNoBreadcrumb() {
  for (const file of TSX_DIRS.flatMap((d) => walk(join(ROOT, d)))) {
    const src = readFileSync(file, "utf8");
    const i = src.indexOf("dashboard-breadcrumb");
    if (i >= 0) fail("breadcrumb", `${relative(ROOT, file)}:${src.slice(0, i).split("\n").length}: còn breadcrumb`);
  }
}

// Mật khẩu admin được cấp trong DB: không có luồng quên mật khẩu (trước đây là giả lập, báo thành công sai).
function checkNoForgotPassword() {
  const files = [...walk(join(ROOT, "components/auth")), ...CSS_FILES.map((f) => join(ROOT, f))];
  for (const file of files) {
    const src = readFileSync(file, "utf8");
    const m = src.match(/forgot/i);
    if (m) fail("login", `${relative(ROOT, file)}:${src.slice(0, m.index).split("\n").length}: còn mã quên mật khẩu`);
  }
}

// Video nền Login: chỉ bản tối ưu trong public/media, không phục vụ bản gốc nặng.
function checkLoginMedia() {
  const size = (rel) => {
    try {
      return statSync(join(ROOT, rel)).size;
    } catch {
      return null;
    }
  };
  const video = size(LOGIN_VIDEO);
  const poster = size(LOGIN_POSTER);
  if (video === null) fail("media", `thiếu ${LOGIN_VIDEO}`);
  else if (video > MAX_VIDEO_BYTES) fail("media", `${LOGIN_VIDEO} ${video} byte > ${MAX_VIDEO_BYTES}`);
  if (poster === null) fail("media", `thiếu ${LOGIN_POSTER}`);
  else if (poster > MAX_POSTER_BYTES) fail("media", `${LOGIN_POSTER} ${poster} byte > ${MAX_POSTER_BYTES}`);
  for (const file of walk(join(ROOT, "public"), /\.(mp4|webm|mov)$/i)) {
    const rel = relative(ROOT, file).replace(/\\/g, "/");
    if (rel !== LOGIN_VIDEO) fail("media", `${rel}: video thừa trong public/ (${statSync(file).size} byte)`);
  }
}

function walk(dir, pattern = /\.tsx$/) {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) return walk(p, pattern);
    return pattern.test(p) ? [p] : [];
  });
}

checkTokenContrast();
checkThemeOverrides();
checkSameRulePairs();
checkTextOnSurface();
checkForbiddenPatterns();
checkFontSizes();
checkRadius();
checkMotion();
checkReducedMotion();
checkShadows();
checkFilterWidths();
checkNoBreadcrumb();
checkNoForgotPassword();
checkLoginMedia();

if (violations.length) {
  const groups = {};
  for (const v of violations) groups[v.slice(1, v.indexOf("]"))] = (groups[v.slice(1, v.indexOf("]"))] ?? 0) + 1;
  console.log(violations.join("\n"));
  console.log(`\naudit-ui: ${violations.length} vi phạm (${Object.entries(groups).map(([g, n]) => `${g} ${n}`).join(", ")})`);
  process.exit(1);
}
console.log(`audit-ui: OK (${TOKEN_PAIRS.length} cặp token, ${rules.length} rule CSS)`);
