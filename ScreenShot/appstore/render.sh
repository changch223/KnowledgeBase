#!/usr/bin/env bash
# build.py が書いた HTML をヘッドレス Chrome で PNG 化する。
# 使い方: cd ScreenShot/appstore && python3 build.py && ./render.sh [locale ...]
#   引数なし = 全 7 ロケール。出力: output/<locale>/<slide><suffix>.png
#   suffix: "" = 1320x2868 (6.9″) / -65 = 1242x2688 (6.5″) / -63 = 1206x2622 (6.3″) / -61 = 1179x2556 (6.1″)
set -euo pipefail
cd "$(dirname "$0")"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
locales=("$@")
[ ${#locales[@]} -eq 0 ] && locales=(ja zh-Hans zh-Hant en ko es de)

size_for() {
  case "$1" in
    "") echo "1320,2868" ;;
    -65) echo "1242,2688" ;;
    -63) echo "1206,2622" ;;
    -61) echo "1179,2556" ;;
  esac
}

for locale in "${locales[@]}"; do
  mkdir -p "output/$locale"
  for n in 01-knowledge 02-wiki 03-chat 04-save 05-library; do
    for suffix in "" -65 -63 -61; do
      f="$locale/$n$suffix.html"
      [ -f "$f" ] || continue
      "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
        --force-device-scale-factor=1 --allow-file-access-from-files \
        --window-size="$(size_for "$suffix")" \
        --screenshot="output/$locale/$n$suffix.png" "file://$PWD/$f" >/dev/null 2>&1
      echo "png  output/$locale/$n$suffix.png"
    done
  done
done
