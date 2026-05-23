# Plan: Knowledge Graph UI + 編集 (Phase B)

**Spec**: [spec.md](./spec.md)
**Date**: 2026-05-16
**前提**: spec 040 (Phase A) 完了 — GraphNode / GraphEdge / GraphExtractionService / GraphTraversalService が稼働している状態

## Technical Context

- Swift 6 / SwiftUI / SwiftData / Foundation Models
- iOS 26+
- 既存 TagStore / TagEditSheet パターンを Graph 編集に流用
- 規模: 中-大 (~1000-1200 行、~20-25 タスク)

## Architecture

```
[Settings]
  └── Graph 表示 Toggle (@AppStorage settings.graphVisible)

[CategoryFilteredListView / CategoryKnowledgeDetailView]
  └── graphVisible == true なら
       └── CategoryGraphView (新)
            ├── GraphLayout で 2D 配置計算 (中心 + 円形)
            ├── Canvas で line + 矢印 + label 描画
            └── ノード tap → GraphNodeDetailView (navigationDestination)

[GraphNodeDetailView] (新)
  ├── 関連記事一覧
  ├── outgoing/incoming edges
  ├── 編集 button → GraphNodeEditSheet (rename/merge/delete)
  └── edge tap → GraphEdgeEditSheet (label/confidence/delete)

[KnowledgeClipView]
  └── 「graph 提案」section (新)
       └── isUncertain=true edge 一覧
            └── 採用 / 却下 / label 変更 button

[GraphNodeStore] (新)
  ├── rename / merge / delete (TagStore 同パターン)
  └── RefreshTrigger.bump

[ConflictDetectionService] (改修)
  └── graph triple 衝突検出追加 (同 source+predicate に複数 target)
```

## Constitution Check

全 7 原則 PASS。spec 040 と同様。

## Implementation Outline

### Phase 1: Foundation
- T001 [P] @AppStorage `settings.graphVisible` 追加 (default false)
- T002 [P] SettingsView に「Graph 表示」Toggle row 追加
- T003 [P] xcstrings に graph.* 約 25 文言追加

### Phase 2: GraphNodeStore
- T004 GraphNodeStore 新規 (rename / merge / delete + RefreshTrigger)
- T005 GraphNodeStoreTests 7 ケース

### Phase 3: GraphLayout + CategoryGraphView
- T006 GraphLayout 新規 — static layout 計算 (中心 + 円形配置)
- T007 GraphLayoutTests 3 ケース (中心 node 選択 / 円形配置位置 / overflow)
- T008 CategoryGraphView 新規 — SwiftUI Canvas 描画
  - ノード: 円 + 名前
  - エッジ: line + 矢印 + label
  - ラベル付き: 実線、共起: 破線、isUncertain: 薄色

### Phase 4: GraphNodeDetailView + Edit Sheets
- T009 GraphNodeDetailView (関連記事 + edges + 編集 button)
- T010 GraphNodeEditSheet (rename / merge / delete + 確認 alert、TagEditSheet 同パターン)
- T011 GraphEdgeEditSheet (label / confidence / delete)

### Phase 5: AI 提案レビュー
- T012 GraphProposalsSection 新規 (知識 Clip タブ用)
- T013 GraphProposalReviewService 新規 (採用 / 却下 / label 変更)
- T014 GraphProposalReviewServiceTests 3 ケース

### Phase 6: spec 037 統合 (graph 衝突)
- T015 ConflictDetectionService に graph triple 衝突検出追加
- T016 ConflictDetectionServiceTests に graph 衝突ケース追加

### Phase 7: 統合 + Polish
- T017 CategoryFilteredListView / CategoryKnowledgeDetailView に CategoryGraphView 追加 (graphVisible 連動)
- T018 KnowledgeClipView に GraphProposalsSection 追加
- T019 KnowledgeTreeApp で GraphNodeStore / GraphProposalReviewService inject
- T020 build 警告ゼロ + 全関連テスト全回帰
- T021 CLAUDE.md / ROADMAP 更新

