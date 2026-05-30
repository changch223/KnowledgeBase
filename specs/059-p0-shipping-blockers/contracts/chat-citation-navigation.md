# Contract: Chat 引用リンク navigation (P0-4 / R4) ★肝

## 対象

- `KnowledgeTree/Views/ChatMessageRow.swift`
- `KnowledgeTree/Views/ChatTabView.swift`

## ChatMessageRow 変更

### 追加 property

```swift
/// spec 059 (P0-4): 引用リンク tap 時に親へ Article を通知。nil の時は遷移しない。
var onArticleLinkTap: ((Article) -> Void)? = nil
```

### OpenURLAction 変更 (現 :64-71)

```swift
.environment(\.openURL, OpenURLAction { url in
    if let id = Self.extractArticleID(from: url),
       let article = allArticles.first(where: { $0.id == id }) {
        onArticleLinkTap?(article)   // ← _ = article を置換
        return .handled
    }
    return .systemAction
})
```

## ChatTabView 変更

### call site (現 :63)

```swift
ChatMessageRow(
    message: message,
    streamingTextOverride: streamingID == message.id ? streamingText : nil,
    onArticleLinkTap: { navigationPath.append($0) }   // ← 追加
)
```

`navigationPath` (`:32`) と `.navigationDestination(for: Article.self)` (既存) は無改修。

## 契約条件

| 条件 | 期待 |
|---|---|
| 引用リンク tap + 該当 Article 存在 | `navigationPath` に append → ArticleDetailView push |
| 引用リンク tap + 該当 Article 不在 (削除済等) | callback 呼ばれず `.systemAction`、遷移なし、クラッシュなし (FR-009) |
| streaming 表示中 (`streamingTextOverride != nil`) | plain Text フォールバック、link 無効 (既存挙動維持、FR-010) |
| streaming 完了後 | AttributedString 表示、link 有効、tap で遷移 |
| CitedArticlesSection / RelatedConceptsChips / ClarificationChipsView | 無改修、既存挙動維持 |

## テスト (任意 unit)

- `extractArticleID(from:)` を `static` 昇格 (private 解除) し、`article-id://<valid-uuid>` → UUID 抽出、不正 URL → nil を 1-2 ケース検証。UI 寄りのため必須ではない。
