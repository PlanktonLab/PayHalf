/**
 * 「本表單支援台北通」徽章的兩個網頁：
 *   /badge                 給局處的徽章與嵌入碼
 *   /demo/agency?form=…    示意：局處既有官網的表單，上方放了徽章
 * 局處官網為虛構示意，頁首明確標示，不使用任何真實機關標誌。
 */
const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const FONT = "-apple-system,BlinkMacSystemFont,'PingFang TC','Noto Sans TC','Microsoft JhengHei',sans-serif";

// ── 示意：局處既有官網表單
function legacyField(f, i) {
  const req = f.required !== false ? '<span class="req">*</span>' : '';
  const label = `<label for="f${i}">${req}${esc(f.label)}</label>`;
  const hint = f.hint ? `<div class="hint">${esc(f.hint)}</div>` : '';
  let input;
  switch (f.type) {
    case 'radio':
      input = (f.options ?? []).map((o, k) => `<label class="opt"><input type="radio" name="f${i}" ${k === 0 ? `id="f${i}"` : ''}> ${esc(o)}</label>`).join('');
      break;
    case 'checkbox':
      input = (f.options ?? []).map((o, k) => `<label class="opt"><input type="checkbox" ${k === 0 ? `id="f${i}"` : ''}> ${esc(o)}</label>`).join('');
      break;
    case 'textarea':
      input = `<textarea id="f${i}" rows="3"></textarea>`;
      break;
    case 'date':
      input = `<span class="roc">民國 <input class="s" id="f${i}"> 年 <input class="s"> 月 <input class="s"> 日</span>`;
      break;
    case 'consent':
      input = `<label class="opt"><input type="checkbox" id="f${i}"> 是</label>`;
      break;
    case 'file':
      input = `<input type="file" id="f${i}">`;
      break;
    default:
      input = `<input id="f${i}" type="text">`;
  }
  return `<tr><th>${label}</th><td>${input}${hint}</td></tr>`;
}

