# Feature Specification: 動的トピック自動発見 (機能 Y)

**Feature Branch**: `036-dynamic-topics` (実装時に作成)
**Created**: 2026-05-08
**Status**: Draft (specify+plan のみ)
**Vision**: [VISION.md](../VISION.md) 機能 Y

## なぜ (Why)

VISION.md コア価値「**読んだ知識を AI が自動で体系化**」の核機能。

ユーザー要望 (2026-05-08):
- 例: **「AI PM 関連の情報を一箇所に整理して、最新の要点が書いてある」** ような体験
- 既存 Category (10 個固定) では捉えられない、**ユーザー固有の興味の交差領域** (例: 「AI × Product Management」、「SwiftUI × 状態管理」、「日本企業 × DX」)
- 発見方式: **AI 自動発見 + ユーザー確認** (a + c の組合せ)
- ライフサイクル: **無制限**、ユーザーが採用したものを **重要度・記事数の多い順** で表示

## ゴール

- 保存記事 essence embedding (spec 021 既存) を **clustering** して動的トピックを発見
- AI が **トピック名 + 構成記事** を提案 → ユーザーが採用 / 却下
- 採用済トピックは知識 Clip タブで **既存 Category と並列表示** (重要度順)
- トピックごとに「**最新の要点**」を AI 統合要約

## 非ゴール

- ユーザーが手動でトピック名を作成 → 自動発見が主役、手動は将来 spec
- リアルタイム再 clustering (記事追加毎に全 reorganize) → コスト高、batch 処理で
- トピック削除 / 統合 UI → 却下フローで吸収、明示削除は将来 spec
- マルチ言語サポート → 日本語のみ
- グラフ可視化 (トピック間の関連) → 将来 spec、本 spec はリスト表示のみ

## ユーザストーリー

### US1 (P1) — AI が新トピックを提案

1. アプリ起動時 (or 週 1 回 batch) に AI が clustering 実行
2. 「新しいトピック候補」セクションに最大 3 件 AI 提案
3. 各候補: トピック名 + 構成記事数 + 数件の代表記事タイトル
4. ユーザーが **採用 / 却下 / 後で** を選択

### US2 (P1) — 採用トピックの永続化

1. ユーザー「採用」をタップ
2. `UserTopic` @Model に永続化
3. 知識 Clip タブで Category と並列表示 (重要度順)
4. トピック名は AI 提案のまま (ユーザー編集は将来 spec)

### US3 (P1) — トピックごとの最新要点

1. UserTopic 詳細画面を開く
2. 構成記事の AI 統合要約 (3 段落) + KeyFact 5 件 + Entity 3 件
3. spec 018 KnowledgeDigest と同形式

### US4 (P2) — 却下したトピックは再提案しない

1. 「却下」した UserTopic は dismissedAt 記録
2. 同じ embedding cluster は **30 日間再提案しない**
3. 期間後 or 構成記事大幅変化で再提案可

### US5 (P2) — 重要度順表示

1. 知識 Clip タブで採用 UserTopic を表示
2. 順序: **記事数 × 最新性スコア**で降順
3. 上位 N 件 (default 5) を画面トップに、それ以下は「もっと見る」展開

## 機能要件

### Clustering

- **FR-001**: spec 021 で生成済 `Article.essenceEmbedding: Data?` を再利用
- **FR-002**: clustering algorithm: K-means (K=動的、シルエット係数で決定) or DBSCAN (density-based)
  - MVP は K-means (実装シンプル、Accelerate 使える)、K の決め方は記事数 / 10 で初期値
- **FR-003**: 各 cluster の重心 (centroid) と所属記事のリストを保持
- **FR-004**: 最低 cluster サイズ: 3 記事 (1-2 件は noise)

### AI トピック命名

- **FR-005**: cluster ごとに Foundation Models で命名
  - prompt: 「以下の記事の共通テーマを 5-10 字の日本語で表現してください」
  - 入力: 各記事の title + essence の concat
- **FR-006**: 命名失敗 / 不可端末 → Fallback (上位 entity 名 2-3 個を結合、例: 「AI / Product Management」)

### UserTopic @Model

- **FR-007**: 新 @Model `UserTopic`:
  - id: UUID @Attribute(.unique)
  - name: String
  - createdAt: Date (AI が提案した時刻)
  - acceptedAt: Date?
  - dismissedAt: Date?
  - clusterCentroid: Data? (Float embedding)
  - articles: @Relationship (deleteRule: .nullify)
- **FR-008**: SharedSchema.all に追加
- **FR-009**: 採用済 = `acceptedAt != nil && dismissedAt == nil`

