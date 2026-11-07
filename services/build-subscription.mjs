// Bundle the official settings view for offline use inside the mobile WebView.
import { build } from 'vite';
import { writeFile } from 'node:fs/promises';

const result = await build({
  define: { 'process.env.NODE_ENV': JSON.stringify('production') },
  build: {
    write: false,
    lib: { entry: 'src/subscription-app.ts', name: 'SubscriptionApp', formats: ['iife'] }
  }
});
const output = result[0].output;
const script = output.find(file => file.type === 'chunk').code;
const css = output.find(file => file.fileName.endsWith('.css')).source;
await writeFile(process.argv[2], `<!doctype html>
<html lang="zh-Hant" data-related="__RELATED_ENABLED__"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>訂閱</title><style>${css}</style></head>
<body><div id="app"></div><script>${script.replaceAll('</script', '<\\/script')}</script></body></html>`);
