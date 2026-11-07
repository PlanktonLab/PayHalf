import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import PDFDocument from 'pdfkit';
import SVGtoPDF from 'svg-to-pdfkit';
import { LAYOUTS } from './poster.js';

/**
 * 海報 PDF：把海報 SVG 畫進實際尺寸（公釐）的 PDF 頁面，可以直接送印。
 * 中文字型用思源黑體（Noto Sans TC），第一次用時下載並快取，之後只內嵌用到的字。
 */
const FONT_URL = (weight) =>
  `https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/SubsetOTF/TC/NotoSansTC-${weight}.otf`;
const WEIGHTS = ['Medium', 'Bold'];
const MM = 72 / 25.4;

let pending = null;
async function ensureFonts(dir) {
  fs.mkdirSync(dir, { recursive: true });
  const files = Object.fromEntries(WEIGHTS.map((w) => [w, path.join(dir, `NotoSansTC-${w}.otf`)]));
  const missing = WEIGHTS.filter((w) => !fs.existsSync(files[w]));
  if (missing.length) {
    pending ??= Promise.all(
      missing.map(async (w) => {
        const res = await fetch(FONT_URL(w));
        if (!res.ok) throw new Error(`字型下載失敗 ${res.status}`);
        const tmp = `${files[w]}.tmp`;
        fs.writeFileSync(tmp, Buffer.from(await res.arrayBuffer()));
        fs.renameSync(tmp, files[w]);
      }),
    ).finally(() => {
      pending = null;
    });
    await pending;
  }
  return files;
}

const A4 = [210, 297];

/** 裁切標記：四個角外側各兩條短線，不畫進成品範圍內 */
function cropMarks(doc, x, y, w, h) {
  const gap = 3 * MM;
  const len = 7 * MM;
  doc.save().lineWidth(0.5).strokeColor('#000000');
  for (const [cx, cy, sx, sy] of [
    [x, y, -1, -1],
    [x + w, y, 1, -1],
    [x, y + h, -1, 1],
    [x + w, y + h, 1, 1],
  ]) {
    doc.moveTo(cx + sx * gap, cy).lineTo(cx + sx * (gap + len), cy).stroke();
    doc.moveTo(cx, cy + sy * gap).lineTo(cx, cy + sy * (gap + len)).stroke();
  }
  doc.restore();
}

/**
 * 一律輸出 A4 頁面，超商、家用印表機都能直接印。
 * 比 A4 小的版型（壓克力立牌、明信片）以實際尺寸放在頁面中間，四角加裁切標記，沿標記剪下就是成品。
 */
export async function posterPdf(svg, layout, { fontDir } = {}) {
  const L = LAYOUTS[layout] ?? LAYOUTS.a4;
  const files = await ensureFonts(fontDir ?? path.join(os.tmpdir(), 'townpass-fonts'));
  const pageW = A4[0] * MM;
  const pageH = A4[1] * MM;
  const width = L.mm[0] * MM;
  const height = L.mm[1] * MM;
  const full = L.mm[0] >= A4[0] && L.mm[1] >= A4[1];
  const doc = new PDFDocument({ size: 'A4', margin: 0, info: { Title: `台北通 QR Code ${L.name}`, Creator: '台北通 陪辦' } });
  doc.registerFont('TC-Medium', files.Medium);
  doc.registerFont('TC-Bold', files.Bold);
  const chunks = [];
  doc.on('data', (c) => chunks.push(c));
  const done = new Promise((resolve) => doc.on('end', resolve));
  const x = full ? 0 : (pageW - width) / 2;
  const y = full ? 0 : (pageH - height) / 2 - 8 * MM;
  SVGtoPDF(doc, svg, x, y, {
    width: full ? pageW : width,
    height: full ? pageH : height,
    assumePt: false,
    fontCallback: (_family, bold) => (bold ? 'TC-Bold' : 'TC-Medium'),
  });
  if (!full) {
    cropMarks(doc, x, y, width, height);
    const cm = (n) => (n / 10).toFixed(1).replace(/\.0$/, '');
    doc
      .font('TC-Medium')
      .fontSize(9)
      .fillColor('#666666')
      .text(
        `${L.name.replace(/（.*）/, '')}：沿四角裁切標記剪下，成品寬 ${cm(L.mm[0])} × 高 ${cm(L.mm[1])} cm`,
        0,
        y + height + 14 * MM,
        { width: pageW, align: 'center' },
      )
      .text('列印時請選「實際大小」或縮放 100%，不要選「符合頁面」', { width: pageW, align: 'center' });
  }
  doc.end();
  await done;
  return Buffer.concat(chunks);
}