export function agencyPage(form, { base, kitHref }) {
  const dept = form.dept || '臺北市政府';
  const href = `${base}/f/${encodeURIComponent(form.id)}`;
  return `<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(form.title)}｜${esc(dept)}（示意）</title>
<style>
*{box-sizing:border-box}body{margin:0;font-family:${FONT};color:#333;background:#EEF1F4;font-size:15px}
.demo{background:#FFF4CC;color:#6B5200;font-size:14px;padding:9px 16px;display:flex;gap:12px;align-items:center;flex-wrap:wrap;border-bottom:1px solid #E8D48A}
.demo b{font-weight:700}.demo a{color:#6B5200;margin-left:auto}
header{background:#1F4E8C;color:#fff}
.top{max-width:1080px;margin:0 auto;padding:18px 16px;display:flex;align-items:center;gap:14px}
.logo{width:46px;height:46px;border-radius:50%;background:#fff;color:#1F4E8C;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:20px;flex:none}
.org{font-size:22px;font-weight:700;letter-spacing:1px}.org small{display:block;font-size:12px;font-weight:400;opacity:.75;letter-spacing:0}
.util{margin-left:auto;font-size:13px;opacity:.85;display:flex;gap:14px}
nav{background:#163A6B}nav ul{max-width:1080px;margin:0 auto;padding:0 16px;list-style:none;display:flex;flex-wrap:wrap}
nav li{padding:12px 18px;font-size:15px;color:#DCE6F5}nav li.on{background:#0F2C55;color:#fff;font-weight:600}
main{max-width:1080px;margin:0 auto;padding:16px}
.crumb{font-size:13px;color:#666;margin:6px 0 14px}
.page{background:#fff;border:1px solid #D5DBE3;padding:28px 32px}
h1{font-size:24px;margin:0 0 6px;color:#1F4E8C}.meta{font-size:13px;color:#777;margin-bottom:18px}
.tp{display:flex;align-items:center;gap:18px;flex-wrap:wrap;padding:16px 18px;margin:0 0 22px;border:1px solid #BFE3EA;background:#F2FAFB;border-radius:10px}
.tp a{display:inline-block;line-height:0;border-radius:12px;transition:transform .12s}
.tp a:hover{transform:translateY(-1px)}.tp a:focus-visible{outline:3px solid #2EB6C7;outline-offset:3px}
.tp p{margin:0;font-size:15px;color:#22474E;line-height:1.6;flex:1;min-width:220px}.tp p b{color:#0E6F7D}
.desc{background:#F7F8FA;border-left:4px solid #1F4E8C;padding:12px 16px;margin-bottom:20px;line-height:1.7}
.note{font-size:13px;color:#C0392B;margin-bottom:8px}
table{width:100%;border-collapse:collapse;font-size:14px}
th,td{border:1px solid #D5DBE3;padding:10px 12px;vertical-align:top;text-align:left}
th{width:26%;background:#F1F4F8;font-weight:600}.req{color:#C0392B;margin-right:2px}
input[type=text],input:not([type]),textarea{width:100%;max-width:360px;padding:5px 7px;border:1px solid #AAB4C0;font:inherit;font-size:14px}
input.s{width:48px}.opt{display:inline-block;margin:2px 16px 2px 0}.hint{font-size:12px;color:#888;margin-top:4px}
.law{height:150px;overflow-y:scroll;border:1px solid #D5DBE3;padding:10px 12px;font-size:12.5px;line-height:1.7;color:#555;background:#FAFAFA;margin-top:18px}
.cap{display:inline-block;padding:4px 12px;background:repeating-linear-gradient(45deg,#ddd 0 4px,#eee 4px 8px);font:italic 700 20px Georgia,serif;letter-spacing:6px;color:#555;vertical-align:middle;margin-left:8px;text-decoration:line-through}
.btns{text-align:center;margin-top:22px}.btns button{font:inherit;padding:8px 30px;margin:0 6px;border:1px solid #1F4E8C;background:#1F4E8C;color:#fff;cursor:pointer}
.btns button.g{background:#fff;color:#1F4E8C}
footer{max-width:1080px;margin:0 auto;padding:18px 16px 40px;font-size:12.5px;color:#777;line-height:1.8}
@media(max-width:700px){.page{padding:18px 14px}th,td{display:block;width:100%}th{border-bottom:0}.util{display:none}}
</style></head><body>
<div class="demo"><b>示意頁面</b>這是虛構的局處官網，用來展示「本表單支援台北通」徽章的放法。<a href="${esc(kitHref)}">取得徽章與嵌入碼 →</a></div>
<header><div class="top"><div class="logo">市</div><div class="org">${esc(dept)}<small>示意網站 · Demo</small></div>
<div class="util"><span>網站導覽</span><span>English</span><span>無障礙</span></div></div>
<nav><ul><li>首頁</li><li>最新消息</li><li>業務介紹</li><li class="on">線上申辦</li><li>下載專區</li><li>聯絡我們</li></ul></nav></header>
<main><div class="crumb">首頁 ＞ 線上申辦 ＞ ${esc(form.title)}</div>
<div class="page">
<h1>${esc(form.title)}</h1>
<div class="meta">發布單位：${esc(dept)}${form.deadline ? `　｜　收件截止：${esc(form.deadline)}` : ''}</div>
<div class="tp">
  <a href="${esc(href)}" target="_blank" rel="noopener" title="使用台北通填寫這份表單"><img src="${base}/badge.svg?theme=dark" alt="本表單支援台北通" height="56"></a>
  <p><b>用台北通填更簡單：</b>姓名、身分證字號一鍵帶入，字放大、可以念給你聽，不會填還能請人陪你辦。</p>
</div>
${form.desc ? `<div class="desc">${esc(form.desc)}</div>` : ''}
<div class="note">＊ 為必填欄位，請詳實填寫。</div>
<form onsubmit="event.preventDefault();alert('這是示意頁面，不會真的送出。\\n請改按上方「本表單支援台北通」徽章試試看。')">
<table>
${form.fields.filter((f) => f.type !== 'consent').map(legacyField).join('\n')}
<tr><th><span class="req">*</span>電子郵件</th><td><input type="text"><div class="hint">審核結果將以電子郵件通知</div></td></tr>
<tr><th><span class="req">*</span>驗證碼</th><td><input class="s" style="width:110px"><span class="cap">7kQ3x</span> <a href="#" onclick="return false" style="font-size:13px">換一張</a> <a href="#" onclick="return false" style="font-size:13px">語音播放</a></td></tr>
</table>
<div class="law"><b>蒐集個人資料告知事項</b><br>
${esc(dept)}（以下簡稱本機關）依據個人資料保護法（以下簡稱個資法）第 8 條規定，向台端告知下列事項：<br>
一、蒐集目的：辦理「${esc(form.title)}」相關業務、行政管理、統計分析及聯繫通知（代號 001、069、157 等）。<br>
二、個人資料類別：辨識個人者（C001）、政府資料中之辨識者（C003）、個人描述（C011）等，詳如申請表所載。<br>
三、個人資料利用之期間、地區、對象及方式：期間為本業務辦理期間及依法令或本機關檔案保存年限；地區為中華民國境內；對象為本機關及其他依法令得提供之機關；方式為以自動化機器或其他非自動化之利用方式。<br>
四、依個資法第 3 條規定，台端得就本機關保有之個人資料行使下列權利：（一）查詢或請求閱覽。（二）請求製給複製本。（三）請求補充或更正。（四）請求停止蒐集、處理或利用。（五）請求刪除。但因本機關執行職務或業務所必須者，本機關得拒絕之。<br>
五、台端若未提供正確之個人資料，本機關將無法為台端提供本項服務。<br>
六、台端如欲行使上述權利，或有任何疑義，請洽本機關承辦人員。</div>
<label class="opt" style="margin-top:10px"><input type="checkbox"> 本人已詳細閱讀並同意上述「蒐集個人資料告知事項」</label>
<div class="btns"><button type="submit">送出申請</button><button type="reset" class="g">清除重填</button></div>
</form></div></main>
<footer>${esc(dept)}（示意）｜地址：臺北市○○區○○路○號｜服務專線：1999（外縣市請撥 02-2720-8889）<br>本網站為黑客松展示用之虛構頁面。建議使用 Chrome、Edge、Safari 最新版本瀏覽。</footer>
</body></html>`;
}

