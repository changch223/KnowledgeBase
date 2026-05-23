# Contract: `ConceptPageStore`

**File**: `KnowledgeTree/Services/ConceptPageStore.swift` (新規、~150 行)
**Type**: `@MainActor final class` ConceptPage CRUD + 編集操作

## Purpose

ConceptPage の編集 (rename / merge / delete / setFollowing) を提供。spec 024 TagStore +
spec 041 GraphNodeStore と同 API 表面。バリデーション + 関連参照クリーンアップ +
RefreshTrigger 通知を 1 箇所に集約。

## Public API

```swift
import Foundation
import SwiftData

@MainActor
final class ConceptPageStore {
    enum ConceptPageStoreError: LocalizedError {
        case emptyName
        case nameTooLong
        case duplicateInCategory
        case sameSourceTarget

        var errorDescription: String? {
            switch self {
            case .emptyName: String(localized: "ConceptPageStore.error.emptyName")
            case .nameTooLong: String(localized: "ConceptPageStore.error.nameTooLong")
            case .duplicateInCategory: String(localized: "ConceptPageStore.error.duplicateInCategory")
            case .sameSourceTarget: String(localized: "ConceptPageStore.error.sameSourceTarget")
            }
        }
    }

    init(context: ModelContext, refreshTrigger: RefreshTrigger)

    /// rename 後の ConceptPage を返す。isStale=true 設定で再合成 trigger。
    @discardableResult
    func rename(_ conceptPage: ConceptPage, to newName: String) throws -> ConceptPage

    /// source を target に統合し、source を削除。target.isStale=true で再合成。
    /// - relatedArticles: union (ID 重複除外)
    /// - relatedConceptIDs: union、self-ref 除外
    /// - nameAliases: union + source.name 追加
    /// - userUnderstanding: max
    /// - isFollowing: OR
    func merge(source: ConceptPage, into target: ConceptPage) throws

    /// ConceptPage 削除、他 ConceptPage.relatedConceptIDs から ID 除去。
    /// Article は @Relationship.nullify で残る。
    func delete(_ conceptPage: ConceptPage) throws

    /// pin (フォロー) 状態を変更。
    func setFollowing(_ conceptPage: ConceptPage, isFollowing: Bool) throws
}
```

## Behavior

### `rename(_:to:)`

```
1. trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
2. guard !trimmed.isEmpty else throw .emptyName
3. guard trimmed.count <= 30 else throw .nameTooLong
4. 同 categoryRaw 内で trimmed.lowercased() に一致する別 ConceptPage が存在
   → throw .duplicateInCategory (自分自身は除外)
5. conceptPage.name = trimmed
6. conceptPage.isStale = true   // 名前変更で再合成
7. conceptPage.updatedAt = .now
8. try context.save()
9. refreshTrigger.bump()
10. return conceptPage
```

### `merge(source:into:)`

```
1. guard source.id != target.id else throw .sameSourceTarget
2. for article in source.relatedArticles
       where !target.relatedArticles.contains(where: { $0.id == article.id }):
       target.relatedArticles.append(article)
3. target.relatedConceptIDs = Array(Set(
       target.relatedConceptIDs + source.relatedConceptIDs
   )).filter { $0 != target.id }
4. target.nameAliases = Array(Set(
       target.nameAliases + [source.name] + source.nameAliases
   ))
5. target.userUnderstanding = max(target.userUnderstanding, source.userUnderstanding)
6. target.isFollowing = target.isFollowing || source.isFollowing
7. target.isStale = true
8. target.updatedAt = .now
9. context.delete(source)
10. try context.save()
11. refreshTrigger.bump()
```

### `delete(_:)`

```
1. let descriptor = FetchDescriptor<ConceptPage>()
2. let all = try context.fetch(descriptor)
3. for other in all where other.id != conceptPage.id {
       other.relatedConceptIDs.removeAll { $0 == conceptPage.id }
   }
4. context.delete(conceptPage)
5. try context.save()
6. refreshTrigger.bump()
```

注意: `relatedArticles` の Article は @Relationship deleteRule: .nullify で自動的に
ConceptPage 参照を外す。Article 自体は残る。

### `setFollowing(_:isFollowing:)`

```
1. conceptPage.isFollowing = isFollowing
2. conceptPage.updatedAt = .now
3. try context.save()
4. refreshTrigger.bump()
```

## Validation Rules

| Field | Rule | Error |
|-------|------|-------|
| `newName` (rename) | trim 後 1+ chars | `.emptyName` |
| `newName` (rename) | trim 後 ≤30 chars | `.nameTooLong` |
| `newName` (rename) | 同 categoryRaw 内 unique (大文字小文字無視、自身除外) | `.duplicateInCategory` |
| `source/target` (merge) | source.id ≠ target.id | `.sameSourceTarget` |

## Concurrency

- `@MainActor` で SwiftData ModelContext と協調 (既存 TagStore / GraphNodeStore と同)
- 各 method は synchronous (throw のみ、async 不要)

## Error Localization (Localizable.xcstrings)

```
"ConceptPageStore.error.emptyName" = "概念名を入力してください";
"ConceptPageStore.error.nameTooLong" = "概念名は 30 文字以内にしてください";
"ConceptPageStore.error.duplicateInCategory" = "同じカテゴリーに同名の概念ページが既に存在します";
"ConceptPageStore.error.sameSourceTarget" = "統合元と統合先は別の概念ページを選んでください";
```

## Acceptance Criteria

- [x] rename / merge / delete / setFollowing が同期的に DB 反映 + UI refresh
- [x] 全 error case が throw され、UI 側で alert 表示可能
- [x] merge 後、source の関連 Article が target に集約、source は削除
- [x] delete 後、他 ConceptPage.relatedConceptIDs から ID が掃除される
- [x] Article 側は delete で nullify (Article 残る)
- [x] 全テスト 7-8 ケースで網羅 (research.md R10)
