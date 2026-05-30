# Contract: RecentDigest token 削減 (P1-10 / R1)

## 対象

- `KnowledgeTree/Services/RecentDigestService.swift` (`buildPrompt(articles:)` ~:195)

## 変更

### 新規定数

```swift
/// spec 060 (P1-10): buildPrompt に列挙する記事上限。maxArticles=30 (差分判定用) とは別。
static let promptArticleLimit = 8
/// spec 060 (P1-10): prompt 累積文字数の安全上限 (日本語 char≈token、4096 未満を保証)。
static let promptCharBudget = 3000
```

### buildPrompt 改修

```swift
static func buildPrompt(articles: [Article]) -> String {
    var prompt = """ ...固定ヘッダ (件数は articles.count を維持)... """

    let promptArticles = Array(articles.prefix(promptArticleLimit))   // ← 8 件に制限
    for (i, article) in promptArticles.enumerated() {
        let essence = (article.extractedKnowledge?.essence ?? "").prefix(50)   // 60→50
        let firstFact = article.extractedKnowledge?.keyFacts?.first?.statement.prefix(20) ?? ""  // 30→20
        let entry = """ [\(i+1)] \(article.title.prefix(50)) / 要点: \(essence) / 事実: \(firstFact) """
        if prompt.count + entry.count > promptCharBudget { break }   // ← token 概算ガード
        prompt += entry
    }

    prompt += """ ...固定フッタ (出力形式)... """
    return prompt
}
```

## 契約条件

| 条件 | 期待 |
|---|---|
| 50 件 Article (title/essence 長め) | `buildPrompt(articles:).count` ≤ 3500 (SC-001) |
| promptArticleLimit=8 | 9 件目以降の title が prompt に含まれない |
| 件数表示 (固定ヘッダ「件数 N」) | `articles.count` (= 最大 30) を維持 (FR-005) |
| articleCount (RecentDigestResult) | 変更なし (maxArticles=30 不変) |
| AI 不可端末 fallback | essence ベース簡易ヘッドライン維持 (無改修、FR-004) |
| 記事 0〜数件 | buildPrompt 正常動作 (prefix が空/少数でも安全) |

## テスト

- `testBuildPromptStaysUnderCharBudget`: 50 件で `.count <= 3500`
- `testBuildPromptLimitsArticleCount`: 9 件目以降の固有 title が prompt に非含有
