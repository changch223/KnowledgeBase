<div align="center">

# 🧠 Knowledge Base

### 端末内で完結する、あなた専用の AI 第二の脳 (iOS)

**保存するだけ → AI が自動で整理 → 自分の知識に何でも聞ける**

[English README](README.md) • [主な機能](#-主な機能) • [仕組み](#-仕組み) • [プライバシー](#-プライバシー) • [構成](#-構成) • [ビルド](#-ビルド--実行)

![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![AI](https://img.shields.io/badge/AI-Apple%20Foundation%20Models%20(端末内)-black)
![License](https://img.shields.io/badge/license-All%20rights%20reserved-lightgrey)

</div>

Knowledge Base は、iPhone / iPad 向けの **完全オンデバイス・プライバシーファーストな知識アプリ**です。共有シートからどこの記事でも保存すると、Apple のオンデバイス基盤モデル (Foundation Models) が**要点・事実・固有名詞を自動抽出**し、すべてを生きた**概念の Wiki** に編み込みます。閲覧・検索・対話まで端末内で完結。外に出るのは、あなた自身の iCloud プライベート DB への任意同期だけ。アカウント不要・サーバー不要・トラッキングなし。

> [!NOTE]
> Knowledge Base は Apple Intelligence を**完全に端末内**で動かします。要約・分類・概念合成・チャットはすべてローカル処理で、開発者や第三者にデータを送信しません。

---

## ✨ 主な機能

| | 機能 |
|---|---|
| 📥 **ワンタップ保存** | Safari / Chrome / X など、どのアプリからでも共有シートで保存。Safari 拡張で閲覧ページの自動保存も可能。 |
| 🧩 **知識の自動抽出** | オンデバイス AI が各記事を *要点*・*事実*・*固有名詞* に蒸留 (手動タグ付け不要)。英語記事は端末内で翻訳してから抽出。 |
| 📚 **生きた概念 Wiki** | 関連記事を**概念ページ**に自動合成。2 階層 (広い分野 → 具体概念)・Markdown 本文・相互リンク付き。Karpathy の「LLM Wiki」を端末内で。 |
| 🎯 **答え先出しフィード** | 「ナレッジ」フィードは各概念の最重要ポイント (超・まとめ) を先頭に表示。重要×最新順、各ポイントに出典記事。 |
| 💬 **会話型 AI チャット (RAG)** | 自分の保存知識に質問。**番号引用 `[1] [2]`** + 出典リスト付きで記事に基づき回答。履歴考慮の検索、該当なしは正直に「ナレッジベース外」バッジ。 |
| 🏷️ **自動タグ・分類** | 全記事を自動タグ付け + 10 分野に分類。裏の「整理」ループが重複統合・再分類・剪定を継続 (再開可能・無停止)。 |
| 🔄 **iCloud 同期 (任意)** | あなたの**プライベート** CloudKit DB で端末間同期。既定オフ。 |
| 🛡️ **設計からプライバシー** | 100% オンデバイス AI。データ収集・解析 SDK・広告・トラッキングなし。 |

---

## 🔍 仕組み

```
   記事を共有
       │
       ▼
 ┌──────────────┐  端末内 Foundation  ┌─────────────────────┐
 │  生記事      │ ─────────────────▶ │ 知識抽出             │  要点・事実・固有名詞
 │ (不変)       │      Models         └─────────────────────┘
 └──────────────┘                              │
       │                                        ▼
       │                             ┌─────────────────────┐
       └────────── 紐付け ──────────▶│  概念 Wiki ページ    │  AI 合成サマリ + 要点
                                     │ (2 階層)             │  + 相互リンク + 要点ごと出典
                                     └─────────────────────┘
                                                │
                          ┌─────────────────────┼─────────────────┐
                          ▼                     ▼                ▼
                   ナレッジフィード       AI チャット (RAG)    自動整理
                   (答え先出し)         (引用付き回答)      (裏の整理ループ)
```

上記はすべて端末内で動作。ネットワーク通信は**あなたが保存を選んだ URL の本文取得のみ**です。

---

## 📱 アプリ

タブは 3 つ、意図的にシンプル:

- **ナレッジ** — 概念の超まとめを答え先出しで。重要×最新順、お気に入りは最上部にピン留め。
- **ライブラリ** — 保存記事を日付別に。関連度ランキング検索対応。
- **AI チャット** — 自分の知識に基づく ChatGPT / Gemini 風チャット。番号引用付き。

設定 (アバターから) で iCloud 同期 / Safari・翻訳セットアップ / タグ・分野管理 / ワンタップ整理。

---

## 🛡️ プライバシー

Apple の [Privacy Manifest](KnowledgeTree/PrivacyInfo.xcprivacy) を同梱:

- **データ収集なし。** 保存記事・抽出知識・チャット履歴・概念ページは端末内 SwiftData (+ 任意同期時はあなたの iCloud プライベート DB) のみ。
- **トラッキング・解析・広告なし。**
- **オンデバイス AI。** 要約・分類・合成・チャットは Apple Foundation Models でローカル処理。

詳細は [プライバシーポリシー](docs/privacy-policy.md)。

---

## 🏗️ 構成

SwiftData + CloudKit を基盤とした単一ターゲットの SwiftUI アプリ + 3 拡張。知識は階層化: 不変の**生記事** → 派生の**抽出知識** → 合成の**概念 Wiki ページ**。

```
KnowledgeTree/
├── KnowledgeTreeApp.swift   # エントリ・タブ・起動 DI・BGTask 登録
├── Models/                  # 22 SwiftData @Model (CloudKit 連携)
├── Services/                # 78 サービス (Protocol + DI、テスト可)
│   ├── KnowledgeExtractionService   # 記事 → 要点/事実/固有名詞 (chunk・token 安全)
│   ├── ConceptSynthesisService      # 記事群 → 概念 Wiki (階層合成)
│   ├── ChatService                  # 会話型 RAG: 検索 → 引用 → 回答
│   ├── EmbeddingService             # NLEmbedding + Accelerate cosine
│   ├── LintEngine                   # 再開可能な裏の自動整理ループ
│   └── …
├── Views/                   # 86 SwiftUI View (3 タブ + 詳細/設定)
├── AppIntents/ · Localization/ (日本語ファースト) · Resources/
KnowledgeTreeShareExtension/ # 共有シート保存
KnowledgeTreeSafariExtension/# 任意の自動保存 Web 拡張
iKnowWidget/                 # ホーム画面ウィジェット
```

**Token 安全・性能**: Foundation Models は 4096 token 窓。`@Generable` の出力サイズが overflow の主因のため schema を slim 化 + overflow 時の compact 再試行。全推論は単一ゲートで直列化し ANE 競合を回避。チャット中は裏の合成を一時停止。検索の cosine 計算はメインスレッド外 + 質問 embedding キャッシュ。

---

## 🛠️ 技術スタック

- **Swift 6** · **SwiftUI** · **SwiftData + CloudKit**
- **Apple Foundation Models** (端末内 LLM) · **NaturalLanguage** (`NLEmbedding`) · **Accelerate** (`vDSP`)
- **BGTaskScheduler** (バックグラウンド抽出 / 概念合成 / 週次整理)
- App Group + 共有拡張 + Safari Web 拡張 + ウィジェット
- 仕様駆動開発 [Spec Kit](.specify/) (`specify → plan → tasks → implement`)

---

## 🚀 ビルド & 実行

**要件**: Xcode 26+ / iOS・iPadOS **26.4+** / **Apple Intelligence 対応端末** (Simulator はキーワード/ヒューリスティック経路に degrade)

```bash
git clone https://github.com/changch223/KnowledgeTree.git
cd KnowledgeTree
open KnowledgeTree.xcodeproj   # KnowledgeTree scheme を実機で実行
```

> 表示名は **Knowledge Base**。Xcode プロジェクト/ターゲット名は歴史的経緯で `KnowledgeTree` のまま (rename すると CloudKit レコードスキーマが壊れるため)。

---

## 📄 ライセンス

© changch223. **All rights reserved.**

本ソースは透明性のために公開しています。再配布・再利用は許諾していません。利用についてのご相談は Issue へ。

<div align="center">

個人開発 · Claude (Opus) の助けを借りて ❤️ で制作

</div>
