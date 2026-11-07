import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import QRCode from 'qrcode';

/**
 * 靜態 QR Code 海報：後端直接產生 SVG（可印 A4 海報、明信片、壓克力立牌）。
 * 點綴只用台北通 Logo（src/poster/art/townpass-mark.svg）與它的線條語彙。
 */
const ART_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), 'art');
const FONT = "-apple-system,'SF Pro Display','PingFang TC','Noto Sans TC','PingFang TC','Heiti TC','Microsoft JhengHei',sans-serif";
const C = {
  ink: '#22474E',
  teal: '#5AB4C5',
  tealDark: '#356C77',
  tealLight: '#DBF1F5',
  cream: '#FDF8ED',
  yellow: '#F5BA4B',
  yellowLight: '#F8E3BC',
  coral: '#E35D5D',
  gray: '#5E6D76',
};

export const LAYOUTS = {
  a4: { w: 1240, h: 1754, name: 'A4 海報', mm: [210, 297] },
  // 壓克力立牌實際尺寸：寬 9.1 cm × 高 14.4 cm
  stand: { w: 1092, h: 1728, name: '壓克力立牌（9.1 × 14.4 cm）', mm: [91, 144] },
  postcard: { w: 1480, h: 1000, name: '明信片', mm: [148, 100] },
};

const artCache = new Map();
function art(name) {
  if (!artCache.has(name)) {
    const file = path.join(ART_DIR, `${name}.svg`);
    if (!fs.existsSync(file)) return null;
    const raw = fs.readFileSync(file, 'utf8');
    const vb = raw.match(/viewBox="([^"]+)"/)?.[1];
    const rootTag = raw.match(/<svg([^>]*)>/)?.[1] ?? '';
    // 根節點上的 fill／stroke 等外觀屬性要保留，包成一個 <g>
    const keep = rootTag.replace(/\s(xmlns(:\w+)?|viewBox|width|height|version)="[^"]*"/g, '');
    const inner = `<g${keep}>${raw.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '')}</g>`;
    // 每張圖的 id 加前綴，避免多張圖合在一起時撞名
    const scoped = inner.replace(/id="([^"]+)"/g, `id="${name}-$1"`).replace(/url\(#([^)]+)\)/g, `url(#${name}-$1)`)
      .replace(/((?:xlink:)?href)="#([^"]+)"/g, `$1="#${name}-$2"`);
    artCache.set(name, { vb, inner: scoped });
  }
  return artCache.get(name);
}

/** 放一張插圖：以寬度為準，高度依比例 */
function place(name, x, y, w, { flip = false, rotate = 0 } = {}) {
  const a = art(name);
  if (!a) return '';
  const [, , vw, vh] = a.vb.split(/\s+/).map(Number);
  const h = (w * vh) / vw;
  const tf = [
    rotate ? `rotate(${rotate} ${x + w / 2} ${y + h / 2})` : '',
    flip ? `translate(${2 * x + w} 0) scale(-1 1)` : '',
  ].join(' ');
  return `<g transform="${tf.trim()}"><svg x="${x}" y="${y}" width="${w}" height="${h}" viewBox="${a.vb}" overflow="visible">${a.inner}</svg></g>`;
}

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

/** 中文以字寬換行（英數算半個字） */
export function wrap(text, maxUnits, maxLines = 99) {
  const lines = [];
  let cur = '';
  let units = 0;
  for (const ch of String(text ?? '')) {
    if (ch === '\n') {
      lines.push(cur);
      cur = '';
      units = 0;
      continue;
    }
    const u = /[\x20-\x7e]/.test(ch) ? 0.56 : 1;
    if (units + u > maxUnits) {
      // 標點不放行首
      if (/[，。、！？：；）」』]/.test(ch)) {
        cur += ch;
        lines.push(cur);
        cur = '';
        units = 0;
        continue;
      }
      lines.push(cur);
      cur = '';
      units = 0;
    }
    cur += ch;
    units += u;
  }
  if (cur) lines.push(cur);
  if (lines.length > maxLines) {
    const kept = lines.slice(0, maxLines);
    kept[maxLines - 1] = `${kept[maxLines - 1].slice(0, -1)}…`;
    return kept;
  }
  return lines;
}

