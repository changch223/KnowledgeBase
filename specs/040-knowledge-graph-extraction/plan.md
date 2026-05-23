# Plan: Knowledge Graph 抽出 + Digest + RAG 統合 (Phase A)

**Spec**: [spec.md](./spec.md)
**Date**: 2026-05-16

## Technical Context

- Swift 6 / SwiftUI / SwiftData / Foundation Models / Accelerate
- iOS 26+
- 既存 KnowledgeEntity / KnowledgeDigest / ChatService / ServiceContainer を再利用 + 拡張
- 規模: 中-大 (~1000-1100 行、~18-22 タスク)
- UI ゼロ (Phase B で対応)

## Architecture

```
[Article 保存]
  → KnowledgeExtractionService.extract
    → KnowledgeExtractor (Foundation Models for ExtractedKnowledge)
      → ExtractedKnowledge 永続化 (essence / keyFacts / entities)
      → applyAutoTags (spec 012)
      → markDigestStale (spec 018)
      → generateEmbedding (spec 021)
      → detectConflicts (spec 037)
      → 【NEW】 extractGraphIfPossible
        → GraphExtractionService.extract(article)
          ↓ AI で triple 抽出 (GraphTripleOutput)
          ↓ KnowledgeEntity → GraphNode 1:1 upsert
          ↓ GraphEdge upsert (label + confidence + weight)
          ↓ node 30 超 → salience 低 deactivate

[Category Digest 生成]
  KnowledgeDigestService
    ↓ Article fetch (Category 内)
    ↓ 【NEW】GraphTraversal で主要 entity + outgoing edges を取得
    ↓ prompt に「## このカテゴリーの主要エンティティ」セクション追加
    ↓ Foundation Models → 主要 entity 中心の文章生成

[AI Chat RAG]
  ChatService.send
    ↓ embedding ベース top-k 記事 retrieval (現状)
    ↓ 【NEW】記事の entity → GraphNode 解決
    ↓ 【NEW】1-hop 近傍 GraphNode 取得 (GraphTraversalService)
    ↓ prompt に「## 関連エンティティ」セクション追加
    ↓ Foundation Models → 網羅的回答
```

## Constitution Check

全 7 原則 PASS:
- I (privacy): on-device、外部送信ゼロ
- II (MVP): Phase A は抽出 + 統合のみ、UI は Phase B
- III (source 追跡): GraphNode.articles で記事 refer
- IV (iOS 実現可能性): Foundation Models triple 抽出 + SwiftData @Relationship
- V (calm UX): silent fire-and-forget、エラーも silent
- VI (architecture): protocol + DI、既存パターン踏襲
- VII (日本語): prompt 日本語、UI 露出なし

## Implementation Outline

### Phase 1: Foundation (Models + protocol)
- T001 [P] GraphNode @Model 新規 — `Models/GraphNode.swift`
- T002 [P] GraphEdge @Model 新規 — `Models/GraphEdge.swift`
- T003 [P] SharedSchema.all に GraphNode / GraphEdge 追加
- T004 [P] GraphTripleOutput @Generable + LanguageModelSession 拡張 — `Services/LanguageModelSessionProtocol.swift`
- T005 MockLanguageModelSession に generateGraphTriples 追加
- T006 pbxproj に GraphNode.swift / GraphEdge.swift を Share/Safari Extension target に登録 (spec 020 / 036 と同パターン)

### Phase 2: GraphExtractionService
- T007 [US1] GraphExtractionService protocol + 実装 — `Services/GraphExtractionService.swift`
  - extract(article:) — AI triple → upsert
  - GraphNode upsert (KnowledgeEntity から取得、Category 解決)
  - GraphEdge upsert (label + confidence + weight)
  - node 上限 30、salience 低を deactivate
  - 確信度判定 (high/medium/low)
  - Fallback (entity 共起のみ)
- T008 [US1] GraphExtractionServiceTests 10 ケース — `Tests/GraphExtractionServiceTests.swift`

### Phase 3: KnowledgeExtractionService hook
- T009 [US1] KnowledgeExtractionService に graphService inject + extractGraphIfPossible hook
- T010 既存 KnowledgeExtractionServiceTests 全 PASS 維持 (regression)

### Phase 4: GraphTraversalService
- T011 [US3] GraphTraversalService 新規 — `Services/GraphTraversalService.swift`
  - resolveNodes(entityNames:) — 名前から GraphNode 解決
  - neighbors(of: GraphNode, hop: Int = 1) — 1-hop 近傍取得
  - topByDegree(category: String, limit: Int) — Category 内 degree 上位
- T012 [US3] GraphTraversalServiceTests 5 ケース

### Phase 5: KnowledgeDigestService 改修
- T013 [US2] DigestService prompt 改修
  - 「## このカテゴリーの主要エンティティ」セクション追加
  - GraphTraversalService.topByDegree で上位 5 件
  - 各 node の outgoing edge 上位 2 件 (label + target)
- T014 [US2] Digest prompt 指示「主要 entity を中心に物語る」追加
- T015 KnowledgeDigestServiceTests 既存 PASS 維持