### バッチ処理

- **FR-010**: 起動時 + 7 日に 1 回 batch run (UserDefaults で last batch run 時刻を tracking)
- **FR-011**: バッチで:
  1. essence embedding を持つ全 Article を fetch
  2. K-means clustering
  3. 既存 UserTopic との overlap check (centroid distance)、重複は skip
  4. 新 cluster で AI 命名 → 候補として `acceptedAt = nil, dismissedAt = nil` で insert
  5. 同 cluster で過去に dismissed されているなら skip (30 日)

### UI

- **FR-012**: 知識 Clip タブに `DynamicTopicsSection` 追加
  - 候補リスト (最大 3 件、acceptedAt/dismissedAt 共に nil)
    - トピック名 + 構成記事数 + 代表記事 3 件
    - 「採用」「却下」「後で」ボタン
  - 採用済リスト (acceptedAt != nil)
    - 重要度順 (記事数 × 最新性)
    - タップで詳細画面 (KnowledgeDigest 風)

### 詳細画面

- **FR-013**: 新 view `UserTopicDetailView`:
  - トピック名 (H1)
  - 構成記事数
  - AI 統合要約 3 段落 (新規生成、spec 035 と類似)
  - Top KeyFact 5 件
  - Top Entity 3 件
  - 元記事一覧

## 成功基準

- SC-001: 30 件以上の Article がある状態でアプリ起動 → 1 件以上の動的トピック候補が提示される
- SC-002: 「採用」タップ → 知識 Clip タブで Category と並列表示
- SC-003: 「却下」タップ → 候補リストから消え、30 日間再提案されない
- SC-004: 採用済トピック詳細画面で 3 段落要約 + KeyFact + Entity が表示
- SC-005: AI 不可端末 → 命名は上位 entity ベース、UI 動作は同等
- SC-006: 既存 Category Digest 表示に regression なし
- SC-007: clustering 処理時間 < 2 秒 (1000 articles)

## アサンプション

- 30 件以上の Article がないと clustering は意味なし → そのため Empty state「もっと記事を保存すると AI がトピックを発見します」
- K-means の K = max(2, articleCount / 10)、上限 K=20
- centroid distance threshold = 0.7 (cosine similarity) で類似 cluster と判定
- batch 処理は MainActor で 2 秒以内 (Accelerate vDSP 使用)

## 依存・前提

- **spec 021** (Article.essenceEmbedding 必須、AI Chat retrieval と同 embedding 再利用)
- **spec 015** (AvailabilityChecker)
- **spec 018** (KnowledgeDigest 詳細画面パターン参考)

## 想定実装規模

- 新規 6 ファイル:
  - `Models/UserTopic.swift` (~50 行 @Model)
  - `Services/TopicClusteringService.swift` (~200 行、K-means + AI 命名)
  - `Services/UserTopicStore.swift` (~80 行、CRUD + 重複 check)
  - `Views/DynamicTopicsSection.swift` (~150 行、候補 + 採用済リスト)
  - `Views/UserTopicCandidateRow.swift` (~80 行、採用 / 却下 ボタン付き row)
  - `Views/UserTopicDetailView.swift` (~150 行、詳細画面)
- 改修 4 ファイル:
  - `Views/KnowledgeClipView.swift` (~20 行、section 追加)
  - `KnowledgeTreeApp.swift` (~15 行、起動時 batch run)
  - `SharedSchema.swift` (~3 行、UserTopic 追加)
  - `Services/LanguageModelSessionProtocol.swift` (~30 行、generateTopicName 追加)
- 新規テスト 2 ファイル:
  - `TopicClusteringServiceTests.swift` (~7 ケース)
  - `UserTopicStoreTests.swift` (~5 ケース)
- 合計 ~810 行、~15-20 タスク

## Constitution

- I (privacy): on-device、外部送信ゼロ
- II (MVP): 自動発見 + 採用/却下のみ、手動作成 / 編集 / 統合は将来 spec
- III (source 追跡): UserTopic.articles で元記事追跡可能、詳細画面で表示
- IV (実現可能性): NLEmbedding (既存) + Accelerate K-means + Foundation Models 命名
- V (calm UX): バッチ処理は silent、提案も控えめ (3 件まで)
- VI (architecture): protocol + DI、spec 015 / 018 と同パターン
- VII (日本語): UI / prompt / トピック名 すべて日本語

## 状態

📝 specify+plan 完了 (2026-05-08)、`/speckit-tasks` + `/speckit-implement` は次セッションで。
