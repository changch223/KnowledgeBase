# Feature Specification: Knowledge Graph UI + 編集 (Phase B)

**Feature Branch**: `041-knowledge-graph-ui` (実装時に作成、spec 040 完了後)
**Created**: 2026-05-16
**Status**: Draft (specify+plan)
**Vision**: [VISION.md](../VISION.md) — 「AI 自動 + ユーザー確認」の graph 編集形

## なぜ (Why)

spec 040 で抽出された Knowledge Graph は内部データのみ、ユーザーは直接見られない。本 spec で:

- ユーザーが Category 内 graph を **Concept Map で可視化** できる (Q6 ユーザー要望: default OFF、Settings で ON)
- AI 自動抽出の graph に対し、ユーザーが **rename / merge / delete + edge 編集** で訂正できる (Q11)
- spec 037 (事実上書き提案) と graph 衝突検出を統合 (Q10)

## ゴール (Phase B、UI + 編集)

- Settings に「Graph 表示」toggle (default OFF)
- Category 詳細画面に「**Concept Map**」セクション (toggle ON 時のみ)
  - 主要 entity を中心に、エッジでつながる Concept Map
  - 矢印 + ラベル付きエッジ (Wikipedia 風)
  - ノード tap → GraphNodeDetailView
- ユーザー編集:
  - **Node rename / merge / delete** (spec 024 タグ管理パターン踏襲)
  - **Edge 編集** (label 修正 / 削除 / 確信度上げ)
  - **AI 提案 edge の採用 / 却下** (uncertain edge を確認 UI に出す)
- spec 037 統合: graph 衝突 (例: `Apple --[CEO]--> A` vs `Apple --[CEO]--> B`) を ConflictProposal として提案

## 非ゴール

- 自動レイアウトの高度化 (force-directed 等は将来 spec、本 spec は static layout)
- Cross category graph 可視化
- 3D / VR graph (将来)
- graph の export
- graph のスナップショット / 時系列再生

## ユーザストーリー

### US1 (P1) — Graph 可視化 toggle ON

1. Settings → 「Graph 表示」toggle ON
2. Category 詳細画面 (CategoryFilteredListView / CategoryKnowledgeDetailView) に「Concept Map」セクション出現
3. 主要 entity を中心にした 2D 可視化

### US2 (P1) — ノード tap で詳細

1. Concept Map の node tap
2. `GraphNodeDetailView` → entity 名 / type / mentionCount / 関連記事一覧 / outgoing / incoming edges

### US3 (P1) — Node 編集 (rename / merge / delete)

1. GraphNodeDetailView の編集 button
2. `GraphNodeEditSheet` (spec 024 TagEditSheet 同パターン):
   - rename (同名既存があれば auto merge)
   - 他 node に統合 (Picker)
   - delete (全 edge 解除 + node 削除)

### US4 (P1) — Edge 編集

1. node 詳細画面の edges section で edge tap
2. `GraphEdgeEditSheet`:
   - label 修正
   - confidence 上げ (high 確定)
   - 削除

### US5 (P2) — AI 提案 edge の採用 / 却下

1. 知識 Clip タブに「graph 提案」セクション (spec 040 で isUncertain=true edge)
2. 各候補に「採用 (確定)」「却下 (削除)」「label 変更して採用」ボタン

### US6 (P2) — Graph 衝突検出

1. AI が「`Apple --[release]--> Swift 6`」と「`Apple --[release]--> Swift 5`」の両方を抽出
2. ConflictProposal (spec 037 統合) で「同じ subject + predicate に複数 object — どれが正しい?」提案
3. ユーザーが採用 → 古い edge は isObsolete

## 機能要件

### Settings

- **FR-001**: SettingsView に「Graph 表示」Toggle (UserDefaults: `settings.graphVisible`、default false)
- **FR-002**: toggle ON → Category 詳細画面の Concept Map 出現

### Concept Map View

- **FR-003**: 新 `CategoryGraphView` (SwiftUI):
  - GraphLayout: static 配置 (主要 node 中心、周辺 node を円形に配置、SwiftUI Canvas 描画)
  - エッジ: line + 矢印 + label テキスト
  - ラベル付き edge: 実線、共起 edge: 破線
  - isUncertain edge: 薄い色
