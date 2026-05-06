# Contract: ArticleSavingActor

App Intent から SwiftData への保存を仲介する actor。ModelContainer の lazy cache + 静的純関数 `performSave` で testable。

## 配置

`KnowledgeTree/AppIntents/ArticleSavingActor.swift` (新規)。

## 定義

```swift
import Foundation
import SwiftData

actor ArticleSavingActor {
    static let shared = ArticleSavingActor()

    private var sharedContainer: ModelContainer?

    private init() {}

    func save(url: String, title: String) async throws {
        let container = try getContainer()
        let context = ModelContext(container)
        _ = try Self.performSave(url: url, title: title, in: context)
    }

    private func getContainer() throws -> ModelContainer {
        if let existing = sharedContainer { return existing }
        AppGroup.ensureContainerDirectoryExists()
        let container = try ModelContainer(
            for: SharedSchema.all,
            configurations: [SharedSchema.sharedConfiguration()]
        )
        sharedContainer = container
        return container
    }

    @discardableResult
    static func performSave(
        url: String,
        title: String,
        in context: ModelContext
    ) throws -> Bool {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty,
              let parsed = URL(string: trimmedURL),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }

        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.url == trimmedURL }
        )
        if let _ = try? context.fetch(descriptor).first {
            return false
        }

        let titleToUse = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? trimmedURL : title
        let article = Article(url: trimmedURL, title: titleToUse)
        context.insert(article)
        try context.save()
        return true
    }
}
```

## 入出力契約

### `save(url:title:)` (instance method, async)

- **入力**:
  - `url: String` — 必須、http/https URL
  - `title: String` — optional 文字列 ("" 可)
- **出力**: void (silent)
- **副作用**:
  - ModelContainer lazy 取得 (App Group 共有)
  - performSave 経由で Article insert + try save
- **failure**: ModelContainer 作成失敗時のみ throws (稀)

### `performSave(url:title:in:)` (static, 純関数)

- **入力**:
  - `url: String` — http/https URL
  - `title: String` — optional 文字列 ("" 可)
  - `context: ModelContext` — 任意の context (production: App Group / test: in-memory)
- **出力**: `Bool` — true (insert 成功) / false (silent skip)
- **副作用**: 入力 context への insert + save
- **failure**: `try context.save()` 失敗時のみ throws

## 不変条件

- `save()` は actor isolation で thread safe、concurrent 呼び出し OK
- `performSave()` は context への副作用以外 pure、test しやすい
- ModelContainer は singleton 内で 1 回だけ生成 (lazy cache)
- 無効 URL / 重複 URL は silent skip、throw しない
- title 空文字は URL で代替

## 動作シナリオ

| シナリオ | 入力 | performSave 出力 | 結果 |
|---|---|---|---|
| 正常 | `https://example.com` + title | true | Article insert |
| 重複 | 既存 URL | false | silent skip |
| 無効 scheme | `javascript:alert(1)` | false | silent skip |
| 空 URL | `""` | false | silent skip |
| 空 title | URL + `""` | true | Article insert (title=URL) |
| ModelContainer 失敗 | (production) | throws (rare) | iOS Shortcut UI で「失敗」表示 |

## アクセシビリティ

actor 自体は表示要素ではないため、accessibility 要件なし。

## 互換性

- 既存 Article @Model 完全再利用
- App Group ModelContainer 共有 (Share Extension と同パターン、spec 001)
- spec 001 ArticleSavingService の重複検出ロジック踏襲
- spec 005 RefreshTrigger は SwiftData `.didSave` 通知経由で auto reload

## テストケース (SaveURLToKnowledgeTreeIntentTests)

| # | ケース | 検証 |
|---|---|---|
| 1 | `testSaveValidURLCreatesArticle` | http URL + title → performSave returns true、Article insert される |
| 2 | `testSaveDuplicateURLSilentSkip` | 既存 URL → performSave returns false、Article 数変わらず |
| 3 | `testSaveInvalidURLSilentSkip` | `javascript:` → performSave returns false、Article insert されない |
| 4 | `testSaveWithoutTitleUsesURLAsTitle` | URL + "" → Article.title == URL |
| 5 | `testSaveWithTitleStoresTitle` | URL + "サンプル" → Article.title == "サンプル" |

(5 ケース、in-memory ModelContainer + static performSave で隔離)