### Phase 6: ChatService RAG 統合
- T016 [US3] ChatService.send に graph traversal 統合
  - top-k 記事の entity → GraphNode 解決
  - 1-hop 近傍 GraphNode 取得
  - prompt の「## 関連エンティティ」セクション追加
- T017 [US3] ChatServiceTests に graph 統合ケース 3 件追加

### Phase 7: Bootstrap + Polish
- T018 ServiceContainer に graphExtractionService / graphTraversalService 追加
- T019 KnowledgeTreeApp で graph service 構築 + knowledge service / chat service / digest service に inject
- T020 build 警告ゼロ + 全関連テスト全回帰
- T021 CLAUDE.md / ROADMAP 更新

## 主要研究項目 (R1-R5)

### R1: GraphNode と KnowledgeEntity の 1:1 リンク

**Decision**: GraphNode は **独立した @Model**、KnowledgeEntity 自体は触らない。GraphNode.name + GraphNode.categoryRaw で「key」を作り、KnowledgeEntity 抽出時の name と一致するもので upsert。

**Rationale**:
- KnowledgeEntity は記事毎に 1 instance (重複可)、GraphNode は Category 内で unique
- KnowledgeEntity.name × Category で重複排除して GraphNode を保つ
- 既存 schema 触らない (Q19 で確定済)

### R2: GraphEdge の upsert キー

**Decision**: `(source.id, target.id, label)` の組み合わせで upsert。同 triple 観察時は weight += 1、confidence は max(existing, new) で更新。

### R3: Category 内 30 node 上限

**Decision**: GraphExtractionService.extract 末尾で `enforceNodeLimit(category:)` を呼ぶ:
- Category 内 GraphNode を `mentionCount * salience` 降順で sort
- 31 件目以降を `isActive = false` (delete はしない)
- 既存 isActive=false が再び mention されたら自動 isActive=true 復帰

### R4: 1-hop 近傍 traversal の計算量

**Decision**: 1-hop は線形時間 (GraphEdge の source.id / target.id で filter)、Category 内最大 100 edge なので 100ms 以内。2-hop は計算量増 (将来 spec)。

### R5: AI prompt の triple 抽出精度

**Decision**: confidence 0.7 以上 = ラベル付き、0.5-0.7 = ラベル付き + isUncertain、0.5 未満 = silent skip。Fallback は entity 共起のみ (記事内同 entity を edge 化、label なし)。

## Critical Files

### 新規 (4 ファイル)
- `KnowledgeTree/Models/GraphNode.swift`
- `KnowledgeTree/Models/GraphEdge.swift`
- `KnowledgeTree/Services/GraphExtractionService.swift`
- `KnowledgeTree/Services/GraphTraversalService.swift`

### 改修 (9 ファイル)
- `KnowledgeTree/SharedSchema.swift` (GraphNode / GraphEdge 追加)
- `KnowledgeTree/Services/LanguageModelSessionProtocol.swift` (GraphTripleOutput + generateGraphTriples)
- `KnowledgeTree/Services/KnowledgeExtractionService.swift` (graphService inject + hook)
- `KnowledgeTree/Services/KnowledgeDigestService.swift` (prompt に graph セクション)
- `KnowledgeTree/Services/ChatService.swift` (send で graph traversal 統合)
- `KnowledgeTree/Services/ServiceContainer.swift` (graph service 2 つ追加)
- `KnowledgeTree/KnowledgeTreeApp.swift` (bootstrap で inject)
- `KnowledgeTreeTests/KnowledgeExtractorTests.swift` (MockLanguageModelSession 拡張)
- `KnowledgeTree.xcodeproj/project.pbxproj` (GraphNode / GraphEdge を Share/Safari Extension target に登録)

### 新規テスト (2 ファイル + 既存 ChatServiceTests に 3 ケース追加)
- `KnowledgeTreeTests/GraphExtractionServiceTests.swift` (~10 ケース)
- `KnowledgeTreeTests/GraphTraversalServiceTests.swift` (~5 ケース)

## MVP 範囲外 (Phase B = spec 041)

- UI / 可視化 (CategoryGraphView、Concept Map)
- Settings の「Graph 表示」toggle
- ユーザー編集 (rename / merge / delete + edge)
- spec 037 (事実上書き) と graph 衝突検出統合
- 2-hop 以上の traversal
- Cross category graph

## 依存関係

- spec 004 ExtractedKnowledge.entities 必須
- spec 015 Tag.categoryRaw 必須 (Article の Category 解決)
- spec 018 KnowledgeDigestService (prompt 改修対象)
- spec 021 ChatService / EmbeddingService (RAG 統合対象)

## 進捗判断 (実装着手 / 段階分割)

特大 spec (~1000+ 行) のため、次セッションで実装する場合は以下の段階分割を推奨:

1. **段階 1**: Foundation (Phase 1-2) — Models + GraphExtractionService 単体
2. **段階 2**: Hook + Traversal (Phase 3-4) — KnowledgeExtractionService 統合 + GraphTraversalService
3. **段階 3**: Digest 統合 (Phase 5) — KnowledgeDigestService prompt 改修
4. **段階 4**: ChatService 統合 (Phase 6-7) — RAG + Bootstrap

各段階で commit、最終的に 1 PR にまとめる、または段階毎に PR 分割。
