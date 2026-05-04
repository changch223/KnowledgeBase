# Data Model: 本文抽出 (Reader View) — Phase 1

**Feature**: spec 003 — 本文抽出 (Reader View)
**Date**: 2026-05-04

## Existing Entity (spec 001 + 002)

### `Article` (要追加: body への optional relationship)

```swift
@Model
final class Article {
    @Attribute(.unique) var id: UUID
    var url: String
    var title: String
    var savedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ArticleEnrichment.article)
    var enrichment: ArticleEnrichment?

    // 新規 (spec 003):
    @Relationship(deleteRule: .cascade, inverse: \ArticleBody.article)
    var body: ArticleBody?

    init(id: UUID = UUID(), url: String, title: String, savedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.savedAt = savedAt
    }
}
```

注: `body` は optional。抽出ジョブ完了前 / 失敗時 / rawHTML が無い既存 Article では nil。

## New Entity (spec 003)

### `ArticleBody`

1 件の `Article` に紐づく抽出済本文。

#### Attributes

| Field | Type | Optional | Default | Description |
|---|---|---|---|---|
| `id` | `UUID` | No | `UUID()` | 一意識別子 (主キー)。 |
| `article` | `Article` | **No** | — | 親 Article への non-optional 参照 (Constitution Principle III)。 |
| `statusRaw` | `String` | No | `"pending"` | ステータス文字列。`BodyExtractionStatus` enum 変換用。 |
| `extractedText` | `String?` | Yes | nil | 抽出された plain text 本文。失敗 / 短すぎる (100 文字未満) のとき nil。 |
| `extractionVersion` | `Int` | No | 1 | 使用したヒューリスティックのバージョン。将来の再抽出判定用。 |
| `lastExtractedAt` | `Date?` | Yes | nil | 最終抽出試行日時 (成否問わず)。 |

#### BodyExtractionStatus (enum)

```swift
enum BodyExtractionStatus: String, Codable, Sendable {
    case pending             // 未着手 (新規挿入直後 or rawHTML 待ち)
    case extracting          // 進行中
    case succeeded           // 抽出成功 (extractedText が ≥ 100 文字)
    case failed              // 抽出失敗 (rawHTML は有るがヒューリスティックが本文を見つけられない、または結果が短すぎる)
    case permanentlyFailed   // 永続失敗 (将来再試行ロジックを追加した時用、本 spec MVP では failed と同じ扱い)
}

extension ArticleBody {
    var status: BodyExtractionStatus {
        get { BodyExtractionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
```

#### SwiftData 構成

```swift
@Model
final class ArticleBody {
    @Attribute(.unique) var id: UUID
    var article: Article
    var statusRaw: String
    var extractedText: String?
    var extractionVersion: Int
    var lastExtractedAt: Date?

    init(
        id: UUID = UUID(),
        article: Article,
        status: BodyExtractionStatus = .pending,
        extractedText: String? = nil,
        extractionVersion: Int = 1,
        lastExtractedAt: Date? = nil
    ) {
        self.id = id
        self.article = article
        self.statusRaw = status.rawValue
        self.extractedText = extractedText
        self.extractionVersion = extractionVersion
        self.lastExtractedAt = lastExtractedAt
    }
}
```

#### Validation rules (Service 層)

`BodyExtractionService.extract(article:)` 内で:

1. **rawHTML 存在チェック**: `article.enrichment?.rawHTML` が nil なら ArticleBody を作成しない (将来再 fetch する spec で対応するため、エンティティを残さない方針)。
2. **抽出結果長さ**: extractedText が 100 文字未満なら `status = .failed`、`extractedText = nil` で保存 (FR-005)。
3. **HTML パース失敗**: 例外時は `status = .failed`、`extractedText = nil` で保存。
4. **extractionVersion**: 本 spec では常に 1 で保存。

#### State transitions

```
pending → extracting → succeeded
                    → failed
                    → permanentlyFailed (将来用、MVP では未到達)
```

- `pending`: ジョブキューイング直後 (初期状態)。
- `extracting`: 抽出実行中 (UI 表示なし、Principle V — UI ノイズ回避、FR-010)。
- `succeeded`: extractedText ≥ 100 文字で抽出完了。
- `failed`: 抽出試みたが短すぎる / 本文見つからない。再抽出は MVP で発生しない。
- `permanentlyFailed`: 将来 retry ロジック追加時の上限到達状態。MVP では未使用。

#### Indexes

- 主キー: `id` (`@Attribute(.unique)`)。
- 二次インデックスは MVP では不要 (relationship 経由のアクセスが主、規模も小さい)。

## Relationships

| 関係 | カーディナリティ | 削除ルール |
|---|---|---|
| `Article` ↔ `ArticleBody` | 1 ↔ 0..1 | Article 削除時に Body も削除 (cascade) |
| `Article` ↔ `ArticleEnrichment` | 1 ↔ 0..1 | (既存、spec 002) |

`ArticleBody` と `ArticleEnrichment` は direct relationship を持たない。両方とも `Article` 経由でアクセスする (Principle III の構造的整合性: Article が source-of-truth)。

将来 spec 予約:
- spec 004 (要約) で `ArticleSummary` が `Article` への non-optional 参照、入力に `ArticleBody.extractedText` を取る予定。
- spec 005 (カテゴリ分類) で `ArticleCategory` が `Article` への many-to-1 参照、入力は `ArticleEnrichment` の summary または `ArticleBody.extractedText` を取る予定。

## Storage location

- spec 001 / 002 と同じ App Group container 配下の SwiftData ストア。
- schema は `Schema([Article.self, ArticleEnrichment.self, ArticleBody.self])` に拡張。
- migration は SwiftData 自動 lightweight migration で吸収 (spec 002 と同じパターン)。