- **FR-004**: 最大 30 node 表示、isActive=true のみ
- **FR-005**: 中心 node = degree 最大 (mentionCount * salience)
- **FR-006**: ノード tap → NavigationLink → GraphNodeDetailView

### Node 詳細

- **FR-007**: 新 `GraphNodeDetailView`:
  - ヘッダ: entity 名 + type + mentionCount
  - Section 「関連記事」: GraphNode.articles 一覧
  - Section 「外向エッジ」: outgoing edges (label / target / confidence)
  - Section 「内向エッジ」: incoming edges
  - Toolbar: 編集 button (歯車) → GraphNodeEditSheet

### Node 編集

- **FR-008**: 新 `GraphNodeEditSheet` (TagEditSheet 同パターン):
  - rename
  - 他 node に統合 (Picker)
  - delete
- **FR-009**: GraphNodeStore に rename / merge / delete メソッド (TagStore 同パターン)

### Edge 編集

- **FR-010**: 新 `GraphEdgeEditSheet`:
  - label 修正
  - confidence 上げ (high 確定)
  - 削除

### AI 提案レビュー

- **FR-011**: 知識 Clip タブに「graph 提案」セクション
  - GraphEdge.isUncertain=true の edge 候補表示
  - 「採用 (確定 = isUncertain false に)」「却下 (削除)」「label 変更 + 採用」

### spec 037 統合

- **FR-012**: ConflictDetectionService に「graph triple 衝突」検出を追加
- **FR-013**: 同 (source, predicate) で複数 target の edge → ConflictProposal として表示
- **FR-014**: 採用 → 旧 edge は削除 or isObsolete

## 成功基準

- SC-001: Settings → Graph 表示 ON → Category 詳細画面に Concept Map 出現
- SC-002: 主要 entity が中心、矢印 + label 表示
- SC-003: node tap → 詳細画面 (関連記事 + edges)
- SC-004: node rename → 同名既存があれば auto merge
- SC-005: node merge → source の outgoing/incoming を target に移動
- SC-006: node delete → 全 edge 解除
- SC-007: edge label 修正 / confidence 上げ / 削除
- SC-008: AI 提案 edge を採用 / 却下できる
- SC-009: graph 衝突 → ConflictProposal で確認
- SC-010: Settings OFF → Concept Map 非表示、既存 UI に影響なし

## 想定実装規模 (Phase B)

### 新規ファイル (~8)
- `Views/CategoryGraphView.swift` (~200 行、Canvas 描画)
- `Views/GraphNodeDetailView.swift` (~150 行)
- `Views/GraphNodeEditSheet.swift` (~150 行)
- `Views/GraphEdgeEditSheet.swift` (~120 行)
- `Views/GraphProposalsSection.swift` (~80 行、知識 Clip タブ用)
- `Views/GraphLayout.swift` (~100 行、static layout 計算)
- `Services/GraphNodeStore.swift` (~120 行、rename/merge/delete)
- `Services/GraphProposalReviewService.swift` (~60 行)

### 改修
- `Views/SettingsView.swift` (Graph 表示 toggle)
- `Views/CategoryFilteredListView.swift` (Concept Map section 追加)
- `Views/CategoryKnowledgeDetailView.swift` (Concept Map section 追加)
- `Views/KnowledgeClipView.swift` (graph 提案 section 追加)
- `Services/ConflictDetectionService.swift` (graph 衝突検出追加)
- `Localizable.xcstrings` (~25 文言)

### 新規テスト
- `GraphNodeStoreTests.swift` (~7 ケース)
- `GraphLayoutTests.swift` (~3 ケース)
- `GraphProposalReviewServiceTests.swift` (~3 ケース)

### 合計
**~1000-1200 行 / ~20-25 タスク** (中-大スコープ)

## Constitution

- I (privacy): on-device、外部送信ゼロ
- II (MVP): default OFF、見たいユーザーだけ ON
- III (source 追跡): GraphNode.articles で記事へ refer 維持
- IV (実現可能性): SwiftUI Canvas + static layout、複雑な force-directed なし
- V (calm UX): 削除確認 alert あり (Constitution V 例外)、編集は ユーザー意思優先
- VI (architecture): TagStore / ChatService 同パターン、protocol + DI
- VII (日本語): 全 UI 日本語

## 状態

📝 specify+plan 完了 (2026-05-16)。**spec 040 (Phase A) 完了後に着手**。
