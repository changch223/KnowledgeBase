# Contract: `SavedAnswer` @Model

**File**: `KnowledgeTree/Models/SavedAnswer.swift` (新規、~80 行)
**Type**: SwiftData persistent model

## Purpose

AI Chat (spec 021) の答えを永続化し、引用記事 + 関連 ConceptPage (spec 042) と結びつける。Compound Moment 条件 1 の実体。

## Public API

```swift
import Foundation
import SwiftData

@Model
final class SavedAnswer {
    @Attribute(.unique) var id: UUID
    var question: String
    var answer: String

    @Relationship(deleteRule: .nullify)
    var citedArticles: [Article] = []

    var relatedConceptIDs: [UUID]
    var chatSessionID: UUID?
    var isPinned: Bool
    var isStale: Bool
    var savedAt: Date
    var updatedAt: Date
    var savedAutomatically: Bool

    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        citedArticles: [Article] = [],
        relatedConceptIDs: [UUID] = [],
        chatSessionID: UUID? = nil,
        isPinned: Bool = false,
        isStale: Bool = false,
        savedAt: Date = .now,
        updatedAt: Date = .now,
        savedAutomatically: Bool = true
    )
}

extension SavedAnswer {
    var questionPreview: String { get }     // 40 字 + 「…」
    var normalizedQuestion: String { get }  // trim 済
}
```

## Behavior

- `init` 時 `isPinned=false, isStale=false, savedAutomatically=true` をデフォルト
- `questionPreview` は履歴 row / セクション内 row で 1 行 preview 用
- `normalizedQuestion` は重複判定で使用 (空白 trim 後完全一致、case sensitive)

## Validation

- question: trim 後 1 char 以上 (ChatService 側で空文字 reject、SavedAnswer 側は信用)
- answer: 50 chars 以上 (Service.captureIfWorthy で gate)
- citedArticles: 2 件以上 (Service.captureIfWorthy で gate)
- relatedConceptIDs: 0-5 件 (Service が prefix(5) で制限)

## SwiftData Schema Integration

- `SharedSchema.all` に `SavedAnswer.self` 追加で全 ModelContainer 構築箇所 (main app + Share/Safari Extension + Tests) で自動利用可能
- lightweight migration: 新規 @Model 追加なので既存 store からの schema 進化は不要
- Tests は `ModelContainer(for: SharedSchema.all, configurations: .init(isStoredInMemoryOnly: true))` で構築

## Acceptance Criteria

- [x] `SavedAnswer` を SwiftData store に save / fetch できる
- [x] `citedArticles` で Article 削除時に SavedAnswer 側が nullify される (Article は残る)
- [x] `chatSessionID = nil` のまま保存可能 (履歴のみの SavedAnswer も成立)
- [x] `questionPreview` / `normalizedQuestion` が in-memory で計算可能
- [x] 既存全テスト suite が SharedSchema 拡張後も PASS する
