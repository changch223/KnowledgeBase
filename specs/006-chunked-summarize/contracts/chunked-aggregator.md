# Contract: ChunkedKnowledgeAggregator

**File**: `KnowledgeTree/Services/ChunkedKnowledgeAggregator.swift` (新規)

## 責務

複数 chunk の生成結果と meta-summary 結果を統合して、ExtractedKnowledge に永続化可能な形に集約する純粋関数群。重複排除・partial success 判定・fallback 処理を担う。

## API

```swift
struct ChunkedKnowledgeAggregator {
    /// 全 chunk の結果 + meta-summary 結果を統合する。
    ///
    /// - Parameters:
    ///   - results: 各 chunk の生成結果 (失敗 chunk は output == nil)
    ///   - metaSummary: meta-summary 生成結果 (失敗時 nil)
    /// - Returns: 集約済み AggregatedKnowledge (status 判定用情報込み)
    static func merge(
        results: [ChunkResult],
        metaSummary: ExtractedKnowledgeOutput?
    ) -> AggregatedKnowledge
}

struct AggregatedKnowledge: Sendable {
    let essence: String
    let summary: String
    let keyFacts: [KeyFactOutput]
    let entities: [KnowledgeEntityOutput]
    let successfulChunkCount: Int
    let totalChunkCount: Int
    let metaSummarySucceeded: Bool

    /// status 判定 (R7 ルール)
    func determineStatus() -> ExtractionStatus {
        if successfulChunkCount == 0 { return .failed }
        if metaSummarySucceeded { return .succeeded }
        return .partiallySucceeded
    }

    /// SwiftData 永続化用の ExtractedKnowledgeOutput を生成
    func toOutput() -> ExtractedKnowledgeOutput {
        ExtractedKnowledgeOutput(
            essence: essence,
            summary: summary,
            keyFacts: keyFacts,
            entities: entities
        )
    }
}
```

## 統合ロジック

### essence / summary

- `metaSummary != nil` → `metaSummary.essence` / `metaSummary.summary` をそのまま採用
- `metaSummary == nil && successfulChunkCount > 0` → fallback:
  - `essence` = 最初の成功 chunk の `essence`
  - `summary` = 全成功 chunk の `essence` を改行で連結 (300 文字超過時は 300 文字に truncate)
- `successfulChunkCount == 0` → `essence = ""`, `summary = ""` (status は `.failed` になるので使われないが空文字で安全)

### keyFacts

```text
1. 全成功 chunk の keyFacts を 1 つの flat list に concat
2. trim 済 statement の完全一致で重複排除 (最初に出現した順序を保持)
3. 上限なし (Generable 出力で各 chunk 3-5 件 → 10 chunk × 5 = 最大 50 件、UI 表示はそのまま)
```

擬似コード:
```swift
var seen: Set<String> = []
var deduped: [KeyFactOutput] = []
for result in results {
    guard let output = result.output else { continue }
    for fact in output.keyFacts {
        let key = fact.statement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !seen.contains(key) else { continue }
        seen.insert(key)
        deduped.append(fact)
    }
}
return deduped
```

### entities

```text
1. 全成功 chunk の entities を flat list に concat
2. lowercased + trim した name で重複判定
3. 重複時は salience 最大値、type は多数決 (同票時は salience 最大の元 entity の type)
```

擬似コード:
```swift
var byKey: [String: [KnowledgeEntityOutput]] = [:]
for result in results {
    guard let output = result.output else { continue }
    for entity in output.entities {
        let key = entity.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        byKey[key, default: []].append(entity)
    }
}
return byKey.values.map { group in
    let maxSalience = group.map(\.salience).max() ?? 1
    let topByCount = Dictionary(grouping: group, by: \.type)
        .max { a, b in
            if a.value.count != b.value.count { return a.value.count < b.value.count }
            return a.value.map(\.salience).max() ?? 0 < b.value.map(\.salience).max() ?? 0
        }
    let topType = topByCount?.key ?? group[0].type
    let representative = group.max(by: { $0.salience < $1.salience }) ?? group[0]
    return KnowledgeEntityOutput(
        name: representative.name,  // case 保持: salience 最大版
        type: topType,
        salience: maxSalience
    )
}
```

## 不変条件 (Invariants)

1. `successfulChunkCount` = `results.filter { $0.output != nil }.count`
2. `totalChunkCount` = `results.count`
3. `successfulChunkCount <= totalChunkCount`
4. `keyFacts.count <= results.compactMap(\.output).flatMap(\.keyFacts).count` (重複排除でしか減らない)
5. `entities.count <= results.compactMap(\.output).flatMap(\.entities).count`
6. `essence.count <= 150`
7. `summary.count <= 300`
8. `metaSummarySucceeded == (metaSummary != nil)`

## テストケース (`ChunkedKnowledgeAggregatorTests.swift`)

```swift
@Test("全 chunk 失敗 → status .failed、essence/summary 空")
func allChunksFailed()

@Test("1 chunk 成功 + meta 成功 → .succeeded、meta 値を採用")
func oneChunkAndMetaSucceeded()

@Test("3 chunk 成功 + meta 失敗 → .partiallySucceeded、最初の chunk の essence を fallback")
func metaFailsButChunksSucceed()

@Test("keyFacts の重複排除 (trim 完全一致)")
func keyFactsDeduplication()

@Test("keyFacts の trim 違いは別 fact")
func keyFactsWhitespaceSensitive()

@Test("entities の case-insensitive 統合")
func entitiesCaseInsensitiveMerge()

@Test("entities の salience は最大値を採用")
func entitiesMaxSalience()

@Test("entities の type は多数決")
func entitiesTypeMajorityVote()

@Test("entities の type 多数決同票時は salience 最大版を採用")
func entitiesTypeTieBreakBySalience()

@Test("空 results は status .failed")
func emptyResults()

@Test("成功 chunk 0 件 + meta 成功 (理論上有り得ないが) → .failed (chunk 失敗が優先)")
func metaSucceededButNoChunks()
```

## エラーケース

純粋関数なのでエラーは投げない。`metaSummary == nil && results.allSatisfy { $0.output == nil }` の場合は `successfulChunkCount = 0` で status `.failed`、文字列フィールドは空文字に初期化。
