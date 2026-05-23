# Feature Specification: Knowledge Graph 抽出 + Digest + RAG 統合 (Phase A)

**Feature Branch**: `040-knowledge-graph-extraction` (実装時に作成)
**Created**: 2026-05-16
**Status**: Draft (specify+plan)
**Vision**: [VISION.md](../VISION.md) — 「読んだ知識を AI が自動で体系化」の核心実装

## なぜ (Why)

VISION コア価値「**読んだ知識を AI が自動で体系化・更新し、最新の自分が見える、第二の脳**」の **「体系化」** を真に実現する。

ユーザー要望 (2026-05-16):
> 記事を knowledge graph で抽出して、それぞれのカテゴリーごとに graph ベースで知識を格納していくこと。この graph をベースに RAG や知識 Clip の概要を生成するデータ元 (記事 + graph) になる。これにより体系化した知識が蓄積される。

現状の限界:
- 記事ごとに `KnowledgeEntity` を抽出するが、entity 間の関係は記録していない
- AI Chat RAG は essence embedding ベース、entity 同士の関連を活用できていない
- Category Digest は記事を順番に列挙するだけ、entity の中心性を意識した文章になっていない

graph 化で得られる体験:
- 「主要 entity ◯◯ を中心に N 件の記事が…」のような **graph 構造を意識した Digest 文章** (Q14 ユーザー希望)
- AI Chat で「Apple について教えて」 → Apple node の周辺 entity も context に → より網羅的な回答
- 過去記事の知識が `Tim Cook --[CEO of]--> Apple` のような形で体系化される

## ゴール (Phase A、UI なし、内部のみ)

- Category 単位の **knowledge graph 自動抽出**:
  - ノード = Entity (既存 `KnowledgeEntity` と 1:1 リンク)
  - エッジ = ラベル付き or 共起 のハイブリッド (確信度判定)
- 記事保存時の自動抽出 (`KnowledgeExtractionService` hook)
- **Category 内 graph** (Cross category は将来 spec)
- **Category Digest prompt に graph 構造を渡す** → 主要 entity 中心の文章生成
- **AI Chat RAG: graph traversal で周辺 node を context に追加** (embedding + graph ハイブリッド)
- アンチパターン回避: 確信度しきい値 / node 上限 / silent skip

## 非ゴール (Phase B = spec 041 で対応)

- UI / 可視化 (Concept Map、Settings toggle)
- ユーザー編集 (node rename / merge / delete + edge 編集)
- spec 037 (事実上書き) と graph 衝突検出の統合
- Cross category graph (将来 spec)
- Concept / Fact / Article ノード (Entity のみ)
- グラフ可視化のレイアウトアルゴリズム

## ユーザストーリー (Phase A は内部動作のみ、UI 観察できない)

### US1 (P1) — 記事保存で graph 自動成長 (内部)

1. 新記事を保存 → knowledge extraction が完了
2. AI が記事の主要 entity + relation を triple (subject, predicate, object) で抽出
3. 既存 `KnowledgeEntity` から `GraphNode` を upsert (1:1 リンク)
4. `GraphEdge` を upsert (label + confidence)
5. Category 単位で graph が成長していく

### US2 (P1) — Category Digest が graph 構造を意識した文章になる

1. 知識 Clip タブ → Category Digest 表示
2. AI 生成文章: 「**Apple を中心に Swift 6 / iOS 26 / Tim Cook の話題が広がっており…**」
3. 主要 entity (graph で degree 最高) を中心に物語る文章

### US3 (P1) — AI Chat RAG が graph で深く回答

1. 「Apple について教えて」と質問
2. ChatService が:
   - embedding ベースで top-k 記事 retrieval (現状)
   - **+ graph traversal**: Apple node の 1-hop 近傍 entity (Swift 6 / Tim Cook etc) も収集
3. prompt に「## 関連エンティティ」セクション追加 → AI が網羅的に回答

### US4 (P2) — 確信度低いエッジは保存しない (アンチパターン回避)

1. AI が triple 抽出時、confidence (high / medium / low) を判定
2. high → ラベル付き edge 作成
3. medium → ラベル付き、`isUncertain = true` flag (Phase B で UI 表示)
4. low → 共起のみ (ラベルなし、Edge.isLabeled = false)

### US5 (P2) — node 数上限で graph 巨大化を防ぐ (アンチパターン回避)

1. Category 内 GraphNode 数が **30 超** になったら
2. 元 KnowledgeEntity.salience が低い順に GraphNode を **deactivate** (delete はせず active=false)
3. Phase B の UI で 「inactive node を表示」 toggle (将来)

## 機能要件

### GraphNode @Model

