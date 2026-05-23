# Contract: `ConceptPage` @Model

**File**: `KnowledgeTree/Models/ConceptPage.swift` (新規、~80 行)
**Type**: SwiftData persistent model

## Purpose

複数の保存記事に登場する entity (人物 / モノ / 概念) を統合した「概念ページ」を SwiftData
で永続化する。新記事 ingest で自動生成・自動更新され、ユーザーは閲覧 + rename / merge /
delete / pin で補正できる。

## Public API

```swift
import Foundation
import SwiftData

@Model
final class ConceptPage {
    @Attribute(.unique) var id: UUID
    var name: String
    var nameAliases: [String]
    var categoryRaw: String
    var summary: String
    var crossSourceInsights: [String]

    @Relationship(deleteRule: .nullify)
    var relatedArticles: [Article] = []

    var relatedConceptIDs: [UUID]
    var userUnderstanding: Int
    var isFollowing: Bool
    var isStale: Bool

    @Attribute(.externalStorage)
    var embedding: Data?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        nameAliases: [String] = [],
        categoryRaw: String,
        summary: String = "",
        crossSourceInsights: [String] = [],
        relatedArticles: [Article] = [],
        relatedConceptIDs: [UUID] = [],
        userUnderstanding: Int = 0,
        isFollowing: Bool = false,
        isStale: Bool = true,
        embedding: Data? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    )
}

extension ConceptPage {
    var searchableNames: [String] { get }      // 全 lowercased + aliases
    var summaryPreview: String { get }          // 1 行 preview
    var isSynthesisInProgress: Bool { get }    // summary 空 or isStale
}
```

## Behavior

- `init` 時 `isStale = true` (デフォルト) → BGTask が再合成
- `searchableNames` は同名判定で使用 (大文字小文字無視 + aliases 考慮)
- `isSynthesisInProgress` は ConceptPageDetailView で「整理中…」placeholder 表示判定
  に使用

## Validation

- name: ConceptPageStore.rename 側で空文字 / 30 字超を reject (Model 側は構造のみ強制)
- summary: 500 chars 超は Service post-process で trim、Model 側は制約なし
- crossSourceInsights: 7 件超は Service post-process で truncate、Model 側は制約なし
- categoryRaw: spec 015 と同 vocab、Service 側で enum mapping

## SwiftData Schema Integration

- `SharedSchema.all` に `ConceptPage.self` 追加で全 ModelContainer 構築箇所 (main app +
  Tests) で自動利用可能
- lightweight migration: 新規 @Model 追加なので既存 store からのスキーマ進化は不要
- Tests は `ModelContainer(for: ConceptPage.self, configurations: .init(isStoredInMemoryOnly: true))`
  または `SharedSchema.all` 経由で構築

## Acceptance Criteria

- [x] `ConceptPage` を SwiftData store に save / fetch できる
- [x] `relatedArticles` で Article 削除時に ConceptPage 側が nullify される (Article は残る)
- [x] `embedding` が Data? として外部 storage に保存される (row サイズ膨らまない)
- [x] `searchableNames` で大文字小文字無視 lookup が in-memory で可能
- [x] 既存全テスト suite が SharedSchema 拡張後も PASS する
