# Data Model: UIUX Redesign V3.0

**Branch**: `056-uiux-redesign-v3` | **Date**: 2026-05-24

## Summary

**新規 SwiftData @Model: なし** (UI 専用 spec)。本 spec は UI 再構成のみで、データレイヤー (SwiftData @Model) は完全無変更。

新規 transient struct 4 つ + UserDefaults キー 3 つのみ。

---

## 新規 Transient Struct (4)

### 1. `MixedSurfaceCard` (enum)

**目的**: InterestingNextSection 内で UnderstandingCard と KnowledgeDigest を 1 list に混在表示するための表示単位

**定義場所**: `KnowledgeTree/Services/RecentArticlesService.swift` 末尾 or 新ファイル `KnowledgeTree/Models/MixedSurfaceCard.swift`

```swift
enum MixedSurfaceCard: Identifiable {
    case understanding(UnderstandingCard)
    case digest(KnowledgeDigest)
    
    var id: UUID {
        switch self {
        case .understanding(let card): return card.id
        case .digest(let digest): return digest.id
        }
    }
    
    /// 共通スケール 0-100 (priorityScore normalization)
    var priorityScore: Int {
        switch self {
        case .understanding(let card): return card.priorityScore  // 0-100 既存
        case .digest(let digest):
            // createdAt desc で 60 (新) → 30 (古) スケール
            let daysSinceCreation = Calendar.current.dateComponents([.day], from: digest.createdAt, to: .now).day ?? 999
            return max(30, 60 - daysSinceCreation * 2)
        }
    }
    
    var displayTitle: String { ... }
    var displaySubtitle: String { ... }
    var labelText: String { ... }  // "新しい知識" / "テクノロジー分野" 等
}
```

**ライフサイクル**: 各 InterestingNextSection 描画時に作成、navigation 完了で破棄。永続化なし。

---

### 2. `LibraryDateGroup` (enum)

**目的**: ライブラリの日付別 grouping 区分

**定義場所**: `KnowledgeTree/Services/LibraryDateGrouper.swift`

```swift
enum LibraryDateGroup: String, CaseIterable, Identifiable {
    case today      // 今日 0:00 以降
    case yesterday  // 昨日 0:00 - 今日 0:00
    case thisWeek   // 今週月曜 0:00 - 昨日 0:00
    case thisMonth  // 今月 1 日 0:00 - 今週月曜 0:00
    case earlier    // 今月 1 日 0:00 より前
    
    var id: String { rawValue }
    
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .today: return "library.dateGroup.today"
        case .yesterday: return "library.dateGroup.yesterday"
        case .thisWeek: return "library.dateGroup.thisWeek"
        case .thisMonth: return "library.dateGroup.thisMonth"
        case .earlier: return "library.dateGroup.earlier"
        }
    }
}
```

**ライフサイクル**: LibraryGroupedView 描画時の Section 識別子、純粋関数ベース。

---

### 3. `SuggestedPrompt` (struct, Codable)

**目的**: AI チャット 空状態で表示する 1 つの prompt + その出典 type

**定義場所**: `KnowledgeTree/Services/SuggestedPromptGenerator.swift`

```swift
struct SuggestedPrompt: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String           // 最大 30 字
    let sourceType: SourceType
    
    enum SourceType: String, Codable {
        case latestConceptPage
        case latestCategory
        case fixedSummaryPrompt   // 「最近保存した記事の要点は?」
        case genericFallback
    }
}
```

**ライフサイクル**: SuggestedPromptGenerator が起動時 (タブ表示時) に生成、UserDefaults `spec056_suggested_prompts_cache` に JSON 永続化、同日内は cache から読み取り。

---

### 4. `ActionItemBadgeData` (struct)

**目的**: 「⚠️ 更新が必要 (N)」 badge の count + 内訳

**定義場所**: `KnowledgeTree/Views/FollowingPeopleSection.swift` private struct or 同 view 内 computed

```swift
struct ActionItemBadgeData {
    let conflictCount: Int           // ConflictProposal undecided count
    let staleSavedAnswerCount: Int   // SavedAnswer where isStale == true
    
    var total: Int { conflictCount + staleSavedAnswerCount }
    var shouldShow: Bool { total > 0 }
}
```