- **FR-001**: 新 @Model `GraphNode`:
  - `id: UUID @Attribute(.unique)`
  - `name: String` (entity 名、KnowledgeEntity.name と同じ)
  - `categoryRaw: String` (所属 Category、Tag.categoryRaw と整合)
  - `entityType: String` (人物 / 組織 / 場所 / 概念 / 製品 / 作品、EntityTypeStored.rawValue)
  - `salience: Int` (1-5、元 KnowledgeEntity の集約平均)
  - `mentionCount: Int` (この entity が何記事で言及されたか、Category 内)
  - `isActive: Bool` (default true、上限超過時 false)
  - `createdAt: Date`
  - `updatedAt: Date`
  - `@Relationship outgoingEdges: [GraphEdge]` (deleteRule: cascade)
  - `@Relationship incomingEdges: [GraphEdge]` (deleteRule: cascade)
  - `@Relationship articles: [Article]` (この entity が出現した記事、deleteRule: nullify)

### GraphEdge @Model

- **FR-002**: 新 @Model `GraphEdge`:
  - `id: UUID @Attribute(.unique)`
  - `source: GraphNode` (relationship、inverse: outgoingEdges)
  - `target: GraphNode` (relationship、inverse: incomingEdges)
  - `label: String?` (例: "release", "CEO of"、共起の場合は nil)
  - `confidence: Float` (0.0-1.0、AI の確信度)
  - `isLabeled: Bool` (computed: label != nil)
  - `isUncertain: Bool` (Phase B 用、confidence 0.5-0.7 で true)
  - `weight: Int` (この edge が観察された回数、共起回数)
  - `categoryRaw: String` (所属 Category、source/target と同じ)
  - `createdAt: Date`
  - `updatedAt: Date`

### SharedSchema 拡張

- **FR-003**: SharedSchema.all に GraphNode / GraphEdge 追加

### GraphExtractionService

- **FR-004**: 新 service `GraphExtractionService` (~250 行):
  - protocol + 実装
  - 記事保存時に knowledge extraction succeeded で trigger
  - 入力: Article (extractedKnowledge 経由で entities / keyFacts 取得済)
  - 処理:
    1. AI で triple 抽出 (`generateGraphTriples` prompt)
    2. 各 triple を GraphNode upsert + GraphEdge upsert
    3. node 上限 30 超なら salience 低い順 deactivate
  - 確信度判定:
    - high (>=0.7) → ラベル付き
    - medium (0.5-0.7) → ラベル付き + isUncertain
    - low (<0.5) → 共起のみ
  - Foundation Models 不可端末 → Fallback (entity 共起のみで graph 作成、ラベルなし)

### GraphTripleOutput @Generable

- **FR-005**: `LanguageModelSessionProtocol` に `generateGraphTriples(prompt:)` 追加
- **FR-006**: `@Generable struct GraphTripleOutput { triples: [GraphTripleItem] }`
- **FR-007**: `@Generable struct GraphTripleItem { subject: String, predicate: String, object: String, confidence: Double }`

### Foundation Models prompt 例

```
以下の記事から、主要な事実関係を triple 形式 (subject, predicate, object) で抽出してください。

## ルール
1. subject / object は entity (人物・場所・モノ・概念) で、記事に明示されているものに限る
2. predicate は短い動詞句 (release, lead, succeed, criticize 等)
3. confidence は 0.0-1.0、確信度 0.5 未満は出力しない
4. 同じ entity ペアに複数 triple があれば最も重要なものだけ
5. 最大 10 triple

## 記事
タイトル: \(title)
要点: \(essence)
KeyFacts: \(keyFacts.joined())
```

### KnowledgeExtractionService hook

- **FR-008**: `KnowledgeExtractionService` に `graphService: GraphExtractionServiceProtocol?` 追加 (default nil で後方互換)
- **FR-009**: knowledge extraction succeeded/partiallySucceeded 後に `extractGraphIfPossible(article:)` を fire-and-forget

### KnowledgeDigestService 改修

- **FR-010**: Category Digest 生成 prompt に「## このカテゴリーの主要エンティティ」セクションを追加:
  - GraphNode を Category 内で degree 高い順に上位 5 件
  - 各 node に対する outgoing edge 上位 2 件 (label + target)
  - 例: 「Apple — release → Swift 6 / iOS 26」
- **FR-011**: prompt 指示「以下の主要エンティティを中心に、記事を統合して 3 段落で文章化してください」

### ChatService RAG 統合

- **FR-012**: `ChatService.send` の retrieval 後に **graph 近傍取得** を追加:
  - 質問のキーワード or top-k 記事の entity から GraphNode を解決
  - 1-hop 近傍 GraphNode (outgoing/incoming edges 経由) を取得
  - 上位 N (default 5) を prompt の `## 関連エンティティ` セクションに追加
- **FR-013**: graph 経由で発見された entity が referencing する article も top-k に追加 (重複除外)
- **FR-014**: 全てフォールバック可能: graph 不可端末 / GraphNode 0 件なら現状の embedding-only retrieval

