# iKnow (KnowledgeTree) — 現状まとめ

最終更新: 2026-06-15 / main は spec 078 (#36) までマージ済み。

---

## 1. これは何のアプリか

**「気になって保存した記事を、AI が裏で勝手に整理して、必要なときだけ開けば最新の自分が見える、優しい第二の脳」**（VISION v2 = LLM Wiki）。

- 記事 URL を保存すると、**端末内の AI** が本文を読み、知識を抽出し、**概念ページ（Wiki）に自動でまとめ続ける**。
- ユーザーは細かい操作をしない。AI が裏で整理し、ユーザーは「まとめ」を読むだけ。間違いは後から直せる（calm UX / AI 自動 + ユーザー訂正）。
- **完全オンデバイス**（Apple Foundation Models / NLEmbedding / Apple Translation）+ **iCloud (CloudKit private DB) 同期**。外部送信ゼロ。

---

## 2. 画面構成（3 タブ）

| タブ | 役割 |
|---|---|
| **iKnow**（`newspaper.fill`） | ホーム。**概念（まとめ）中心のフィード**。上部に未概念化の「新着」棚 + おすすめ横棚、縦に概念カード（超まとめ：名前+1-2行サマリ+子トピック+記事数）。タップで概念詳細→子トピック→記事へドリルダウン。(spec 075/068) |
| **ライブラリ** | 保存記事の一覧（日付グループ + 検索 + swipe/長押し削除）。FAB で URL 追加。 |
| **AI チャット** | 保存知識に対する RAG チャット（家庭教師ループ / 引用リンク / 履歴サイドバー）。答えは SavedAnswer として永続化し概念に紐付く。 |

- 記事の入口: **Share Extension**（任意アプリの共有）+ **Safari Web Extension**（自動保存）。
- 設定: アバターメニュー → 健全性スコア / 「今すぐ整理」/ タグ・分野の管理 / iCloud / チャット履歴削除 等。

---

## 3. データモデル（主要 @Model、SwiftData + CloudKit）

| モデル | 内容 |
|---|---|
| `Article` | 保存記事（URL/title/savedAt + 各種 relationship） |
| `ArticleBody` / `ArticleEnrichment` | 本文 / OGP 画像等 |
| `ExtractedKnowledge` (+ `KeyFact` / `KnowledgeEntity`) | AI 抽出した essence / 重要事実 / 固有名詞。status で処理状態 |
| `Tag` | 自動タグ。`categoryRaw`（分野）+ `lastLintedAt`（整理進捗） |
| `ConceptPage`（=WikiPage） | **概念ページ**。`bodyMarkdown`/`summary`/`crossSourceInsights`/`embedding`/`kind`(人物/概念/プロジェクト)/`parentConceptID`+`conceptLevelRaw`（2 階層）/`nameAliases`/`relatedConceptIDs`/`isFollowing`/`userUnderstanding` |
| `CategoryDefinition` | 動的カテゴリ（10 シード + agent loop が昇格追加） |
| `SavedAnswer` | AI チャットの答えの永続化（概念に紐付け） |
| `ChatSession` / `ChatMessage` | AI チャット履歴 |
| `ConflictProposal` | 時系列の事実矛盾（自動採用 / 履歴保持） |
| `LintLog` | 整理ループの操作履歴 |
| `GraphNode`/`GraphEdge` | 旧グラフ（**生成は停止**、RAG/表示で参照のみ存続） |
| `UserTopic` / `KnowledgeDigest` | 退役/孤児（CloudKit 安全のため定義のみ残置） |

---

## 4. AI パイプライン（記事保存 → 整理）

```
記事保存
  └─ 本文抽出 (BodyExtractor / PDFKit)
      └─ KnowledgeExtractor
          ├─ 英語なら入口翻訳 (Apple Translation) で日本語化
          ├─ chunked 抽出 (chunk ごとに essence/keyFacts/entities、案A slim schema)
          └─ メタ統合
      ├─ auto-tag: 記事から数タグ → classify で categoryRaw 付与（非同期）
      └─ 概念合成 (ConceptSynthesis)
          ├─ AI が概念階層を抽出: 広い概念(broad) > 具体概念(specific)
          ├─ ConceptPage を canonical 名で upsert（表記ゆれ統合）
          ├─ summary / crossSourceInsights / bodyMarkdown を生成（plain string で token 安全）
          └─ embedding 生成 + 関連概念リンク補完
      └─ 矛盾検出 (ConflictDetection) など hook
```

- **概念合成は直列化**（`ConceptSynthesisGate`）。記事一括処理での同時実行クラッシュを防止。
- **裏の整理ループ `LintEngine`**（週1 BGTask + 起動毎1バッチ + 「今すぐ整理」、resumable NEVER STOP）:
  1. 概念 merge（canonical 名 + 編集距離 + **embedding 意味統合 cosine≥0.88**）
  2. 孤立概念 delete / 3. 孤立タグ delete / 4. 概念 link 強化
  5. タグ再分類（**TTL=30 日**: 確定済み安定タグは再分類しない）+ 概念カテゴリ heal
  6. SavedAnswer 再生成
  7. **新カテゴリ昇格**（その他 概念を embedding クラスタ→AI 命名→動的追加）

---

## 5. オンデバイス AI の制約（重要）

- **Apple Foundation Models の窓 = 4096 token**。Apple 固定オーバーヘッドが大きく、実質の自由枠は狭い。
- `@Generable` は宣言した**最大出力サイズ分を予約**する → 出力スキーマを小さくしないと overflow（`exceededContextWindowSize` ~4090）。
- 対策の歴史: 記事レベル直列化（並列逼迫の解消）/ chunk 専用 slim schema / 概念合成 summary 縮小（spec 077 で 120-180・insights≤2）。
- それでも**重い多記事同時処理下では spurious overflow が稀に残る**（graceful に essence-list fallback で吸収）。

---

## 6. 直近の品質ブラッシュアップ（spec 071〜078、全て main マージ済み）

| spec | 内容 | 状態 |
|---|---|---|
| 071 | TokenBudgetProbe（token 実測基盤） | ✅ |
| 072 | カテゴリ誤分類修正（定義+例+文脈 prompt） | ✅ |
| 073/074 | token 真因解決 + 概念 2 階層 + 動的カテゴリ | ✅ |
| 075 | iKnow タブを概念中心に再設計 + 階層ドリルダウン + カテゴリ管理 | ✅ |
| 076 | resumable 整理ループ + 概念合成の直列化 + 全AI再処理ボタン(DEBUG) | ✅ |
| 077 | [その他] 精度+再ヒール / 概念 slim / 新カテゴリ昇格 / TTL ゲート | ✅ |
| 078 | 概念ページの重複統合（canonical 正規化 + embedding 意味統合） | ✅ |

**到達点**: カテゴリ分類精度が大幅改善（AI/tech 用語が正しく テクノロジー 等に）、概念の [その他] 氾濫が解消、概念の重複（Apple/Apple Inc、生成AI/LLM、全角/かな変種）が入口正規化 + embedding 統合で畳まれる、overflow が大幅減、整理ボタンが安定タグを再分類しなくなった。

---

## 7. 既知の残課題 / 次の候補

| テーマ | 内容 | 体感価値 | リスク |
|---|---|---|---|
| **meta-summary に KeyFact 追加** | 多記事概念の最終 summary が「要約の要約」で事実が薄い → KeyFact を bound して meta に渡す | 高（概念が濃くなる） | token 管理が要 |
| broad/specific overflow の adaptive retry | overflow を catch して1回短縮再試行で確実に救う | 中 | 実装やや増 |
| 新カテゴリ昇格の実発火確認・チューニング | Part C 実装済だが ≥5 凝集 embedding が要るため未発火。閾値調整 | 中 | 過剰生成 |
| embedding 閾値適応化 | 固定の cosine 閾値を分布から動的に | 低（地味） | 検証難 |
| 人名・組織の tech 寄り | classifier が AI 業界の人名/組織まで テクノロジー に倒す | 低（ノイズ） | 小 |
| 各 spec の実機検証 backlog | quickstart シナリオの未消化分 | — | — |

**直近の実機確認待ち**（次の通常起動で見える）:
- TTL ゲート: 確定タグが毎回再分類されず、ログが静かになるか
- spec 078: Apple/Apple Inc・生成AI/LLM が「今すぐ整理」後に 1 ページに畳まれるか / 過剰統合がないか

---

## 8. 開発の鉄則（このプロジェクト固有）

- **CloudKit 安全**: `@Model` の削除・rename 禁止。フィールド追加は default 必須。`ConceptPage` 型名は永久に rename しない（`CD_ConceptPage` record type 破壊回避、「WikiPage」は docs/UI 呼称のみ）。
- **token 安全**: 出力スキーマを小さく保つ。入力削りより「出力予約」を疑う。
- **軽さ優先**: 記事保存あたりの AI 呼び出しを増やさない。裏処理は直列 + resumable。
- **連続 spec のブランチ規律**: 前段が main マージ後に main から切る（stacked branch 事故回避）。
- **commit/PR/マージはユーザー指示後**。`.agents/` はコミット対象外。
</content>
