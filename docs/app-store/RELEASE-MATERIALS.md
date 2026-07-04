# Knowledge Base — App Store リリース素材一式

作成日: 2026-07-04 / 対象バージョン: **v1.0** / 主要プラットフォーム: iPhone (iOS 26+, Apple Intelligence)

このドキュメントは以下 4 部構成:
1. App Store Connect メタデータ（日本語 primary / 英語 secondary）
2. アプリ内文言の修正・整合（在庫監査）
3. スクリーンショット撮影指示（画面・順序・キャプション・仕様）
4. クリエイティブ指示 prompt（キービジュアル・スクショ枠・アイコンの生成 prompt）

> **一文ビジョン（全コピーの North Star）**
> 「読んだ記事を AI が裏で 1 つの百科事典に編さんし続け、美しいフィードを開くだけで“自分だけの知識”が育っていくのが見える、優しい第二の脳」

---

## 1. App Store Connect メタデータ

### 1-A. 基本情報

| 項目 | 値 | 備考 |
|---|---|---|
| プライマリ言語 | 日本語 (ja) | 英語 (en-US) は任意で追加 |
| Primary Category | **仕事効率化 (Productivity)** | |
| Secondary Category | **辞書/参考書 (Reference)** | 教育 (Education) でも可 |
| 価格 | 無料（App 内課金の予定があれば別途） | |
| 年齢制限 | **4+** | UGC なし・トラッキングなし・外部通信なし |
| Support URL | `https://github.com/changch223/KnowledgeBase`（Issues 受付） | `docs/support.md` を GitHub Pages 公開推奨 |
| Privacy Policy URL | `docs/privacy-policy.md` を公開した URL | 提出前に GitHub Pages 等で hosting |
| Marketing URL | 任意（LP があれば） | |
| 暗号輸出 | `ITSAppUsesNonExemptEncryption = false`（Info.plist 設定済） | 標準 HTTPS のみ = exempt |

### 1-B. App 名（最大 30 文字）

- **推奨（純ブランド）**: `Knowledge Base`（14）
- **ASO 強化版（任意）**: `Knowledge Base ‑ AIノート`（22）
  - 「Knowledge Base」は汎用語で検索埋没しやすい。サブタイトル + キーワードで補うのが前提。差別化を名前に入れたい場合は ASO 版を検討。

### 1-C. サブタイトル（最大 30 文字）

- **推奨 A**: `AIが読んだ記事を整理する第二の脳`（17）
- 代替 B: `読んだ記事を、AIが勝手にまとめる`（17）
- 代替 C: `保存するだけ。AIが知識を編さん`（15）

### 1-D. プロモーションテキスト（最大 170 文字・審査なしで随時更新可）

```
読んで終わり、を卒業。共有シートで保存するだけで、AIがあなたの記事をテーマごとの「概念ページ」にまとめ続けます。要点は一目、深掘りはチャットで根拠付きに。すべて端末内で完結し、データは外に出ません。
```
（97 文字）

### 1-E. キーワード（最大 100 文字・カンマ区切り・スペース禁止）

```
ノート,メモ,AI,第二の脳,知識管理,ブックマーク,あとで読む,要約,ウィキ,PKM,学習,整理,オフライン,記事保存
```
（英語ロケール用: `note,AI,second brain,knowledge,bookmark,read later,summary,wiki,PKM,offline,save article`）

> ASO メモ: 「Knowledge Base」を名前に含めるので keyword には入れない（重複無駄）。競合語「Notion」「Readwise」等の商標は入れない。

### 1-F. 説明文（最大 4000 文字・日本語）

