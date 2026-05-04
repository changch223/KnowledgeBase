# Contract: ArticleSavingService Protocol

**Layer**: Business logic boundary (Constitution Principle VI)
**Used by**: `ShareViewController` (Share Extension target)

## Purpose

Share payload からの URL/Title を受け取り、validation・重複検出・永続化までを 1 メソッドにまとめる。Share Extension UI を薄く保ち、テスト可能なロジックをこの Service に集約する。

## Protocol

```swift
protocol ArticleSavingServiceProtocol: Sendable {
    /// 指定された URL とタイトルを保存する。
    /// 重複・URL 不正・スキーム非対応はエラーとして返却する (UI 側でメッセージ表示)。
    func save(url: URL?, suppliedTitle: String?) async -> SaveResult
}

enum SaveResult: Equatable {
    case saved(Article)
    case duplicate                  // FR-014 / FR-015 / SC-009
    case missingURL                 // FR-008
    case unsupportedScheme          // Edge Case (file://, mailto: 等)
    case persistenceFailure(String) // FR-008 (ストレージ書き込み失敗)
}
```

## Behavior

### 入力 validation

1. `url == nil` → `.missingURL`。
2. `url.scheme != "http"` かつ `url.scheme != "https"` → `.unsupportedScheme`。
3. `suppliedTitle?.isEmpty != false` → `url.host` を fallback として使用 (FR-009)。それも nil なら `url.absoluteString` を使用。

### 重複検出

`ArticleStoreProtocol.exists(url: url.absoluteString)` を呼び、`true` なら `.duplicate` を返す (新規保存しない、既存 savedAt は変更しない)。

### 永続化

新規 `Article(url:, title:, savedAt:)` を生成し `ArticleStoreProtocol.insert` に渡す。例外は `.persistenceFailure` でラップして返す。

## Tests (KnowledgeTreeTests / `ArticleSavingServiceTests`)

最低限以下のケースを `MockArticleStore` を使って網羅:

| ケース | 入力 | 期待 |
|---|---|---|
| 通常保存 | https URL + title 有 | `.saved(_)` 1 件追加 |
| URL 不在 | nil | `.missingURL` 0 件追加 |
| 非対応スキーム | `mailto:foo@bar.com` | `.unsupportedScheme` 0 件追加 |
| Title 空 → host fallback | https URL + title 空 | `.saved(_)`、保存された title が url.host に等しい (FR-009) |
| Title 空 + host nil → absoluteString fallback | 例外的 URL | `.saved(_)`、title が url.absoluteString |
| 重複保存 | 既存と同じ URL を 2 回 save | 1 回目 `.saved`、2 回目 `.duplicate`、Store の件数は 1 (FR-015) |
| 重複後の savedAt 不変 | 既存 + 同 URL の 2 回目 save | 既存 Article の savedAt が変更されていない (FR-015) |
| persistence エラー | Mock Store が throw | `.persistenceFailure(_)` |

すべて `MockArticleStore` で実行し、SwiftData 依存なく決定論的に走る (Constitution テストゲート)。
