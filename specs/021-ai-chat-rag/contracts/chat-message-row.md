# Contract — ChatMessageRow

**spec**: 021 / **file**: `KnowledgeTree/Views/ChatMessageRow.swift` (new)

## 役割

1 message を表示。role に応じた layout + assistant の引用記事 footnote。

## 構成

```swift
struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer(minLength: 40)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 40)
            }
        }
    }

    private var userBubble: some View {
        Text(message.text)
            .padding(DS.Spacing.lg)
            .foregroundStyle(.white)
            .background(DS.Color.actionBlue, in: RoundedRectangle(cornerRadius: 16))
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(message.text)
                .foregroundStyle(.primary)
            if !message.citedArticleIDs.isEmpty {
                CitedArticlesSection(articleIDs: message.citedArticleIDs)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
    }
}

private struct CitedArticlesSection: View {
    let articleIDs: [String]
    @Query private var allArticles: [Article]

    private var citedArticles: [Article] {
        let idSet = Set(articleIDs)
        return allArticles.filter { idSet.contains($0.id.uuidString) }
    }

    var body: some View {
        DisclosureGroup {
            ForEach(citedArticles) { article in
                NavigationLink(value: article) {
                    HStack {
                        Text(article.title).font(.caption).lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } label: {
            Text("chat.message.cited.count \(citedArticles.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

## 動作

- user: 右寄せ actionBlue 背景 white text
- assistant: 左寄せ dsCardBackground、下に DisclosureGroup で引用記事一覧
- 引用記事が DB に存在しない (削除済) → `citedArticles` から除外、表示数 0 なら DisclosureGroup 非表示

## Constitution

- III (source 追跡): citedArticleIDs → 実 Article fetch → NavigationLink で詳細
- V (calm UX): バブル design は actionBlue 1 色 + neutral card