```
■ 読んだ知識が、勝手に育つ。

気になった記事を保存するだけ。あとは AI が裏側で、あなただけの百科事典を編さんし続けます。
Knowledge Base は「読んで終わり」を卒業するための、優しい第二の脳です。

■ どこからでも、ひと手間で保存

・Safari やアプリの共有シートから、記事をそのまま保存
・＋ボタンで URL・テキスト・PDF・写真（文字認識）・音声（文字起こし）も取り込み
・英語や中国語のコンテンツは、自動で日本語に翻訳して整理

保存はすぐ完了。重い処理はすべて裏側で進むので、あなたを待たせません。

■ AI が、テーマごとに要点をまとめる

複数の記事をまたいで、AI が「概念ページ（あなた専用の Wiki）」を自動で生成・更新します。
「ナレッジ」タブを開けば、テーマごとの要点まとめが常に最新の状態で並んでいます。
・最重要ポイントが、クリック不要で先に読める
・関連する概念どうしが自動でリンクし、知識がつながっていく
・どのページも、必ず元の記事にさかのぼって確認できる

■ あなたの知識に、根拠付きで答えるチャット

「あの記事、何て書いてあったっけ？」に、AI チャットが答えます。
・回答はあなたが保存した記事だけを根拠に生成
・引用番号をタップすれば、元記事にすぐ移動
・一般知識で補うときは、はっきり明示

■ AI の間違いは、ひとことで直せる

・記事詳細の「訂正」から自然言語で指示するだけ（例:「Claude Code を誤認識しています」）
・要らない概念やタグは、いつでも編集・統合・非表示に
最終的な主導権は、いつもあなたの手に。

■ プライバシーは、設計の中心

・AI 処理は Apple Intelligence によりすべて端末内で完結
・広告なし・トラッキングなし・外部サーバーへの送信ゼロ
・iCloud 同期はあなたのプライベートデータベースのみ

■ 日本語ファースト、和の佇まい

明朝体の見出しと墨色、青海波の余白。開くたびに静かで心地よい、日本語のために作られた画面です。

さあ、読んだものを「自分だけの知識」に変えていきましょう。
```

### 1-G. 「このバージョンの新機能」（What's New / v1.0）

```
Knowledge Base v1.0 をリリースしました。
・共有シート/＋ボタンから、URL・テキスト・PDF・写真・音声を保存
・AI が記事をまたいで概念ページ（Wiki）を自動編さん
・保存した知識に根拠付きで答える AI チャット
・すべて端末内で完結、プライバシーファースト
ご意見・不具合は GitHub Issues までお寄せください。
```

### 1-H. 英語版（en-US、任意で追加する場合）

- **Subtitle**: `Your AI-organized second brain`
- **Promotional Text**:
  `Stop reading and forgetting. Just save an article and AI keeps weaving it into an evolving encyclopedia of your own — key points up front, answers with citations, all on-device.`
- **Description（要約版）**:
  ```
  Save anything you read — AI quietly compiles it into your personal encyclopedia.

  • Save from the share sheet, or add URLs, text, PDFs, photos (OCR) and audio (transcription). Non-Japanese content is auto-translated.
  • AI generates and updates "concept pages" (your own wiki) across articles. Key points are shown first; related concepts link automatically.
  • Ask your knowledge base anything — answers are grounded only in your saved articles, with tappable citations.
  • Correct AI mistakes in plain language; merge, edit or hide anything.
  • Privacy by design: all AI runs on-device via Apple Intelligence. No ads, no tracking, no external servers. iCloud sync uses your private database only.
  ```

---

## 2. アプリ内文言の修正・整合（監査結果）

リリース前に UI 文言と App Store コピーの用語を揃えるための監査。

### 2-A. 対応済み（本ブランチ）
- ✅ オンボーディング旧ブランド名「iKnow タブ」→「ナレッジタブ」に修正（唯一のリブランド漏れ）
- ✅ 本文常時表示化に伴う不要文言「タップして本文を展開」削除

### 2-B. 確認済み・良好
- アプリ内 UI 文言は全て `Localizable.xcstrings` キー経由でローカライズ済み。ハードコードされた英語表示文字列の漏れなし。
- タブ名: `ナレッジ` / `ライブラリ` / `AI チャット`。App Store コピーでも「ナレッジ」タブと表記を統一（本ドキュメント準拠）。

### 2-C. 任意の磨き込み候補（リリースブロッカーではない）
- **用語の統一**: 画面によって「概念ページ」「Wiki」「まとめ」「超まとめ」が混在。App Store では「概念ページ（Wiki）」に寄せた。アプリ内も主表記を1つに寄せると初見ユーザーに親切（例: 主=「まとめ」、補足=「概念ページ」）。
- **空状態コピー**: 初回起動直後（記事ゼロ）の各タブ空状態が、スクショ撮影・初見体験に直結。「保存するとここに知識が育ちます」等、行動を促す一文に統一すると良い。
- **オンボーディング**: 4 ページの本文は現行のままで App Store 説明文とトーンが揃っている。変更不要。

---

## 3. スクリーンショット撮影指示

