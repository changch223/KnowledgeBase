# 06 — Branding Migration: 知積 → iKnow

## Status: Skeleton (Phase 3 で詳細化予定)

## このファイルの目的

アプリ名・ロゴ・App Store メタデータの **「知積」→「iKnow」リブランディング** 手順。

---

## 決定事項

| 項目 | 旧 (現知積) | 新 (iKnow) |
|---|---|---|
| アプリ名 | 知積 (KnowledgeTree) | **iKnow** |
| 表示名 (iOS Home) | 知積 | **iKnow** |
| Bundle ID | `app.KnowledgeTree` (現状) | **同じ** (継承) |
| App Store ID | (現状) | **同じ** (継承) |
| バージョン | v1.x | **v2.0** (メジャー跳ね上げ) |
| 内部 framework / 開発者名 | KnowledgeTree | (任意で残す) |

---

## キャッチコピー / メッセージング

### 旧 (知積)
- 一文: 「読んだ知識を AI が自動で体系化・更新し、必要な時だけ開けば最新の自分が見える、優しい第二の脳」
- focus: 知識の体系化 + 第二の脳

### 新 (iKnow)
- 一文: 「日常で触れた情報を AI が体系化し、秘書のように要点を、家庭教師のように深堀りを、完全 on-device で提供する『Apple Intelligence をあなた専用に進化させた』アプリ」
- short: 「**あなた専用に進化する Apple Intelligence**」
- focus: Apple Intelligence の差別化 + 思考 / 理解 両方

---

## App Store メタデータ更新

### 必須更新項目

| 項目 | 旧 | 新 (iKnow) |
|---|---|---|
| App Name | 知積 | iKnow |
| Subtitle | (現状) | "Your Personal Knowledge AI" or 「あなた専用 AI が育つ」 |
| Promotional Text | (現状) | iKnow v2.0、Apple Intelligence をあなた専用に進化 |
| Description | 知積向け | iKnow 向け全面刷新 |
| Keywords | 知識 / 体系化 / RAG / etc. | knowledge / AI / Apple Intelligence / iPhone / 概念 / etc. |
| Support URL | (現状) | 更新 (iKnow 専用 LP) |
| Marketing URL | (現状) | 更新 (iKnow 専用 LP) |
| Privacy Policy | (現状) | 必要なら更新 |
| Screenshots | 知積 view | iKnow 新タブ + Understanding Card 等 |
| App Preview Video | (なし or 旧) | iKnow 紹介動画 (任意) |
| What's New | "v1.x: ..." | "v2.0: 知積から iKnow に進化、学習タブ + 概念ページ + Widget 等を新規搭載" |

---

## アイコン (App Icon) 制作

| サイズ | 用途 |
|---|---|
| 1024x1024 | App Store |
| 180x180 / 120x120 | iPhone (3x / 2x) |
| 167x167 | iPad Pro |
| 152x152 | iPad |
| 76x76 | iPad (1x、現代では稀) |
| 60x60 (3x / 2x / 1x) | Settings / Notification 等 |
| 各種 Watch / TV (将来用) | (V1 では省略) |

### デザインガイド

- iKnow の "i" を象徴的に
- 知識 / 蓄積 / AI / 学習 のいずれかをモチーフに
- Apple HIG 準拠 (角丸 / 余白 / コントラスト)
- 視認性高い (Lock screen / Widget で小さく表示されるため)

### 候補テーマ

| テーマ | 中身 |
|---|---|
| A. 脳 + i | 脳 アイコン + "i" 文字 |
| B. 本 + 光 | 本が光る (知識の蓄積) |
| C. 抽象 + i | 抽象的なシンボル + "i" |
| D. ロゴタイプ | "iKnow" 文字主体、フォントデザイン |

→ デザイナーと議論、または AI 生成 (Midjourney / Adobe Firefly) で初稿

---

## 内部コード (任意) リネーム

| 項目 | 推奨 |
|---|---|
| Xcode project 名 | KnowledgeTree → iKnow (任意、git 影響あり) |
| Module 名 | KnowledgeTree → iKnow (任意) |
| Class / file 名 | (個別判断、必要なものだけ) |
| folder 構造 | (現状維持で OK) |
| Subsystem (os_log) | `app.KnowledgeTree` → `app.iKnow` (任意) |

→ **内部リネームは V2.1 以降の Cleanup spec で実施**、V1 では project 名は KnowledgeTree のまま、表示名のみ iKnow

---

## ローンチ戦略

| タイミング | やること |
|---|---|
| 内部 TestFlight (M4 = 12 週目) | 開発者 + 信頼できる人 + 既存ユーザー一部に「iKnow ベータ」案内 |
| 公開 TestFlight (M8 = 20 週目) | 公開ベータ、SNS / blog で 「iKnow 公開ベータ参加」募集 |
| App Store 公開 | iKnow v2.0 リリース、blog + SNS 告知 |
| ローンチ blog | 「知積から iKnow への進化」(技術背景 + vision + 機能) |
| Twitter / X 投稿 | キャッチコピー + screenshot + LP リンク |
| Hacker News / Reddit | 適切なサブで紹介 (技術コミュニティ向け) |

---

## リブランディング後の Onboarding (既存ユーザー向け)

初回起動時の overlay:

```
🎉 知積から iKnow に進化しました

新しい体験:
✨ 学習タブ — 「今のあなたへ」AI がカードで surface
🤖 Apple Intelligence をあなた専用に進化
🧠 概念ページが時間とともに育つ
📌 質問の答えを保存できる
🖼️ 写真 / スクリーンショットも保存可能

既存データは全部そのまま使えます。
                            [はじめる]
```

→ 1 回表示、dismiss 可、再表示しない。

---

## 次のステップ

Phase 3 で詳細化:
- アイコンデザインの具体ラフ
- App Store description 草稿
- ローンチ blog 構成案
- SNS 文言テンプレ
- 既存ユーザー向けメール / push 通知文言 (任意)
