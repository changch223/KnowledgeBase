#!/usr/bin/env python3
# App Store スクリーンショット v3 (1320x2868 / 6.9", 多言語対応)
#
# v2 ブラッシュアップ (Apple 公式スクショのベストプラクティス反映):
#   1. 端末下端ブリード — 端末を +18% 大型化し下端で切る (UI を大きく、死に余白を消す)
#   2. 見出しキーワードだけ藍色 #3A4A63 (朱書きのような品のある強調、サムネイルで埋もれない)
#   3. コールアウトチップ 1 枚 1 つ (見どころを 0.5 秒で伝える)
#   4. 見出しベースライン全 5 枚固定 / 1 枚 1 メッセージ / 柔らかい大影 + 薄ベゼル
#
# v3 多言語対応 (App Store v1.1、docs/app-store/RELEASE-MATERIALS.md §1-J と対応):
#   - LOCALES 分のキャプション (CAPTIONS) を持ち、ロケールごとに HTML / 出力先を分ける
#   - 元画像は ScreenShot/<locale>/<同名ファイル> を優先、なければ ScreenShot/<同名ファイル> (ja 実機) に
#     フォールバックする。→ zh/en の実機スクショが無い環境でも、ja 画像 + 各言語キャプションで
#     プレビュー生成ができる (キャプション先行レビュー用)。実機を差し替えたら再実行するだけで反映される。
#   - 出力先は HTML: <locale>/*.html、PNG: output/<locale>/*.png (旧: 直下 *.html / output/ フラット構成
#     から明確に移行。旧パスの互換維持はしない。詳細は README.md 参照)
#
# 記法: 見出しの "|" = 改行、《...》 = 藍色アクセント。
# 生成後にヘッドレス Chrome で PNG 化する (README 参照)。

import os
import re
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
SCREENSHOT_DIR = os.path.join(HERE, "..")  # ScreenShot/

# 生成するロケール (App Store Connect のロケールコードに合わせる)
LOCALES = ["ja", "zh-Hans", "zh-Hant", "en"]

# レイアウト共通設定 (ロケール非依存): (出力名, 既定の元画像ファイル名, チップ側 left/right, チップ top px)
# 元画像はロケールごとに ScreenShot/<locale>/<ファイル名> を優先探索し、無ければこのファイル名で
# ScreenShot/ 直下 (ja 実機) にフォールバックする。
SLIDE_LAYOUT = [
    ("01-knowledge", "knowledge base.PNG", "right", 1835),
    ("02-wiki", "wiki page.PNG", "left", 1156),
    ("03-chat", "AI Chat.PNG", "right", 2069),
    ("04-save", "content page.PNG", "right", 1560),
    ("05-library", "library.PNG", "right", 1227),
]

# ロケール別キャプション。SLIDE_LAYOUT と同じ順序 5 件、各 (見出し, サブ, チップ文言)。
# 《》の位置は言語ごとに自然な語順に置いてある (docs/app-store/RELEASE-MATERIALS.md §1-J の
# ASO コピーに合わせた訳語・用語統一済み)。
CAPTIONS = {
    "ja": [
        ("読んだことが、|《勝手に》まとまる。", "AIがテーマごとに要点を先に見せる", "要点がひと目で"),
        ("AIが、あなただけの|《百科事典》を編さん。", "複数の記事を1ページに束ねる", "読むほど育つ"),
        ("あなたの知識に、|《根拠付き》で答える。", "引用をタップで元記事へ", "出典付き回答"),
        ("読んだその場で、|《2タップ》で保存。", "URL・写真・PDF・音声も", "共有からすぐ"),
        ("分野もタグも、|AIが《自動》で整理。", "保存するほど、見つけやすくなる", "自動で分類"),
    ],
    "zh-Hans": [
        ("读过的知识，|《自动》梳理成型。", "AI 按主题为你先列出要点", "要点一目了然"),
        ("AI 为你编纂|专属《百科全书》。", "多篇文章汇成一页", "越读越丰富"),
        ("你的知识，|《有据可查》地回答。", "点击引用直达原文", "附出处回答"),
        ("读到就存，|《两步》搞定。", "URL・照片・PDF・语音都行", "分享即可保存"),
        ("类别与标签，|AI《自动》整理。", "保存越多，越容易找到", "自动分类"),
    ],
    "zh-Hant": [
        ("讀過的知識，|《自動》梳理成型。", "AI 依主題為你率先列出要點", "要點一目了然"),
        ("AI 為你編纂|專屬《百科全書》。", "多篇文章彙整成一頁", "越讀越豐富"),
        ("你的知識，|《有憑有據》地回答。", "點擊引用直達原文", "附出處回答"),
        ("讀到就存，|《兩步》搞定。", "URL・照片・PDF・語音都行", "分享即可儲存"),
        ("類別與標籤，|AI《自動》整理。", "儲存越多，越容易找到", "自動分類"),
    ],
    "en": [
        ("What you read|《organizes itself》.", "AI surfaces key points by topic first", "Key points at a glance"),
        ("AI compiles your own|《personal encyclopedia》.", "Multiple articles, one page", "Grows as you read"),
        ("Answers to your knowledge,|《backed by citations》.", "Tap a citation to jump to the source", "Answers with sources"),
        ("Save the moment you read it,|in 《2 taps》.", "URL, photo, PDF, or audio", "Straight from Share Sheet"),
        ("Categories and tags,|organized 《automatically》.", "The more you save, the easier to find", "Auto-classified"),
    ],
}