function textBlock(lines, x, y, size, { weight = 400, color = C.ink, lh = 1.35, anchor = 'start' } = {}) {
  return lines
    .map(
      (l, i) =>
        `<text x="${x}" y="${y + i * size * lh}" font-family="${FONT}" font-size="${size}" font-weight="${weight}" fill="${color}" text-anchor="${anchor}">${esc(l)}</text>`,
    )
    .join('');
}

async function qr(url, x, y, size) {
  const svg = await QRCode.toString(url, { type: 'svg', margin: 0, errorCorrectionLevel: 'Q', color: { dark: '#1B2B30', light: '#FFFFFF' } });
  const vb = svg.match(/viewBox="([^"]+)"/)[1];
  const inner = svg.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
  return `<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="${vb}" shape-rendering="crispEdges">${inner}</svg>`;
}

const deadlineText = (d) => {
  if (!d) return '';
  const [y, m, day] = d.split('-').map(Number);
  return `截止日期：${y} 年 ${m} 月 ${day} 日`;
};

const INK = '#1D1D1F';
const GRAY = '#6E6E73';
const TEAL = '#2EB6C7'; // 台北通 Logo 的藍綠
const LOGO_GRAY = '#959595'; // 台北通 Logo 的灰
const PALE = '#D5EEF2';

/** 以 (cx, cy) 為圓心的一段圓弧（角度用度數，0° 朝右、順時針） */
function arc(cx, cy, r, a1, a2, color, width) {
  const rad = (d) => (d * Math.PI) / 180;
  const x1 = cx + r * Math.cos(rad(a1));
  const y1 = cy + r * Math.sin(rad(a1));
  const x2 = cx + r * Math.cos(rad(a2));
  const y2 = cy + r * Math.sin(rad(a2));
  const large = Math.abs(a2 - a1) > 180 ? 1 : 0;
  return `<path d="M${x1.toFixed(1)} ${y1.toFixed(1)}A${r} ${r} 0 ${large} 1 ${x2.toFixed(1)} ${y2.toFixed(1)}" stroke="${color}" stroke-width="${width}" stroke-linecap="round" fill="none"/>`;
}
const dot = (x, y, r, color) => `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r}" fill="${color}"/>`;
const bar = (x, y, len, width, color) =>
  `<path d="M${x} ${y}V${y + len}" stroke="${color}" stroke-width="${width}" stroke-linecap="round"/>`;
const polar = (cx, cy, r, deg) => [cx + r * Math.cos((deg * Math.PI) / 180), cy + r * Math.sin((deg * Math.PI) / 180)];

/**
 * 點綴線條：取自台北通 Logo 的語彙——圓頭直線、弧線、圓點（藍綠＋灰）。
 * 左上一組同心弧、右下一組反向的弧，再加幾根圓頭直線，不搶 QR Code 的焦點。
 */
function accents(w, h, k) {
  const S = (n) => n * k;
  const out = [];
  out.push(arc(0, 0, S(150), 8, 82, TEAL, S(14)));
  out.push(arc(0, 0, S(205), 14, 70, PALE, S(14)));
  out.push(arc(0, 0, S(260), 20, 58, LOGO_GRAY, S(6)));
  out.push(dot(...polar(0, 0, S(260), 68), S(9), TEAL));
  out.push(arc(w, h, S(170), 188, 262, TEAL, S(14)));
  out.push(arc(w, h, S(225), 196, 250, PALE, S(14)));
  out.push(arc(w, h, S(280), 204, 240, LOGO_GRAY, S(6)));
  out.push(dot(...polar(w, h, S(280), 252), S(9), TEAL));
  out.push(bar(w - S(120), S(110), S(90), S(12), PALE));
  out.push(bar(w - S(86), S(140), S(60), S(12), TEAL));
  out.push(bar(S(96), h - S(230), S(70), S(12), TEAL));
  out.push(bar(S(130), h - S(205), S(110), S(12), PALE));
  return out.join('');
}

/** 台北通 Logo 標誌＋「台北通」字樣 */
function brand(x, y, size, anchor = 'middle') {
  const markW = size * 1.15;
  const gap = size * 0.35;
  const textW = size * 3;
  const left = anchor === 'middle' ? x - (markW + gap + textW) / 2 : x;
  return (
    place('townpass-mark', left, y - size * 0.95, markW) +
    textBlock(['台北通'], left + markW + gap, y, size, { weight: 700, color: INK })
  );
}

