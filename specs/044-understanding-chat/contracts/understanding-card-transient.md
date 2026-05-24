# Contract: UnderstandingCard (transient struct)

**Feature**: spec 044 Understanding Chat
**Type**: SwiftUI transient (not @Model)
**File**: `KnowledgeTree/Models/UnderstandingInteraction.swift` (同ファイル末尾)

## Definition

```swift
struct UnderstandingCard: Identifiable, Hashable {
    let id: UUID                       // 元 entity.id
    let kind: UnderstandingCardKind
    let priorityScore: Int             // 内部、UI 非表示
    let label: UnderstandingCardLabel
    let lastInteractedAt: Date?
}

enum UnderstandingCardKind: Hashable {
    case conceptPage(ConceptPage)
    case savedAnswer(SavedAnswer)
}

enum UnderstandingCardLabel: String, Hashable, CaseIterable {
    case newKnowledge, needsUpdate, shallow, deepDive, review
}
```

## Invariants

- `id` = wrapped entity の `id` と一致 (`UnderstandingCard(...).id == conceptPage.id`)
- `priorityScore` は SurfaceService が計算、UI に直接出さない
- `label` は UI に badge として表示、xcstrings 経由で日本語ラベル化
- `lastInteractedAt` は nil の場合「未操作」UI、非 nil は SavedAtFormatter.relative で表示
- transient struct なので毎回再構築、永続化しない

## Static Constructors

```swift
extension UnderstandingCard {
    static func fromConceptPage(_ page: ConceptPage, label: UnderstandingCardLabel = .deepDive, lastInteractedAt: Date? = nil) -> UnderstandingCard
    static func fromSavedAnswer(_ answer: SavedAnswer, label: UnderstandingCardLabel = .needsUpdate, lastInteractedAt: Date? = nil) -> UnderstandingCard
}
```

ConceptPageDetailView の「学習する」Button (P2 US9) や test fixture で利用。

## Computed Properties

```swift
extension UnderstandingCard {
    var titleText: String              // ConceptPage.name or SavedAnswer.question.prefix(80)
    var deepDiveTitle: String          // "\(titleText) を深掘り"
    var kindString: String             // "conceptPage" or "savedAnswer" (xcstrings / a11y id 用)
}
```

## Hashable Conformance

`Identifiable` + `Hashable` で SwiftUI `ForEach(cards, id: \.id)` + `navigationDestination(for: UnderstandingCard.self)` に直接渡せる。

```swift
extension UnderstandingCard: Hashable {
    static func == (lhs: UnderstandingCard, rhs: UnderstandingCard) -> Bool {
        lhs.id == rhs.id && lhs.label == rhs.label && lhs.lastInteractedAt == rhs.lastInteractedAt
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(label)
    }
}
```

## Test Coverage

- `UnderstandingCardSurfaceServiceTests`: 各 label 付与パターン + priorityScore 期待値
- UI test: NavigationLink push 動作 (UnderstandingTabUITests)

## Notes

- SwiftData @Model を struct 内に保持するが、UI 表示時間のみ生存 (List scroll で fetch されたインスタンス) なので detach 問題なし
- Surface ロジック毎回再構築するので、ConceptPage 更新 (例: userUnderstanding +1) は次回 `surfaceTopCards` 呼び出しで自動反映
