# Contract: ChunkProgressStore

**File**: `KnowledgeTree/Services/ChunkProgressStore.swift` (新規)

## 責務

`KnowledgeChunkProgress` の CRUD を担う。Generable type の JSON encode/decode をカプセル化し、Service レイヤーから RAW JSON を扱わなくて済むようにする。

## API

```swift
@MainActor
protocol ChunkProgressStoreProtocol {
    /// chunk の生成結果を 1 行 insert + save。重複 (同 knowledge + chunkIndex) は upsert (上書き)。
    func add(
        knowledge: ExtractedKnowledge,
        chunkIndex: Int,
        output: ExtractedKnowledgeOutput
    ) throws

    /// 該当 knowledge の全 progress を取得 (chunkIndex 昇順)。
    /// JSON decode してメモリ上の構造体として返す。
    func fetchAll(knowledge: ExtractedKnowledge) throws -> [LoadedChunkProgress]

    /// 該当 knowledge の全 progress を削除 (chunked extraction 完了時の cleanup)。
    func cleanup(knowledge: ExtractedKnowledge) throws
}

struct LoadedChunkProgress: Sendable {
    let chunkIndex: Int
    let output: ExtractedKnowledgeOutput
}

@MainActor
final class SwiftDataChunkProgressStore: ChunkProgressStoreProtocol {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?
    private let encoder: JSONEncoder = JSONEncoder()
    private let decoder: JSONDecoder = JSONDecoder()

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) { ... }
    // 実装は data-model.md セクション 4.1 / 4.2 のフローに従う
}

/// テスト / spec 006 既存テスト互換用の no-op 実装。
final class NoopChunkProgressStore: ChunkProgressStoreProtocol {
    func add(knowledge: ExtractedKnowledge, chunkIndex: Int, output: ExtractedKnowledgeOutput) throws {}
    func fetchAll(knowledge: ExtractedKnowledge) throws -> [LoadedChunkProgress] { [] }
    func cleanup(knowledge: ExtractedKnowledge) throws {}
}
```

## 動作詳細

### add(knowledge:chunkIndex:output:)

```swift
func add(knowledge: ExtractedKnowledge, chunkIndex: Int, output: ExtractedKnowledgeOutput) throws {
    let json = try encoder.encode(output)
    let jsonString = String(data: json, encoding: .utf8) ?? "{}"

    // 既存 entry があれば update (重複防止: 同 chunkIndex で 2 回呼ばれた場合)
    if let existing = knowledge.chunkProgress.first(where: { $0.chunkIndex == chunkIndex }) {
        existing.chunkOutputJSON = jsonString
        existing.savedAt = Date()
    } else {
        let progress = KnowledgeChunkProgress(
            knowledge: knowledge,
            chunkIndex: chunkIndex,
            chunkOutputJSON: jsonString
        )
        context.insert(progress)
        knowledge.chunkProgress.append(progress)
    }
    try context.save()
    refreshTrigger?.bump()
}
```

### fetchAll(knowledge:)

```swift
func fetchAll(knowledge: ExtractedKnowledge) throws -> [LoadedChunkProgress] {
    return knowledge.chunkProgress
        .sorted { $0.chunkIndex < $1.chunkIndex }
        .compactMap { progress in
            guard let data = progress.chunkOutputJSON.data(using: .utf8),
                  let output = try? decoder.decode(ExtractedKnowledgeOutput.self, from: data)
            else { return nil }
            return LoadedChunkProgress(chunkIndex: progress.chunkIndex, output: output)
        }
}
```

### cleanup(knowledge:)

```swift
func cleanup(knowledge: ExtractedKnowledge) throws {
    for progress in knowledge.chunkProgress {
        context.delete(progress)
    }
    knowledge.chunkProgress = []
    try context.save()
    refreshTrigger?.bump()
}
```

## 不変条件

1. `add` 後、同 chunkIndex の重複 entry は無い (upsert)
2. `fetchAll` の戻り値は chunkIndex 昇順
3. JSON decode 失敗 (corrupted data) のエントリは fetchAll でスキップ
4. cleanup 後、`knowledge.chunkProgress.isEmpty == true`

## テストケース

```swift
@Test("add で 1 件 insert、fetchAll で取得")
func addAndFetch()

@Test("add 同 chunkIndex 2 回で upsert (重複しない)")
func addUpsertSameIndex()

@Test("fetchAll は chunkIndex 昇順")
func fetchAllSorted()

@Test("cleanup で全削除")
func cleanupRemovesAll()

@Test("JSON decode 失敗のエントリは fetchAll で skip")
func fetchAllSkipsCorruptedJSON()

@Test("add → cleanup → add で重複しない (cleanup が完全削除している)")
func addAfterCleanup()

@Test("空 knowledge で fetchAll は空配列")
func fetchAllOfEmptyKnowledge()
```
