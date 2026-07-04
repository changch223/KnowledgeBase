# App Store スクリーンショット (自動生成) — v2

実機スクショに上帯キャプション(明朝)+ 端末フレーム(和紙背景)を合成した **1320×2868 / 6.9″** の App Store 用スライド。

## v2 ブラッシュアップ (Apple 公式スクショのベストプラクティス反映)
- **端末下端ブリード**: 端末を +18% 大型化し下端でカット → UI が大きく読め、死に余白が消える (Apple マーケの定番構図)
- **藍アクセント**: 見出しの核心語 1 つだけ藍 `#3A4A63` (勝手に / 百科事典 / 根拠付き / 自動 / 知識)
- **コールアウトチップ**: 1 枚に 1 つだけ、画面の見どころを指す和紙チップ (藍ドット付き)
- 見出しベースライン全 5 枚固定 / 薄ベゼル 12px / 柔らかい大影 / 青海波は端末左右の下コーナーに覗く

## できあがり (そのまま App Store Connect にアップロード可)
`output/` に 5 枚構成の PNG（すべて **1320×2868**、6.9″ スロット対応）:

| ファイル | 元画面 | 見出し (《》=藍) | チップ |
|---|---|---|---|
| `output/01-knowledge.png` | ナレッジフィード | 読んだことが、《勝手に》まとまる。 | 要点がひと目で |
| `output/02-wiki.png` | 概念ページ(Wiki) | AIが、あなただけの《百科事典》を編さん。 | 読むほど育つ |
| `output/03-chat.png` | AI チャット(引用) | あなたの知識に、《根拠付き》で答える。 | 出典付き回答 |
| `output/04-save.png` | 記事詳細 (共有訴求) | 読んだその場で、《2タップ》で保存。 | 共有からすぐ |
| `output/05-library.png` | ライブラリ | 分野もタグも、AIが《自動》で整理。 | 自動で分類 |

物語の弧: まとまる → 事典 → 根拠付き回答 → その場で保存 → 自動整理。

## 作り直し / 微調整
1. `build.py` の `SLIDES`(画像・見出し・サブ)や CSS を編集
   - 見出しの `|` = 改行位置
2. 再生成:
```bash
cd ScreenShot/appstore
python3 build.py
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for n in 01-knowledge 02-wiki 03-chat 04-save 05-library; do
  [ -f "$n.html" ] && "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --allow-file-access-from-files \
    --window-size=1320,2868 --screenshot="output/$n.png" "file://$PWD/$n.html"
done
```

## 自分でキャプチャする場合(HTML から)
- `*.html` を Chrome で開く → DevTools(Cmd+Opt+I)→ Cmd+Shift+P → 「Capture node screenshot」で `#slide` を選ぶと 1320×2868 で書き出せる。

## メモ
- 実機の時刻は 18:03/18:04・電池 52%。9:41・満充電に揃えたい場合は撮り直して同じファイル名で `../` に置けば再生成で反映される。
- デザイン仕様の詳細は `../../docs/app-store/SCREENSHOT-DESIGN.md`。
