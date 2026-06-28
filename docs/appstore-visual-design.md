# App Store ビジュアル設計書 — KnowledgeBaseAI

_対象: アイコン / スクリーンショット / App Preview / nano banana 生成 prompt_

---

## 1. アプリアイコン

### デザイン方針
- **世界観**: 「脳 × 知識の結晶 × 静けさ」。散らかった情報が整理されていく瞬間。
- **配色**: 深いネイビー〜ブラックの背景 + 白〜アイスブルーの光。派手にしない。
- **形状**: iOS アイコン角丸正方形。中央に 1 つのシンボル。
- **禁止**: 文字、多色グラデーション、ごちゃごちゃした要素。

### nano banana 生成 prompt（アイコン）

```
iOS app icon, deep navy black background (#0a0a14), centered glowing crystal brain 
made of interconnected light nodes and edges, soft arctic blue and white light 
emanating from within, subtle bokeh glow, clean minimalist design, no text, 
no gradients, ultra sharp edges, Apple Human Interface Guidelines style, 
square composition, 1024x1024
```

**バリエーション案（3つ試す）**

```
[A] iOS app icon, pure black background, single glowing geometric brain shape 
formed by thin white interconnected lines (like a constellation), center emits 
soft blue-white light, no text, minimal, Apple-style icon, 1024x1024

[B] iOS app icon, dark midnight blue background, abstract open book transforming 
into a neural network at the top, nodes and edges glow ice blue, clean flat style, 
no text, centered symbol, Apple iOS aesthetic, 1024x1024

[C] iOS app icon, black background, stylized letter K formed by glowing light 
particles connecting into a knowledge graph, particles in white and arctic blue, 
soft outer glow, premium minimal design, no text, 1024x1024
```

---

## 2. スクリーンショット設計（全5枚）

**サイズ**: iPhone 6.9インチ優先（iPhone 17 Pro Max: 1320×2868 px）  
**スタイル**: 実機画面 + 上部キャプション文（黒背景・白文字）

---

### SC-1「保存するだけ、AIが整理する」

**見せる画面**: iKnow タブ（Knowledge フィード）  
**上部テキスト**:
```
保存するだけ。
AIが勝手に整理する。
```
**画面内容**: 縦フィード。概念カード（要点 2〜3 行・記事数チップ）が並んでいる状態。  
**強調**: ConceptSummaryCard の要点箇条書き（青い•）が見えている。

**nano banana prompt（背景・装飾用）**:
```
Dark app screenshot background for iOS knowledge app, deep black #0a0a0f,
very subtle blue particle dust scattered in upper right corner, no text, 
minimal atmospheric texture, 1290x2796 px portrait
```

---

### SC-2「読んだ記事が、概念として蓄積される」

**見せる画面**: 概念ページ詳細（WikiページDetail）  
**上部テキスト**:
```
複数の記事を
AIが自動で束ねる。
```
**画面内容**: 概念名「生成AI」など + 要点リスト + 「関連記事 N件」セクション。  
**強調**: crossSourceInsights（要点）セクションが画面上部に見える。

---

### SC-3「気になった場所から、すぐ保存」

**見せる画面**: 共有シート or ＋ボタン AddArticleSheet  
**上部テキスト**:
```
Safari でもメモでも音声でも。
あらゆる入力に対応。
```
**画面内容**: AddArticleSheet の URL/メモ/ファイル/写真/音声 のセグメント選択 UI。  
**強調**: 5つのモードが並んでいること。

---

### SC-4「保存した知識に、AIが答える」

**見せる画面**: AI チャットタブ（ChatTabView）  
**上部テキスト**:
```
「最近読んだAI記事は?」
自分の知識の中から答える。
```
**画面内容**: 質問「最近のAI関連の記事を教えて」→ 回答（番号付き引用 [1][2]）+ 出典リスト。  
**強調**: 番号引用 + 出典セクション。

---

### SC-5「完全無料・完全オンデバイス」

**見せる画面**: 設定画面 or 静的スプラッシュ風（実機画面でなくてよい）  
**上部テキスト**:
```
サーバーに送らない。
Apple Intelligenceで、端末の中だけで動く。
```
**画面内容**: 3つの特長をアイコン付きで並べたシンプルなカード:
- 🔒 完全オンデバイス・プライバシー保護
- ¥0 完全無料・APIキー不要
- 🔄 iOSアップデートで自動進化

**nano banana prompt（この画面の背景生成用）**:
```
Clean dark iOS settings screen background, deep navy #0d0d1a, three subtle 
frosted glass card shapes stacked vertically, soft blue glow on card edges, 
minimalist Apple-style UI mockup background, no text, portrait 1290x2796
```

---

## 3. App Preview（動画、任意・推奨）

**長さ**: 15〜30秒  
**構成案**:

| 秒数 | 画面 | ナレーション（テロップ） |
|------|------|------------------------|
| 0〜4s | 記事URLをペーストして保存 | 「気になった記事を保存する」 |
| 4〜9s | iKnowフィードに概念カードが出現 | 「AIが自動で要点を抽出」 |
| 9〜15s | 概念詳細を開く（要点・関連記事） | 「複数の記事が1つの知識に」 |
| 15〜22s | AIチャットで質問→引用付き回答 | 「保存した知識に、AIが答える」 |
| 22〜28s | 「完全無料・オンデバイス」テキスト | 「サーバーに送らない。ずっと無料。」 |

---

## 4. スクリーンショット 説明テキスト（App Store 各画像下部）

App Store Connect の「スクリーンショット説明」欄（任意・旧バージョン用）

```
SC-1: KnowledgeフィードにAIが自動生成した「超まとめ」が並びます。
SC-2: 複数の記事をAIが1つの概念ページに自動でまとめ、要点を抽出します。
SC-3: URL・メモ・PDF・音声・写真など、あらゆる形式の知識を取り込めます。
SC-4: 保存した記事の中からAIが引用付きで回答します。一般知識には頼りません。
SC-5: Apple Intelligenceを使用。サーバー不要・完全無料・プライバシー保護。
```

---

## 5. nano banana まとめ依頼メモ

以下を依頼する:

| # | 用途 | prompt 場所 |
|---|------|------------|
| 1 | アプリアイコン × 3案 | §1 バリエーション A / B / C |
| 2 | SC-1 背景 | §2 SC-1 prompt |
| 3 | SC-5 背景 | §2 SC-5 prompt |

**共通指定**:
- 解像度: 1024×1024（アイコン）/ 1290×2796（スクリーンショット背景）
- スタイル: Apple HIG ライク、暗め、ミニマル
- 文字なし（テキストは後からオーバーレイ）

---

## 6. スクリーンショット制作フロー

```
1. nano banana でアイコン 3案生成 → 1案選定
2. nano banana で背景画像生成（SC-1, SC-5 用）
3. Simulator / 実機で各画面を撮影（sc コマンド or QuickTime）
4. Figma / Sketch / Canva でキャプションテキストをオーバーレイ
5. 書き出し: PNG, 1290×2796 (iPhone 6.9") + 1284×2778 (iPhone 6.7")
6. App Store Connect にアップロード
```