### アンチパターン対策

- **FR-015**: confidence しきい値 0.5 未満は AI 出力でも採用しない
- **FR-016**: Category 内 GraphNode は最大 30 (active)
- **FR-017**: 同 (source, target, label) の edge は upsert (重複作成なし)、weight += 1
- **FR-018**: AI 失敗時は silent skip (graph extraction なしでも本フローは継続)

## 成功基準

- SC-001: 記事 N 件保存 → Category 内 graph が成長 (GraphNode / GraphEdge 数で確認)
- SC-002: graph 抽出で正しいラベル付き edge ができる (例: 「Apple --[release]--> Swift 6」)
- SC-003: 確信度 0.5 未満 は filter で消える
- SC-004: node 30 超 → salience 低 deactivate
- SC-005: Category Digest が graph 構造を反映 (「主要エンティティ Apple を中心に…」のような文章)
- SC-006: AI Chat 質問 → graph 経由で関連 entity が context に追加され、回答が深くなる
- SC-007: 既存 ExtractedKnowledge / Digest 出力に regression なし (graph 機能 OFF でも動作)
- SC-008: AI 不可端末 → fallback で entity 共起のみの graph、UI / 既存機能継続動作

## アサンプション

- 1 記事 5-10 triple 抽出、Foundation Models で 1 prompt
- Category 内 GraphNode 最大 30 (active)、初期は ~10 程度
- GraphEdge 数は Category 内最大 100 程度 (node 30 × outgoing 平均 3)
- AI Chat の graph traversal は 1-hop 近傍 (2-hop は計算量増、将来 spec)
- 確信度 0.7 以上 = high、0.5-0.7 = medium、0.5 未満は除外

## 依存・前提

- spec 004 ExtractedKnowledge / KnowledgeEntity (1:1 リンク元)
- spec 008 Tag / Category
- spec 015 AutoCategoryClassifier (Tag.categoryRaw 経由で Article の Category 解決)
- spec 018 KnowledgeDigest (本 spec で prompt 拡張)
- spec 021 ChatService / EmbeddingService (graph 統合)

## 想定実装規模 (Phase A)

### 新規ファイル
- `Models/GraphNode.swift` (~70 行)
- `Models/GraphEdge.swift` (~60 行)
- `Services/GraphExtractionService.swift` (~250 行)
- `Services/GraphTraversalService.swift` (~120 行、RAG 用近傍取得)

### 改修ファイル
- `SharedSchema.swift` (GraphNode / GraphEdge 追加)
- `Services/LanguageModelSessionProtocol.swift` (~50 行追加、GraphTripleOutput + generateGraphTriples)
- `Services/KnowledgeExtractionService.swift` (~30 行追加、hook)
- `Services/KnowledgeDigestService.swift` (~80 行追加、graph セクション in prompt)
- `Services/ChatService.swift` (~80 行追加、graph traversal 統合)
- `KnowledgeTreeApp.swift` (~20 行、service inject)
- `Services/ServiceContainer.swift` (~5 行)
- `KnowledgeTreeTests/KnowledgeExtractorTests.swift` MockLanguageModelSession 拡張
- `KnowledgeTree.xcodeproj/project.pbxproj` (GraphNode / GraphEdge を Share/Safari Extension target に登録)

### 新規テスト
- `GraphExtractionServiceTests.swift` (~10 ケース)
- `GraphTraversalServiceTests.swift` (~5 ケース)
- ChatService graph 統合テスト (~3 ケース追加 in `ChatServiceTests.swift`)

### 合計
**~1000-1100 行 / ~18-22 タスク** (中-大スコープ、spec 036 並)

## Constitution

- I (privacy): on-device 抽出、外部送信ゼロ
- II (MVP): Phase A は graph 抽出 + 既存機能統合のみ、UI / 編集は Phase B
- III (source 追跡): GraphNode.articles で出現記事へ refer、graph 上の entity が必ず元記事に追跡可能
- IV (実現可能性): Foundation Models triple 抽出 + SwiftData @Relationship + Accelerate (将来 layout 計算用)
- V (calm UX): graph 抽出は silent fire-and-forget、エラーも silent
- VI (architecture): protocol + DI、spec 021 / 036 と同パターン
- VII (日本語): prompt 日本語、entity 名そのまま、UI 露出なし (Phase A)

## 状態

📝 specify+plan 完了 (2026-05-16)。`/speckit-tasks` + `/speckit-implement` はユーザー判断後。

Phase A 完了後、**spec 041 (Phase B): Knowledge Graph UI + 編集** で:
- Settings に「Graph 表示」toggle
- CategoryGraphView (Concept Map 風)
- ユーザー編集 UI (node rename / merge / delete + edge 採用/却下)
- spec 037 と graph 衝突検出統合
