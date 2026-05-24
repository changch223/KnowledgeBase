# Phase 1 Data Model: Understanding Chat

**Feature**: spec 044 Understanding Chat
**Date**: 2026-05-23

spec 044 で導入される SwiftData @Model 1 つ + UI 用 transient struct 群を定義。既存 @Model (ConceptPage / SavedAnswer / ChatSession / Article / GraphNode / GraphEdge) はそのまま流用、本 spec で **改修ゼロ**。

---

## 1. UnderstandingInteraction (新 @Model)

ユーザーの学習行動履歴を永続化する SwiftData entity。集計 (FR-021) と surface 優先度補正 (dismissed) に利用。

```swift
import Foundation
import SwiftData

@Model
final class UnderstandingInteraction {
    @Attribute(.unique) var id: UUID
    var targetKind: String     // "conceptPage" / "savedAnswer" / "article"
    var targetID: UUID         // ConceptPage.id / SavedAnswer.id / Article.id
    var action: String         // "understood" / "needMore" / "openedChat" / "dismissed" / "propagated"
    var occurredAt: Date

    init(
        id: UUID = UUID(),
        targetKind: String,
        targetID: UUID,
        action: String,
        occurredAt: Date = .now
    ) {
        self.id = id
        self.targetKind = targetKind
        self.targetID = targetID
        self.action = action
        self.occurredAt = occurredAt
    }
}
```

**Fields**:

| Field | Type | Optional | 説明 |
|-------|------|----------|------|
| `id` | `UUID` | No (unique) | 主キー、自動生成 |
| `targetKind` | `String` | No | 対象 entity の種類。enum `Kind.rawValue` |
| `targetID` | `UUID` | No | 対象 entity の id (ConceptPage.id 等)。@Relationship なしの弱結合 |
| `action` | `String` | No | ユーザー操作種別。enum `Action.rawValue` |
| `occurredAt` | `Date` | No | 行動発生時刻、`Date.now` default |

**Type-safe enum (Swift 側で wrap)**:

```swift
extension UnderstandingInteraction {
    enum Kind: String {
        case conceptPage
        case savedAnswer
        case article
    }
    enum Action: String {
        case understood     // ✓ わかった
        case needMore       // 🤔 もっと
        case openedChat     // カードタップで chat 起動
        case dismissed      // ✗ 違う
        case propagated     // 1-hop 波及 (内部 action、UI 露出なし)
    }

    var kindEnum: Kind? { Kind(rawValue: targetKind) }
    var actionEnum: Action? { Action(rawValue: action) }
}
```

**Validation rules** (Service 層で enforce):
- `targetKind` は `Kind` 列挙のいずれか
- `action` は `Action` 列挙のいずれか
- `targetID` は対象 entity 存在時のみ insert (削除済 entity への参照は許容、孤立残存 OK)

**Relationships**: なし (孤立 ID 参照のみ、ConceptPage / SavedAnswer 削除でも残存)

**Indexes**: SwiftData default (id unique のみ)、`targetID` predicate fetch が頻繁なら将来 index 検討

**Migration**: lightweight (新規 @Model 1 つ追加、既存 schema 改変なし)、SharedSchema に `UnderstandingInteraction.self` 1 行追加で自動

---

## 2. UnderstandingCard (transient struct)

学習タブで surface される統一カード。SwiftData @Model **ではない** (永続化不要、表示専用)。`UnderstandingCardSurfaceService.surfaceTopCards()` が ConceptPage / SavedAnswer を都度 wrap して返却。

