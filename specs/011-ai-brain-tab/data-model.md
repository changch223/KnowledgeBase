# Phase 1 Data Model: spec 011 (UI リブランディング + AI ブレインタブ)

**Created**: 2026-05-05

## 概要

本 spec は **新 @Model / 新 schema migration ゼロ**。既存の SwiftData モデルを **読み取り専用** で参照する。本ドキュメントでは:

- **Section A**: 既存 @Model モデルの再確認 (改修なし)
- **Section B**: 新規 transient (非永続) 型の定義

の 2 部構成とする。

---

## Section A: 既存 @Model モデル (改修なし)

| @Model | 利用箇所 | アクセスパターン |
|---|---|---|
| `Article` | PowerGauge / RecentActivity | `@Query<Article>` 全件 + 7 日 predicate |
| `Tag` | KnowledgeMap / RecentActivity | `@Query<Tag>` 全件、`tag.articles.count` でノードサイズ算出 |
| `KnowledgeEntity` | PowerGauge / RecentActivity | `@Query<KnowledgeEntity>` 全件、`name.lowercased().trim()` で重複排除 |
| `KeyFact` | PowerGauge | `@Query<KeyFact>` 全件 count |
| `ExtractedKnowledge` | KnowledgeMap | `tag.articles[i].extractedKnowledge.entities` 経由でエッジ計算 |
| `ArticleEnrichment` / `ArticleBody` | (本 spec 未使用) | — |

すべての relationship は spec 001-010 で確立済。Article ↔ Tag (多対多)、Article → ExtractedKnowledge → KnowledgeEntity / KeyFact のチェーンを traverse する。

### 検証

- `Tag.articles.count` を ScrollView 内で読む際、`@Query<Tag>` から得られたインスタンスは relationship を lazy load 済 (spec 008 で動作確認済)
- 同様に `tag.articles[i].extractedKnowledge?.entities` も lazy load 動作

---

## Section B: 新規 Transient 型 (View / 純粋関数間の dataflow のみ。永続化なし)

### B-1. `MapNode`

KnowledgeMap の 1 ノード = 1 Tag。位置と半径を保持。

```swift
struct MapNode: Identifiable, Hashable, Sendable {
    let id: String           // tag.name (TagNormalizer 済正規化値)
    var position: CGPoint    // force-directed 後の最終位置 (Canvas 座標系、単位は pt)
    var radius: CGFloat      // 40-100pt、tag.articles.count 対数スケール
    let articleCount: Int    // 表示用 (VoiceOver / Tooltip 対応)
}
```

| Field | 説明 | 制約 |
|---|---|---|
| `id` | Tag.name | 空文字列禁止 (Tag schema で unique 保証済) |
| `position` | Canvas 内座標 | 初期値はランダム、force-directed で更新 |
| `radius` | 円のサイズ | min(100, max(40, log2(articleCount + 1) * 20)) |
| `articleCount` | tag.articles.count スナップショット | 0 以上 |

### B-2. `MapEdge`

KnowledgeMap のエッジ = 共通 KnowledgeEntity を持つ Tag ペア。

```swift
struct MapEdge: Hashable, Sendable {
    let from: String         // Tag.name (alphabetical で小さい方)
    let to: String           // Tag.name (alphabetical で大きい方)
    let sharedEntityCount: Int  // 表示はしないが将来の重みづけ用に保持
}
```

| Field | 説明 | 制約 |
|---|---|---|
| `from` | Tag.name | `from < to` (Hashable で重複排除) |
| `to` | Tag.name | `to > from` |
| `sharedEntityCount` | 共通 entity 数 | ≥ 1 (空のエッジは作らない) |

### B-3. `MapGraph`

`buildGraph` の戻り値。

```swift
struct MapGraph: Sendable {
    let nodes: [MapNode]
    let edges: [MapEdge]
}
```

### B-4. `RecentActivitySnapshot`

RecentActivityCards の 3 枚分のデータ。AIBrainView の computed property として作成 (永続化なし)。

```swift
struct RecentActivitySnapshot: Sendable {
    let articlesThisWeek: Int                    // 直近 7 日の Article 件数
    let growingTags: [(name: String, count: Int)] // 直近 7 日で記事増加が多いタグ Top3
    let newConnections: [(String, String)]        // 直近 7 日で初出現の entity ペア
}
```

| Field | 説明 | 空値時の表示 |
|---|---|---|
| `articlesThisWeek` | Article.savedAt > 7 日前 の件数 | 0 件: 「今週はまだ吸収していません」 |
| `growingTags` | 上位 3 タグ (件数 desc) | 空配列: 「まだありません」 |
| `newConnections` | 上位 2 entity ペア | 空配列: 「まだありません」 |

---

## State Transitions

本 spec の view state transitions は以下の通り (永続化なし、メモリのみ):

| From | Event | To |
|---|---|---|
| AIBrainView 初期表示 | `onAppear` | `MapGraph` 構築 (空タグなら空グラフ) |
| 任意状態 | `RefreshTrigger.version` 変化 | 再 query + `MapGraph` 再構築 |
| KnowledgeMap 表示中 | `MagnificationGesture` 更新 | `mapScale` 更新 (0.5x-3x clamp) |
| KnowledgeMap 表示中 | `DragGesture` 更新 | `mapOffset` 更新 |
| KnowledgeMap ノードタップ | `NavigationLink(value: TagFilteredDestination(...))` | TagFilteredListView へ遷移 |
| 新タグ Save | `RefreshTrigger.bump` | `MapGraph` 再構築 → 新ノードを `withAnimation(.easeIn(0.4))` で fade-in |

---

## Validation Rules

| Rule | 適用先 | 違反時の挙動 |
|---|---|---|
| `MapNode.id` は空でない | `KnowledgeMapBuilder.buildGraph` | 該当 Tag を skip (precondition) |
| `MapNode.radius` は 40 以上 100 以下 | `buildGraph` | clamp |
| `MapEdge.from < MapEdge.to` | `buildGraph` | swap |
| `MapEdge.sharedEntityCount > 0` | `buildGraph` | 空エッジは生成しない |
| `mapScale` は 0.5 以上 3 以下 | KnowledgeMapView ジェスチャ | clamp |
| `RecentActivitySnapshot.growingTags` は最大 3 件 | computed property | truncate |
| `RecentActivitySnapshot.newConnections` は最大 2 ペア | computed property | truncate |

---

## 永続化なし宣言

本 spec で **新規 SwiftData @Model は追加しない**。`SharedSchema.all` の改修は不要。schema migration は **走らない**。既存 ModelContainer は spec 010 までと同じ構成で起動する。
