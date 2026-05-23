# Contract: `SavedAnswerSection` View

**File**: `KnowledgeTree/Views/SavedAnswerSection.swift` (新規、~80 行)
**Type**: SwiftUI View (ConceptPageDetailView 内 section)

## Purpose

ConceptPage 詳細画面の 5 番目セクション「この概念についての質問と答え (N)」。関連 SavedAnswer を上位 5 件表示、6 件以上は「+N すべて見る」リンク。

## Public API

```swift
struct SavedAnswerSection: View {
    let conceptPageID: UUID
    @Query private var allAnswers: [SavedAnswer]

    init(conceptPageID: UUID) {
        self.conceptPageID = conceptPageID
        _allAnswers = Query(
            sort: [SortDescriptor(\SavedAnswer.savedAt, order: .reverse)]
        )
    }

    var body: some View { ... }
}
```

## Visual Layout

```
─────────────────────────────────────────
この概念についての質問と答え (8)

📌 Apple Vision Pro の価格は…       3 件引用 · 今日
   Apple Vision Pro はどう違う?      2 件引用 · 昨日
   Vision Pro と Quest の比較は?    3 件引用 · 3 日前
   …
   +5 すべて見る →
─────────────────────────────────────────
```

- ピン済 (📌) は上に表示
- 各 row は質問 preview (40 字) + 引用件数 + savedAt (相対 / 絶対)
- 5 件超は「+N すべて見る」リンク (NavigationLink → SavedAnswerListByConceptDestination)

## Behavior

```swift
/// in-memory filter + sort (SwiftData @Predicate は [UUID].contains を直接サポートしないため)
private var relatedAnswers: [SavedAnswer] {
    allAnswers
        .filter { $0.relatedConceptIDs.contains(conceptPageID) }
        .sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.savedAt > rhs.savedAt
        }
}

var body: some View {
    if relatedAnswers.isEmpty {
        EmptyView()  // 0 件で section 自体非表示
    } else {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(String(format: String(localized: "ConceptPage.detail.savedAnswers.title"), relatedAnswers.count))
                .font(.title3.bold())

            ForEach(relatedAnswers.prefix(5), id: \.id) { answer in
                NavigationLink(value: SavedAnswerDetailDestination(id: answer.id)) {
                    SavedAnswerRow(answer: answer)
                }
                .buttonStyle(.plain)
            }

            if relatedAnswers.count > 5 {
                NavigationLink(value: SavedAnswerListByConceptDestination(conceptPageID: conceptPageID)) {
                    Text(String(format: String(localized: "ConceptPage.detail.savedAnswers.showAll"), relatedAnswers.count - 5))
                        .font(.caption)
                        .foregroundStyle(DS.Color.actionBlue)
                }
            }
        }
        .accessibilityIdentifier("conceptPageDetail_savedAnswersSection")
    }
}
```

## Integration with ConceptPageDetailView

`ConceptPageDetailView.aliveBody` で 5 番目セクションとして追加:

```swift
VStack(alignment: .leading, spacing: DS.Spacing.section) {
    headerSection
    summarySection
    crossSourceInsightsSection
    relatedArticlesSection
    SavedAnswerSection(conceptPageID: conceptPage.id)   // ★ 5 番目 (relatedConceptsSection の前)
    relatedConceptsSection
}
```

配置順の理由: 「関連記事 → この概念についての質問と答え → つながる人物・モノ」で「ソース → 蓄積 → 関連」の論理順。

## Acceptance Criteria

- [x] 関連 SavedAnswer 0 件で section 非表示 (Constitution V calm UX)
- [x] 1+ 件で section 表示、ピン済が上位
- [x] 上位 5 件 + 「+N すべて見る」リンク
- [x] row タップで SavedAnswerDetailView 遷移
- [x] 「+N すべて見る」タップで SavedAnswer フィルター済 list 画面遷移 (将来 SavedAnswerListByConceptView は MVP では SavedAnswerHistoryView を代用、conceptPageID filter 適用)
