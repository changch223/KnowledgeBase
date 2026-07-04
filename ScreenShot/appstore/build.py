#!/usr/bin/env python3
# App Store スクリーンショット v2 (1320x2868 / 6.9")
#
# v2 ブラッシュアップ (Apple 公式スクショのベストプラクティス反映):
#   1. 端末下端ブリード — 端末を +18% 大型化し下端で切る (UI を大きく、死に余白を消す)
#   2. 見出しキーワードだけ藍色 #3A4A63 (朱書きのような品のある強調、サムネイルで埋もれない)
#   3. コールアウトチップ 1 枚 1 つ (見どころを 0.5 秒で伝える)
#   4. 見出しベースライン全 5 枚固定 / 1 枚 1 メッセージ / 柔らかい大影 + 薄ベゼル
#
# 記法: 見出しの "|" = 改行、《...》 = 藍色アクセント。
# 生成後にヘッドレス Chrome で PNG 化する (README 参照)。

import os
import re
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))

# (出力名, 元画像, 見出し, サブ, チップ文言, チップ側 left/right, チップ top px)
SLIDES = [
    ("01-knowledge", "knowledge base.PNG",
     "読んだことが、|《勝手に》まとまる。", "AIがテーマごとに要点を先に見せる",
     "要点がひと目で", "right", 1835),
    ("02-wiki", "wiki page.PNG",
     "AIが、あなただけの|《百科事典》を編さん。", "複数の記事を1ページに束ねる",
     "読むほど育つ", "left", 1156),
    ("03-chat", "AI Chat.PNG",
     "あなたの知識に、|《根拠付き》で答える。", "引用をタップで元記事へ",
     "出典付き回答", "right", 2069),
    ("04-save", "content page.PNG",
     "読んだその場で、|《2タップ》で保存。", "URL・写真・PDF・音声も",
     "共有からすぐ", "right", 1560),
    ("05-library", "library.PNG",
     "分野もタグも、|AIが《自動》で整理。", "保存するほど、見つけやすくなる",
     "自動で分類", "right", 1227),
]

# 出力サイズ (suffix, 幅, 高さ)。基準デザインは 1320x2868、他サイズは精密スケールで生成。
SIZES = [
    ("", 1320, 2868),          # 6.9" (iPhone 17 Pro Max 等)
    ("-65", 1242, 2688),       # 6.5" (1242x2688 スロット)
]

TEMPLATE = """<!DOCTYPE html>
<html lang="ja">
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


def main():
    for name, img_file, headline, sub, chip, chip_side, chip_top in SLIDES:
        # 元画像が未キャプチャのスライドはスキップ (後で撮って再実行すれば生成される)
        if not os.path.exists(os.path.join(HERE, "..", img_file)):
            print("skip  %s — 元画像なし: ScreenShot/%s (撮影後に再実行)" % (name, img_file))
            continue
        img_rel = "../" + urllib.parse.quote(img_file)
        for suffix, w, h in SIZES:
            if suffix == "":
                slide_scale = ""
            else:
                sx = w / 1320.0
                sy = h / 2868.0
                slide_scale = "transform:scale(%.6f,%.6f); transform-origin:0 0;" % (sx, sy)
            html = TEMPLATE.format(
                name=name + suffix,
                slide_scale=slide_scale,
                headline=render_headline(headline),
                sub=sub,
                img=img_rel,
                chip=chip,
                chip_side=chip_side,
                chip_top=chip_top,
            )
            out = os.path.join(HERE, name + suffix + ".html")
            with open(out, "w", encoding="utf-8") as f:
                f.write(html)
            print("wrote", out)

    links = "\n".join(
        '<li><a href="{n}.html">{n} — {h}</a></li>'.format(
            n=n, h=re.sub(r"[《》|]", "", h))
        for n, _, h, *_ in SLIDES
    )
    index = """<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8">
<title>App Store screenshots v2</title>
<style>body{{font-family:-apple-system,sans-serif;padding:40px;line-height:2}}a{{color:#3A4A63}}</style>
</head><body><h1>App Store スクリーンショット v2 (5 枚)</h1><ol>{links}</ol></body></html>""".format(links=links)
    with open(os.path.join(HERE, "index.html"), "w", encoding="utf-8") as f:
        f.write(index)
    print("wrote index.html")


if __name__ == "__main__":
    main()