## 主要研究項目

### R1: SwiftUI Canvas での graph 描画

**Decision**: SwiftUI `Canvas` view を使用、`GraphicsContext.draw` で circle / line / arrow / text を描画。

**Rationale**: SpriteKit / Metal は overkill、Canvas は performance 十分 (30 node × 100 edge は余裕)。

### R2: Layout アルゴリズム

**Decision**: **Static layout** (中心 + 円形配置):
- 中心: degree 最大 node (mentionCount * salience の max)
- 周辺: degree 降順で円形配置、半径は node 数に比例
- Force-directed は将来 spec (重い、iPhone 負荷)

### R3: 編集の影響範囲

**Decision**: 編集後 RefreshTrigger.bump、@Query 経由で UI 自動更新。spec 024 TagStore 同パターン。

### R4: graph 衝突検出のタイミング

**Decision**: ConflictDetectionService (spec 037) の `detect(article:)` 末尾に graph triple 衝突検出を追加。新 article 保存 → triple 抽出済 → 同 source+predicate に複数 target があれば ConflictProposal 作成。

### R5: spec 037 ConflictProposal の拡張

**Decision**: ConflictProposal に `graphEdgeID: UUID?` 任意 attribute 追加 (lightweight migration)、graph 衝突は target.id 配列で記録。

## Critical Files

### 新規 (~8 ファイル)
- `Views/CategoryGraphView.swift`
- `Views/GraphNodeDetailView.swift`
- `Views/GraphNodeEditSheet.swift`
- `Views/GraphEdgeEditSheet.swift`
- `Views/GraphProposalsSection.swift`
- `Views/GraphLayout.swift` (private struct or 純関数)
- `Services/GraphNodeStore.swift`
- `Services/GraphProposalReviewService.swift`

### 改修 (~6 ファイル)
- `Views/SettingsView.swift` (Graph 表示 Toggle)
- `Views/CategoryFilteredListView.swift`
- `Views/CategoryKnowledgeDetailView.swift`
- `Views/KnowledgeClipView.swift`
- `Services/ConflictDetectionService.swift` (graph 衝突)
- `Models/ConflictProposal.swift` (graphEdgeID 追加、lightweight migration)
- `Localizable.xcstrings` (~25 文言)

### 新規テスト
- `GraphNodeStoreTests.swift` (~7 ケース)
- `GraphLayoutTests.swift` (~3 ケース)
- `GraphProposalReviewServiceTests.swift` (~3 ケース)

## MVP 範囲外 (Phase C 以降)

- Force-directed layout (動的)
- 3D / VR graph
- graph export (PNG / SVG / JSON)
- graph スナップショット (時系列再生)
- 2-hop 以上の表示
- Cross category graph
- パフォーマンス最適化 (Metal 等)
- グラフ検索 (entity 名で zoom in)

## 依存関係

- **spec 040 (Phase A) 完了必須** — GraphNode / GraphEdge / GraphExtractionService が稼働済
- **spec 024 TagStore パターン** を Graph 編集に流用
- **spec 037 ConflictDetectionService** を graph 衝突に拡張
- **spec 005 RefreshTrigger** を編集後の UI 更新に使用

## 着手タイミング

spec 040 が main にマージ + 実機検証 OK 後。実装は段階分割で進める:

1. **段階 1**: Foundation + Settings toggle (Phase 1) — UI に「Graph 表示」が出るが中身ゼロ
2. **段階 2**: CategoryGraphView + GraphLayout (Phase 3) — 描画だけ動く
3. **段階 3**: Detail + Edit (Phase 2 + 4) — 編集機能完成
4. **段階 4**: 提案 + 衝突 (Phase 5 + 6) — spec 037 統合
5. **段階 5**: 統合 (Phase 7) — bootstrap + 全 view 連動