# 出力サイズ (suffix, 幅, 高さ)。基準デザインは 1320x2868、他サイズは精密スケールで生成。
SIZES = [
    ("", 1320, 2868),          # 6.9" (iPhone 17 Pro Max 等)
    ("-65", 1242, 2688),       # 6.5" (1242x2688 スロット)
]

TEMPLATE = """<!DOCTYPE html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<title>{name}</title>
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  html, body {{ background:#c9c3b6; }}
  /* 基準デザイン = 1320x2868。他サイズは .slide を transform scale して等倍出力。 */
  .slide {{
    position:relative;
    width:1320px; height:2868px;
    {slide_scale}
    background:#F4EFE6;               /* 和紙 washiBackground */
    overflow:hidden;
    font-family:"Hiragino Sans","Noto Sans JP",sans-serif;
  }}
  /* ===== 上帯 (キャプション) — 見出しベースラインは全 5 枚で固定 ===== */
  .band {{
    position:absolute; top:0; left:0; right:0; height:560px;
    padding:112px 96px 0 96px;
  }}
  .headline {{
    font-family:"Hiragino Mincho ProN","YuMincho","Noto Serif JP",serif;
    font-weight:700;
    color:#1C1B19;                    /* 墨 sumiInk */
    font-size:76px; line-height:1.30;
    letter-spacing:0.005em;
  }}
  .headline .accent {{ color:#3A4A63; }}   /* 藍アクセント (キーワードのみ) */
  .sub {{
    margin-top:30px;
    font-weight:400;
    color:#57524A;                    /* 墨中間 sumiMid */
    font-size:40px; line-height:1.4;
  }}
  .hairline {{
    position:absolute; left:96px; right:96px; bottom:0;
    height:2px; background:#D9D2C4;    /* 墨罫 sumiRule */
  }}
  /* ===== 青海波 (下端・低透明、端末の左右コーナーに覗く) ===== */
  .seigaiha {{
    position:absolute; left:0; right:0; bottom:0; height:170px;
    opacity:0.09; pointer-events:none;
    background-image:
      radial-gradient(circle at 44px 44px, transparent 32px, #3A4A63 33px 35px, transparent 36px),
      radial-gradient(circle at 44px 44px, transparent 20px, #3A4A63 21px 23px, transparent 24px);
    background-size:88px 48px;
  }}
  /* ===== 端末 (下端ブリード = Apple 公式の定番構図) ===== */
  .device {{
    position:absolute; top:700px; left:50%;
    transform:translateX(-50%);
    width:1100px;                      /* v1 928px → +18% 大型化 */
    background:#1C1B19;
    border-radius:88px 88px 0 0;       /* 下端は画面外 → 角丸不要 */
    padding:12px 12px 0 12px;          /* 薄ベゼル */
    box-shadow:0 30px 80px rgba(28,27,25,0.18), 0 8px 20px rgba(28,27,25,0.08);
  }}
  .device .screen {{
    display:block; width:100%; height:auto;
    border-radius:76px 76px 0 0;
  }}
  /* ===== コールアウトチップ (1 枚に 1 つだけ) ===== */
  .chip {{
    position:absolute; z-index:10;
    display:flex; align-items:center; gap:16px;
    background:#FCFAF5;
    border:2px solid #E3DCCB;
    border-radius:999px;
    padding:20px 36px;
    font-weight:600; font-size:38px; color:#1C1B19;
    box-shadow:0 14px 38px rgba(28,27,25,0.16);
    white-space:nowrap;
  }}
  .chip::before {{
    content:""; width:16px; height:16px; border-radius:50%;
    background:#3A4A63; flex:none;
  }}
  .chip-right {{ right:44px; }}
  .chip-left  {{ left:44px; }}
</style>
</head>
<body>
  <div class="slide" id="slide">
    <div class="band">
      <div class="headline">{headline}</div>
      <div class="sub">{sub}</div>
      <div class="hairline"></div>
    </div>
    <div class="seigaiha"></div>
    <div class="device">
      <img class="screen" src="{img}" alt="">
    </div>
    <div class="chip chip-{chip_side}" style="top:{chip_top}px">{chip}</div>
  </div>
</body>
</html>
"""


