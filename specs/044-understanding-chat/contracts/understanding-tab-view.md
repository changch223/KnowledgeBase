# Contract: UnderstandingTabView

**Feature**: spec 044 Understanding Chat
**Type**: SwiftUI View
**File**: `KnowledgeTree/Views/UnderstandingTabView.swift`

## Definition

```swift
struct UnderstandingTabView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var services: ServiceContainer
    @State private var cards: [UnderstandingCard] = []
    @State private var allCount: Int = 0
    @State private var isLoading = false

    var body: some View
}
```

## Layout

```text
NavigationStack {
    ScrollView {
        LazyVStack(spacing: 12) {
            if isLoading && cards.isEmpty {
                ProgressView()
            } else if cards.isEmpty {
                UnderstandingEmptyState()        // "まだ学ぶカードがありません..."
            } else {
                ForEach(cards) { card in
                    NavigationLink(value: card) {
                        UnderstandingCardRow(card: card)
                    }
                    .buttonStyle(.plain)
                }
                if allCount > cards.count {
                    NavigationLink(value: UnderstandingCardListDestination()) {
                        Text("+\(allCount - cards.count) すべて見る")
                            .font(.callout)
                            .foregroundStyle(DesignSystem.actionBlue)
                            .padding(.vertical, 8)
                    }
                    .accessibilityIdentifier("link.allCards")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    .navigationTitle("学習")
    .navigationDestination(for: UnderstandingCard.self) { card in
        DeepDiveChatView(card: card)
    }
    .navigationDestination(for: UnderstandingCardListDestination.self) { _ in
        UnderstandingCardListView()
    }
    .task { await refresh() }
    .refreshable { await refresh() }
}
```

## Behavior

- `.task` で initial load (1 秒以内、SC-001)
- `.refreshable` でユーザー pull-to-refresh 可
- `cards` は上位 5 件 (surfaceService.surfaceTopCards(limit: 5))
- `allCount` は surfaceService.surfaceAllCards().count (paginated UI へのカウント表示用)
- 空状態 placeholder は `UnderstandingEmptyState` view

## refresh()

```swift
private func refresh() async {
    guard let surfaceService = services.understandingCardSurfaceService else { return }
    isLoading = true
    defer { isLoading = false }
    cards = await surfaceService.surfaceTopCards(limit: 5)
    allCount = (await surfaceService.surfaceAllCards()).count
}
```

## Accessibility

- `accessibilityIdentifier`:
  - tab item: `tab.learning` (KnowledgeTreeApp tabItem 側で設定)
  - empty state: `state.understanding.empty`
  - 各 card: `card.understanding.{kindString}.{id.uuidString}` (CardRow 側で設定)
  - +N link: `link.allCards`
- VoiceOver: NavigationLink label が「カード」+ titleText + label名

## Performance

- 上位 5 カード表示 1 秒以内 (SC-001)
- 空状態 表示 1 秒以内 (SC-007)

## Test Coverage

- UI test (UnderstandingTabUITests):
  - 学習タブ起動で content または empty state が表示
  - カードあり時、最初のカードタップで DeepDiveChatView 遷移
  - 「+N すべて見る」タップで UnderstandingCardListView 遷移
- Unit test (SurfaceService 経由で間接的に検証、View 単体テストなし)

## Constitution Compliance

- V (calm UX): empty state は迷路化しない静かな案内、unread バッジなし ✅
- VI (architecture): View は Service に DI、ロジック層分離 ✅
- VII (日本語ファースト): 「学習」「すべて見る」「まだ学ぶカードがありません...」xcstrings 経由 ✅
