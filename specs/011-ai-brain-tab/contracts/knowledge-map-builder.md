# Contract: KnowledgeMapBuilder

**Created**: 2026-05-05
**File**: `KnowledgeTree/Services/KnowledgeMapBuilder.swift`

## 責務

`Tag` 配列を入力に受け、KnowledgeMap 表示用の `MapGraph` (ノード + エッジ + 力学的安定座標) を返す純粋関数モジュール。SwiftUI / UI 状態への依存ゼロ。決定論性のためテスト用に固定 seed を受ける版を提供する。

## API

```swift
enum KnowledgeMapBuilder {
    /// Public — production 用。canvasSize は KnowledgeMapView の GeometryReader から渡される。
    /// seed なし呼び出しは Date().timeIntervalSince1970 ベースで毎回違う配置になる。
    static func buildGraph(
        tags: [Tag],
        canvasSize: CGSize,
        iterations: Int = 8
    ) -> MapGraph

    /// Public — テスト用。固定 seed で決定論的レイアウト生成。
    static func buildGraph(
        tags: [Tag],
        canvasSize: CGSize,
        iterations: Int,
        seed: UInt64
    ) -> MapGraph

    /// Internal (testable) — 1 反復だけ進める純粋関数。テストで反復ごとの位置を観察。
    static func step(
        nodes: [MapNode],
        edges: [MapEdge],
        canvasSize: CGSize,
        params: ForceParams
    ) -> [MapNode]
}

struct ForceParams: Sendable {
    let repulsion: Double      // ノード間反発係数 (default: 1500.0)
    let spring: Double         // エッジバネ係数 (default: 0.05)
    let centerPull: Double     // 中心引力係数 (default: 0.02)
    let damping: Double        // 速度減衰 (default: 0.85)
    let idealEdgeLength: Double // バネの自然長 (default: 120.0)

    static let `default` = ForceParams(
        repulsion: 1500.0,
        spring: 0.05,
        centerPull: 0.02,
        damping: 0.85,
        idealEdgeLength: 120.0
    )
}
```

## 入力契約

| 入力 | 型 | 制約 |
|---|---|---|
| `tags` | `[Tag]` | 重複なし (Tag.name unique で保証)。空配列許容。 |
| `canvasSize` | `CGSize` | width / height 共に > 0。≤ 0 の場合は precondition failure。 |
| `iterations` | `Int` | 1 以上 50 以下。clamp で対応。 |
| `seed` | `UInt64` (テスト版のみ) | 任意の 64bit 値。 |

## 出力契約

`MapGraph` (data-model.md B-3 参照) を返す。

- `nodes.count == tags.count` (空 tag 入力時は 0)
- `nodes` の position は `(0...canvasSize.width, 0...canvasSize.height)` 範囲内に clamp
- `edges` は重複排除済 (`Set<MapEdge>` 経由) で順序保証なし。表示順影響なし。
- 純粋関数: 同一 (tags 内容, canvasSize, iterations, seed) で同一 `MapGraph` を返す (シード版)

## ノード位置計算アルゴリズム

```
1. 初期位置: 各ノードを canvas 中心 ± random offset (seeded RandomNumberGenerator)
2. 各反復 (iterations 回):
   a. 反発力: 全ノードペアで F_rep = repulsion / distance^2 を相互に push
   b. バネ力: 各エッジで F_spring = spring * (distance - idealEdgeLength) で 引/押し
   c. 中心引力: 各ノードを canvas 中心へ F_center = centerPull * distance で pull
   d. 速度に dt=1.0 を適用、damping を掛けて position 更新
   e. canvas 境界内に clamp
3. 最終 position を MapNode に書き込み返す
```

## エッジ計算アルゴリズム

```
1. 各 tag に対し entitySet[tag.name] = Set<String>() を初期化
2. 各 tag.articles[i].extractedKnowledge?.entities を走査し、name.lowercased().trim() を entitySet に追加
3. 全 (tagA, tagB) ペア (a < b) で:
   a. let intersection = entitySet[tagA].intersection(entitySet[tagB])
   b. intersection.isEmpty == false なら MapEdge(from: a, to: b, sharedEntityCount: intersection.count)
4. 戻り値の edges として返す
```

## ノードサイズ計算

```
radius = min(100, max(40, log2(Double(tag.articles.count) + 1) * 20))
```

| articles.count | radius |
|---|---|
| 0 | 40pt |
| 1 | 40pt (log2(2)*20=20、min 40 で clamp) |
| 3 | 40pt (log2(4)*20=40) |
| 7 | 60pt (log2(8)*20=60) |
| 15 | 80pt (log2(16)*20=80) |
| 31 | 100pt (log2(32)*20=100、max 100) |
| 100 | 100pt (clamp) |

## テスト

`KnowledgeTreeTests/KnowledgeMapBuilderTests.swift`:

| Test | 検証 |
|---|---|
| `testEmptyTagsReturnsEmptyGraph` | tags=[] → nodes=[], edges=[] |
| `testSingleTagSingleNode` | 1 タグ → 1 ノード、edges=[] |
| `testTwoTagsSharedEntity` | 共通 entity → 1 エッジ |
| `testTwoTagsNoSharedEntity` | 共通 entity なし → edges=[] |
| `testEdgeIsAlphabeticallyNormalized` | tagB / tagA → MapEdge(from: "tagA", to: "tagB") |
| `testEdgeDeduplication` | 同じペアが 2 経路で発見されても 1 エッジ |
| `testRadiusClamping` | articles.count=0 → radius=40、count=200 → radius=100 |
| `testNodePositionsWithinCanvas` | 全ノード position が canvasSize 内 |
| `testDeterministicWithSeed` | 同 seed で 2 回呼び出して同じ MapGraph |
| `testHundredTagsPerformance` | 100 タグで buildGraph が 200ms 以内 (XCTest measure) |
| `testStepReducesEnergy` | 1 step 後の総エネルギー (運動量) が 0 step 時より低い (収束方向) |

## 副作用

なし。純粋関数。

- ファイル I/O なし
- ネットワーク I/O なし
- `Tag` モデルへの書き込みなし (`@Query` から渡される `Tag` を read-only で参照)
- ログ出力なし

## 実装上の注意

- `Tag.articles` の lazy load を避けるため、buildGraph 内で `tag.articles.compactMap { $0.extractedKnowledge?.entities ?? [] }` を 1 回だけ実行 (forced load)。SwiftData faulting で N+1 が発生しないよう、@MainActor で実行されることを前提とする。
- `@MainActor` 注釈は **付けない** (純粋関数として data-only に保つ)。呼び出し側 (AIBrainView) が MainActor から呼ぶ責務を持つ。
- Random 用に `SystemRandomNumberGenerator` を default 使用、テストは `SeededRandomNumberGenerator` (新規 internal struct) を使用。
