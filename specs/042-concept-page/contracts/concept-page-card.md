# Contract: `ConceptPageCard` View

**File**: `KnowledgeTree/Views/ConceptPageCard.swift` (新規、~80 行)
**Type**: SwiftUI View

## Purpose

知識 Clip タブ「あなたが追っている人物・モノ」セクションに表示する ConceptPage カード。
タップで ConceptPageDetailView に遷移する。spec 015 KnowledgeCategoryRow と同 visual
language (DesignSystem token + SF Symbol + アクセシビリティ完備)。

## Public API

```swift
import SwiftUI

struct ConceptPageCard: View {
    let conceptPage: ConceptPage

    var body: some View { ... }
}
```

## Visual Layout

```
┌────────────────────────────────────────────────┐
│ [Icon] Apple                          [📌 5]  │  ← isFollowing + relatedArticles.count
│ AI が「Apple」について複数記事を統合した…       │  ← summaryPreview lineLimit(1)
│ 最終更新: 3 日前                                │  ← SavedAtFormatter 流用
└────────────────────────────────────────────────┘
```

- Icon: categoryRaw に応じた SF Symbol
  - person.fill (人物)
  - building.2.fill (組織)
  - cube.fill (モノ / 製品)
  - lightbulb.fill (概念 / アイデア)
  - その他: tag.fill
- 名前: `font(.dsBodyEmphasized)`
- 関連記事数 badge: `Image(systemName: "doc.text.fill")` + count、`font(.dsCaption)`
- isFollowing 時: 右上に `Image(systemName: "pin.fill")` を tint `.dsActionBlue`
- summary preview: `font(.dsBody)`, `foregroundStyle(.secondary)`, `lineLimit(1)`,
  `truncationMode(.tail)`
  - `summary.isEmpty` または `isStale` の時は「整理中…」を gray で表示
- 最終更新: `SavedAtFormatter.relative(from: conceptPage.updatedAt)` (今日/昨日/N日前/絶対)
- カード全体: `padding(.dsContentPadding)`, `background(Color.dsCardBackground)`,
  `clipShape(RoundedRectangle(cornerRadius: 12))`

## State

なし (read-only view、@Bindable 不要)。

## Accessibility

- `accessibilityIdentifier("conceptPageCard_\(conceptPage.id.uuidString)")`
- `accessibilityLabel("\(conceptPage.name)、関連記事 \(count) 件、\(summaryPreview)")`
- VoiceOver で 1 要素として読み上げ (`accessibilityElement(children: .combine)`)
- Dynamic Type 対応 (DesignSystem token 使用で自動)

## Layout Performance

- 1 カードあたり 3 行固定、`prefix(5)` で上位 5 件のみ render → 60fps 維持 (SC-007)
- summary は preview 1 行のみ表示で reflow コスト最小化

## Acceptance Criteria

- [x] Icon が categoryRaw に応じて切り替わる
- [x] 関連記事数 badge が表示される
- [x] isFollowing pin icon が表示される (pin 時のみ)
- [x] summary が空 / isStale 時に「整理中…」placeholder 表示
- [x] 最終更新が SavedAtFormatter 形式で表示
- [x] Dynamic Type / Dark Mode で正常表示
- [x] VoiceOver で意味のある label 読み上げ
