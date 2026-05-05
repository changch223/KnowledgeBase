# Contract: RecentActivityCards

**Created**: 2026-05-05
**File**: `KnowledgeTree/Views/RecentActivityCards.swift`

## 責務

AI ブレインタブの Section 3。直近 7 日の活動を 3 枚カード横スクロールで表示。

- カード A: 今週吸収数
- カード B: 育ったテーマ Top3
- カード C: 新しい繋がり 上位 2 ペア

## 構造

```swift
struct RecentActivityCards: View {
    private let sevenDaysAgo: Date

    init(now: Date = Date()) {
        self.sevenDaysAgo = now.addingTimeInterval(-7 * 86400)
    }

    @Query private var allTags: [Tag]
    @Query private var allEntities: [KnowledgeEntity]

    private var snapshot: RecentActivitySnapshot {
        RecentActivitySnapshotBuilder.build(
            tags: allTags,
            entities: allEntities,
            sevenDaysAgo: sevenDaysAgo
        )
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                cardThisWeek(count: snapshot.articlesThisWeek)
                cardGrowingTags(snapshot.growingTags)
                cardNewConnections(snapshot.newConnections)
            }
            .padding(.horizontal)
        }
        .accessibilityIdentifier("aibrain.recent_activity")
    }

    private func cardThisWeek(count: Int) -> some View { ... }
    private func cardGrowingTags(_ tags: [(name: String, count: Int)]) -> some View { ... }
    private func cardNewConnections(_ pairs: [(String, String)]) -> some View { ... }
}
```

## 入力契約

- `now: Date = Date()` (テストで時刻注入可能)
- `@Query<Tag>` と `@Query<KnowledgeEntity>` で全件取得 (Article は Tag の relationship 経由)

## カード仕様

### カード A: 今週吸収数

| 状態 | 表示 |
|---|---|
| `articlesThisWeek > 0` | 「今週 **N** 件 新たに吸収」 |
| `articlesThisWeek == 0` | 「今週はまだ吸収していません」 |

### カード B: 育ったテーマ

| 状態 | 表示 |
|---|---|
| `growingTags.isEmpty == false` | 「最近育ったテーマ」+ Top3 タグ名を bullet (`・`) で 3 行 |
| `growingTags.isEmpty` | 「最近育ったテーマ」+ 「まだありません」 |

### カード C: 新しい繋がり

| 状態 | 表示 |
|---|---|
| `newConnections.count >= 1` | 「新しい繋がり」+ 「○○ ↔ ○○」を 1〜2 行 |
| `newConnections.isEmpty` | 「新しい繋がり」+ 「まだありません」 |

## RecentActivitySnapshotBuilder

純粋関数モジュール (テスト容易化):

```swift
enum RecentActivitySnapshotBuilder {
    static func build(
        tags: [Tag],
        entities: [KnowledgeEntity],
        sevenDaysAgo: Date
    ) -> RecentActivitySnapshot
}
```

**articlesThisWeek**: 全タグの article 重複排除集合のうち、`savedAt > sevenDaysAgo` の件数

**growingTags**: 各タグについて、article のうち `savedAt > sevenDaysAgo` の件数を集計し、件数 desc で Top3 (件数 0 のタグは除外)

**newConnections**:
1. 全 entity を name (lowercased + trim) でグループ化
2. グループの中で `min(article.savedAt)` を計算
3. `min > sevenDaysAgo` のグループのみ抽出 (= 7 日以内に初出現)
4. salience desc で上位 2 つを取り、`(name1, name2)` ペアとして返す

## アクセシビリティ

| 要素 | accessibilityIdentifier | VoiceOver Label |
|---|---|---|
| Section root | `aibrain.recent_activity` | — |
| Card A | `aibrain.recent.card.this_week` | "今週の吸収: N 件" |
| Card B | `aibrain.recent.card.growing` | "最近育ったテーマ: ..." |
| Card C | `aibrain.recent.card.connections` | "新しい繋がり: ..." |

## ローカライゼーション

`Localizable.xcstrings`:

- `"今週 %lld 件 新たに吸収"`
- `"今週はまだ吸収していません"`
- `"最近育ったテーマ"`
- `"新しい繋がり"`
- `"まだありません"`
- `"今週の吸収: %lld 件"` (VoiceOver)

## エラーハンドリング

- 全てのカードが「まだありません」状態でも view は崩れない (calm UX)
- 7 日 filter は `sevenDaysAgo` を init で確定するため、view 表示中の時刻変化には反応しない (TabView 切替で再 init される)

## 副作用

なし。read-only。

## テスト

`KnowledgeTreeTests/RecentActivitySnapshotBuilderTests.swift`:

| Test | 検証 |
|---|---|
| `testEmptyTagsReturnsZeroSnapshot` | tags=[] → all 0/empty |
| `testArticlesThisWeekOnlyCountsRecent` | 7 日以内 / 8 日前混合 → 7 日以内のみ count |
| `testGrowingTagsReturnsTop3DescendingByCount` | 5 タグ各々違う count → Top3 |
| `testGrowingTagsEmptyWhenNoRecentArticles` | 全 article が 8 日以上前 → growingTags=[] |
| `testNewConnectionsOnlyReturnsFirstAppearance` | 旧 entity と新 entity 混在 → 新のみ |
| `testNewConnectionsLimitedTo2Pairs` | 5 つの新 entity → 2 ペア (上位 4 つ) |
| `testEntityNameNormalization` | "OpenAI" / "openai" / " OpenAI " → 同一とみなす |

## 依存

- `Tag`, `KnowledgeEntity`, `Article` (`@Query`)
- `RecentActivitySnapshot` (data-model.md B-4)
- `RecentActivitySnapshotBuilder` (本 spec で新規)
