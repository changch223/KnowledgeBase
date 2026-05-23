# Data Model: SavedAnswer

**Feature**: spec 043 SavedAnswer
**Phase**: 1 (Design & Contracts)
**Date**: 2026-05-23

---

## 1. SavedAnswer (新規 @Model)

AI Chat の答えを永続化した entity。

### Fields

| Name | Type | Constraint | Initial | 説明 |
|------|------|-----------|---------|------|
| `id` | `UUID` | `@Attribute(.unique)`, non-nil | `UUID()` | 主キー、不変 |
| `question` | `String` | non-nil, 1-2000 chars (spec 上限) | — | ユーザー入力 question、trim 済で保存 |
| `answer` | `String` | non-nil, 50-5000 chars (50 字未満なら auto-save しない) | — | AI 答え本文、UUID strip 済 |
| `citedArticles` | `[Article]` | `@Relationship(deleteRule: .nullify)` | `[]` | 引用 Article、nullify で Article 削除時に link だけ外れ Article 自体は残る |
| `relatedConceptIDs` | `[UUID]` | 0-5 件 (`maxRelatedConcepts = 5`) | `[]` | 引用記事 → 関連 ConceptPage を overlap 数 desc で top 5 |
| `chatSessionID` | `UUID?` | nullable | `nil` | 元 ChatSession.id、ChatSession 削除でも SavedAnswer は残る |
| `isPinned` | `Bool` | — | `false` | ユーザー手動ピン (履歴画面で上位表示) |
| `isStale` | `Bool` | — | `false` | 新記事 ingest → 関連 ConceptPage 更新で true、本 spec では仕込みのみ (WikiLint で別 spec) |
| `savedAt` | `Date` | — | `.now` | 保存日時 (履歴 sort key) |
| `updatedAt` | `Date` | — | `.now` | 更新日時 (pin / stale 化で更新) |
| `savedAutomatically` | `Bool` | — | `true` | true = ChatService hook 経由 auto-save、false = (将来) 手動保存 |

### Computed properties

```swift
extension SavedAnswer {
    /// 履歴 row 用 (40 字 preview + ellipsis)
    var questionPreview: String {
        let trimmed = question.replacingOccurrences(of: "\n", with: " ")
        return trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
    }

    /// 重複判定用 normalized key
    var normalizedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

### Validation rules

- `question`: trim 後 1 char 以上 (空文字は ChatService 側で reject 済、SavedAnswer 側は信用)
- `answer`: 50 chars 以上 (Service.captureIfWorthy で gate)
- `citedArticles`: 2 件以上 (Service.captureIfWorthy で gate)
- `relatedConceptIDs`: 0-5 件 (Service が prefix(5) で制限)
- `chatSessionID`: nullable、後で ChatSession 削除時に nil にはしない (孤立 UUID として残す、ChatSession の existence は別 query で確認)

### State transitions

```
[新規作成] (Service.captureIfWorthy で条件達成)
   isPinned=false, isStale=false, savedAutomatically=true

[Service.setPinned(true)] → isPinned=true, updatedAt=.now
[Service.setPinned(false)] → isPinned=false, updatedAt=.now
[Service.delete] → context.delete + save (Article は残る、ChatSession 参照は孤立)

[KnowledgeExtractionService extract hook]
   引用記事 → ConceptPage 更新 → SavedAnswer.isStale=true, updatedAt=.now (本 spec UI 影響なし)

[ConceptPageStore.merge]
   source.id を含む relatedConceptIDs → target.id に置換 (top 5 制限維持)
```

### Indices

- `id` (unique attribute)
- `savedAt` desc は @Query sort で活用、in-memory sort で十分 (100 件規模)
- `normalizedQuestion` は重複判定で fetch 全件 → in-memory linear scan (30-100 件規模で問題なし)

---

## 2. SharedSchema (改修)

`SharedSchema.swift` の `static var all: Schema` に `SavedAnswer.self` を追加。SwiftData lightweight migration 自動。

```swift
Schema([
    Article.self,
    // ... 既存 17 @Model
    ConceptPage.self,                      // spec 042
    SavedAnswer.self,                      // spec 043 ★ 追加
])
```

---

## 3. Article (既存、変更なし)

`SavedAnswer.citedArticles` の参照先。Article 側に `var savedAnswers: [SavedAnswer]?` などの inverse は **追加しない** (spec 042 ConceptPage と同方針、片方向)。

理由:
- 既存 spec 全への regression リスク回避
- Article から派生 SavedAnswer の取得は `FetchDescriptor<SavedAnswer>` + in-memory filter で実現 (頻度低、性能影響小)

---

## 4. ChatMessage / ChatSession (既存、変更なし)

`chatSessionID: UUID?` で弱結合参照。@Relationship は使わず ChatSession 削除でも SavedAnswer は孤立 UUID として残る (履歴保護)。

---

## 5. ConceptPage (既存、spec 042、変更なし)

`SavedAnswer.relatedConceptIDs` の参照先。SavedAnswer ↔ ConceptPage は弱結合 (ID 配列)、ConceptPage 削除時に SavedAnswer.relatedConceptIDs から孤立 ID を掃除するロジックは **本 spec では実装しない** (出現頻度低、UI 表示時に in-memory で existence check)。

ConceptPageStore.merge で source.id → target.id の置換のみ実装 (R6、data integrity)。

---

## 6. Transient (non-persisted) 型

### `SavedAnswerDetailDestination` (Hashable, transient)

```swift
struct SavedAnswerDetailDestination: Hashable {
    let id: UUID
}
```

NavigationStack の navigationDestination 用、@Model 直接 navigation value を避ける (spec 042 ConceptPageDetailDestination と同パターン)。

### `SavedAnswerListByConceptDestination` (Hashable, transient)

```swift
struct SavedAnswerListByConceptDestination: Hashable {
    let conceptPageID: UUID
}
```

「+N すべて見る」遷移先で、特定 ConceptPage の SavedAnswer フィルター済 list を表示する画面用。

### `ScoredSavedAnswer` (P3 検索結果)

```swift
struct ScoredSavedAnswer: Identifiable {
    var id: UUID { savedAnswer.id }
    let savedAnswer: SavedAnswer
    let score: Int
}
```

SearchService.searchSavedAnswers の戻り値。

---

## 7. Relationship 図

```
ChatSession (既存)        ←─── SavedAnswer.chatSessionID (UUID?, 弱結合、nullable)
                          (ChatSession 削除でも SavedAnswer 残る)

ChatMessage (既存)        ─── (関係なし、SavedAnswer は ChatMessage を直接参照しない)

Article (既存)            ←─ @Relationship(.nullify) ─ SavedAnswer.citedArticles
                          (片方向、Article 側 inverse なし)
                                  │
                                  └─ Article 削除 → citedArticles から除外

ConceptPage (既存、spec 042) ←─ SavedAnswer.relatedConceptIDs (UUID 配列、弱結合)
                                  (ConceptPage merge → source.id を target.id に置換、ConceptPageStore.merge で対応)

SavedAnswer                ── 新規 @Model
    ├─ question / answer
    ├─ citedArticles (@Relationship.nullify)
    ├─ relatedConceptIDs: [UUID]
    ├─ chatSessionID: UUID?
    ├─ isPinned / isStale / savedAt / updatedAt / savedAutomatically
```

- SavedAnswer ↔ Article: 1:N (片方向 to-many)
- SavedAnswer ↔ ConceptPage: N:N (ID 配列で疎結合)
- SavedAnswer ↔ ChatSession: 1:1 (nullable UUID 参照、孤立可)
