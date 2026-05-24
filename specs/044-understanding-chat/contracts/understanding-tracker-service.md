# Contract: UnderstandingTrackerService

**Feature**: spec 044 Understanding Chat
**Type**: @MainActor Protocol + Default 実装
**File**: `KnowledgeTree/Services/UnderstandingTrackerService.swift`

## Protocol

```swift
@MainActor
protocol UnderstandingTrackerServiceProtocol: AnyObject {
    func recordUnderstood(card: UnderstandingCard) async throws
    func recordNeedMore(card: UnderstandingCard) async throws
    func recordDismissed(card: UnderstandingCard) async throws
    func recordOpenedChat(card: UnderstandingCard) async throws
}
```

## Default 実装

```swift
@MainActor
final class DefaultUnderstandingTrackerService: UnderstandingTrackerServiceProtocol {
    private let context: ModelContext
    private weak var graphService: GraphTraversalServiceProtocol?    // optional, spec 040
    private weak var refreshTrigger: RefreshTrigger?
    private let now: () -> Date
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "tracker")

    init(
        context: ModelContext,
        graphService: GraphTraversalServiceProtocol? = nil,
        refreshTrigger: RefreshTrigger? = nil,
        now: @escaping () -> Date = { .now }
    )
}
```

## Algorithm: recordUnderstood

```text
1. UnderstandingInteraction insert (action="understood")
2. 対象 ConceptPage 解決:
   - kind=.conceptPage → [page.id]
   - kind=.savedAnswer → answer.relatedConceptIDs (max 5)
3. 各 ConceptPage に対し:
   a. userUnderstanding += 1、clamp [0, 5] で永続化
4. 1-hop 波及 (graphService non-nil 時):
   a. 各 ConceptPage.id について graphService.neighborConceptIDs(for:hops:1)
   b. neighbor ConceptPage に対し UnderstandingInteraction insert (action="propagated")
   c. propagated 累積件数で userUnderstanding +1 (累積 2 件 = +1、round-half-up)
      - 実装: 該当 neighbor の既存 propagated 件数を fetch、(現在数 + 1) ÷ 2 を floor、前 floor からの差分を userUnderstanding に加算
5. context.save()
6. refreshTrigger?.bump()
```

## Algorithm: recordNeedMore

```text
1. UnderstandingInteraction insert (action="needMore")
2. userUnderstanding 不変
3. refreshTrigger?.bump()
```

## Algorithm: recordDismissed

```text
1. UnderstandingInteraction insert (action="dismissed")
2. userUnderstanding 不変
3. refreshTrigger?.bump()
   (次回 SurfaceService.surfaceTopCards で dismissedIDs から -10 補正される)
```

## Algorithm: recordOpenedChat

```text
1. UnderstandingInteraction insert (action="openedChat")
2. userUnderstanding 不変
3. refreshTrigger?.bump() しない (頻繁なので UI 振動回避)
```

## Performance

- DB 操作: insert 1-2 件 + ConceptPage update 1-10 件 (1-hop)、< 200ms
- graph fetch: 5-10 neighbor node 想定、< 500ms
- 全体 2 秒以内 (SC-004)

## Test Coverage (8 ケース)

| # | ケース | 期待 |
|---|------|------|
| 1 | recordUnderstood で ConceptPage A の userUnderstanding=0 → 1 | DB 反映 + interaction 1 件 |
| 2 | userUnderstanding=5 で recordUnderstood | clamp 5 維持、interaction は記録 |
| 3 | graphService non-nil で 1-hop 2 neighbor あり、recordUnderstood 2 回 | neighbor userUnderstanding += 1 (累積 2 件) |
| 4 | recordNeedMore で userUnderstanding 不変 | interaction "needMore" 記録のみ |
| 5 | recordDismissed → SurfaceService で当該 card が priority -10 | 後続 surface で score 補正 |
| 6 | SavedAnswer 経由 recordUnderstood (relatedConceptIDs=[A,B]) | A/B の userUnderstanding 各 +1 |
| 7 | graphService=nil で recordUnderstood | 本体 +1 のみ、波及スキップ、log warning |
| 8 | 同 ConceptPage に recordUnderstood 連打 (6 回) | userUnderstanding=5 で停止 (clamp) |

## Constitution Compliance

- I (privacy): 全 SwiftData local、外部送信ゼロ ✅
- V (calm UX): record 後 UI 通知ゼロ (refreshTrigger.bump() のみで自然反映)、効果音なし ✅
- VI (architecture): Protocol + Default + Test Mock = 2 箇所抽象化 ✅

## DI

`ServiceContainer.understandingTrackerService: UnderstandingTrackerServiceProtocol?` + bootstrap で graphService inject (optional)。
