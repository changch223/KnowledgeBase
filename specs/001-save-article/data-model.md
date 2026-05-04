# Data Model: 記事保存 (Share Sheet 経由) — Phase 1

**Feature**: spec 001 — 記事保存 (Share Sheet 経由)
**Date**: 2026-05-04

## Entities

### `Article`

保存された 1 件の記事を表す。

#### Attributes

| Field | Type | Optional | Default | Description |
|---|---|---|---|---|
| `id` | `UUID` | No | `UUID()` | 一意識別子 (主キー)。 |
| `url` | `String` | No | — | 元記事の URL (絶対 URL 文字列、http/https のみ受理)。重複検出のキー。 |
| `title` | `String` | No | — | 記事タイトル。Share payload 由来。空文字列の場合はサービス層で URL ホスト名にフォールバック (FR-009) してから永続化する。 |
| `savedAt` | `Date` | No | `Date()` | 保存日時。一覧の並べ替えキー。重複保存時は更新しない (FR-015)。 |

#### SwiftData macro 構成 (実装ガイド)

```swift
import Foundation
import SwiftData

@Model
final class Article {
    @Attribute(.unique) var id: UUID
    var url: String
    var title: String
    var savedAt: Date

    init(id: UUID = UUID(), url: String, title: String, savedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.savedAt = savedAt
    }
}
```

注: `url` には `@Attribute(.unique)` を **付けない**。重複検出はサービス層で `FetchDescriptor` を用いて事前判定する (research.md / R3 参照)。

#### Validation rules

サービス層 (`ArticleSavingService`) で以下を実施し、`Article` インスタンス化前に reject する:

1. **URL の存在**: nil または空文字列の場合は `.missingURL` エラー (FR-008)。
2. **URL スキーム**: `URL` パース成功し、`scheme == "http" || scheme == "https"` のみ受理。それ以外は `.unsupportedScheme` エラー (Edge Case)。
3. **重複チェック**: 既存レコードの `url` と完全一致するエントリが 1 件以上存在する場合は `.duplicate` エラー (FR-014 / FR-015)。

#### Indexes

- 主キー: `id` (`@Attribute(.unique)`)。
- 推奨: `url` への二次インデックス (重複検出クエリのパフォーマンス向上)。SwiftData の `#Index` マクロが提供されたら追加する。本 spec では数千件規模なら問題ないため未追加。100,000 件超を想定するフェーズで再評価。

#### State transitions

- **挿入**: `ArticleSavingService.save(...)` で validation 通過後 1 回のみ。
- **削除**: `ArticleStore.delete(article)` でユーザーがスワイプ削除した時のみ (US3 / FR-007)。
- **更新**: 本 spec では発生しない (重複保存でも savedAt を bump しない、FR-015)。将来 enrichment spec で本文 / description / OG image 等が追加されるが、それらは別エンティティへの relationship として扱う想定 (本 entity は immutable な事実を保持)。

## Relationships (将来予約)

本 spec では `Article` は他のエンティティと relationship を持たない。

将来 spec の予約:
- spec 002 (本文取得・メタデータエンリッチメント) で `ArticleEnrichment` (description、OG image URL、本文) が `Article` への 1-to-1 関係として追加される予定。
- spec 003 (要約) で `Summary` が `Article` への 1-to-1 関係として追加され、`Article` への参照は **non-optional** (Constitution Principle III)。
- spec 004 (カテゴリ分類) で `Category` が `Article` への many-to-1 関係として追加される予定。

これらすべての派生データは `Article` への non-optional 参照を持つことが Constitution Principle III の要件。本 spec の `Article` 設計は、それらが後で安全に追加できる土台 (id 主キー、削除時の cascade ルール) を確保する。

## Storage location

- **本番**: App Group container (`group.<reverse-domain>.knowledgetree.shared`) 配下のデフォルト SQLite ファイル。
- **テスト**: `ModelConfiguration(isStoredInMemoryOnly: true)` (Constitution Quality Gate / テスト)。
