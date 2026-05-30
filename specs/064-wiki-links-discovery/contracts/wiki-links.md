# Contract: AI 本文リンク + 表示遷移 (Phase 2 / R2-R4)

## buildWikiBodyPrompt 拡張 (ConceptSynthesisService)
```swift
static func buildWikiBodyPrompt(conceptPage:articles:linkCandidates:) -> String
// linkCandidates: [(name: String, id: UUID)] = []  ← default で後方互換
```
候補を `- 名前 → concept-id://UUID` 形式 (name 30 字 truncate、最大 8) + schema.md「Wiki リンクルール」を prompt に embed。

## sanitizeConceptLinks (static 純関数)
```swift
static func sanitizeConceptLinks(in markdown: String, validIDs: Set<UUID>) -> String
```
regex `\[([^\]]+)\]\(concept-id://(UUID)\)` → UUID が validIDs に無ければ `名前` にプレーン化。generateBodyMarkdown の trimmed 直後に適用。

## extractConceptID (ConceptPageDetailView static、spec 033 流用)
```swift
static func extractConceptID(from url: URL) -> UUID?
// url.scheme == "concept-id" → host を UUID 化
```

## wikiBodySection OpenURLAction
```swift
Text(Self.renderMarkdown(conceptPage.bodyMarkdown))
    .environment(\.openURL, OpenURLAction { url in
        if let id = Self.extractConceptID(from: url) {
            onConceptLinkTap?(ConceptPageDetailDestination(id: id)); return .handled
        }
        return .systemAction
    })
```
+ `var onConceptLinkTap: ((ConceptPageDetailDestination) -> Void)? = nil` を DetailView に追加、push 親で配線。

## 契約条件
| 条件 | 期待 |
|---|---|
| 候補内リンク | 色付き表示 + tap で遷移 (SC-003) |
| 候補外/捏造 UUID | プレーン化、dead link なし (SC-004 / FR-006) |
| 本文生成 AI 回数 | 従来と同じ 1 回 (FR-007 / SC-005) |
| リンク先削除 | reactive guard で auto-dismiss、crash なし (FR-009) |
| renderMarkdown 失敗 | plain text fallback (既存) |
