# Contract: `SavedAnswerService`

**File**: `KnowledgeTree/Services/SavedAnswerService.swift` (新規、~250 行)
**Type**: Protocol + 単一実装 (AI 不要)

## Purpose

SavedAnswer の自動 / 手動 CRUD。ChatService.ask 末尾 hook で `captureIfWorthy` 呼び出し、KnowledgeExtractionService.extract 末尾 hook で `markStaleForArticle` 呼び出し。

## Public API

```swift
@MainActor
protocol SavedAnswerServiceProtocol: AnyObject {
    /// chat 答えが条件を満たせば SavedAnswer として保存。silent fire-and-forget、throw しない。
    /// 条件: citedArticleIDs.count >= 2 && answer.count >= 50 && 同 question 既存なし
    func captureIfWorthy(
        question: String,
        answer: String,
        citedArticleIDs: [String],
        sessionID: UUID?
    ) async

    /// 手動 pin toggle (UI から throw 可能)
    func setPinned(_ answer: SavedAnswer, isPinned: Bool) throws

    /// 削除 (UI から throw 可能)
    func delete(_ answer: SavedAnswer) throws

    /// 新記事 ingest で関連 SavedAnswer を stale 化 (引用記事 → 関連 ConceptPage → SavedAnswer)
    /// silent fire-and-forget。
    func markStaleForArticle(_ article: Article) async
}

@MainActor
final class DefaultSavedAnswerService: SavedAnswerServiceProtocol {
    static let minAnswerChars: Int = 50
    static let minCitedCount: Int = 2
    static let maxRelatedConcepts: Int = 5

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil)
}
```

## Behavior

### `captureIfWorthy(question:answer:citedArticleIDs:sessionID:)`

```
1. let trimmedQ = question.trimmingCharacters(in: .whitespacesAndNewlines)
2. guard !trimmedQ.isEmpty else return
3. guard citedArticleIDs.count >= minCitedCount else return  // 1 引用以下は skip
4. guard answer.count >= minAnswerChars else return  // 50 字未満は skip
5. // 重複判定 (normalized question 完全一致、case sensitive)
   let existing = try context.fetch(FetchDescriptor<SavedAnswer>(
       predicate: #Predicate { $0.question == trimmedQ }
   ))
   // SwiftData @Predicate で String 完全一致は OK、trim は事前に手動
   guard existing.isEmpty else { /* logger 注記 */ return }
6. // 引用記事 fetch
   let uuids = citedArticleIDs.compactMap { UUID(uuidString: $0) }
   let citedArticles = try context.fetch(FetchDescriptor<Article>(
       predicate: #Predicate { uuids.contains($0.id) }
   ))
   // SwiftData @Predicate で [UUID].contains はサポートあり (iOS 17+)
   guard !citedArticles.isEmpty else { /* logger error */ return }
7. // 関連 ConceptPage を resolve (R5)
   let topConceptIDs = resolveTopConceptIDs(citedArticles: citedArticles, in: context)
8. // SavedAnswer insert
   let saved = SavedAnswer(
       question: trimmedQ,
       answer: answer,
       citedArticles: citedArticles,
       relatedConceptIDs: topConceptIDs,
       chatSessionID: sessionID,
       savedAutomatically: true
   )
   context.insert(saved)
   try context.save()
   refreshTrigger?.bump()
   logger.notice("captured: question=\(saved.questionPreview, privacy: .public) cited=\(citedArticles.count) concepts=\(topConceptIDs.count)")
```

例外発生 → silent fail、logger.error 記録のみ。

### `setPinned(_:isPinned:)`

```
1. guard answer.isPinned != isPinned else return
2. answer.isPinned = isPinned
3. answer.updatedAt = .now
4. try context.save()
5. refreshTrigger?.bump()
```

### `delete(_:)`

```
1. context.delete(answer)
2. try context.save()
3. refreshTrigger?.bump()
```

@Relationship.nullify により Article 側は自動で link 解除、Article 自体は残る。

### `markStaleForArticle(_:)`

```
1. // 引用記事に関連する ConceptPage 集合を取得
   let allPages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
   let affectedPages = allPages.filter { $0.relatedArticles.contains(where: { $0.id == article.id }) }
   guard !affectedPages.isEmpty else { return }
   let pageIDs = Set(affectedPages.map(\.id))
2. // 該当 ConceptPage に紐付く SavedAnswer を fetch (in-memory filter)
   let allAnswers = (try? context.fetch(FetchDescriptor<SavedAnswer>())) ?? []
   let affected = allAnswers.filter { ans in
       ans.relatedConceptIDs.contains(where: { pageIDs.contains($0) })
   }
   guard !affected.isEmpty else { return }
3. // isStale = true で更新
   for a in affected {
       a.isStale = true
       a.updatedAt = .now
   }
   try? context.save()
   logger.notice("markStale: \(affected.count) answers affected by article \(article.url, privacy: .public)")
```

silent。本 spec では UI 表示なし、WikiLint (spec 044+) で活用。

### Private: `resolveTopConceptIDs(citedArticles:in:) -> [UUID]`

```swift
private func resolveTopConceptIDs(
    citedArticles: [Article],
    in context: ModelContext
) -> [UUID] {
    let citedIDs = Set(citedArticles.map(\.id))
    let allPages: [ConceptPage] = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
    let scored: [(UUID, Int)] = allPages.compactMap { page in
        let overlap = page.relatedArticles.filter { citedIDs.contains($0.id) }.count
        return overlap > 0 ? (page.id, overlap) : nil
    }
    return scored
        .sorted { $0.1 > $1.1 }
        .prefix(Self.maxRelatedConcepts)
        .map(\.0)
}
```

## Concurrency

- `@MainActor` で SwiftData ModelContext と協調
- `captureIfWorthy` / `markStaleForArticle` は呼び出し元 (ChatService / KnowledgeExtractionService) の Task 内で実行、silent fire-and-forget
- `setPinned` / `delete` は UI から同期的に呼ばれる (throw)

## Error Handling

- `captureIfWorthy` / `markStaleForArticle`: throw しない、内部 try? + logger.error
- `setPinned` / `delete`: throw する (UI で alert 表示可能)

## Acceptance Criteria

- [x] 2+ 引用 + 50 字+ answer で SavedAnswer 生成、savedAutomatically=true
- [x] 1 引用 で SavedAnswer 生成しない
- [x] 49 字 answer で SavedAnswer 生成しない
- [x] 同 question 既存で SavedAnswer 重複作成しない
- [x] 関連 ConceptPage 自動解決 (overlap 数 desc top 5)
- [x] setPinned で isPinned 永続化
- [x] delete で SavedAnswer 削除、Article は残る
- [x] markStaleForArticle で関連 SavedAnswer.isStale=true 連鎖
- [x] 全例外 silent fail (captureIfWorthy / markStaleForArticle)
- [x] テスト 8-10 ケース全 PASS
