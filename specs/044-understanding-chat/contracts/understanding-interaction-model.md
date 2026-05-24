# Contract: UnderstandingInteraction @Model

**Feature**: spec 044 Understanding Chat
**Type**: SwiftData @Model (新規)
**File**: `KnowledgeTree/Models/UnderstandingInteraction.swift`

## Definition

```swift
@Model
final class UnderstandingInteraction {
    @Attribute(.unique) var id: UUID
    var targetKind: String
    var targetID: UUID
    var action: String
    var occurredAt: Date

    init(id: UUID = UUID(), targetKind: String, targetID: UUID, action: String, occurredAt: Date = .now)
}

extension UnderstandingInteraction {
    enum Kind: String { case conceptPage, savedAnswer, article }
    enum Action: String { case understood, needMore, openedChat, dismissed, propagated }
    var kindEnum: Kind? { Kind(rawValue: targetKind) }
    var actionEnum: Action? { Action(rawValue: action) }
}
```

## Invariants

- `id` MUST be unique (SwiftData `@Attribute(.unique)`)
- `targetKind` MUST be one of `Kind.allCases.rawValue`
- `action` MUST be one of `Action.allCases.rawValue`
- `targetID` SHOULD reference an existing `ConceptPage.id` / `SavedAnswer.id` / `Article.id` at insert time. 削除後の孤立残存は許容。
- `occurredAt` MUST default to `.now` when not specified

## Relationships

None. 弱結合 (targetID 文字列参照) のみで、参照先 entity 削除でも自動 cascade しない。

## Schema Registration

`SharedSchema.swift` に `UnderstandingInteraction.self` を追加 (1 行)。lightweight migration で既存ストアに自動追加。

## pbxproj

`UnderstandingInteraction.swift` を以下 3 target に登録:
- `KnowledgeTree` (main, auto-sync)
- `ShareExtension` (PBXBuildFile + PBXFileReference + Sources entries 手動追加)
- `SafariExtension` (同上)

spec 042 ConceptPage / spec 043 SavedAnswer と同手順。

## Usage Patterns

```swift
// 行動記録
let interaction = UnderstandingInteraction(
    targetKind: UnderstandingInteraction.Kind.conceptPage.rawValue,
    targetID: page.id,
    action: UnderstandingInteraction.Action.understood.rawValue
)
context.insert(interaction)
try context.save()

// dismissed 既往 fetch
let descriptor = FetchDescriptor<UnderstandingInteraction>(
    predicate: #Predicate { $0.action == "dismissed" }
)
let dismissed = try context.fetch(descriptor)
let dismissedIDs = Set(dismissed.map(\.targetID))
```

## Test Coverage

- `UnderstandingTrackerServiceTests`: insert + 各 action / targetKind 組合せの正常系
- `UnderstandingCardSurfaceServiceTests`: dismissed 既往読み出し + surface 補正

## Migration / Backward Compatibility

- 新規 @Model 追加のみ、既存 schema 改変なし → lightweight migration 自動
- 既存ユーザーは初回起動で空 UnderstandingInteraction store + LastOpenedStore migration (UserDefaults キーで 1 回限り `.learning` default 設定)
