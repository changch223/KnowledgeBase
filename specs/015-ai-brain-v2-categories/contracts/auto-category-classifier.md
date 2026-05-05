# Contract: AutoCategoryClassifier

**File**: `KnowledgeTree/Services/AutoCategoryClassifier.swift`

## 責務

`Tag.name` を入力に、`CategorySeed.allSeeds` のうち 1 つの Category 名を返す protocol + 2 実装 (Foundation Models / InMemory mock)。1 回/Tag、永続化は呼び出し側 (TagStore / AutoCategoryBackfillRunner) が担当。

## API

```swift
@MainActor
protocol AutoCategoryClassifier {
    /// Tag の name を入力に、CategorySeed の category 名を返す。
    /// 失敗 / 不明 → "その他" を返す (CategorySeed.otherCategory.name)。
    func classify(tagName: String) async -> String
}

@MainActor
final class FoundationModelsAutoCategoryClassifier: AutoCategoryClassifier {
    init(session: LanguageModelSessionProtocol = FoundationModelLanguageModelSession())
    func classify(tagName: String) async -> String
}

@MainActor
final class InMemoryAutoCategoryClassifier: AutoCategoryClassifier {
    init(mapping: [String: String] = [:], defaultCategory: String = "その他")
    func classify(tagName: String) async -> String
}

@Generable
struct CategoryClassificationOutput: Sendable {
    @Guide(description: "テクノロジー / 経済 / 健康 / デザイン / 学術 / アート / ニュース / スポーツ / エンタメ / その他 のいずれか 1 つ。完全一致")
    let categoryName: String
}
```

## 入力契約

| パラメータ | 型 | 制約 |
|---|---|---|
| `tagName` | `String` | TagNormalizer.normalize 済の値。空文字列 → "その他" |

## 出力契約

戻り値: `CategorySeed.allSeeds.map(\.name)` のいずれかの **正確な文字列**。

不一致時の挙動 (`classify` 内で吸収):
- Foundation Models が prompt に従わず別文字列を返した → "その他"
- `availability != .available` → "その他"
- `tagName.isEmpty` → "その他"
- 例外 throw → "その他"

## アルゴリズム (FoundationModelsAutoCategoryClassifier)

```swift
func classify(tagName: String) async -> String {
    let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return CategorySeed.otherCategory.name }
    guard SystemLanguageModel.availability == .available else {
        return CategorySeed.otherCategory.name
    }

    let candidates = CategorySeed.allSeeds.map(\.name).joined(separator: " / ")
    let prompt = """
        次のタグはどのカテゴリーに属しますか? 候補から 1 つだけ完全一致で返してください。
        候補: \(candidates)
        タグ: \(trimmed)
        """

    do {
        let output: CategoryClassificationOutput = try await session.respond(
            to: prompt,
            generating: CategoryClassificationOutput.self
        )
        if CategorySeed.allSeeds.contains(where: { $0.name == output.categoryName }) {
            return output.categoryName
        }
        return CategorySeed.otherCategory.name
    } catch {
        logger.error("classify failed for \(trimmed): \(error)")
        return CategorySeed.otherCategory.name
    }
}
```

## 副作用境界

`AutoCategoryClassifier` は **副作用ゼロ**。SwiftData / UserDefaults / RefreshTrigger に触れない。永続化は呼び出し側が担う。

## テスト (`AutoCategoryClassifierTests.swift`)

| Test | 検証 |
|---|---|
| `testInMemoryReturnsMappedCategory` | mapping = ["swift": "テクノロジー"] → classify("Swift") → "テクノロジー" (lowercased match) |
| `testInMemoryReturnsDefaultForUnknown` | mapping = [:] → classify("xyz") → "その他" |
| `testInMemoryReturnsDefaultForEmpty` | classify("") → "その他" |
| `testInMemoryRespectsCustomDefault` | defaultCategory: "学術" → classify("xyz") → "学術" |
| `testFallbackContainsAllSeedNames` | InMemory が 10 シードを正しい name で返せる (mapping 全網羅 test、CategorySeed の整合性確認) |

Foundation Models 統合 test は実機/Simulator で手動検証 (`quickstart.md` 検証 6 / 7)。

## 依存

- `LanguageModelSessionProtocol` (spec 004 既存)
- `CategorySeed` (本 spec 新規)
- `os.Logger` (`subsystem: "app.KnowledgeTree", category: "auto-category"`)
