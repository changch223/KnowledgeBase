# Contract: UnderstandingCardRow

**Feature**: spec 044 Understanding Chat
**Type**: SwiftUI View
**File**: `KnowledgeTree/Views/UnderstandingCardRow.swift`

## Definition

```swift
struct UnderstandingCardRow: View {
    let card: UnderstandingCard

    var body: some View
}
```

## Layout

```text
HStack(spacing: 12) {
    iconView                           // SF Symbol (concept or saved answer)
        .font(.title2)
        .foregroundStyle(iconColor)
        .frame(width: 32, height: 32)

    VStack(alignment: .leading, spacing: 4) {
        Text(card.titleText)
            .font(.body)
            .foregroundStyle(DesignSystem.dsPrimaryText)
            .lineLimit(2)
        HStack(spacing: 8) {
            LabelBadge(label: card.label)
            if let lastInteracted = card.lastInteractedAt {
                Text(SavedAtFormatter.relative(from: lastInteracted))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.dsSecondaryText)
            }
        }
    }
    Spacer(minLength: 0)
    Image(systemName: "chevron.right")
        .foregroundStyle(DesignSystem.dsSecondaryText)
        .font(.callout)
}
.padding(12)
.background(DesignSystem.dsCardBackground)
.clipShape(RoundedRectangle(cornerRadius: 12))
.accessibilityIdentifier("card.understanding.\(card.kindString).\(card.id.uuidString)")
.accessibilityElement(children: .combine)
.accessibilityLabel(accessibilityLabelText)
```

## iconView

```swift
@ViewBuilder
private var iconView: some View {
    switch card.kind {
    case .conceptPage:
        Image(systemName: "lightbulb.fill")
    case .savedAnswer:
        Image(systemName: "quote.bubble.fill")
    }
}

private var iconColor: Color {
    switch card.kind {
    case .conceptPage: return DesignSystem.actionBlue
    case .savedAnswer: return DesignSystem.dsAccent
    }
}
```

## LabelBadge Sub-View

```swift
struct LabelBadge: View {
    let label: UnderstandingCardLabel

    var body: some View {
        Text(label.localizationKey)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.2))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch label {
        case .newKnowledge: return .green
        case .needsUpdate: return .orange
        case .shallow: return .yellow
        case .deepDive: return .blue
        case .review: return .gray
        }
    }
}
```

## Accessibility

```swift
private var accessibilityLabelText: String {
    let kindStr = card.kind.kindString == "conceptPage" ? "概念" : "質問"
    let labelStr = NSLocalizedString(card.label.localizationKey.stringKey, comment: "")
    return "\(kindStr): \(card.titleText)、\(labelStr)"
}
```

## Performance

- 単一 row 描画 < 16ms (60fps)
- 100+ 件 LazyVStack で 60fps (SC-006)

## Test Coverage

- Visual test (snapshot 推奨だが Phase A scope 外): 全 5 label の色とテキストが正しい
- Unit test: LabelBadge の localizationKey 解決 + iconView の SF Symbol 名
- UI test: UnderstandingTabUITests で card tap → DeepDiveChatView 遷移確認

## Constitution Compliance

- V (calm UX): badge 色は 5 種で穏やか、unread バッジなし ✅
- VI (architecture): View は card transient 1 つのみ依存、Service 直接呼ばない ✅
- VII (日本語ファースト): label / titleText 全て xcstrings + ConceptPage.name / SavedAnswer.question の日本語値 ✅