/**
 * 產生海報 SVG：白底、簡約，大標題＋QR Code，用台北通 Logo 的線條點綴。
 * url 是 QR Code 的內容（表單的固定網址）。
 */
export async function posterSvg(form, { layout = 'a4', url }) {
  const L = LAYOUTS[layout] ?? LAYOUTS.a4;
  const { w, h } = L;
  const parts = [`<rect width="${w}" height="${h}" fill="#FFFFFF"/>`];
  const deadline = deadlineText(form.deadline);

  if (layout === 'postcard') {
    // ── 橫式：左邊文字，右邊 QR
    parts.push(accents(w, h, 0.75));
    const left = 120;
    parts.push(brand(left, 300, 34, 'start'));
    const title = wrap(form.title, 8, 2);
    parts.push(textBlock(title, left, 420, 78, { weight: 800, color: INK, lh: 1.18 }));
    let y = 420 + (title.length - 1) * 78 * 1.18 + 76;
    parts.push(textBlock(['使用台北通來填寫表單'], left, y, 28, { weight: 500, color: GRAY }));
    y += 46;
    if (deadline) parts.push(textBlock([deadline], left, y, 26, { weight: 500, color: GRAY }));
    parts.push(textBlock([form.dept || '臺北市政府'], left, h - 120, 24, { weight: 500, color: GRAY }));
    parts.push(await qr(url, 880, 250, 480));
  } else {
    // ── 直式：A4 海報／壓克力立牌（同版型、依尺寸縮放）
    const k = w / 1240;
    const S = (n) => n * k;
    const cx = w / 2;
    // 比 A4 細長的版面（壓克力立牌）：多出來的高度一部分放到上方，讓內容在畫面中間
    const top = S(Math.max(0, h / k - 1754) * 0.65);
    parts.push(accents(w, h, k));
    parts.push(brand(cx, top + S(250), S(44)));
    const title = wrap(form.title, 9, 2);
    const tSize = S(104);
    parts.push(textBlock(title, cx, top + S(420), tSize, { weight: 800, color: INK, anchor: 'middle', lh: 1.16 }));
    let y = top + S(420) + (title.length - 1) * tSize * 1.16 + S(84);
    parts.push(textBlock(['使用台北通來填寫表單'], cx, y, S(38), { weight: 500, color: GRAY, anchor: 'middle' }));
    y += S(90);
    const q = S(600);
    parts.push(await qr(url, cx - q / 2, y, q));
    y += q + S(80);
    if (deadline) parts.push(textBlock([deadline], cx, y, S(32), { weight: 500, color: GRAY, anchor: 'middle' }));
    parts.push(textBlock([form.dept || '臺北市政府'], cx, h - S(150), S(28), { weight: 500, color: GRAY, anchor: 'middle' }));
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${L.mm[0]}mm" height="${L.mm[1]}mm">${parts.join('')}</svg>`;
}

/** 列印頁：直接內嵌 SVG，用瀏覽器「列印 → 存成 PDF」就是正確尺寸 */
export function posterPage(form, svg, layout) {
  const L = LAYOUTS[layout] ?? LAYOUTS.a4;
  return `<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(form.title)}｜${L.name}</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+TC:wght@400;500;700;800;900&display=swap" rel="stylesheet">
<style>
@page{size:${L.mm[0]}mm ${L.mm[1]}mm;margin:0}
html,body{margin:0;background:#E3E7E9;font-family:${FONT}}
.bar{position:sticky;top:0;display:flex;gap:8px;align-items:center;padding:12px 16px;background:#fff;border-bottom:1px solid #CAD1D5;z-index:2;flex-wrap:wrap}
.bar b{margin-right:auto;color:#22474E}
.bar a,.bar button{font:inherit;font-size:15px;padding:8px 14px;border-radius:999px;border:1px solid #5AB4C5;background:#fff;color:#356C77;cursor:pointer;text-decoration:none}
.bar .primary{background:#5AB4C5;color:#fff}
.sheet{padding:24px 16px;display:flex;justify-content:center}
.sheet svg{width:min(100%,${L.mm[0] * 3.2}px);height:auto;box-shadow:0 8px 30px rgba(0,0,0,.18);background:#fff}
@media print{.bar{display:none}.sheet{padding:0}.sheet svg{width:${L.mm[0]}mm;height:${L.mm[1]}mm;box-shadow:none}html,body{background:#fff}}
</style></head><body>
<div class="bar"><b>${esc(form.title)}｜${L.name}</b>
${Object.entries(LAYOUTS).map(([k, v]) => `<a href="?layout=${k}"${k === layout ? ' class="primary"' : ''}>${v.name}</a>`).join('')}
<a href="/api/forms/${encodeURIComponent(form.id)}/poster.pdf?layout=${layout}">下載 PDF</a><button onclick="png()">下載 PNG</button><button class="primary" onclick="print()">列印／存成 PDF</button></div>
<div class="sheet">${svg}</div>
<script>
function png(){const s=document.querySelector('.sheet svg');const vb=s.viewBox.baseVal;const c=document.createElement('canvas');const k=3;c.width=vb.width*k/1.0;c.height=vb.height*k/1.0;
const x=new XMLSerializer().serializeToString(s);const img=new Image();img.onload=()=>{const g=c.getContext('2d');g.drawImage(img,0,0,c.width,c.height);c.toBlob(b=>{const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=${JSON.stringify(`${form.title}_${L.name}.png`)};a.click()})};
img.src='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(x)}
</script></body></html>`;
}

/**
 * QR Code 指向的網址（/f/<表單代號>）。
 * 已安裝台北通的 iPhone 會透過 Universal Link 直接打開 App，不會看到這頁；
 * 沒有安裝、或連結還沒生效時，才會在 Safari 看到這頁，按按鈕用 townpass:// 開 App。
 */
export function landingPage(form, url, id, qrSvg = '') {
  const appLink = `townpass://f/${encodeURIComponent(id ?? '')}`;
  return `<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(form?.title ?? '找不到表單')}｜台北通</title>
<style>body{margin:0;font-family:${FONT};background:#fff;color:#1D1D1F;display:flex;min-height:100vh;align-items:center;justify-content:center;padding:24px;box-sizing:border-box;text-align:center}
.card{max-width:420px;width:100%}.brand{font-size:17px;font-weight:700;color:#2EB6C7;margin-bottom:28px}
h1{font-size:30px;margin:0 0 8px}.dept{font-size:16px;color:#6E6E73}p{font-size:17px;line-height:1.6;color:#6E6E73}
a.btn{display:block;margin:28px 0 12px;padding:16px;border-radius:14px;background:#2EB6C7;color:#fff;font-size:19px;font-weight:700;text-decoration:none}
.small{font-size:13px;color:#91A0A8;word-break:break-all}
.qr{display:none}.desk .qr{display:block;margin:26px auto 6px;width:220px;padding:12px;border:1px solid #DCE3E6;border-radius:18px}
.qr svg{display:block;width:100%;height:auto}.desk a.btn,.desk .mobile{display:none}.desk-only{display:none}.desk .desk-only{display:block}</style>
<script>if(!/iPhone|iPad|Android/i.test(navigator.userAgent))document.documentElement.classList.add('desk')</script></head>
<body><div class="card"><div class="brand">台北通</div>${
    form
      ? `<h1>${esc(form.title)}</h1><div class="dept">${esc(form.dept)}</div>
<a class="btn" href="${esc(appLink)}">使用台北通開啟</a>
<p class="mobile">請先安裝並登入台北通 App。<br>也可以打開台北通，點選「掃描」再掃一次 QR Code。</p>
${qrSvg ? `<div class="qr" role="img" aria-label="這份表單的 QR Code">${qrSvg}</div>` : ''}
<p class="desk-only">用手機相機掃描 QR Code，<br>就會直接在台北通打開這份表單。</p>`
      : `<h1>找不到這份表單</h1><p>這份表單可能已經停止收件。</p>`
  }<p class="small">${esc(url)}</p></div>${
    form
      ? `<script>
// 手機掃到 QR Code：直接請系統用台北通打開（iOS 會問一次「要在台北通中打開嗎？」）
if (/iPhone|iPad|Android/i.test(navigator.userAgent)) setTimeout(function () { location.href = ${JSON.stringify(appLink)}; }, 300);
</script>`
      : ''
  }</body></html>`;
}