// ── 給局處的徽章與嵌入碼
export function badgeKitPage(forms, { base }) {
  const first = forms[0]?.id ?? 'demo';
  const options = forms.map((f) => `<option value="${esc(f.id)}">${esc(f.title)}（${esc(f.dept)}）</option>`).join('');
  return `<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>本表單支援台北通｜徽章</title>
<style>
*{box-sizing:border-box}body{margin:0;font-family:${FONT};background:#F5F7F8;color:#1D2A30}
main{max-width:880px;margin:0 auto;padding:40px 20px 60px}
.brand{font-size:15px;font-weight:700;color:#2EB6C7;margin-bottom:10px}
h1{font-size:30px;margin:0 0 10px}.lead{font-size:16px;line-height:1.7;color:#4A5A62;margin:0 0 28px}
.card{background:#fff;border:1px solid #DCE3E6;border-radius:16px;padding:24px;margin-bottom:18px}
h2{font-size:18px;margin:0 0 14px}
.row{display:flex;gap:16px;flex-wrap:wrap}
.sw{flex:1;min-width:260px;border-radius:12px;padding:28px;display:flex;flex-direction:column;align-items:center;gap:14px}
.sw.l{background:#F0F3F4}.sw.d{background:#1D2A30;color:#fff}
.sw a.dl{font-size:13px;color:inherit;opacity:.8}
ol{margin:0;padding-left:20px;line-height:1.9;color:#33444C}
select,textarea{width:100%;font:inherit;font-size:14px;border:1px solid #CAD3D7;border-radius:10px;padding:10px 12px;background:#fff}
textarea{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12.5px;height:96px;resize:vertical;margin-top:10px;color:#22474E}
.bar{display:flex;gap:10px;flex-wrap:wrap;margin-top:12px;align-items:center}
button,a.btn{font:inherit;font-size:15px;padding:10px 18px;border-radius:999px;border:1px solid #5AB4C5;background:#fff;color:#356C77;cursor:pointer;text-decoration:none}
.primary{background:#2EB6C7 !important;border-color:#2EB6C7 !important;color:#fff !important}
.seg{display:inline-flex;border:1px solid #CAD3D7;border-radius:999px;overflow:hidden}.seg button{border:0;border-radius:0;padding:8px 14px}
.seg button.on{background:#E3F4F7;color:#0E6F7D;font-weight:600}
.ok{font-size:13px;color:#2E8B57;display:none}
.rules{font-size:14px;color:#4A5A62;line-height:1.8}
</style></head><body><main>
<div class="brand">台北通 · 陪辦</div>
<h1>本表單支援台北通</h1>
<p class="lead">局處的表單還放在自己的官網上也沒關係。在台北通後台建立同一份表單，再把這個徽章貼在官網表單的上方：民眾點一下，就改用台北通填寫，個資一鍵帶入、字體放大，還能請人陪辦。</p>

<div class="card"><h2>徽章</h2>
<div class="row">
  <div class="sw l"><img src="${base}/badge.svg?theme=dark" alt="本表單支援台北通（黑色）" height="64"><a class="dl" href="${base}/badge.svg?theme=dark" download="townpass-badge-dark.svg">下載黑色 SVG</a></div>
  <div class="sw d"><img src="${base}/badge.svg?theme=light" alt="本表單支援台北通（白色）" height="64"><a class="dl" href="${base}/badge.svg?theme=light" download="townpass-badge-light.svg">下載白色 SVG（深色背景用）</a></div>
</div></div>

<div class="card"><h2>貼到局處官網</h2>
<ol><li>先在台北通後台「我的表單」建立並發布這份表單。</li><li>選擇表單，複製下面的程式碼。</li><li>貼在官網原本表單的最上方（標題下面）。</li></ol>
<div style="margin-top:14px"><select id="form">${options}</select></div>
<div class="bar"><span class="seg" id="theme"><button class="on" data-t="dark">黑色</button><button data-t="light">白色</button></span></div>
<textarea id="code" readonly></textarea>
<div class="bar"><button class="primary" id="copy">複製程式碼</button><a class="btn" id="demo" target="_blank" rel="noopener">看局處網站示意 ↗</a><span class="ok" id="ok">已複製</span></div>
</div>

<div class="card rules"><h2>使用方式</h2>
・高度不要小於 40px，周圍至少留徽章高度 1/4 的空白。<br>
・只能連到台北通的表單網址（${esc(base)}/f/…），不要改顏色或文字。<br>
・民眾沒有安裝台北通時，點了會看到 QR Code 與下載說明；原本的官網表單仍可照常使用。</div>
</main>
<script>
const base=${JSON.stringify(base)};let theme='dark';
const embed=(id)=>'<a href="'+base+'/f/'+encodeURIComponent(id)+'" target="_blank" rel="noopener" title="使用台北通填寫這份表單">\\n  <img src="'+base+'/badge.svg?theme='+theme+'" alt="本表單支援台北通" height="56">\\n</a>';
const sel=document.getElementById('form'),code=document.getElementById('code');
function render(){code.value=embed(sel.value);document.getElementById('demo').href='/demo/agency?form='+encodeURIComponent(sel.value);}
sel.value=${JSON.stringify(first)};sel.onchange=render;
document.querySelectorAll('#theme button').forEach(b=>b.onclick=()=>{theme=b.dataset.t;document.querySelectorAll('#theme button').forEach(x=>x.classList.toggle('on',x===b));render();});
document.getElementById('copy').onclick=async()=>{try{await navigator.clipboard.writeText(code.value)}catch{code.select();document.execCommand('copy')}const ok=document.getElementById('ok');ok.style.display='inline';setTimeout(()=>ok.style.display='none',1500)};
render();
</script></body></html>`;
}
