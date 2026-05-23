# Contract: `SavedAnswerHistoryView` + `SavedAnswerRow`

**Files**:
- `KnowledgeTree/Views/SavedAnswerHistoryView.swift` (新規、~150 行) — 全 list + 検索 P3
- `KnowledgeTree/Views/SavedAnswerRow.swift` (新規、~80 行) — 履歴 / セクション内 row

## Purpose

SavedAnswer 全履歴画面 + 共通 row。Settings → 「保存された答えの履歴」NavigationLink で開く独立画面。

## SavedAnswerRow

### Public API

```swift
struct SavedAnswerRow: View {
    let answer: SavedAnswer

    var body: some View { ... }
}
```

### Visual Layout

```
┌──────────────────────────────────────────────┐
│ 📌 Apple Vision Pro の価格は…   3 件引用 · 今日│  ← 1 行レイアウト
└──────────────────────────────────────────────┘
```

- 📌 pin icon (条件付き)
- question preview (40 字、`answer.questionPreview` 使用)
- 引用件数 (`citedArticles.count` 件引用)
- savedAt 相対 (`SavedAtFormatter.format` 流用)

### Implementation

```swift
struct SavedAnswerRow: View {
    let answer: SavedAnswer

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            if answer.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.actionBlue)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(answer.questionPreview)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: DS.Spacing.sm) {
                    Text(String(format: String(localized: "SavedAnswer.row.citedCount"), answer.citedArticles.count))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(SavedAtFormatter.format(answer.savedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(answer.questionPreview), 引用 \(answer.citedArticles.count) 件, \(SavedAtFormatter.accessibilityText(answer.savedAt))")
        .accessibilityIdentifier("savedAnswerRow_\(answer.id.uuidString)")
    }
}
```

## SavedAnswerHistoryView

### Public API

```swift
struct SavedAnswerHistoryView: View {
    @Query(sort: [SortDescriptor(\SavedAnswer.savedAt, order: .reverse)])
    private var allAnswers: [SavedAnswer]
    @State private var searchText: String = ""

    init() {}

    var body: some View { ... }
}
```

### Visual Layout

```
┌────────────────────────────────────────┐
│ [< Back]   保存された答え               │  ← navigationTitle
├────────────────────────────────────────┤
│ 🔍 保存された答えを検索                  │  ← .searchable
├────────────────────────────────────────┤
│ 📌 Apple Vision Pro の価格は…  3 · 今日 │  ← LazyVStack で SavedAnswerRow
│    Vision Pro と Quest の違い  2 · 昨日 │
│    AI モデルの最新情報        4 · 3 日前│
│    …                                    │
└────────────────────────────────────────┘
```

### Implementation

```swift
struct SavedAnswerHistoryView: View {
    @Query(sort: [SortDescriptor(\SavedAnswer.savedAt, order: .reverse)])
    private var allAnswers: [SavedAnswer]
    @State private var searchText: String = ""

    init() {}

    /// isPinned 優先 + savedAt desc (in-memory)、検索時は SearchService.searchSavedAnswers
    private var displayedAnswers: [SavedAnswer] {
        let baseSort = allAnswers.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.savedAt > rhs.savedAt
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return baseSort }
        return SearchService.searchSavedAnswers(query: trimmed, in: baseSort).map(\.savedAnswer)
    }

    var body: some View {
        Group {
            if displayedAnswers.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "SavedAnswer.empty.title" : "SavedAnswer.search.empty.title",
                    systemImage: searchText.isEmpty ? "quote.bubble" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "SavedAnswer.empty.description" : "SavedAnswer.search.empty.description")
                )
                .accessibilityIdentifier("savedAnswerHistory_empty")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedAnswers, id: \.id) { answer in
                            NavigationLink(value: SavedAnswerDetailDestination(id: answer.id)) {
                                SavedAnswerRow(answer: answer)
                                    .padding(.horizontal, DS.Spacing.xxl)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .padding(.leading, DS.Spacing.xxl)
                        }
                    }
                    .padding(.vertical, DS.Spacing.md)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("SavedAnswer.history.title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "SavedAnswer.search.prompt")
        .navigationDestination(for: SavedAnswerDetailDestination.self) { dest in
            SavedAnswerDetailLoader(destinationID: dest.id)
        }
        .accessibilityIdentifier("savedAnswerHistory_root")
    }
}
```

## Entry Point (SettingsView)

`SettingsView` 内に NavigationLink 追加 (既存 settings list の中に section として):

```swift
Section("SavedAnswer.section.title") {
    NavigationLink {
        SavedAnswerHistoryView()
    } label: {
        Label("SavedAnswer.history.title", systemImage: "quote.bubble")
    }
    .accessibilityIdentifier("settings.savedAnswerHistory")
}
```

## Acceptance Criteria

- [x] @Query で全 SavedAnswer fetch、isPinned 優先 + savedAt desc で表示
- [x] LazyVStack で 100+ 件でも 60fps 維持 (SC-005)
- [x] 検索 (P3): SearchService.searchSavedAnswers 経由、空 query で全件、query あればスコア順
- [x] 空状態 ContentUnavailableView (検索ヒットなし vs 履歴 0 件 で別文言)
- [x] Settings からの navigation entry
- [x] row タップで SavedAnswerDetailView 遷移
- [x] Dark Mode / Dynamic Type / VoiceOver 対応
