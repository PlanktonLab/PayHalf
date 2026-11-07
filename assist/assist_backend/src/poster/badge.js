import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * 「本表單支援台北通」徽章（仿 Add to Apple Wallet 的形式）。
 * 局處把它放在自己官網的表單上方，民眾點一下就改用台北通填寫。
 *
 *   /badge.svg?theme=dark|light
 */
const here = path.dirname(fileURLToPath(import.meta.url));
const markInner = fs
  .readFileSync(path.join(here, 'art', 'townpass-mark.svg'), 'utf8')
  .replace(/^<svg[^>]*>/, '')
  .replace(/<\/svg>\s*$/, '');

const FONT = "-apple-system,BlinkMacSystemFont,'SF Pro Display','PingFang TC','Noto Sans TC','Microsoft JhengHei',sans-serif";

export const BADGE_THEMES = {
  dark: { bg: '#000000', stroke: '#A6A6A6', tile: '#FFFFFF', small: '#FFFFFF', big: '#FFFFFF' },
  light: { bg: '#FFFFFF', stroke: '#000000', tile: '#EAF6F8', small: '#000000', big: '#000000' },
};

/** 寬 336、高 96 的徽章；用 height 控制大小即可 */
export function badgeSvg(theme = 'dark') {
  const t = BADGE_THEMES[theme] ?? BADGE_THEMES.dark;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 336 96" width="336" height="96" role="img" aria-label="本表單支援台北通">
<title>本表單支援台北通</title>
<rect x="1.5" y="1.5" width="333" height="93" rx="17" fill="${t.bg}" stroke="${t.stroke}" stroke-width="3"/>
<rect x="17" y="16" width="64" height="64" rx="15" fill="${t.tile}"/>
<svg x="25" y="25" width="48" height="46" viewBox="0 2.6 20.5 18.8">${markInner}</svg>
<text x="98" y="40" font-family="${FONT}" font-size="20" font-weight="500" letter-spacing="1" fill="${t.small}">本表單支援</text>
<text x="96" y="78" font-family="${FONT}" font-size="37" font-weight="700" fill="${t.big}">台北通<tspan dx="8" font-size="22" font-weight="600">TownPass</tspan></text>
</svg>`;
}
