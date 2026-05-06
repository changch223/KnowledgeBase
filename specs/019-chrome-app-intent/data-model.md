# Data Model: spec 019

## 既存 @Model 再利用

### Article (spec 001 で定義済)

`KnowledgeTree/Models/Article.swift` を再利用、改修なし。

App Intent 経由で保存される記事は `Article(url:, title:, savedAt:)` で挿入され、既存 spec 002/003 backfill で enrichment / body / knowledge が後追い取得される。

## 永続化スキーマへの影響

**ゼロ**。新 @Model なし、SwiftData migration なし。`SharedSchema.all` の変更なし。

## 新規 transient 型 (永続化なし)

### SaveURLToKnowledgeTreeIntent (App Intent)

`KnowledgeTree/AppIntents/SaveURLToKnowledgeTreeIntent.swift` (新規)。

```swift
import AppIntents
import Foundation

struct SaveURLToKnowledgeTreeIntent: AppIntent {
    static var title: LocalizedStringResource = "知積に保存"
    static var description: IntentDescription = IntentDescription(
        "URL を 知積に保存します",
        categoryName: "コンテンツ"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "URL")
    var url: URL

    @Parameter(title: "タイトル", default: nil)
    var title: String?

    func perform() async throws -> some IntentResult {
        try await ArticleSavingActor.shared.save(
            url: url.absoluteString,
            title: title ?? ""
        )
        return .result()
    }
}
```

**フィールド**:
- `url: URL` (必須、`@Parameter`)
- `title: String?` (任意、`@Parameter`)

**ライフサイクル**: iOS Shortcuts 起動時に AppIntents framework が instance 化、`perform()` 実行後 deinit。

### KnowledgeTreeShortcuts (AppShortcutsProvider)

```swift
struct KnowledgeTreeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveURLToKnowledgeTreeIntent(),
            phrases: [
                "知積に保存",
                "URL を 知積に保存",
                "Save to \(.applicationName)",
            ],
            shortTitle: "保存",
            systemImageName: "square.and.arrow.down"
        )
    }
}
```

**ライフサイクル**: アプリインストール時に iOS が自動 detect、Shortcuts.app + Spotlight + Siri に登録。

### SettingsDestination

`KnowledgeTree/Views/SettingsView.swift` 末尾 or 同ファイル内:

```swift
struct SettingsDestination: Hashable {}
```

**用途**: AIBrainView の `.navigationDestination(for: SettingsDestination.self)` で SettingsView へ遷移するための Hashable type。空 struct で十分。

### ChromeSetupDestination

`KnowledgeTree/Views/SettingsView.swift` 末尾 or 同ファイル内:

```swift
struct ChromeSetupDestination: Hashable {}
```

**用途**: SettingsView の `.navigationDestination(for: ChromeSetupDestination.self)` で ChromeShortcutSetupView へ遷移するための Hashable type。

## 新規 actor

### ArticleSavingActor

`KnowledgeTree/AppIntents/ArticleSavingActor.swift` (新規)。

```swift
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

    /// testable 純粋関数
    @discardableResult
    static func performSave(url: String, title: String, in context: ModelContext) throws -> Bool {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty,
              let parsed = URL(string: trimmedURL),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false  // silent skip on invalid
        }

        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.url == trimmedURL }
        )
        if let _ = try? context.fetch(descriptor).first {
            return false  // silent skip on duplicate
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

**特性**:
- actor で thread safety、App Intent の concurrent access 安全
- ModelContainer は lazy init + cache (singleton 内 cache、複数回保存呼び出し効率化)
- `static performSave` は純関数、test で in-memory ModelContext で検証可能

## UserDefaults エントリ (新規)

| Key | 型 | 用途 |
|---|---|---|
| `settings.shortcutSetupCompleted` | `Bool` | ChromeShortcutSetupView の「セットアップ完了」flag、SettingsView の checkmark 表示と「もう一度見る」リンク表示の切替 |

`@AppStorage` 経由で Bool default false、UserDefaults.standard に永続化、再起動でも保持。

## State 遷移

### ChromeShortcutSetupView の Setup state

```
初期: setupCompleted = false (default)
   ↓
ユーザー Step 1-3 を実行 (Shortcuts.app で Personal Automation 設定)
   ↓
「セットアップ完了」ボタン → setupCompleted = true
   ↓
SettingsView に戻る → entry に checkmark 表示
   ↓
「もう一度見る」リンク → setupCompleted = false (再表示用)
```

### App Intent perform() の lifecycle

```
iOS Shortcuts 起動 → SaveURLToKnowledgeTreeIntent instance 作成 (URL + title 受信)
   ↓
perform() 呼び出し → ArticleSavingActor.shared.save()
   ↓
ModelContainer lazy 取得 (App Group 共有)
   ↓
URL バリデーション (空 / 無効 scheme → silent skip)
   ↓
重複検出 (既存 URL → silent skip)
   ↓
新規 Article insert + try context.save()
   ↓
return .result() → silent 完了 (dialog なし)
```

## 検証ルール

| ルール | 検証 |
|---|---|
| `url` は http/https scheme のみ | `performSave` 内で scheme チェック、それ以外は silent skip |
| `url` トリミング後空文字 | silent skip |
| 重複 URL | spec 001 と同様 `predicate: { $0.url == trimmedURL }` |
| `title` トリミング後空 | URL を title に使用 (article.title がない記事を防ぐ) |
| ModelContainer 作成失敗 | throws、AppIntent で catch されると Shortcut が「失敗」表示 (constitution V 整合性は要検証、稀ケース) |

## エラーケース

| ケース | 挙動 |
|---|---|
| 無効 URL (`javascript:` / 空文字 / scheme なし) | silent skip、ユーザー通知なし |
| 重複 URL | silent skip、既存 article は touch されない |
| ModelContainer 作成失敗 | throws、iOS Shortcuts UI で「失敗」表示 (稀、ストレージ満杯等) |
| App 起動中の concurrent save | actor で thread safety、両方処理される |
| App 終了中の App Intent 起動 | iOS が main app process を起動 → AppIntents framework が perform() 実行 |