```swift
struct UnderstandingCard: Identifiable, Hashable {
    let id: UUID                       // 元 entity.id
    let kind: UnderstandingCardKind
    let priorityScore: Int             // surface 順位 (内部、UI 非表示)
    let label: UnderstandingCardLabel
    let lastInteractedAt: Date?        // 行動履歴最新 occurredAt
}

enum UnderstandingCardKind: Hashable {
    case conceptPage(ConceptPage)
    case savedAnswer(SavedAnswer)

    var kindString: String {
        switch self {
        case .conceptPage: return "conceptPage"
        case .savedAnswer: return "savedAnswer"
        }
    }
}

enum UnderstandingCardLabel: String, Hashable, CaseIterable {
    case newKnowledge   // 「新しい知識」
    case needsUpdate    // 「更新が必要」
    case shallow        // 「理解が浅い」
    case deepDive       // 「深掘り余地あり」
    case review         // 「復習」

    var localizationKey: LocalizedStringKey {
        switch self {
        case .newKnowledge: return "understanding.label.newKnowledge"
        case .needsUpdate: return "understanding.label.needsUpdate"
        case .shallow: return "understanding.label.shallow"
        case .deepDive: return "understanding.label.deepDive"
        case .review: return "understanding.label.review"
        }
    }
}

extension UnderstandingCard {
    var titleText: String {
        switch kind {
        case .conceptPage(let page): return page.name
        case .savedAnswer(let answer): return answer.question.prefix(80).description
        }
    }
    var deepDiveTitle: String {
        "\(titleText) を深掘り"
    }
    static func fromConceptPage(_ page: ConceptPage, label: UnderstandingCardLabel = .deepDive, lastInteractedAt: Date? = nil) -> UnderstandingCard {
        UnderstandingCard(
            id: page.id,
            kind: .conceptPage(page),
            priorityScore: 0,
            label: label,
            lastInteractedAt: lastInteractedAt
        )
    }
}
```

**State transitions**: なし (transient、再構築されるたび新規)

---

## 3. UnderstandingCardListDestination (Hashable struct)

「+N すべて見る」NavigationLink 用 transient destination。

```swift
struct UnderstandingCardListDestination: Hashable {
    let scope: Scope = .all   // 将来拡張用 (例: .conceptOnly, .savedAnswerOnly)
    enum Scope: Hashable { case all }
}
```

---

## 4. UnderstandingCardSurfaceContext (transient, 内部)

SurfaceService が scoring 時に持つ計算用 context、外部公開なし。

```swift
struct UnderstandingCardSurfaceContext {
    let now: Date
    let dismissedTargetIDs: Set<UUID>      // dismissed action 既往の UUID 集合
    let lastInteractedMap: [UUID: Date]    // targetID → 最新 occurredAt
    let articleRecentSavedAtMap: [UUID: Date]  // ConceptPage.id → 関連記事最新 savedAt (shallow 判定用)
}
```

---

## 5. SharedSchema 拡張

`SharedSchema.swift` に 1 行追加:

```swift
enum SharedSchema {
    static let all: [any PersistentModel.Type] = [
        Article.self,
        Tag.self,
        // ... (既存)
        ConceptPage.self,
        SavedAnswer.self,
        UnderstandingInteraction.self,  // ★ spec 044 追加
    ]
}
```

ShareExtension + SafariExtension target にも `UnderstandingInteraction.swift` を pbxproj 追加 (spec 042 / 043 同手順)。

---

## 6. 既存 @Model 利用 (改修ゼロ)

本 spec で **改修しない** 既存 @Model:

| @Model | 利用箇所 | 改修 |
|--------|---------|------|
| ConceptPage (spec 042) | Surface 主対象 / userUnderstanding +1 直接記録先 | **なし** (userUnderstanding 既存フィールドのみ使用) |
| SavedAnswer (spec 043) | Surface 副対象 / isStale 判定 / relatedConceptIDs 解決 | **なし** |
| ChatSession (spec 021) | DeepDiveChatStarter で都度新規作成 + title 設定 | **なし** (既存 title setter 使用) |
| ChatMessage (spec 021) | ChatService.ask 経由で自動生成 | **なし** |
| Article (spec 001) | ConceptPage 関連記事の savedAt 参照 (shallow 判定) | **なし** |
| GraphNode / GraphEdge (spec 040) | 1-hop 波及で参照 | **なし** |
| Tag (spec 008) | 本 spec では未使用 | **なし** |