### 3-A. 必要サイズ・仕様
| 項目 | 指定 |
|---|---|
| デバイス | **iPhone 6.9″（iPhone 17 Pro Max / 16 Pro Max）**: 1320 × 2868 px（縦） |
| 補助（任意） | 6.5″ 1284 × 2778 も用意すると古い機種の見栄えが安定 |
| 枚数 | 最小 3・最大 10。**下記 8 枚**を推奨、上位 3 枚で価値が伝わる順に |
| 形式 | PNG または JPEG、sRGB、アルファなし |
| 向き | 縦（Portrait）固定 |
| 文字 | 端末画像の上に**日本語キャプション帯**を重ねる（実機 UI だけでは訴求不足） |

### 3-B. 撮影前の準備（重要）
- **デモデータを仕込む**: 実際の英語/日本語記事を 15〜20 本保存し、AI 整理を完走させてから撮る（概念ページ・カテゴリ・チャット引用が“中身のある”状態に）。空の画面は撮らない。
- **Light モード**で撮影（和紙背景が最も映える）。1 枚だけ Dark を混ぜても良い。
- ステータスバー: 時刻 9:41、フル電波・フル充電に整える（クリーンな見栄え）。
- 個人情報・実在の固有名詞が不都合な場合はダミー記事に差し替え。

### 3-C. 8 枚の構成（順序 = 訴求の強い順）

| # | 画面 | 撮り方 | キャプション（帯・日本語） | サブ（任意・小さめ） |
|---|---|---|---|---|
| 1 | **ナレッジ フィード**（概念カード + 要点先出し） | 概念カードが 3〜4 枚見える位置。要点の箇条書きが読める状態 | **読んだことが、勝手にまとまる。** | AIがテーマごとに要点を先出し |
| 2 | **概念ページ（Wiki）詳細** | 大見出し + 要点 + 子トピック + 記事数が見える | **AIが、あなただけの百科事典を編さん。** | 関連ページへ自動リンク |
| 3 | **AI チャット（引用付き回答）** | 回答本文に番号引用 `[1]` + 下部に出典リスト | **あなたの知識に、根拠付きで答える。** | 引用をタップで元記事へ |
| 4 | **取り込み（共有シート / ＋メニュー）** | 共有シートに Knowledge Base、または＋の 5 モード | **URL・写真・PDF・音声。どこからでも。** | 保存はすぐ完了、整理は裏側で |
| 5 | **自動翻訳**（英語記事 → 日本語の概念ページ） | 英語ソース名 + 日本語の要点が並ぶ | **英語も中国語も、日本語で整理。** | 読める言語に、自動で |
| 6 | **カテゴリ/タグ自動整理**（ライブラリ or 分野カード） | 分野・タグが並ぶ一覧 | **分野もタグも、AIが自動で。** | 間違いはひとことで訂正 |
| 7 | **プライバシー（設定 or 説明画面）** | 「すべて端末内」を示す設定 or オンボーディング | **すべて端末内。データは外に出ない。** | 広告なし・トラッキングなし |
| 8 | **訂正/主導権**（記事詳細の「訂正」） | 訂正シート or 訂正バナー | **AIの間違いは、ひとことで直せる。** | 最終的な主導権はあなたに |

> 最低 3 枚に絞る場合は **#1・#3・#2** の順。App Store は最初の 1〜3 枚しか多くのユーザーが見ないため、#1 に最も強い価値（自動でまとまる）を置く。

### 3-D. キャプション帯のデザイン規則（全 8 枚共通）
- 位置: 端末画像の**上部 22%**に帯。帯の下に端末スクショ。
- 背景: 和紙色 `#F4EFE6` 系（`washiBackground`）。
- 見出し: **明朝体（serif）太字**、墨色 `#1C1B19`（`sumiInk`）、28〜34pt 相当。
- サブ: ゴシック細字、`sumiMid`、14〜16pt 相当。
- 装飾: 帯下端に 0.5px の墨罫線 or 青海波（`seigaiha`）の薄い連続文様を 1 本。過剰にしない。

---

## 4. クリエイティブ指示 prompt

生成AI（Midjourney / DALL·E / Firefly / Nano-Banana / Figma AI 等）に渡す prompt 集。**アートディレクションの一貫キーワード**を各 prompt に必ず含める。

### 4-0. アートディレクション（共通・全 prompt に前置き）
```
Art direction: refined Japanese "washi + sumi-e" aesthetic, ukiyo-e restraint.
Palette: warm off-white washi paper (#F4EFE6), sumi ink black (#1C1B19),
soft indigo accent (#3A4A63), muted stone grey. No neon, no gradients-heavy.
Typography feel: elegant Mincho (serif) headings. Motifs: seigaiha (青海波) waves,
thin hairline rules, generous negative space (ma / 間). Calm, premium, quiet,
literary. NOT flashy, NOT corporate-tech-blue, NOT cluttered.
```

