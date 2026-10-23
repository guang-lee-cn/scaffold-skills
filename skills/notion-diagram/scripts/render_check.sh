#!/usr/bin/env bash
# 把 SVG 转成 PNG 以便肉眼自检。自动探测可用渲染器。
# 用法: render_check.sh <input.svg> [out.png] [width] [height]
#   Linux/WSL/git-bash: rsvg-convert / inkscape / chromium / google-chrome
#   Windows (git-bash):  Microsoft Edge / Chrome
set -u
SVG=${1:?need svg path}
OUT=${2:-"${SVG%.svg}.png"}
W=${3:-1280}
H=${4:-1000}
ABSPATH="$(cd "$(dirname "$SVG")" 2>/dev/null && pwd)/$(basename "$SVG")"

run(){ echo "[render] $*"; "$@" && echo "[ok] $OUT" && exit 0; }

# 1) rsvg-convert
if command -v rsvg-convert >/dev/null 2>&1; then
  run rsvg-convert -w "$W" -h "$H" -o "$OUT" "$ABSPATH"
fi
# 2) inkscape
if command -v inkscape >/dev/null 2>&1; then
  run inkscape "$ABSPATH" -w "$W" -h "$H" -o "$OUT"
fi
# 3) 浏览器 headless（Edge/Chrome/Chromium）
BROWSERS=(
  "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
  "/c/Program Files/Microsoft/Edge/Application/msedge.exe"
  "/c/Program Files/Google/Chrome/Application/chrome.exe"
  "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"
  microsoft-edge microsoft-edge-stable google-chrome chromium chromium-browser
)
URL="file://$(echo "$ABSPATH" | sed 's|^/c/|/|; s| |%20|g')"
for b in "${BROWSERS[@]}"; do
  if command -v "$b" >/dev/null 2>&1 || [ -x "$b" ]; then
    "$b" --headless=new --disable-gpu --force-device-scale-factor=1 --hide-scrollbars \
      --window-size="$W,$H" --screenshot="$OUT" "$URL" >/dev/null 2>&1
    [ -s "$OUT" ] && { echo "[ok] $OUT ($b)"; exit 0; }
  fi
done
echo "[fail] 未找到 rsvg-convert/inkscape/Edge/Chrome。请在 Windows 用 PowerShell 调 Edge headless（见 SKILL.md）。" >&2
exit 1
