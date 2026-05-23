# Contract: `SavedAnswerDetailView`

**File**: `KnowledgeTree/Views/SavedAnswerDetailView.swift` (新規、~200 行)
**Type**: SwiftUI View (NavigationStack destination)

## Purpose

SavedAnswer の詳細画面。質問 / AI 答え / 引用記事 / 関連概念ページを縦 scroll で表示、toolbar に [ピン] + [削除] を配置。spec 042 ConceptPageDetailView と同 `@Query live check` パターンで削除時 crash 回避。

## Public API

```swift
import SwiftUI
import SwiftData

struct SavedAnswerDetailView: View {
    @Bindable var answer: SavedAnswer
    /// 削除時に空になる reactive guard (spec 042 と同パターン)
    @Query private var liveMatches: [SavedAnswer]

    init(answer: SavedAnswer) {
        self.answer = answer
        let id = answer.id
        _liveMatches = Query(filter: #Predicate<SavedAnswer> { $0.id == id })
    }

    var body: some View { ... }
}
```

## Visual Layout

```
┌─────────────────────────────────────────────────┐
│ [< Back]   保存された答え          [📌] [🗑️]   │  ← toolbar: pin + delete
├─────────────────────────────────────────────────┤
│                                                 │
│  保存: 3 日前  ·  自動保存  ·  📌 ピン          │  ← header (savedAt + auto/manual + pin badge)
│                                                 │
│  ─────────────────────────────────────────     │
│  質問                                            │
│                                                 │
│  Apple Vision Pro について教えて                 │  ← question (.dsBody)
│                                                 │
│  ─────────────────────────────────────────     │
│  答え                                            │
│                                                 │
│  Apple Vision Pro は…(AI 答え本文)…である。     │  ← answer (.dsBody, lineSpacing)
│                                                 │
│  ─────────────────────────────────────────     │
│  引用された記事 (3)                              │
│                                                 │
│  ▸ Apple Vision Pro 発表 (2026-04-20)          │  ← NavigationLink → ArticleDetailView
│  ▸ Tim Cook インタビュー (2026-04-25)           │
│  ▸ Vision Pro 価格戦略 (2026-05-01)            │
│                                                 │
│  ─────────────────────────────────────────     │
│  関連する概念ページ (2)                         │
│                                                 │
│  [Apple Vision Pro] [Tim Cook]                  │  ← chip 状の NavigationLink
│                                                 │
└─────────────────────────────────────────────────┘
```

## Sections

### 1. `headerSection`

- 保存日時 (`SavedAtFormatter.format`)
- 自動保存ラベル: `savedAutomatically ? "自動保存" : "手動保存"`
- pin badge: `answer.isPinned ? "📌 ピン" : ""`
- ピン状態は live update (Toggle 連動)

### 2. `questionSection`

- セクションタイトル「質問」(.dsSectionTitle)
- `Text(answer.question).font(.dsBody)` 折りたたみなし

### 3. `answerSection`

- セクションタイトル「答え」
- `Text(answer.answer).font(.dsBody).lineSpacing(DS.Typography.bodyLineSpacing)`
- 改行は SwiftUI が auto rendering

### 4. `citedArticlesSection`

- セクションタイトル「引用された記事 (N)」
- ForEach (citedArticles.sorted savedAt desc):
  - `NavigationLink(value: article)` → 既存 ArticleDetailView (spec 042 と同経路)
- 0 件: 「引用記事は削除されました」placeholder

### 5. `relatedConceptsSection`

- `relatedConceptIDs.isEmpty` → セクション非表示
- セクションタイトル「関連する概念ページ (N)」
- relatedConceptIDs から ConceptPage を fetch (in-memory)
- `FlowingTagsLayout` (spec 042 既存) で chip 表示
- `NavigationLink(value: ConceptPageDetailDestination(id: page.id))` で遷移

## Toolbar

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Toggle(isOn: pinBinding) {
            Image(systemName: answer.isPinned ? "pin.fill" : "pin")
        }
        .toggleStyle(.button)
        .accessibilityIdentifier("savedAnswerDetail_pinToggle")
    }
    ToolbarItem(placement: .topBarTrailing) {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Image(systemName: "trash")
        }
        .accessibilityIdentifier("savedAnswerDetail_deleteButton")
    }
}
.alert("この答えを削除", isPresented: $showDeleteConfirm) {
    Button("削除", role: .destructive) {
        try? services.savedAnswerService?.delete(answer)
        // dismiss は live check が自動で実行
    }
    Button("キャンセル", role: .cancel) {}
} message: {
    Text("引用された記事は残ります。")
}
```

## Live Check Pattern (重要)

`body` 冒頭で `isAlive` short-circuit:

```swift
var body: some View {
    if !isAlive {
        Color.clear.onAppear { dismiss() }
    } else {
        aliveBody
    }
}

private var isAlive: Bool { !liveMatches.isEmpty }
```

削除 → SwiftData 観測通知 → `liveMatches` 空 → body 再評価 → `Color.clear.onAppear { dismiss() }` 短絡 → @Bindable answer プロパティ参照ゼロ → crash 回避。spec 042 で確立済パターン。

## Navigation Destinations

親 view (KnowledgeClipView or SettingsView 経由の HistoryView) で `.navigationDestination(for: SavedAnswerDetailDestination.self) { dest in SavedAnswerDetailLoader(id: dest.id) }` を配線。

`SavedAnswerDetailLoader` (補助 view) は ID から SavedAnswer を fetch、なければ ContentUnavailableView (削除済対応):

```swift
struct SavedAnswerDetailLoader: View {
    let destinationID: UUID
    @Environment(\.dismiss) private var dismiss
    @Query private var matchingAnswers: [SavedAnswer]

    init(destinationID: UUID) {
        self.destinationID = destinationID
        let id = destinationID
        _matchingAnswers = Query(filter: #Predicate<SavedAnswer> { $0.id == id })
    }

    var body: some View {
        if let answer = matchingAnswers.first {
            SavedAnswerDetailView(answer: answer)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }
}
```

## Accessibility

- 各セクションに `accessibilityIdentifier` (`savedAnswerDetail_questionSection` 等)
- Dynamic Type / Dark Mode / VoiceOver 対応

## Acceptance Criteria

- [x] 質問 / 答え / 引用記事 / 関連概念ページの 5 セクション表示
- [x] 引用記事タップで ArticleDetailView 遷移 (1 秒以内、SC-004)
- [x] 関連概念ページ chip タップで ConceptPageDetailView 遷移
- [x] toolbar pin / delete 動作 + 削除時 alert 確認
- [x] 削除後 live check で自動 navigation pop (crash なし)
- [x] Dark Mode / Dynamic Type 正常表示
