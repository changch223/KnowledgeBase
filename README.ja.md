<div align="center">

# 🧠 Knowledge Base

### 端末内で完結する、あなた専用の AI 第二の脳 (iOS)

**保存するだけ → AI が自動で整理 → 自分の知識に何でも聞ける**

[English README](README.md) • [設計概念と思想](#-設計概念と思想) • [主な機能](#-主な機能) • [仕組み](#-仕組み) • [構成](#-構成) • [ビルド](#-ビルド--実行)

![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![AI](https://img.shields.io/badge/AI-Apple%20Foundation%20Models%20(端末内)-black)
![License](https://img.shields.io/badge/license-All%20rights%20reserved-lightgrey)

</div>

## なぜ作ったか

「あとで読む」で溜め込んで、見ない。見てもその場で理解したつもりになって、見返さない。忘れたらおしまい——知識として蓄積されない、複利効果がない。もったいない。もっと活用できるはず。
そう感じていた個人的な課題から、このアプリを作りました。

**必要なときに「最新の自分の理解」として取り出せる**——それが Knowledge Base の存在理由です。

Apple Intelligence で動くので**無料**。端末内で動くので**プライバシーが守られる**。Apple がアップデートするたびに**自動的に賢くなる**。使えば使うほど**あなただけの AI として進化する**。

---

Knowledge Base は、iPhone / iPad 向けの **完全オンデバイス・プライバシーファーストな知識アプリ**です。記事はもちろん、PDF・写真・音声メモ・共有テキストを保存すると、Apple のオンデバイス基盤モデル (Foundation Models) が**要点・事実・固有名詞を自動抽出**し、すべてを生きた**概念の Wiki** に編み込みます。閲覧・検索・対話まで端末内で完結。外に出るのは、あなた自身の iCloud プライベート DB への任意同期だけ。アカウント不要・サーバー不要・トラッキングなし。

> [!NOTE]
> Knowledge Base は Apple Intelligence を**完全に端末内**で動かします。要約・分類・翻訳・概念合成・チャットはすべてローカル処理で、開発者や第三者にデータを送信しません。

> **一文ビジョン:** *読んだ記事を AI が裏で 1 つの百科事典に編さんし続け、開くだけで「自分だけの知識」が育っていくのが見える、優しい第二の脳。*

---

## 💡 設計概念と思想

詳細は **[`docs/design-concept.md`](docs/design-concept.md)** に。要点だけ:

### Andrej Karpathy の「LLM Wiki」にインスパイア

> *「思考は外注できても、理解は外注できない (You can outsource your thinking, but you cannot outsource your understanding)」*

AI に要約させること（思考の外注）はできても、「自分が分かっている」状態は自分の中にしか作れない。だから Knowledge Base は、AI の出力を一方的に見せるのではなく、**自分の読んだものが時間とともに 1 つの体系に育ち**、間違いがあれば自分で直せるようにします。Karpathy の LLM Wiki は、アプリの 3 層にそのまま対応します。

| Karpathy の層 | Knowledge Base での実体 | 性質 |
|---|---|---|
| **Raw sources（元資料）** | `Article`（保存記事 + 本文 + 写真 + 音声/PDF/OCR） | **不変。** ユーザーが保存し、AI は読むだけで書き換えない。すべての正確性の基準点。 |
| **The wiki（百科事典）** | `ConceptPage`（人物・モノ・概念ごとの Markdown ページ） | AI が生成・更新：要約・横断的な要点・全体像・ページ間の相互リンク。**AI が全部書き、ユーザーは書かない。** |
| **The schema（運用ルール）** | [`docs/iknow-schema.md`](docs/iknow-schema.md)（バンドル） | AI に「どう整理するか」を教える指示書。取り込み・点検のルールを 1 か所に。 |

**3 操作のうち 2 つだけ。** Karpathy の Wiki は *Ingest / Lint / Query* で回りますが、あえて 2 つに絞りました。

- **Ingest（取り込み）** — 記事を保存すると AI が読み、概念ページを作り・更新し、相互リンクを張る。1 保存が複数ページに波及して知識が **compound（複利的に蓄積）** する。
- **Lint（点検）** — 裏の再開可能ループが定期的に知識ベースの健全性を点検（古い記述・矛盾・孤立ページ・分類のゆらぎ）。起動毎 + 週 1、中断しても続きから。
- **~~Query → ページ化~~** — 「Wiki に質問して答えをページ化」は**作らない**。新しい操作を覚えさせないため。質問は既存の **AI チャット（RAG）** で足りる。

### なぜ「Wiki に畳む」のか

開発途中、「人物・モノ・概念」を表す @Model が **7 種類に分裂**し、1 記事の保存で AI を **12〜15 回**呼ぶ「重くて情報過多」な状態に陥りました。LLM Wiki の発想は、これに **引き算ではなく「統合による引き算」** で答えます。7 つの分裂概念を **1 つの `ConceptPage`** に畳むことで、**重さ（生成系統を 1 本に）と情報過多（概念を 1 種類に）を同時に解消**しました。

### 設計原則

1. **Wiki 中心** — 人物・モノ・概念は 1 種類。分裂モデルを増やさない。
2. **AI 管理が基本、人は確認して直せる** — 整理は全部 AI が裏でやる。ただし AI は間違える（音声/OCR の固有名詞、カテゴリ分類）ので、人が**訂正・削除・非表示**にでき、**最終的な主導権は人間**。
3. **軽さ優先** — *見られないものを生成しない*。記事保存あたり AI 呼び出し 2〜3 回目標、起動 ~1 秒、暴走を防ぐ出力ハード上限。
4. **ソースに基づいた生成** — 全ての要約・要点・回答は不変の `Article` に辿れる。根拠なし出力を出さない（データモデル層で参照を強制）。
5. **静かな UX** — 未読バッジや通知で不安を煽らない。情報過多を減らす道具。
6. **プライバシー / ローカルファースト** — 全データ端末内 + あなたの iCloud、全 AI 端末内。
7. **日本語ファースト** — UI・AI 出力（Wiki 本文含む）はすべて日本語。外国語は日本語に翻訳してから知識化。

---

## ✨ 主な機能

| | 機能 |
|---|---|
| 📥 **あらゆる入力を保存** | 共有シートでどのアプリからでも — **Web ページ・選択テキスト・ファイル(PDF/txt/md)・写真(OCR)・音声(自動文字起こし)**、Gmail 等の PDF 添付も。合成 URL で全入力を同じフローに乗せる。Safari 拡張で閲覧ページの自動保存も可能。 |
| 🧩 **知識の自動抽出** | オンデバイス AI が各記事を *要点*・*事実*・*固有名詞* に蒸留（手動タグ付け不要）。日本語以外（英語・中国語…）は**端末内で翻訳**してから抽出。 |
| 📚 **生きた概念 Wiki** | 関連記事を**概念ページ**に自動合成。2 階層（広い分野 → 具体概念）・Markdown 本文・相互リンク付き。Karpathy の「LLM Wiki」を端末内で。 |
| 🎯 **答え先出しフィード** | 「ナレッジ」フィードは各概念の最重要ポイント（超・まとめ）を先頭に表示。重要×最新順、各ポイントに出典記事。 |
| 💬 **会話型 AI チャット (RAG)** | 自分の保存知識に質問。**番号引用 `[1] [2]`** + 出典リスト付きで記事に基づき回答。履歴考慮のクエリ書き換え、該当なしは正直に「ナレッジベース外」バッジ。 |
| 🏷️ **賢くなる分類** | 全記事を自動タグ付け + 10 分野に分類、**確信度付き**。Low は保守的に「その他」へ、裏の整理ループが不確実なものから再分類。**分野を直すと AI が学習（few-shot）**し、同じ間違いを繰り返さない。 |
| ✍️ **AI を見直す・カスタマイズ** | 本文の表現を知識ベース基準で見直し（誤認識の固有名詞を修正）、自然言語で訂正指示、または**生成内容をカスタマイズ**（「技術的詳細を重視」「要約を短く」等）。 |
| 🔄 **iCloud 同期 (任意)** | あなたの**プライベート** CloudKit DB で端末間同期。既定オフ。 |
| 🛡️ **設計からプライバシー** | 100% オンデバイス AI。データ収集・解析 SDK・広告・トラッキングなし。 |

---

## 🔍 仕組み

```
   保存（URL・テキスト・PDF・写真/OCR・音声）
       │
       ▼
 ┌──────────────┐  端末内 Foundation  ┌─────────────────────┐
 │  生記事      │ ─────────────────▶ │ 知識抽出             │  要点・事実・固有名詞
 │ (不変)       │      Models         └─────────────────────┘  (+ 外国語は端末内翻訳)
 └──────────────┘                              │
       │                                        ▼
       │                             ┌─────────────────────┐
       │                             │ 自動タグ + 分野分類  │  確信度付き (High/Med/Low)
       │                             └─────────────────────┘
       │                                        │
       │                                        ▼
       │                             ┌─────────────────────┐
       └────────── 紐付け ──────────▶│  概念 Wiki ページ    │  AI 合成サマリ + 要点
                                     │ (2 階層)             │  + 相互リンク + 要点ごと出典
                                     └─────────────────────┘
                                                │
                          ┌─────────────────────┼─────────────────┐
                          ▼                     ▼                ▼
                   ナレッジフィード       AI チャット (RAG)    自動整理ループ
                   (答え先出し)         (引用付き回答)    (点検・学習・修復)
```

上記はすべて端末内で動作。ネットワーク通信は**あなたが保存を選んだ URL の本文取得**（と任意の iCloud 同期）のみ。保存は即完了、AI 処理は裏で進み、完了次第反映されます。

---

## 📱 アプリ

タブは 3 つ、意図的にシンプル:

- **ナレッジ** — 概念の超まとめを答え先出しで。重要×最新順、お気に入りは最上部にピン留め。「For You」Wiki 棚やおすすめカードも。
- **ライブラリ** — 保存記事を日付別に。関連度ランキング検索（タイトル/要点/事実/固有名詞/タグ横断）。
- **AI チャット** — 自分の知識に基づく ChatGPT / Gemini 風チャット。番号引用・履歴サイドバー・インライン出典リンク。

設定（アバターから）で iCloud 同期 / Safari・翻訳セットアップ / **タグ・分野管理** / **「分類の確認」**（要確認タグ + 精度状況をその場で修正）/ ワンタップ整理。

---

## 🔁 賢くなる仕組み（学習ループ）

カテゴリ分類はオンデバイスモデルが最もぶれやすい所なので、使うほど良くなるループとして作っています:

```
① 取り込み時に分類 → 確信度 [High / Medium / Low] を付ける
      Low → 保守的に「その他」へ   ·   Medium / その他 → 「要確認」
② 整理ループが 不確実なものを優先的に再分類（必要な時だけ・安価）
③ ユーザーが「分類の確認」画面で正しい分野に直す
      → 修正を「正解例」として端末内に記録
④ 次回の分類で その正解例を手本(few-shot)として AI に渡す → 同じ間違いを繰り返さない
```

分類プロンプトは IT に偏らないよう主要分野（健康・経済・スポーツ等）の判断基準を持ち、概念ページ生成は**分野ごとに最適化**（健康なら症状・対処、スポーツなら選手・結果、技術なら表記統一）。*人間の確認が AI の教師になる* ——「理解を外注しない」思想の実装です。

---

## 🛡️ プライバシー

Apple の [Privacy Manifest](KnowledgeTree/PrivacyInfo.xcprivacy) を同梱:

- **データ収集なし。** 保存記事・抽出知識・チャット履歴・概念ページは端末内 SwiftData（+ 任意同期時はあなたの iCloud プライベート DB）のみ。
- **トラッキング・解析・広告なし。**
- **オンデバイス AI。** 要約・分類・翻訳・合成・チャットは Apple Foundation Models でローカル処理。
- **暗号輸出申告**は exempt（標準 HTTPS のみ）。

詳細は [プライバシーポリシー](docs/privacy-policy.md)。

---

## 🏗️ 構成

SwiftData + CloudKit を基盤とした単一ターゲットの SwiftUI アプリ + 3 拡張。知識は LLM Wiki を反映して階層化: 不変の**生記事** → 派生の**抽出知識** → 合成の**概念 Wiki ページ**。

```
KnowledgeTree/
├── KnowledgeTreeApp.swift   # エントリ・3 タブ・起動 DI・BGTask 登録
├── Models/                  # 22 SwiftData @Model (CloudKit 連携・共有スキーマ)
│   ├── Article / ArticleBody / ArticleEnrichment / ExtractedKnowledge (+ KeyFact / KnowledgeEntity)
│   ├── ConceptPage          # 「Wiki ページ」(要約・要点・階層・リンク・出典)
│   ├── ChatSession / ChatMessage / SavedAnswer
│   ├── Tag / CategoryDefinition  # タグ + 動的カテゴリ (10 シード分野)
│   └── LintLog …            # + アプリ専用 CategoryCorrectionExample (端末内学習ストア)
├── Services/                # 約 90 サービス (Protocol + DI、テスト可)
│   ├── KnowledgeExtractionService  # 記事 → 要点/事実/固有名詞 (chunk・token 安全)
│   ├── KnowledgeExtractor          # プロンプト構築 + 端末内翻訳の前処理
│   ├── ConceptSynthesisService     # 記事群 → 概念 Wiki (階層・分野別プロンプト)
│   ├── ChatService                 # 会話型 RAG: 検索 → 引用 → 回答 (履歴考慮)
│   ├── EmbeddingService            # NLEmbedding + Accelerate cosine (メイン外・キャッシュ)
│   ├── AutoCategoryClassifier      # カテゴリ + 確信度 + few-shot 学習
│   ├── LintEngine                  # 再開可能な裏の自動整理ループ
│   ├── TranslationCache            # 再抽出時の再翻訳を回避
│   └── LanguageModelSessionProtocol # Foundation Models ラッパ + 直列化ゲート + token 実測
├── Views/                   # 約 90 SwiftUI View (3 タブ + 詳細/設定/確認)
├── AppIntents/ · Localization/ (日本語ファースト) · Resources/ (iknow-schema.md)
KnowledgeTreeShareExtension/ # 共有シート保存 (テキスト/URL/PDF/ファイル)
KnowledgeTreeSafariExtension/# 任意の自動保存 Web 拡張
iKnowWidget/                 # ホーム画面ウィジェット
```

### 知識パイプライン（1 保存あたり）
1. **取り込み** — Web/テキスト/ファイル/写真/音声を正規化。非 URL は合成 `knowledgebase://…` URL で同じ経路に。
2. **本文** — 読みやすいテキストを抽出（HTML 本文抽出 / PDFKit / Vision OCR / Speech 文字起こし）。
3. **翻訳（必要時）** — 外国語本文 → 日本語、セッションキャッシュで再翻訳を回避。
4. **抽出** — 短文は単発、長文は **chunk + 階層 meta 要約**。
5. **タグ + 分類** — entity から自動タグ、各タグを確信度 + few-shot で分類。
6. **合成** — `ConceptPage`（広い概念 + 具体）を upsert/更新、記事を紐付け、Markdown 本文と相互リンクを生成。
7. **表示** — フィード/チャット/検索が reactively に読む。

### Token 安全・性能
- Foundation Models は **4096 token 窓**。overflow の主因は `@Generable` 出力予約 → schema を slim 化 + **compact 適応再試行** + **`maximumResponseTokens` ハード上限**で暴走を防ぐ。
- 全推論は**単一ゲートで直列化**し ANE 競合を回避、裏の合成はチャットに譲る。
- 検索の cosine 計算は**メインスレッド外** + 質問 embedding キャッシュ、全件スキャンで recall は不変。
- 整理ループは**再開可能・バッチ式**（タグ単位で進捗管理）でアプリ再起動を跨ぐ。

---

## 🛠️ 技術スタック

- **Swift 6** · **SwiftUI** · **SwiftData + CloudKit**（App Group 共有ストア）
- **Apple Foundation Models**（端末内 LLM・`@Generable` 構造化出力）· **NaturalLanguage**（`NLEmbedding`・言語判定）· **Translation** · **Speech**（端末内文字起こし）· **Vision**（OCR）· **PDFKit** · **Accelerate**（`vDSP`）
- **BGTaskScheduler**（バックグラウンド抽出 / 概念合成 / 週次整理）
- 共有拡張 · Safari Web 拡張 · App Intents / ショートカット · ウィジェット
- 仕様駆動開発 [Spec Kit](.specify/)（`specify → plan → tasks → implement`）

---

## 🧭 開発手法 — 仕様駆動 (spec-driven)

すべての機能は番号付き **spec**（`specs/NNN-name/`）として、規律あるパイプラインで進めます:

```
/specify   → spec.md          (何を・なぜ、ユーザーストーリー、受け入れ条件)
/plan      → plan.md          (設計・データモデル・契約・憲法チェック)
/tasks     → tasks.md         (依存順・テスト可能なタスク)
/implement → コード + unit テスト (build green、テスト pass、@Model は CloudKit 安全)
```

プロジェクト**憲法**（`.specify/memory/constitution.md`）が 7 つの核原則（プライバシー / ソース根拠 / 静かな UX / 保守しやすい SwiftUI / 日本語ファースト…）を定め、全 plan がそれに照らしてチェックされます。長期方針「LLM Wiki」第二の脳は [`VISION.md`](VISION.md) に。これまで 80+ の spec をこの方式で出荷しています。

---

## 🚀 ビルド & 実行

**要件**: Xcode 26+ / iOS・iPadOS **26.4+** / **Apple Intelligence 対応端末**（Simulator はキーワード/ヒューリスティック経路に degrade）

```bash
git clone https://github.com/changch223/KnowledgeBase.git
cd KnowledgeTree
open KnowledgeTree.xcodeproj   # KnowledgeTree scheme を実機で実行
```

テスト:

```bash
xcodebuild test -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

> 表示名は **Knowledge Base**。Xcode プロジェクト/ターゲット名は歴史的経緯で `KnowledgeTree` のまま（rename すると CloudKit レコードスキーマが壊れるため）。

---

## 🗺️ ロードマップ

仕様駆動開発 — [`VISION.md`](VISION.md) / [`docs/design-concept.md`](docs/design-concept.md) / `specs/` を参照（長期は「LLM Wiki」第二の脳）。

**出荷済み:** あらゆる入力の取り込み（URL/テキスト/PDF/写真OCR/音声）· 端末内知識抽出 + 翻訳 · 階層・相互リンク・要点出典付き概念 Wiki · 番号引用の会話型 RAG チャット · 確信度 + few-shot 学習の賢い自動分類 · 分野別概念合成 · 裏の自動整理（lint）· AI の見直し・カスタマイズ · iCloud 同期。

**検討中:** 学習ストアの端末間同期 · 概念の関係発見の深化 · 周期「今週」ダイジェスト。

---

## ❓ FAQ

**データはどこかに送られますか?** いいえ。全 AI は端末内。データは端末内 + （任意で）あなたの iCloud プライベート DB のみ。ネットワークは保存を選んだページの取得だけ。

**API キーや課金は必要?** いいえ。Apple の端末内 Foundation Models を使うので、API キー・クラウド LLM コストはありません。

**対応端末は?** Apple Intelligence 対応の iPhone / iPad（iOS 26.4+）。非対応端末では graceful に degrade（意味検索→キーワード、AI 機能無効、保存・閲覧・検索は継続）。

**AI チャットはどう作り話を防ぐ?** 保存記事に基づき番号引用で回答。該当なしは明示し「一般知識」とバッジ表示。

**分類を間違えたら直せる?** はい。*設定 → 分類の確認*（またはタグ管理で長押し）から正しい分野を選ぶと、修正が端末内に記録され、以後の分類に活かされます。

---

## 💬 サポート

質問・不具合・要望 → [GitHub Issues](https://github.com/changch223/KnowledgeBase/issues)。[サポートページ](docs/support.md) も。

---

## 📄 ライセンス

© changch223. **All rights reserved.**

本ソースは透明性のために公開しています。再配布・再利用は許諾していません。利用についてのご相談は Issue へ。

<div align="center">

個人開発 · Claude (Opus) の助けを借りて ❤️ で制作

</div>
