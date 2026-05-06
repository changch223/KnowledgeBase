# Contract: SaveURLToKnowledgeTreeIntent

iOS 16+ App Intent。「URL を 知積に保存」アクションを Shortcuts.app + Spotlight + Siri から呼び出し可能にする。

## 配置

`KnowledgeTree/AppIntents/SaveURLToKnowledgeTreeIntent.swift` (新規)。

## 定義

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

## 入力

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| `url` | `URL` | 必須 | 保存する URL (http/https のみ) |
| `title` | `String?` | 任意 | 記事タイトル (空なら URL を使用) |

## 出力

`some IntentResult` — silent return (`.result()` のみ)、dialog 表示なし。

## 不変条件

- `openAppWhenRun: false` でアプリを起動せず perform() 完了
- 無効 URL (空 / 非 http/https) は silent skip (throw しない)
- 重複 URL は silent skip (既存 article は touch しない)
- title 空文字なら url を title に使用 (article.title に何かしら入る)

## 動作シナリオ

| シナリオ | 入力 | 結果 |
|---|---|---|
| 正常 | `url=https://example.com`, `title="サンプル"` | Article insert、return |
| title なし | `url=https://example.com`, `title=nil` | Article insert (title=URL)、return |
| 重複 | 既存 url と同じ | silent skip、return (既存記事は変化なし) |
| 無効 scheme | `url=javascript:alert(1)` | silent skip、return |
| 空 URL | `url=""` (実際は URL 型バインドで起こらない) | silent skip、return |

## アクセシビリティ

App Intent 自体は表示要素ではないが、`title` / `description` は VoiceOver で読み上げられる Shortcuts.app UI で使用される。日本語で明確に。

## 互換性

- iOS 16+ AppIntents framework (Constitution IV iOS 26+ でカバー)
- 既存 Article @Model 完全再利用
- 既存 spec 001 重複検出ロジック踏襲

## テスト戦略

App Intent struct 自体の test は AppIntents framework の mock 困難。代わりに ArticleSavingActor.performSave() (静的純関数) を test (R10 採用案 B)。
