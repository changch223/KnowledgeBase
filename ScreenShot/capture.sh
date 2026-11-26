#!/usr/bin/env bash
# App Store スクリーンショット自動撮影 (DEBUG ビルドのデモデータ投入モード)。
#
# 使い方:
#   ScreenShot/capture.sh                 # 7 ロケール × 5 画面 (35 枚)
#   ScreenShot/capture.sh en ja           # 指定ロケールのみ
#   SCREENS="home chat" ScreenShot/capture.sh en   # 指定画面のみ
#   SKIP_BUILD=1 ScreenShot/capture.sh    # ビルドを省略 (既存ビルドを再利用)
#
# 環境変数: SIM_UDID (既定: iPhone 17 Pro / iOS 26.5), DERIVED_DATA, WAIT (起動後の待機秒, 既定 6)
# 出力: ScreenShot/<locale>/<ファイル名>.PNG (ファイル名は ScreenShot/appstore/build.py の SLIDE_LAYOUT 準拠)
# デモモードの実体: KnowledgeBase/ScreenshotDemo.swift (#if DEBUG 限定)。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM_UDID="${SIM_UDID:-907EBA93-1FB8-4A0C-B320-33B52EC7D8B5}"   # iPhone 17 Pro (iOS 26.5)
DERIVED_DATA="${DERIVED_DATA:-${TMPDIR:-/tmp}/kb-screenshot-dd}"
WAIT="${WAIT:-6}"
SCREENS="${SCREENS:-home topic chat article library}"

# locale -> "AppleLanguages|AppleLocale"
locale_args() {
  case "$1" in
    ja)      echo "ja|ja_JP" ;;
    en)      echo "en|en_US" ;;
    zh-Hans) echo "zh-Hans|zh_CN" ;;
    zh-Hant) echo "zh-Hant|zh_TW" ;;
    ko)      echo "ko|ko_KR" ;;
    es)      echo "es|es_ES" ;;
    de)      echo "de|de_DE" ;;
    *) echo "unknown locale: $1" >&2; return 1 ;;
  esac
}

# screen -> 出力ファイル名
file_for() {
  case "$1" in
    home)    echo "knowledge base.PNG" ;;
    topic)   echo "wiki page.PNG" ;;
    chat)    echo "AI Chat.PNG" ;;
    article) echo "content page.PNG" ;;
    library) echo "library.PNG" ;;
    *) echo "unknown screen: $1" >&2; return 1 ;;
  esac
}

if [ "$#" -gt 0 ]; then LOCALES=("$@"); else LOCALES=(ja en zh-Hans zh-Hant ko es de); fi

xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null

if [ -z "${SKIP_BUILD:-}" ]; then
  echo "== build (Debug) =="
  xcodebuild build -project "$ROOT/KnowledgeBase.xcodeproj" -scheme KnowledgeBase \
    -configuration Debug -destination "platform=iOS Simulator,id=$SIM_UDID" \
    -derivedDataPath "$DERIVED_DATA" -quiet
fi

APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/KnowledgeBase.app"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
xcrun simctl install "$SIM_UDID" "$APP"

xcrun simctl ui "$SIM_UDID" appearance light
xcrun simctl status_bar "$SIM_UDID" override --time 9:41 --batteryState charged \
  --batteryLevel 100 --cellularBars 4 --wifiBars 3

for loc in "${LOCALES[@]}"; do
  IFS='|' read -r lang appleLocale <<<"$(locale_args "$loc")"
  mkdir -p "$ROOT/ScreenShot/$loc"
  for screen in $SCREENS; do
    out="$ROOT/ScreenShot/$loc/$(file_for "$screen")"
    xcrun simctl launch --terminate-running-process "$SIM_UDID" "$BUNDLE_ID" \
      -screenshotDemo YES -screenshotScreen "$screen" \
      -AppleLanguages "($lang)" -AppleLocale "$appleLocale" >/dev/null
    sleep "$WAIT"
    xcrun simctl io "$SIM_UDID" screenshot "$out" >/dev/null 2>&1
    echo "saved: $out"
  done
done

xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$SIM_UDID" clear
echo "done"