**ライフサイクル**: FollowingPeopleSection が `@Query` で取得した 2 配列から body 内で computed、navigation 完了で破棄。

---

## UserDefaults キー (3)

### 1. `spec056_recent_articles_cache` (JSON Array<UUID>)

**目的**: 「最近の記事」セクションの差分ゼロ時に維持する Article ID 配列

- **型**: `[UUID]`、max 3 件
- **JSON encode 形式**: `[{"id":"UUID-string"}, ...]` (`JSONEncoder` 標準)
- **read/write**: `RecentArticlesService.cachedRecentArticleIDs` get/set
- **初期値**: 空配列 (新規 install 時)
- **更新タイミング**: 差分あり時 = fetch 結果の上位 3 件 ID で上書き

### 2. `spec056_suggested_prompts_cache` (JSON struct)

**目的**: AI チャット 空状態 prompt を 1 日 1 回更新、起動毎の再生成負荷回避

- **型**: `SuggestedPromptsCacheEntry` struct (内部定義)

```swift
struct SuggestedPromptsCacheEntry: Codable {
    let date: String       // "yyyy-MM-dd" 形式 (UTC 基準)
    let prompts: [SuggestedPrompt]
}
```

- **JSON encode 形式**: 上記 struct の標準 encode
- **read/write**: `SuggestedPromptGenerator.cache` get/set (private)
- **初期値**: nil (cache miss 扱い)
- **更新タイミング**: date が今日と異なる時 = 再生成 + 新 cache 保存

### 3. `spec056_v3_migrated` (Bool)

**目的**: V2.5 → V3.0 初回起動 onboarding tooltip 表示判定

- **型**: `Bool`
- **read/write**: KnowledgeTreeApp.init() or UnderstandingTabView delete 時の cleanup logic
- **初期値**: `false` (新規 install + 既存 V2.5 ユーザー両方)
- **更新タイミング**: 初回 V3.0 起動完了時 = true 永続化、以降 tooltip 表示しない

---

## 既存 @Model / Service の利用箇所

本 spec は新規 @Model ゼロだが、既存 @Model を以下のように利用:

| 既存 @Model | 利用箇所 |
|---|---|
| `Article` | RecentArticlesSection (差分 fetch) / LibraryGroupedView (全件 fetch + 日付 group) / AddArticleSheet (重複検知) |
| `ConceptPage` | InterestingNextSection (MixedSurfaceCard 構成要素) / FollowingPeopleSection (isFollowing fetch) / SuggestedPromptGenerator (最新 1 件) |
| `KnowledgeDigest` | InterestingNextSection (MixedSurfaceCard 構成要素) |
| `SavedAnswer` | FollowingPeopleSection (isStale count) / ActionItemsReviewView (一覧) |
| `ConflictProposal` | FollowingPeopleSection (undecided count) / ActionItemsReviewView (一覧) |
| `GraphNode` / `GraphEdge` | KnowledgeGraphFullScreenView (Category 単位 subgraph) |
| `UnderstandingInteraction` | InterestingNextSection (UnderstandingCardSurfaceService 経由、間接) |
| `UserTopic` | InterestingNextSection (DynamicTopics integration、Topic Dashboard 形式) |

| 既存 Service | 利用箇所 |
|---|---|
| `UnderstandingCardSurfaceService` (spec 044) | InterestingNextSection (UnderstandingCard surface) |
| `ArticleSavingService` (spec 001) | AddArticleSheet (URL 保存) |
| `LastOpenedStore` (spec 035) | RecentArticlesService (差分判定 since 基準) |
| `RefreshTrigger` | 全新 view (UI 反映) |
| `ServiceContainer` | 全新 service inject |

---

## Schema 変更ゼロ確認

```
新規 @Model: 0
既存 @Model 変更: 0
@Attribute 変更: 0
@Relationship 変更: 0
SharedSchema 変更: 0
lightweight migration 不要
CloudKit schema (spec 051) 影響なし
```

SwiftData 観点では本 spec は **完全に純 UI/Service refactor**。CloudKit Production schema deploy 後にも本 spec の merge は安全 (schema 影響ゼロ)。
