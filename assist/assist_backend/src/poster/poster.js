import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import QRCode from 'qrcode';

/**
 * 靜態 QR Code 海報：後端直接產生 SVG（可印 A4 海報、明信片、壓克力立牌）。
 * 插圖都是原創向量圖（src/poster/art），沒有使用任何既有吉祥物。
 */
const ART_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), 'art');
const FONT = "'Noto Sans TC','PingFang TC','Heiti TC','Microsoft JhengHei',sans-serif";
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
  stand: { w: 1050, h: 1480, name: '壓克力立牌（A6）', mm: [105, 148] },
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

function pill(x, y, text, size, { bg = C.teal, fg = '#fff', padX = 0.9, anchor = 'start' } = {}) {
  const w = [...text].reduce((a, ch) => a + (/[\x20-\x7e]/.test(ch) ? 0.56 : 1), 0) * size + padX * 2 * size;
  const h = size * 1.9;
  const left = anchor === 'middle' ? x - w / 2 : x;
  return `<rect x="${left}" y="${y}" width="${w}" height="${h}" rx="${h / 2}" fill="${bg}"/>${textBlock([text], left + w / 2, y + h / 2 + size * 0.36, size, { weight: 700, color: fg, anchor: 'middle' })}`;
}

const deadlineText = (d) => {
  if (!d) return '';
  const [, m, day] = d.split('-').map(Number);
  return `${m} 月 ${day} 日前填好`;
};

/** QR 卡片：白底圓角＋虛線框＋「打開台北通掃一掃」 */
async function qrCard(url, x, y, size, label = '打開台北通，掃一掃') {
  const pad = size * 0.09;
  const cardH = size + pad * 2 + size * 0.17;
  return [
    `<rect x="${x + 10}" y="${y + 14}" width="${size + pad * 2}" height="${cardH}" rx="${size * 0.09}" fill="${C.ink}" opacity="0.12"/>`,
    `<rect x="${x}" y="${y}" width="${size + pad * 2}" height="${cardH}" rx="${size * 0.09}" fill="#fff" stroke="${C.ink}" stroke-width="${Math.max(4, size * 0.008)}"/>`,
    await qr(url, x + pad, y + pad, size),
    textBlock([label], x + pad + size / 2, y + pad + size + size * 0.12, size * 0.072, { weight: 700, color: C.tealDark, anchor: 'middle' }),
  ].join('');
}

function helpBubble(x, y, w, size) {
  const lines = ['不會填也沒關係！', '按畫面上的「找人幫我」，客服或身邊的人馬上來幫你。'];
  const body = wrap(lines[1], Math.floor((w - size * 2) / (size * 0.86)));
  const h = size * 1.6 + body.length * size * 0.86 * 1.4 + size * 0.9;
  return [
    `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${size * 0.7}" fill="#fff" stroke="${C.ink}" stroke-width="4"/>`,
    `<path d="M${x + w * 0.18} ${y + h - 2} l${size * 0.5} ${size * 0.9} l${size * 0.35} ${-size * 0.92}z" fill="#fff" stroke="${C.ink}" stroke-width="4" stroke-linejoin="round"/>`,
    `<rect x="${x + w * 0.18 + 3}" y="${y + h - 8}" width="${size * 0.8}" height="8" fill="#fff"/>`,
    textBlock([lines[0]], x + size, y + size * 1.45, size, { weight: 800, color: C.coral }),
    textBlock(body, x + size, y + size * 1.45 + size * 1.25, size * 0.86, { weight: 500, color: C.ink, lh: 1.4 }),
  ].join('');
}

