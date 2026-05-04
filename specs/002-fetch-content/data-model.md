# Data Model: 本文取得・メタデータエンリッチメント — Phase 1

**Feature**: spec 002 — 本文取得・メタデータエンリッチメント
**Date**: 2026-05-04

## Existing Entity (spec 001)

### `Article` (要追加: enrichment への optional relationship)

spec 001 の `Article` に **新規 relationship を追加** する以外は変更なし。

```swift
@Model
final class Article {
    @Attribute(.unique) var id: UUID
    var url: String
    var title: String
    var savedAt: Date

    // 新規 (spec 002):
    @Relationship(deleteRule: .cascade, inverse: \ArticleEnrichment.article)
    var enrichment: ArticleEnrichment?

    init(id: UUID = UUID(), url: String, title: String, savedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.savedAt = savedAt
    }
}
```

注: `enrichment` は optional。enrichment ジョブ完了前 / 失敗時 / pre-spec-002 既存 Article では nil。

## New Entity (spec 002)

### `ArticleEnrichment`

1 件の `Article` に紐づく enriched メタデータ + raw HTML キャッシュ。

#### Attributes

| Field | Type | Optional | Default | Description |
|---|---|---|---|---|
| `id` | `UUID` | No | `UUID()` | 一意識別子 (主キー)。 |
| `article` | `Article` | **No** | — | 親 Article への non-optional 参照 (Constitution Principle III)。 |
| `statusRaw` | `String` | No | `"pending"` | ステータス文字列。`EnrichmentStatus` enum に変換するための保存形。 |
| `canonicalTitle` | `String?` | Yes | nil | HTML `<title>` の値。失敗 / 空のとき nil。 |
| `summary` | `String?` | Yes | nil | `<meta name="description">` の content 値。失敗 / 不在のとき nil。 |
| `ogImageURL` | `String?` | Yes | nil | `<meta property="og:image">` の content 値 (絶対 URL に解決済み)。失敗 / 不在のとき nil。 |
| `rawHTML` | `String?` | Yes | nil | 取得した HTML の生文字列。2 MB 超の場合は nil (FR-012)。 |
| `lastFetchedAt` | `Date?` | Yes | nil | 最終 fetch 試行日時 (成否問わず)。 |
| `retryCount` | `Int` | No | 0 | これまでのリトライ回数。3 で `permanentlyFailed` 確定。 |

#### EnrichmentStatus (enum)

`@Model` の中に直接 enum は持てないため、`statusRaw: String` と enum 変換ヘルパに分ける。

```swift
enum EnrichmentStatus: String, Codable, Sendable {
    case pending             // 未着手 (新規挿入直後)
    case fetching            // 進行中
    case succeeded           // 取得成功 (canonicalTitle / summary / ogImageURL のいずれかが入った)
    case failed              // 一時失敗 (リトライ予定)
    case permanentlyFailed   // 上限超過、自動再試行終了
}

extension ArticleEnrichment {
    var status: EnrichmentStatus {
        get { EnrichmentStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
```

#### SwiftData 構成

```swift
@Model
final class ArticleEnrichment {
    @Attribute(.unique) var id: UUID
    var article: Article
    var statusRaw: String
    var canonicalTitle: String?
    var summary: String?
    var ogImageURL: String?
    var rawHTML: String?
    var lastFetchedAt: Date?
    var retryCount: Int

    init(
        id: UUID = UUID(),
        article: Article,
        status: EnrichmentStatus = .pending,
        canonicalTitle: String? = nil,
        summary: String? = nil,
        ogImageURL: String? = nil,
        rawHTML: String? = nil,
        lastFetchedAt: Date? = nil,
        retryCount: Int = 0
    ) {
        self.id = id
        self.article = article
        self.statusRaw = status.rawValue
        self.canonicalTitle = canonicalTitle
        self.summary = summary
        self.ogImageURL = ogImageURL
        self.rawHTML = rawHTML
        self.lastFetchedAt = lastFetchedAt
        self.retryCount = retryCount
    }
}
```

#### Validation rules (Service 層)

`ArticleEnrichmentService.fetchAndPersist(for:)` 内で:

1. **rawHTML サイズ**: 取得バイト数が 2 MB 超なら rawHTML フィールドを nil で保存 (メタデータだけ抽出済みなら他フィールドは保存)。
2. **URL スキーム再確認**: `Article.url` の scheme が "https" でなければ enrichment しない (即 `permanentlyFailed`)。spec 001 で http/https のみ受理しているため通常は通過。
3. **canonicalTitle 長さ**: 1000 文字超は 200 文字で切り詰め保存 (Edge Case 対応)。
4. **ogImageURL の絶対化**: 相対 URL (例 `/images/og.jpg`) は base URL を使って絶対化。失敗時 nil。

#### State transitions

```
pending → fetching → succeeded
                  → failed → fetching (retry, retryCount++) → succeeded
                                                            → failed → ... (max 3) → permanentlyFailed
```

- `pending`: enrichment record 新規作成直後 (Article 挿入と同時)。
- `fetching`: ジョブが running 中 (UI で「取得中」インジケータ)。
- `succeeded`: canonicalTitle / summary / ogImageURL のいずれかが入った状態 (enriched カード表示)。
- `failed`: 一時失敗 (UI で「未取得」、自動 retry スケジュール済み)。
- `permanentlyFailed`: retry 上限超 (UI で「取得失敗」、手動再取得は spec 003 以降)。

#### Indexes

- 主キー: `id` (`@Attribute(.unique)`)。
- 推奨: `statusRaw` への二次インデックス (起動時に `pending` / `failed` を効率的に query するため)。SwiftData の `#Index` マクロが安定したら追加 (本 spec では未追加、件数が多くなった時点で再評価)。

## Relationships

| 関係 | カーディナリティ | 削除ルール |
|---|---|---|
| `Article` ↔ `ArticleEnrichment` | 1 ↔ 0..1 | Article 削除時に Enrichment も削除 (cascade) |

将来 spec 予約:
- spec 003 (本文抽出) で `ArticleBody` (本文 plain text) が `ArticleEnrichment` の `rawHTML` を入力に派生し、`Article` への non-optional 参照を持つ予定。
- spec 004 (要約) で `ArticleSummary` が `Article` への non-optional 参照を持つ予定。

## Storage location

- spec 001 と同じ App Group container 配下の SwiftData ストア。
- schema は `Schema([Article.self, ArticleEnrichment.self])` に拡張。
- migration は SwiftData 自動 lightweight migration で吸収 (research.md / R6)。
