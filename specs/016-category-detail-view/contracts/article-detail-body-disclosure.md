# Contract: ArticleDetailView 本文 DisclosureGroup 折りたたみ

ArticleDetailView の `bodySection` を `DisclosureGroup("本文を読む", isExpanded: $isBodyExpanded) { ... }` でラップ。初期 collapsed、タップで展開。

## 改修箇所

`KnowledgeTree/Views/ArticleDetailView.swift:365` 付近の `private var bodySection: some View`。

## 改修前 (概略)

```swift
private var bodySection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
        Text("reader.bodySectionTitle")
            .font(DS.Typography.sectionTitle)
        ForEach(paragraphs.indices, id: \.self) { i in
            Text(paragraphs[i])
                .font(DS.Typography.body)
        }
    }
}
```

## 改修後

```swift
@State private var isBodyExpanded: Bool = false   // ArticleDetailView の state に追加

private var bodySection: some View {
    if !paragraphs.isEmpty {
        DisclosureGroup(
            isExpanded: $isBodyExpanded,
            content: {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(paragraphs.indices, id: \.self) { i in
                        Text(paragraphs[i])
                            .font(DS.Typography.body)
                    }
                }
                .padding(.top, DS.Spacing.md)
            },
            label: {
                Text("reader.bodyDisclosureLabel")  // 「本文を読む」
                    .font(DS.Typography.sectionTitle)
            }
        )
        .accessibilityHint("タップして本文を展開")
        .accessibilityIdentifier("reader.bodyDisclosure")
    } else {
        EmptyView()
    }
}
```

## 不変条件

- `paragraphs.isEmpty` 時は DisclosureGroup 自体を出さない (FR-028)
- 初期 `isBodyExpanded == false` (FR-024)
- `isExpanded` バインディングで SwiftUI 標準アニメ (Reduce Motion 自動対応、FR-025)
- 折りたたみ時の本文 view は SwiftUI が render しない (FR-026)
- 折りたたみ状態は記事ごと永続化なし (sheet 起動毎に新 instance、FR-029)

## 既存 layout への影響

- 改修前: `bodySection` は header / tags / knowledge / 関連記事 / 元記事ボタンと同列で常時 render
- 改修後: 本 spec で **本文部分のみ** 折りたたみ。それ以外 (essence / KnowledgeSummary / 関連記事 / タグ / OG 画像 / AI バッジ) は完全に変わらない (FR-027)

## アクセシビリティ

- DisclosureGroup の chevron / disclosure indicator は標準 SwiftUI accessibility 提供
- accessibilityHint で動作説明
- accessibilityIdentifier で UI test の要素特定 (本 spec では UI test なし、将来用)

## Localizable.xcstrings 文言

| Key | 日本語 |
|---|---|
| `reader.bodyDisclosureLabel` | 本文を読む |

(既存 `reader.bodySectionTitle` を `reader.bodyDisclosureLabel` に置換、または新規追加。実装で「本文」→ 「本文を読む」へ文言変更も同時に実施)

## テスト戦略

- DisclosureGroup の SwiftUI 内部挙動は SwiftUI が保証 → unit test 不要
- 状態遷移は `@State` で SwiftUI 管理 → 純関数性なし、unit test しづらい
- **本 spec では unit test なし、quickstart 実機検証で代替** (SC-006 / SC-007)
