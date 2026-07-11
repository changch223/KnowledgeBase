# App Store スクリーンショット (自動生成) — v3 (多言語対応)

実機スクショに上帯キャプション(明朝)+ 端末フレーム(和紙背景)を合成した **1320×2868 / 6.9″** の App Store 用スライド。
v3 では **ja / zh-Hans / zh-Hant / en / ko / es / de** の 7 ロケール分を一度に生成する(App Store v1.1 多言語リリース対応、
`docs/app-store/RELEASE-MATERIALS.md` §1-J〔zh/en〕・§1-K〔ko/es/de〕のコピーと用語統一済み)。

## v2 ブラッシュアップ (Apple 公式スクショのベストプラクティス反映)
- **端末下端ブリード**: 端末を +18% 大型化し下端でカット → UI が大きく読め、死に余白が消える (Apple マーケの定番構図)
- **藍アクセント**: 見出しの核心語 1 つだけ藍 `#3A4A63`
- **コールアウトチップ**: 1 枚に 1 つだけ、画面の見どころを指す和紙チップ (藍ドット付き)
- 見出しベースライン全 5 枚固定 / 薄ベゼル 12px / 柔らかい大影 / 青海波は端末左右の下コーナーに覗く

## v3 多言語対応 (このバージョンの変更点)
- `build.py` の `SLIDES` を **`SLIDE_LAYOUT`(画像・チップ位置など言語非依存のレイアウト)** と
  **`CAPTIONS`(ロケール別の見出し・サブ・チップ文言)** に分離。ロケールを増やすときは `CAPTIONS` に
  1 セット追加するだけで良い。
- **元画像はロケールごとに探索**: `ScreenShot/<locale>/<ファイル名>`(例: `ScreenShot/en/knowledge base.PNG`)が
  あればそれを使い、無ければ `ScreenShot/<ファイル名>`(既存の ja 実機スクショ)にフォールバックする。
  → **zh/en の実機スクショがまだ無い環境でも、ja のスクショ + 各言語キャプションでプレビューが生成できる**
  (キャプションのレビューを実機撮影より先に進められる)。
- **出力先を `<locale>/` 配下に明確移行**(旧: `ScreenShot/appstore/*.html` 直下 → 新: `ScreenShot/appstore/ja/*.html` 等)。
  PNG も `output/<locale>/*.png` に生成する。**旧パスとの互換は維持していない**(旧 `output-1242x2688/` フォルダも
  v3 では生成しない。過去に生成物があれば削除して問題ない、いずれも gitignore 対象)。

## できあがり (そのまま App Store Connect にアップロード可)
`output/<locale>/` に 5 枚構成の PNG(すべて **1320×2868**、6.9″ スロット対応。`-65` 付きは 1242×2688 の 6.5″ 版):

| ファイル | 元画面 | ja 見出し(《》=藍) |
|---|---|---|
| `01-knowledge` | ナレッジフィード | 読んだことが、《勝手に》まとまる。 |
| `02-wiki` | 概念ページ(Wiki) | AIが、あなただけの《百科事典》を編さん。 |
| `03-chat` | AI チャット(引用) | あなたの知識に、《根拠付き》で答える。 |
| `04-save` | 記事詳細 (共有訴求) | 読んだその場で、《2タップ》で保存。 |
| `05-library` | ライブラリ | 分野もタグも、AIが《自動》で整理。 |

各ロケールのキャプション文言(見出し・サブ・チップ)は `build.py` の `CAPTIONS` を参照。
用語は各言語の `Localizable.xcstrings` 実訳(简体中文の「知识/资料库/保存」、繁體中文の「知識/資料庫/儲存」、
한국어の「지식/라이브러리/저장」、español の「Conocimiento/Biblioteca/Guardar」、Deutsch の
„Wissen/Bibliothek/Sichern" 等)と統一してある。

物語の弧: まとまる → 事典 → 根拠付き回答 → その場で保存 → 自動整理。

## 生成コマンド

```bash
cd ScreenShot/appstore
python3 build.py
```

これで **7 ロケール × 5 スライド × 2 サイズ = 70 HTML** + ロケール別 `index.html` 7 枚 + トップ `index.html` が
`ScreenShot/appstore/<locale>/` 以下に生成される(実行結果は `wrote ...` のログで確認できる)。
元画像が 1 枚も見つからないスライドは `skip ...` と表示されてスキップされる(HTML 自体は壊れない)。

## PNG 化 (ヘッドレス Chrome)

ロケールを指定して実行する。すべてのロケールをまとめて焼く場合は下のループを 7 回(ロケール名を変えて)回すか、
シェルの二重ループにする。

```bash
cd ScreenShot/appstore
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for locale in ja zh-Hans zh-Hant en ko es de; do
  mkdir -p "output/$locale"
  for n in 01-knowledge 02-wiki 03-chat 04-save 05-library; do
    for suffix in "" "-65"; do
      f="$locale/$n$suffix.html"
      [ -f "$f" ] && "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
        --force-device-scale-factor=1 --allow-file-access-from-files \
        --window-size=1320,2868 --screenshot="output/$locale/$n$suffix.png" "file://$PWD/$f"
    done
  done
done
```

1 ロケールだけ焼き直したい場合は `for locale in en; do ...` のように絞る。

## zh / en / ko / es / de の実機スクショを差し替える手順

1. 実機(または Simulator)で、`SLIDE_LAYOUT` にある 5 画面(ナレッジフィード / Wiki 詳細 / AI チャット / 記事詳細 / ライブラリ)
   を対象言語の UI で撮影する(App の 設定 > 生成言語、および端末の言語設定を対象ロケールに切り替えてから撮る)。
2. `ScreenShot/<locale>/` フォルダ(無ければ作成)に、**ja と同じファイル名**で置く。
   - 例: 英語版なら `ScreenShot/en/knowledge base.PNG` / `ScreenShot/en/wiki page.PNG` / `ScreenShot/en/AI Chat.PNG` /
     `ScreenShot/en/content page.PNG` / `ScreenShot/en/library.PNG`
   - `locale` は `ja` / `zh-Hans` / `zh-Hant` / `en` / `ko` / `es` / `de` のいずれか(`build.py` の `LOCALES` と一致させる)。
3. `python3 build.py` を再実行すると、その言語だけ実機スクショに差し替わり、他の言語は引き続き ja の
   画像 + 各言語キャプションのプレビューのまま残る(全部揃うまで待たなくてよい)。
4. PNG 化して `output/<locale>/` からアップロード。

## 作り直し / 微調整
1. `build.py` の `CAPTIONS[locale]`(見出し・サブ・チップ)や `SLIDE_LAYOUT`(画像ファイル名・チップ位置)、
   CSS を編集
   - 見出しの `|` = 改行位置、`《...》` = 藍アクセント
2. 再生成: `python3 build.py`

## 自分でキャプチャする場合(HTML から)
- `<locale>/*.html` を Chrome で開く → DevTools(Cmd+Opt+I)→ Cmd+Shift+P → 「Capture node screenshot」で
  `#slide` を選ぶと 1320×2868 で書き出せる。

## メモ
- 実機の時刻は 18:03/18:04・電池 52%。9:41・満充電に揃えたい場合は撮り直して同じファイル名で
  `ScreenShot/` (または `ScreenShot/<locale>/`) に置けば再生成で反映される。
- デザイン仕様の詳細は `../../docs/app-store/SCREENSHOT-DESIGN.md`。
- 提出メタデータ(App 名・キーワード・説明文など、多言語含む)は `../../docs/app-store/RELEASE-MATERIALS.md`。