/** 產生海報 SVG。url 是 QR Code 的內容（表單的固定網址） */
export async function posterSvg(form, { layout = 'a4', url }) {
  const L = LAYOUTS[layout] ?? LAYOUTS.a4;
  const { w, h } = L;
  const parts = [];
  parts.push(`<rect width="${w}" height="${h}" fill="${C.cream}"/>`);

  if (layout === 'postcard') {
    // ── 橫式：左邊文字、右邊 QR
    parts.push(`<rect x="0" y="0" width="${w}" height="${h * 0.12}" fill="${C.teal}"/>`);
    parts.push(textBlock(['台北通 TownPass ‧ 掃碼填表'], 56, h * 0.08, 34, { weight: 700, color: '#fff' }));
    parts.push(textBlock([form.dept || '臺北市政府'], w - 56, h * 0.08, 28, { weight: 500, color: '#fff', anchor: 'end' }));
    parts.push(place('cloud', 620, 150, 150));
    parts.push(place('sparkles', 560, h * 0.5, 100));
    const title = wrap(form.title, 9, 2);
    parts.push(textBlock(title, 64, 250, 84, { weight: 900, lh: 1.2 }));
    let ty = 250 + title.length * 84 * 1.2;
    if (form.desc) {
      const d = wrap(form.desc, 17, 2);
      parts.push(textBlock(d, 66, ty + 6, 32, { weight: 500, color: C.gray, lh: 1.45 }));
      ty += d.length * 32 * 1.45 + 10;
    }
    if (form.deadline) parts.push(pill(64, ty + 10, deadlineText(form.deadline), 28, { bg: C.yellow, fg: C.ink }));
    parts.push(place('skyline', 0, h - 250, w));
    parts.push(place('grandma', 70, h - 440, 230));
    parts.push(place('grandpa', 300, h - 440, 230));
    parts.push(await qrCard(url, 900, 190, 440));
    parts.push(place('magpie', 1250, 92, 170, { flip: true }));
    parts.push(place('blossom', 850, 150, 120));
    parts.push(pill(w - 56 - 520, h - 92, '不會填？按「找人幫我」就有人陪你辦', 24, { bg: C.ink }));
  } else {
    // ── 直式：A4 海報／壓克力立牌（同版型、依尺寸縮放）
    const k = w / 1240;
    const S = (n) => n * k;
    const compact = layout === 'stand';
    parts.push(`<path d="M0 0H${w}V${S(300)}C${w * 0.7} ${S(360)} ${w * 0.3} ${S(250)} 0 ${S(320)}Z" fill="${C.teal}"/>`);
    parts.push(place('cloud', S(880), S(36), S(200)));
    parts.push(place('cloud', S(60), S(210), S(120)));
    parts.push(textBlock(['台北通 TownPass ‧ 掃碼填表'], S(80), S(110), S(40), { weight: 700, color: '#fff' }));
    parts.push(textBlock([form.dept || '臺北市政府'], S(80), S(170), S(34), { weight: 500, color: C.tealLight }));

    const title = wrap(form.title, compact ? 9 : 10, 2);
    const tSize = S(compact ? 108 : 104);
    let y = S(420);
    parts.push(textBlock(title, w / 2, y, tSize, { weight: 900, anchor: 'middle', lh: 1.18 }));
    y += (title.length - 1) * tSize * 1.18 + S(70);
    if (form.desc && !compact) {
      const d = wrap(form.desc, 24, 2);
      parts.push(textBlock(d, w / 2, y, S(38), { weight: 500, color: C.gray, anchor: 'middle', lh: 1.45 }));
      y += d.length * S(38) * 1.45;
    }
    if (form.deadline) {
      parts.push(pill(w / 2, y - S(10), deadlineText(form.deadline), S(32), { bg: C.yellow, fg: C.ink, anchor: 'middle' }));
      y += S(80);
    } else {
      y += S(10);
    }

    if (compact) y += S(40);
    const qSize = S(compact ? 560 : 520);
    const cardW = qSize * 1.18;
    const qx = (w - cardW) / 2;
    parts.push(place('taipei101', S(54), y + S(60), S(150)));
    parts.push(place('sparkles', S(1050), y - S(10), S(130)));
    parts.push(await qrCard(url, qx, y, qSize));
    parts.push(place('magpie', qx + cardW - S(150), y - S(118), S(200), { flip: true }));
    parts.push(place('blossom', qx - S(70), y - S(60), S(130)));
    const cardBottom = y + qSize + qSize * 0.18 + qSize * 0.17;

    parts.push(place('skyline', 0, h - S(250), w));
    parts.push(place('grandma', S(40), h - S(470), S(260)));
    parts.push(place('helper', w - S(300), h - S(470), S(260)));
    const bubbleY = Math.max(cardBottom + S(40), h - S(560));
    parts.push(helpBubble(S(300), bubbleY, w - S(600), S(compact ? 40 : 38)));
    parts.push(place('mrt', S(880), h - S(120), S(200)));
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
<button onclick="png()">下載 PNG</button><button class="primary" onclick="print()">列印／存成 PDF</button></div>
<div class="sheet">${svg}</div>
<script>
function png(){const s=document.querySelector('.sheet svg');const vb=s.viewBox.baseVal;const c=document.createElement('canvas');const k=3;c.width=vb.width*k/1.0;c.height=vb.height*k/1.0;
const x=new XMLSerializer().serializeToString(s);const img=new Image();img.onload=()=>{const g=c.getContext('2d');g.drawImage(img,0,0,c.width,c.height);c.toBlob(b=>{const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=${JSON.stringify(`${form.title}_${L.name}.png`)};a.click()})};
img.src='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(x)}
</script></body></html>`;
}

/** 一般相機掃到 QR（沒有用台北通）時看到的頁面 */
export function landingPage(form, url) {
  return `<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(form?.title ?? '找不到表單')}｜台北通</title>
<style>body{margin:0;font-family:${FONT};background:${C.cream};color:${C.ink};display:flex;min-height:100vh;align-items:center;justify-content:center;padding:16px;box-sizing:border-box}
.card{background:#fff;border-radius:24px;padding:32px 24px;max-width:420px;width:100%;text-align:center;box-shadow:0 6px 24px rgba(0,0,0,.08)}
h1{font-size:28px;margin:8px 0 4px}p{font-size:19px;line-height:1.6;color:${C.gray}}.dept{font-size:16px;color:${C.tealDark}}
.step{background:${C.tealLight};border-radius:16px;padding:16px;margin:20px 0;font-size:20px;font-weight:700;color:${C.tealDark}}</style></head>
<body><div class="card">${
    form
      ? `<div class="dept">${esc(form.dept)}</div><h1>${esc(form.title)}</h1><p>${esc(form.desc)}</p>
<div class="step">請打開「台北通」App<br>按右下角「掃描」，再掃一次這個 QR Code</div>
<p>用台北通填寫，可以一鍵帶入你的資料。<br>不會填的時候，也可以按「找人幫我」。</p>`
      : `<h1>找不到這份表單</h1><p>這份表單可能已經停止收件了。</p>`
  }<p style="font-size:13px;color:#91A0A8;word-break:break-all">${esc(url)}</p></div></body></html>`;
}
