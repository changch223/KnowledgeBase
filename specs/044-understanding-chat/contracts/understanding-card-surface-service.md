# Contract: UnderstandingCardSurfaceService

**Feature**: spec 044 Understanding Chat
**Type**: @MainActor Protocol + Default 実装
**File**: `KnowledgeTree/Services/UnderstandingCardSurfaceService.swift`

## Protocol

```swift
@MainActor
protocol UnderstandingCardSurfaceServiceProtocol: AnyObject {
    func surfaceTopCards(limit: Int) async -> [UnderstandingCard]
    func surfaceAllCards() async -> [UnderstandingCard]
}
```

## Default 実装

```swift
@MainActor
final class DefaultUnderstandingCardSurfaceService: UnderstandingCardSurfaceServiceProtocol {
    private let context: ModelContext
    private let now: () -> Date          // テスト用注入、default `{ .now }`
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "surface")

    init(context: ModelContext, now: @escaping () -> Date = { .now })

    func surfaceTopCards(limit: Int) async -> [UnderstandingCard]
    func surfaceAllCards() async -> [UnderstandingCard]
}
```

## Surface Algorithm

```text
1. context から fetch:
   - 全 ConceptPage
   - 全 SavedAnswer
   - 過去 60 日 UnderstandingInteraction (lastInteractedMap + dismissedIDs 計算用)

2. ConceptPage の dictionary 化 + Article.savedAt 最新マップ作成

3. 各 ConceptPage に対し label 判定 (上から順、最初に match した label 採用):
   - newKnowledge (score 100): createdAt >= now - 24h && userUnderstanding == 0
   - shallow      (score 80) : userUnderstanding <= 1 && 関連記事最新 savedAt >= now - 7d
   - deepDive     (score 60) : userUnderstanding in [2,3] && isFollowing == true
   - review       (score 40) : lastInteractedAt == nil || lastInteractedAt < now - 30d
   (該当しない ConceptPage は surface 候補外)

4. 各 SavedAnswer に対し label 判定:
   - needsUpdate  (score 90): isStale == true
   - newKnowledge (score 70): isStale == false && savedAt >= now - 24h && !relatedConceptIDs.isEmpty
   (該当しない SavedAnswer は surface 候補外)

5. dismissed 既往 (`UnderstandingInteraction.action == "dismissed"` の targetID set) で priorityScore -10

6. priorityScore desc + tiebreak (savedAt / createdAt desc) で sort

7. surfaceTopCards: prefix(limit) で 5 件
   surfaceAllCards: 全件返却 (paginated は呼び出し側 LazyVStack で)

8. UnderstandingCard transient struct に wrap して return
```

## Performance

- ConceptPage fetch: O(N) where N = 全件 (200 件想定、< 50ms)
- SavedAnswer fetch: O(M) where M = 全件 (100 件想定、< 30ms)
- UnderstandingInteraction fetch: 過去 60 日に限定、< 100ms
- 全体 1 秒以内 (SC-001)

## Test Coverage (10 ケース)

| # | ケース | 期待 |
|---|------|------|
| 1 | ConceptPage / SavedAnswer 共に 0 件 | `[]` 返却、UI 側で empty state |
| 2 | 24h 以内新規 ConceptPage 1 件 + userUnderstanding=0 | label=newKnowledge、最上位 |
| 3 | isStale な SavedAnswer 1 件 | label=needsUpdate、score 90 |
| 4 | userUnderstanding=0 + 関連記事 3 日前保存 | label=shallow、score 80 |
| 5 | dismissed 既往 ConceptPage | priorityScore = score - 10 で下位 |
| 6 | 候補 10 件で surfaceTopCards(limit=5) | 5 件返却 (score desc order) |
| 7 | ConceptPage 3 + SavedAnswer 2 を score 混在 sort | 期待順位通り |
| 8 | 全 ConceptPage userUnderstanding=5 + 30d 以内触れている | surface 候補 0 件、empty 返却 |
| 9 | 各 label の付与正確性 (5 種を 1 つずつ用意) | 各 label が正しく付く |
| 10 | 同 score の 2 件は savedAt desc tiebreak | 新しい方が先 |

## Constitution Compliance

- I (privacy): SwiftData fetch のみ、外部送信ゼロ ✅
- V (calm UX): score / label は内部、UI は label 日本語名 + 5 色 badge のみ ✅
- VI (architecture): Protocol 抽象 + Default 実装 + テスト 1 Mock = 2 箇所 ✅
- パフォーマンス: 1 秒以内 (SC-001) ✅

## DI

`ServiceContainer.understandingCardSurfaceService: UnderstandingCardSurfaceServiceProtocol?` に登録、`KnowledgeTreeApp.bootstrap` で構築 + inject。
