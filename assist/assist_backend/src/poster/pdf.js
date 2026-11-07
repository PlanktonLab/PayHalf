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

export async function posterPdf(svg, layout, { fontDir } = {}) {
  const L = LAYOUTS[layout] ?? LAYOUTS.a4;
  const files = await ensureFonts(fontDir ?? path.join(os.tmpdir(), 'townpass-fonts'));
  const width = L.mm[0] * MM;
  const height = L.mm[1] * MM;
  const doc = new PDFDocument({ size: [width, height], margin: 0, info: { Title: '台北通 QR Code 海報', Creator: '台北通 陪辦' } });
  doc.registerFont('TC-Medium', files.Medium);
  doc.registerFont('TC-Bold', files.Bold);
  const chunks = [];
  doc.on('data', (c) => chunks.push(c));
  const done = new Promise((resolve) => doc.on('end', resolve));
  SVGtoPDF(doc, svg, 0, 0, {
    width,
    height,
    assumePt: false,
    fontCallback: (_family, bold) => (bold ? 'TC-Bold' : 'TC-Medium'),
  });
  doc.end();
  await done;
  return Buffer.concat(chunks);
}