---

## 7. Predicate / FetchDescriptor 一覧

主要 fetch pattern (各 service で使用):

```swift
// UnderstandingInteraction で dismissed 既往 targetID 集合
let dismissedDescriptor = FetchDescriptor<UnderstandingInteraction>(
    predicate: #Predicate { $0.action == "dismissed" }
)

// 最近 30 日の interaction (lastInteractedAt 計算用)
let cutoff = Date.now.addingTimeInterval(-30 * 86400)
let recentDescriptor = FetchDescriptor<UnderstandingInteraction>(
    predicate: #Predicate { $0.occurredAt >= cutoff },
    sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
)

// 当月の understood 件数 (P3 統計)
let monthStart = Calendar.current.startOfMonth(for: .now)
let monthlyDescriptor = FetchDescriptor<UnderstandingInteraction>(
    predicate: #Predicate { $0.action == "understood" && $0.occurredAt >= monthStart }
)

// 新規 ConceptPage (24h 以内)
let dayCutoff = Date.now.addingTimeInterval(-86400)
let newConceptDescriptor = FetchDescriptor<ConceptPage>(
    predicate: #Predicate { $0.createdAt >= dayCutoff && $0.userUnderstanding == 0 }
)

// isStale な SavedAnswer
let staleAnswerDescriptor = FetchDescriptor<SavedAnswer>(
    predicate: #Predicate { $0.isStale == true },
    sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
)

// userUnderstanding 低 (0-1) ConceptPage
let shallowDescriptor = FetchDescriptor<ConceptPage>(
    predicate: #Predicate { $0.userUnderstanding <= 1 }
)
```

すべて in-memory ModelContainer で動作確認可、fetchLimit 必要な場合は 50-100 で境界付け。

---

## 8. ER 図 (簡略)

```
         ┌──────────────────────┐
         │ ConceptPage          │
         │ (spec 042、改修なし) │
         │ + userUnderstanding   │
         └──────────┬───────────┘
                    │ (id 弱結合)
                    │
┌──────────────────┴──────────────────────┐
│ UnderstandingInteraction (★ 新規)         │
│ - targetKind: "conceptPage"/"savedAnswer"│
│ - targetID: UUID                          │
│ - action: "understood"/"needMore"/...     │
│ - occurredAt: Date                        │
└──────────────────┬──────────────────────┘
                    │ (id 弱結合)
                    │
         ┌──────────┴───────────┐
         │ SavedAnswer          │
         │ (spec 043、改修なし) │
         │ + isStale             │
         └──────────────────────┘

Surface 経路:
  ConceptPage + SavedAnswer + UnderstandingInteraction
    ↓ (SurfaceService)
  [UnderstandingCard] (transient)
    ↓ (UI ForEach + NavigationLink)
  DeepDiveChatView → ChatService (spec 021)
                   → UnderstandingTrackerService (本 spec)
                      ↓
                   UnderstandingInteraction insert + ConceptPage.userUnderstanding +1
                      ↓
                   1-hop 波及 (GraphTraversalService, spec 040)
                      ↓
                   neighbor ConceptPage に propagated 記録
```

---

## 9. データ完全性 / Constitution 整合

- **Constitution I (privacy)**: UnderstandingInteraction 全件 local SwiftData、外部送信ゼロ
- **Constitution III (source 追跡)**: 本 spec は AI 生成物を作らない (deep dive chat の AI 答えは ChatService 経由で既存 citedArticles 保持)。UnderstandingInteraction は行動 log のみで「生成物」ではない、Constitution III 該当箇所なし
- **Constitution VI (architecture)**: @Model は永続化、transient は UI 表示専用と層分離明示
- **Constitution V (calm UX)**: UnderstandingInteraction は内部 metric、UI には surface 順位補正と P3 統計 (0 件で非表示) のみで露出

データモデル設計完了、Phase 1 contracts へ進む。
