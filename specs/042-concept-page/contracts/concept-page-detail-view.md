# Contract: `ConceptPageDetailView`

**File**: `KnowledgeTree/Views/ConceptPageDetailView.swift` (新規、~200 行)
**Type**: SwiftUI View (NavigationStack 内 destination)

## Purpose

ConceptPage の詳細画面。4 セクション (今わかっていること / 横断的知見 / 関連記事 /
つながる人物・モノ) を縦 scroll で表示、toolbar に [編集] と [ピン] を配置。spec.md
US3 + FR-022/023/024/025/026 を実装。

## Public API

```swift
import SwiftUI
import SwiftData

struct ConceptPageDetailView: View {
    @Bindable var conceptPage: ConceptPage

    var body: some View { ... }
}
```

## Visual Layout

```
┌──────────────────────────────────────────────────┐
│  [< Back]              Apple        [📌] [⋯]    │  ← toolbar: ピン toggle + 編集 ⋯
├──────────────────────────────────────────────────┤
│                                                  │
│  Apple                                           │  ← header: name (.dsHeadlineLarge)
│  [テクノロジー]  関連記事 5 件  最終更新 3 日前   │  ← chip + 統計 (.dsCaption)
│                                                  │
│  ─────────────────────────────────────────────  │
│  今わかっていること                              │  ← summarySection title (.dsSectionTitle)
│                                                  │
│  Apple は…(AI 合成 200-400 字、断定調)…である。 │  ← summary 本文 (.dsBody)
│                                                  │
│  ─────────────────────────────────────────────  │
│  横断的知見                                       │
│                                                  │
│  • 2024 年から M5 搭載で…                        │  ← bullet list (各 50-150 字)
│  • Tim Cook の発言から見える…                    │
│                                                  │
│  ─────────────────────────────────────────────  │
│  関連記事 (5)                                     │
│                                                  │
│  ▸ Apple の新製品発表 (2026-05-01)               │  ← NavigationLink → ArticleDetailView
│  ▸ Tim Cook インタビュー (2026-04-20)            │
│  ...                                             │
│                                                  │
│  ─────────────────────────────────────────────  │
│  つながる人物・モノ (3)                          │
│                                                  │
│  [Tim Cook] [Foundation Models] [iPhone]         │  ← chip 状の NavigationLink
│                                                  │
└──────────────────────────────────────────────────┘
```

## Sections

### 1. `headerSection`

- `Text(conceptPage.name).font(.dsHeadlineLarge)`
- カテゴリー chip (`Text(categoryDisplay).padding(.horizontal).background(.dsChipBackground)`)
- 統計 row: `Text("関連記事 \(count) 件 ・ 最終更新 \(relative)")`

### 2. `summarySection`

- セクションタイトル `Text("今わかっていること").font(.dsSectionTitle)`
- 本文:
  - `conceptPage.isSynthesisInProgress` → 「整理中… AI が複数記事を統合しています」
    + ProgressView (sized small, gray)
  - それ以外: `Text(conceptPage.summary).font(.dsBody)`
- 折りたたみなし、常に展開 (短文 200-400 字想定)

### 3. `crossSourceInsightsSection`

- `conceptPage.crossSourceInsights.isEmpty` → セクション自体非表示
- それ以外:
  - セクションタイトル `Text("横断的知見").font(.dsSectionTitle)`
  - ForEach (各 insight): `HStack(alignment: .top) { Text("•"); Text(insight) }`
  - `.font(.dsBody)`, `.padding(.vertical, 4)`

### 4. `relatedArticlesSection`

- セクションタイトル `Text("関連記事 (\(count))").font(.dsSectionTitle)`
- 0 件: 「関連記事はまだありません」placeholder
- 1+ 件: ForEach (Article、savedAt desc):
  - `NavigationLink(value: articleDestination) { ArticleRowCompact(article: article) }`
  - ArticleRowCompact = title + savedAt の 2 行 (新規 view OR 既存 ArticleRow 流用)
- 関連記事タップで ArticleDetailView に遷移 (FR-023, SC-010)

### 5. `relatedConceptsSection`

- `conceptPage.relatedConceptIDs.isEmpty` → セクション自体非表示
- それ以外:
  - セクションタイトル `Text("つながる人物・モノ (\(count))").font(.dsSectionTitle)`
  - FetchDescriptor で relatedConceptIDs に該当する ConceptPage を取得 (最大 8 件)
  - chip layout (FlowLayout or HStack with wrap):
    - `NavigationLink(value: ConceptPageDetailDestination(id: other.id)) {
         Text(other.name).chip()
       }`
  - 他 ConceptPage 詳細に再帰遷移可能 (FR-024)

## Toolbar

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Toggle(isOn: $conceptPage.isFollowing) {
            Label("ピン", systemImage: conceptPage.isFollowing ? "pin.fill" : "pin")
        }
        .toggleStyle(.button)
        .accessibilityIdentifier("conceptPageDetail_pinToggle")
    }
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            showEditSheet = true
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityIdentifier("conceptPageDetail_editButton")
    }
}
.sheet(isPresented: $showEditSheet) {
    ConceptPageEditSheet(conceptPage: conceptPage, store: store)
}
```

- ピン Toggle は `@Bindable` で直接 conceptPage.isFollowing をバインド (即時 DB 反映は
  onChange で store.setFollowing 呼び出し、または `@Bindable` 経由で SwiftData
  autosave に任せる)
- 編集 ⋯ ボタンで ConceptPageEditSheet を modal 表示

## Navigation Destinations

NavigationStack の `.navigationDestination` で対応:

```swift
.navigationDestination(for: ConceptPageDetailDestination.self) { dest in
    if let page = fetchConceptPage(by: dest.id) {
        ConceptPageDetailView(conceptPage: page)
    }
}
```

`ConceptPageDetailDestination(id:)` は Hashable struct (data-model.md 参照)。

## State

- `@State private var showEditSheet: Bool = false`
- `@Environment(\.modelContext) private var context`
- `@Environment(\.refreshTrigger)` (既存環境値) - 再合成完了通知の auto-refresh 用
- `@State private var store: ConceptPageStore?` (環境注入経由 or .task で初期化)

## Accessibility

- 各セクションに `accessibilityIdentifier`:
  - `conceptPageDetail_header`
  - `conceptPageDetail_summarySection`
  - `conceptPageDetail_crossSourceInsightsSection`
  - `conceptPageDetail_relatedArticlesSection`
  - `conceptPageDetail_relatedConceptsSection`
- Dynamic Type / Dark Mode / VoiceOver 対応 (DesignSystem token 使用)

## Acceptance Criteria

- [x] 4 セクションが順次表示される (空セクションは非表示)
- [x] 「整理中…」placeholder が summary 空 or isStale 時に表示される
- [x] 関連記事タップで ArticleDetailView に遷移する (1 秒以内、SC-010)
- [x] 関連概念タップで該当 ConceptPageDetailView に再帰遷移する (FR-024)
- [x] toolbar [ピン] toggle で isFollowing が即時 DB 反映 + UI 更新
- [x] toolbar [編集 ⋯] で ConceptPageEditSheet 表示
- [x] Dark Mode / Dynamic Type で正常表示
