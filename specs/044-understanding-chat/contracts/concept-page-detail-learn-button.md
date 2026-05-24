# Contract: ConceptPageDetailView 「学習する」Button (P2 US9)

**Feature**: spec 044 Understanding Chat
**Type**: SwiftUI View 改修
**File**: `KnowledgeTree/Views/ConceptPageDetailView.swift`

## 改修内容

既存 `ConceptPageDetailView` の toolbar (右上、`.topBarTrailing`) に **「学習する」Button** を追加。tap で `UnderstandingCard.fromConceptPage(conceptPage)` を作り、`navigationPath.append(card)` で DeepDiveChatView を push。

## Code

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            let card = UnderstandingCard.fromConceptPage(conceptPage, label: .deepDive)
            navigationPath.append(card)
        } label: {
            Label("学習する", systemImage: "book.fill")
        }
        .accessibilityIdentifier("button.learn")
    }
    // 既存 toolbar item (ピン / 編集 / 削除) はそのまま保持
}
```

ConceptPageDetailView 親 (KnowledgeClipView や CategoryFilteredListView) で:
```swift
.navigationDestination(for: UnderstandingCard.self) { card in
    DeepDiveChatView(card: card)
}
```
を追加必要。spec 042 で既に `navigationDestination(for: ConceptPageDetailDestination.self)` 等を持っているので、同パターン追加。

## navigationPath

ConceptPageDetailView は既に @Binding navigationPath を持っている (spec 042 SavedAnswer detail jump 用)。本 spec で UnderstandingCard 用に流用、新規 binding 不要。

## Behavior

- 「学習する」tap → 3 秒以内に DeepDiveChatView の AI 初期発話表示 (SC-002 と同じ)
- chat 画面で「✓ わかった」→ DB 反映後、navigation pop で ConceptPageDetailView に戻る (userUnderstanding +1 が「いま分かっていること」セクションに反映)
- ConceptPage が他経路 (merge/delete) で消えた場合、@Query live check で auto dismiss (spec 042 既存 pattern)

## Accessibility

- `accessibilityIdentifier`: `button.learn`
- `accessibilityLabel`: 「この概念を学習する」(VoiceOver)
- SF Symbol: `book.fill` (学習の概念に合致)

## Constitution Compliance

- VI (architecture): 既存 navigationDestination + UnderstandingCard transient + DeepDiveChatStarter 経由、層分離維持 ✅
- VII (日本語ファースト): 「学習する」label xcstrings 経由 ✅

## Test Coverage

- UI test: ConceptPageDetailView 開く → 「学習する」tap → DeepDiveChatView 起動 + AI 初期発話表示
- 既存 ConceptPage 詳細 test は影響受けない (toolbar item 追加のみ、既存挙動破壊なし)
