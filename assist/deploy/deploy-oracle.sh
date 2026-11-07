#!/usr/bin/env bash
# 把陪辦後端＋承辦工作台網頁部署到 OracleCloud（https://payhalf.plankton.tw）。
#
#   assist/deploy/deploy-oracle.sh            # 用現有的 build/web
#   BUILD_WEB=1 assist/deploy/deploy-oracle.sh # 先重新 build 網頁
#
# 主機上的配置（第一次已設好，這支腳本只同步程式碼並重啟）：
#   ~/payhalf/                        程式碼（與 repo 相同的相對路徑）
#   ~/payhalf/ecosystem.config.cjs    pm2 設定，內含固定的 TOKEN_SECRET（只在主機上，不進 git）
#   pm2 名稱 payhalf-assist → 127.0.0.1:3210
#   /etc/nginx/sites-available/payhalf（內容同 nginx-payhalf.conf）→ Cloudflare 憑證 /etc/ssl/cloudflare/plankton-*.pem
set -euo pipefail

HOST="${HOST:-OracleCloud}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FLUTTER="${FLUTTER:-flutter}"

if [[ "${BUILD_WEB:-0}" == "1" ]]; then
  (cd "$ROOT/assist/assist_web" && "$FLUTTER" build web --release)
fi
[[ -f "$ROOT/assist/assist_web/build/web/index.html" ]] || { echo "找不到 assist_web/build/web，請先 build 或加 BUILD_WEB=1"; exit 1; }

ssh "$HOST" 'mkdir -p ~/payhalf/assist/assist_web/build ~/payhalf/admin-form-builder'
rsync -az --delete --exclude node_modules --exclude test "$ROOT/assist/assist_backend/" "$HOST:payhalf/assist/assist_backend/"
rsync -az --delete "$ROOT/assist/assist_web/build/web/" "$HOST:payhalf/assist/assist_web/build/web/"
rsync -az --delete --exclude node_modules "$ROOT/admin-form-builder/" "$HOST:payhalf/admin-form-builder/"

ssh "$HOST" 'set -e
  cd ~/payhalf/assist/assist_backend && npm ci --omit=dev --silent
  pm2 startOrReload ~/payhalf/ecosystem.config.cjs >/dev/null && pm2 save >/dev/null
  sleep 2
  curl -fsS -o /dev/null http://127.0.0.1:3210/api/legal && echo "後端正常：https://payhalf.plankton.tw"'