### 4-1. App Store キービジュアル / フィーチャーグラフィック
```
[Art direction above]
A serene hero key visual for a personal-knowledge iPhone app called "Knowledge Base".
Concept: scattered paper articles gently flowing and being woven into a single,
glowing open book / encyclopedia — a "second brain". Ink-wash strokes suggest
connections between floating cards. Seigaiha wave pattern subtly in the lower third.
Vast washi negative space at top for a Mincho headline. Muted, meditative, premium.
16:9 and 1:1 crops. No text in the image. --style raw --ar 16:9
```

### 4-2. スクリーンショットの背景 / 枠テンプレート（8 枚共通の下地）
```
[Art direction above]
A minimal App Store screenshot BACKGROUND template (portrait 1320x2868).
Top 22%: solid warm washi band for a Japanese Mincho headline (leave empty).
Below: soft washi paper texture with a single thin sumi hairline separating the
caption band from the device area. A faint seigaiha wave motif along the very
bottom edge, low opacity. Nothing else — this is a clean stage for a device mockup.
No device, no UI, no text. --ar 1320:2868
```
> 実運用: この下地に、実機スクショ（3-C の各画面）を端末フレーム込みで合成し、上帯に 3-C のキャプションを Mincho で載せる。Figma/Sketch のテンプレ 1 枚を作り 8 枚展開が最速。

### 4-3. キャプション・タイポグラフィ指定（デザイナー/Figma AI 向け）
```
Design an 8-slide App Store screenshot caption system, Japanese-first.
Heading: bold Mincho serif, sumi ink (#1C1B19), 2 lines max, punchy.
Subhead: light sans, sumiMid grey, 1 line.
Background band: washi (#F4EFE6). One 0.5px sumi rule under the band.
Keep 60% of each slide for the device screenshot. Consistent baseline grid
across all 8. Provide the 8 headline/subhead pairs from RELEASE-MATERIALS §3-C.
Aesthetic: calm, literary, premium — like a quiet Japanese stationery brand.
```

### 4-4. アプリアイコン ブラッシュアップ（任意）
```
[Art direction above]
An iOS app icon for "Knowledge Base". A single elegant sumi-ink brushstroke forming
an open book or the kanji "知" (knowledge) abstractly, on warm washi paper.
Centered, balanced, works at small sizes. One indigo accent stroke max.
Timeless, premium, unmistakably Japanese-craft. Flat, no bevels, no gradients.
1024x1024, safe margins. --style raw
```

### 4-5. プロモーション動画（App Preview, 15–30秒・任意）絵コンテ prompt
```
Storyboard a 20s vertical App Preview for "Knowledge Base" (washi/sumi aesthetic):
0-3s  Share sheet → tap "Knowledge Base" (saving from Safari). Caption: 保存するだけ。
3-8s  Feed assembles: article cards flow into concept cards. Caption: AIが自動でまとめる。
8-13s Open a concept page: key points appear first, related links glow. Caption: 要点が、先に読める。
13-18s AI chat answers with a tappable [1] citation → jumps to source. Caption: 根拠付きで答える。
18-20s Logo on washi + seigaiha. Caption: あなただけの、第二の脳。
Transitions: soft ink-bleed dissolves. Music: quiet koto / ambient. No hard cuts.
```

### 4-6. 禁止事項（全生成物・negative prompt）
```
Avoid: neon colors, heavy 3D glass, generic blue SaaS gradients, stock-photo people,
cluttered UI dumps, emoji, drop shadows everywhere, AI-brain-with-circuits cliché,
English-only text, busy backgrounds competing with the device.
```

---

## 5. 提出前チェックリスト（抜粋）
- [ ] Privacy Policy / Support URL を実際に公開して疎通確認
- [ ] `PrivacyInfo.xcprivacy`（同梱済）と App Privacy 質問票の内容を一致させる（データ収集=なし / トラッキング=なし）
- [ ] スクショはデモデータ完走後・9:41・Light で撮影
- [ ] App 名/サブタイトル/キーワードの文字数が上限内
- [ ] 年齢制限 4+、暗号輸出 `ITSAppUsesNonExemptEncryption=false` を確認
- [ ] Apple Intelligence 非対応端末での挙動（fallback）を審査ノートに一言添える
