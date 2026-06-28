# Knowledge Base — App Icon Prompt

アプリアイコンのコンセプトと、AI 画像生成ツール向けのプロンプト案です。

---

## コンセプト

**「読んだものが、育つ知識になる」**

- 記事・情報がバラバラから→体系化・蓄積されるイメージ
- 静かで知的（不安を煽らない、calm UX）
- Apple Intelligence / on-device AI（プライベート・安全・賢い）
- 日本語ファースト、シンプルさ

Apple のデザイン言語に合わせて: **クリーン・幾何学的・グラデーション・角丸正方形**

---

## 推奨カラー

| 役割 | カラー |
|---|---|
| メイン | Deep Indigo `#1C1C6E`〜 Midnight Blue `#003399` |
| アクセント | Electric Blue / AI Blue `#007AFF`（Apple Blue） |
| グロー / ハイライト | Soft White / Warm Gold（知識・啓発） |
| 背景 | 深い紺〜黒グラデーション |

---

## プロンプト案

### 案 A — 「輝く脳 × ページ」（推奨・最もシンボリック）

```
iOS app icon for an app called "Knowledge Base", a personal second brain app.
Design: A glowing human brain silhouette with soft blue light, 
inside the brain are miniature floating pages, documents, and interconnected nodes 
forming a network. The brain emits a warm golden sparkle at its center.
Style: Flat vector, clean, minimal. Deep indigo to midnight blue gradient background.
Rounded square icon shape. Apple App Store aesthetic. Professional and calm.
No text, no letters.
```

### 案 B — 「本が開いて知識が飛び出す」

```
iOS app icon for a knowledge management app. 
Design: An open book with glowing pages, from which abstract knowledge nodes and 
connecting lines emerge upward like a growing network. 
The book has a warm white/cream glow. Background is deep navy to dark indigo gradient.
Small sparkle particles floating around the network.
Style: Flat vector, clean, modern. Apple App Store aesthetic. Rounded square shape.
No text.
```

### 案 C — 「キューブ × ネットワーク」（モダン・テック感）

```
iOS app icon. Design: A 3D isometric cube made of glass/crystal material,
inside the cube is a glowing network of connected dots (knowledge graph).
The cube emits a soft blue light from within. 
Corner of cube shows a small lightning bolt or sparkle indicating AI.
Background: Deep dark blue to black gradient.
Style: Minimalist, premium, Apple design language. Clean vector. Rounded square icon.
No text, no letters.
```

### 案 D — 「シンプル K × 葉脈」（最もシンプル・汎用）

```
iOS app icon for "Knowledge Base" app.
Design: Elegant letter "K" formed by organic branching lines that resemble 
both a tree vein structure and a neural network. 
Lines glow softly in electric blue against a deep midnight blue background.
The overall shape fits within a rounded square.
Style: Minimal, refined, Apple aesthetic. Vector illustration. No additional text.
Premium and calm feeling.
```

---

## 使用ツール別の調整

### Midjourney
いずれかのプロンプトの末尾に追加:
```
--ar 1:1 --style raw --v 6 --no text, letters, words
```

### DALL-E 3 (ChatGPT)
プロンプトをそのまま貼り付け。「テキストなし」を強調して:
```
Important: absolutely no text, letters, or numbers in the image.
```

### Stable Diffusion / Adobe Firefly
ネガティブプロンプト:
```
Negative: text, letters, words, numbers, blurry, noisy, low quality, ugly
```

---

## サイズ仕様 (App Store 提出用)

| 用途 | サイズ |
|---|---|
| App Store 掲載 | 1024 × 1024 px PNG (アルファチャンネルなし) |
| iOS ホーム画面 iPhone | 60 × 60 pt (@3x = 180px) |
| iOS ホーム画面 iPad | 76 × 76 pt (@2x = 152px) |
| Spotlight | 40 × 40 pt |

Xcode の `Assets.xcassets/AppIcon.appiconset/` に各サイズを配置。
1024px 1 枚だけ用意すれば Xcode が自動リサイズする設定も可能 (Single Size オプション)。

---

## 参考: 競合アプリのアイコン傾向

- **Notion**: シンプルな白黒、タイポグラフィ
- **Readwise**: 本 + スター
- **Obsidian**: 宝石 (アメジスト) + グラフ
- **Reflect**: 鏡のような曲線

Knowledge Base の差別化ポイント: **AI × on-device × 育つ知識** を表現する、
温かみ + 知性 + プライバシーの3点を伝えるアイコン。

---

*最終決定後、Xcode の `KnowledgeTree/Assets.xcassets/AppIcon.appiconset/` に配置してください。*