def render_headline(text: str) -> str:
    """《...》 → 藍アクセント span、| → 改行。"""
    text = re.sub(r"《(.+?)》", r'<span class="accent">\1</span>', text)
    return text.replace("|", "<br>")


def resolve_image(locale: str, img_file: str):
    """ロケール別の実機画像 (ScreenShot/<locale>/<img_file>) があれば優先、
    無ければ ScreenShot/<img_file> (ja 実機、既定フォールバック) を使う。
    どちらも無ければ None (未撮影スライドはスキップ)。
    戻り値は (絶対パス, HTML からの相対 src) のタプル。
    """
    locale_path = os.path.join(SCREENSHOT_DIR, locale, img_file)
    if os.path.exists(locale_path):
        return locale_path, "../../%s/%s" % (urllib.parse.quote(locale), urllib.parse.quote(img_file))
    default_path = os.path.join(SCREENSHOT_DIR, img_file)
    if os.path.exists(default_path):
        return default_path, "../../" + urllib.parse.quote(img_file)
    return None, None


def build_locale(locale: str):
    out_dir = os.path.join(HERE, locale)
    os.makedirs(out_dir, exist_ok=True)
    captions = CAPTIONS[locale]
    written = []
    for (name, default_img, chip_side, chip_top), (headline, sub, chip) in zip(SLIDE_LAYOUT, captions):
        abs_img, img_rel = resolve_image(locale, default_img)
        if abs_img is None:
            print("skip  [%s] %s — 元画像なし: ScreenShot/%s or ScreenShot/%s/%s (撮影後に再実行)"
                  % (locale, name, default_img, locale, default_img))
            continue
        for suffix, w, h in SIZES:
            if suffix == "":
                slide_scale = ""
            else:
                sx = w / 1320.0
                sy = h / 2868.0
                slide_scale = "transform:scale(%.6f,%.6f); transform-origin:0 0;" % (sx, sy)
            html = TEMPLATE.format(
                lang=locale,
                name=name + suffix,
                slide_scale=slide_scale,
                headline=render_headline(headline),
                sub=sub,
                img=img_rel,
                chip=chip,
                chip_side=chip_side,
                chip_top=chip_top,
            )
            out = os.path.join(out_dir, name + suffix + ".html")
            with open(out, "w", encoding="utf-8") as f:
                f.write(html)
            print("wrote", out)
        written.append((name, headline))

    # ロケール別 index
    links = "\n".join(
        '<li><a href="{n}.html">{n} — {h}</a></li>'.format(n=n, h=re.sub(r"[《》|]", "", h))
        for n, h in written
    )
    index = """<!DOCTYPE html><html lang="{lang}"><head><meta charset="utf-8">
<title>App Store screenshots — {lang}</title>
<style>body{{font-family:-apple-system,sans-serif;padding:40px;line-height:2}}a{{color:#3A4A63}}</style>
</head><body><h1>App Store スクリーンショット — {lang} ({count} 枚)</h1><ol>{links}</ol>
<p><a href="../index.html">&larr; ロケール一覧に戻る</a></p></body></html>""".format(
        lang=locale, count=len(written), links=links)
    with open(os.path.join(out_dir, "index.html"), "w", encoding="utf-8") as f:
        f.write(index)
    print("wrote", os.path.join(out_dir, "index.html"))
    return written


def main():
    results = {}
    for locale in LOCALES:
        results[locale] = build_locale(locale)

    # トップレベル index (ロケール一覧)
    items = "\n".join(
        '<li><a href="{loc}/index.html">{loc}</a> — {n} 枚生成</li>'.format(loc=loc, n=len(results[loc]))
        for loc in LOCALES
    )
    top_index = """<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<title>App Store screenshots v3 (multi-locale)</title>
<style>body{{font-family:-apple-system,sans-serif;padding:40px;line-height:2}}a{{color:#3A4A63}}</style>
</head><body><h1>App Store スクリーンショット v3 (多言語)</h1><ul>{items}</ul></body></html>""".format(items=items)
    with open(os.path.join(HERE, "index.html"), "w", encoding="utf-8") as f:
        f.write(top_index)
    print("wrote", os.path.join(HERE, "index.html"))


if __name__ == "__main__":
    main()
