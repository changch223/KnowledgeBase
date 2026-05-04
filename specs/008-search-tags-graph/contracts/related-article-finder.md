# Contract: RelatedArticleFinder + SuggestedTagFinder

**Files**:
- `KnowledgeTree/Services/RelatedArticleFinder.swift` (新規)
- `KnowledgeTree/Services/SuggestedTagFinder.swift` (新規)

## RelatedArticleFinder

### 責務
基準記事と共通 KnowledgeEntity を持つ他記事を関連記事として算出する純粋関数。

### API

```swift
struct RelatedArticleFinder {
    /// 基準記事と共通 entity を持つ他記事を上位 limit 件返す。
    /// 共通 entity 数で降順 sort、同 count は savedAt 降順で tiebreak。
    /// 自記事は除外。
    /// - Parameters:
    ///   - article: 基準記事
    ///   - candidates: 候補となる全記事 (article 自身を含んで OK、内部で除外)
    ///   - limit: 上位件数 (default 5)
    /// - Returns: 共通 entity 数 1 以上の候補のみ。最大 limit 件
    static func find(
        for article: Article,
        in candidates: [Article],
        limit: Int = 5
    ) -> [RelatedArticle]
}

struct RelatedArticle: Identifiable, Sendable {
    var id: UUID { article.id }
    let article: Article
    let commonEntityCount: Int
    let commonEntities: [String]   // 上位 3 件 (UI 表示用)
}
```

### 動作詳細

```swift
static func find(for article: Article, in candidates: [Article], limit: Int = 5) -> [RelatedArticle] {
    // 基準記事の entity セット (lowercase + trim)
    let baseEntities: Set<String> = Set(
        (article.extractedKnowledge?.entities ?? []).compactMap { entity in
            let key = entity.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return key.isEmpty ? nil : key
        }
    )
    guard !baseEntities.isEmpty else { return [] }

    // 各候補との共通 entity 数を計算
    var related: [RelatedArticle] = []
    for other in candidates {
        guard other.id != article.id else { continue }
        let otherEntitiesByKey: [String: KnowledgeEntity] = Dictionary(
            uniqueKeysWithValues: (other.extractedKnowledge?.entities ?? []).compactMap { entity in
                let key = entity.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                return key.isEmpty ? nil : (key, entity)
            }
        )
        let common = baseEntities.intersection(Set(otherEntitiesByKey.keys))
        guard !common.isEmpty else { continue }

        // 表示用の上位 3 entity name (元 entity の name を保持、salience 降順)
        let topNames = common
            .compactMap { otherEntitiesByKey[$0] }
            .sorted { $0.salience > $1.salience }
            .prefix(3)
            .map { $0.name }

        related.append(RelatedArticle(
            article: other,
            commonEntityCount: common.count,
            commonEntities: Array(topNames)
        ))
    }

    // sort: commonEntityCount desc, savedAt desc (tiebreak)
    related.sort { lhs, rhs in
        if lhs.commonEntityCount != rhs.commonEntityCount {
            return lhs.commonEntityCount > rhs.commonEntityCount
        }
        return lhs.article.savedAt > rhs.article.savedAt
    }

    return Array(related.prefix(limit))
}
```

### 不変条件

1. 戻り値は最大 limit 件
2. 戻り値の各要素 `commonEntityCount >= 1`
3. 戻り値に基準 article 自身は含まれない
4. 戻り値は commonEntityCount 降順、tiebreak は savedAt 降順
5. 基準 article に entity が無い (knowledge.failed/skipped) なら空配列

### テストケース

```swift
@Test("共通 entity 0 件なら空配列")
func noCommonEntities()

@Test("基準 article に entity 無しなら空配列")
func baseHasNoEntities()

@Test("自記事は候補から除外")
func selfExcluded()

@Test("共通 entity 数で降順 sort")
func sortedByCommonCount()

@Test("同 count は savedAt 降順 tiebreak")
func tiebreakBySavedAt()

@Test("上限 5 件")
func limitFive()

@Test("commonEntities は salience 降順 上位 3")
func topThreeCommonEntities()

@Test("entity name の case-insensitive 一致")
func caseInsensitiveMatch()

@Test("entity name の trim 一致")
func trimMatch()
```

---

## SuggestedTagFinder

### 責務
KnowledgeEntity から「自動タグ候補」を抽出する純粋関数。

### API

```swift
struct SuggestedTagFinder {
    /// 記事の entity から salience 4 以上の候補を上位 5 件返す。
    /// 既存タグと重複するものは除外。
    /// - Parameters:
    ///   - article: 対象記事
    ///   - existingTagNames: 既に手動タグとして登録済の正規化済 name set
    /// - Returns: タグ候補 (順序: salience desc, order asc)
    static func find(
        for article: Article,
        existingTagNames: Set<String>,
        limit: Int = 5
    ) -> [SuggestedTag]
}

struct SuggestedTag: Identifiable, Sendable {
    var id: String { normalizedName }
    let normalizedName: String      // TagNormalizer.normalize 済
    let displayName: String         // 元 entity.name
    let salience: Int
}
```

### 動作詳細

```swift
static func find(for article: Article, existingTagNames: Set<String>, limit: Int = 5) -> [SuggestedTag] {
    let entities = article.extractedKnowledge?.entities ?? []
    let candidates = entities.compactMap { entity -> SuggestedTag? in
        guard entity.salience >= 4 else { return nil }
        guard let normalized = TagNormalizer.normalize(entity.name) else { return nil }
        guard !existingTagNames.contains(normalized) else { return nil }
        return SuggestedTag(
            normalizedName: normalized,
            displayName: entity.name,
            salience: entity.salience
        )
    }
    // 重複排除 (normalizedName で)
    var seen: Set<String> = []
    var unique: [SuggestedTag] = []
    for c in candidates {
        if !seen.contains(c.normalizedName) {
            seen.insert(c.normalizedName)
            unique.append(c)
        }
    }
    // sort by salience desc
    let sorted = unique.sorted { lhs, rhs in
        lhs.salience > rhs.salience
    }
    return Array(sorted.prefix(limit))
}
```

### 不変条件

1. 戻り値の各要素は `salience >= 4`
2. 戻り値に既存タグ (existingTagNames) と重複する name は無い
3. 戻り値の normalizedName は TagNormalizer.normalize 済 (lowercase + trim + 50 char)
4. 戻り値は salience 降順
5. 戻り値は最大 limit 件
6. article に entity が無い (knowledge.failed/skipped) なら空配列

### テストケース

```swift
@Test("salience 4 以上のみ候補")
func salience4OrAbove()

@Test("salience 3 以下は除外")
func salience3OrBelowExcluded()

@Test("既存タグと重複は除外")
func existingTagsExcluded()

@Test("salience 降順 sort")
func sortedBySalience()

@Test("normalizedName で重複排除")
func dedupeByNormalizedName()

@Test("article に entity 無しなら空配列")
func noEntitiesEmptyResult()

@Test("上限 5 件")
func limitFive()

@Test("displayName は元 entity.name 保持")
func displayNamePreservesCase()
```
