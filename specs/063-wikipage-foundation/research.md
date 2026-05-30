# Research: WikiPage 土台

行番号は 2026-05-30 main @ `aa36a45` 時点。

---

## R1: ConceptPage に 4 フィールド追加 (CloudKit 安全)

**Decision**: `Models/ConceptPage.swift` に default 付き 4 フィールド追加。

```swift
var bodyMarkdown: String = ""        // AI が書く Wiki 本文
var kindRaw: String = "concept"      // WikiPageKind rawValue
var isHidden: Bool = false           // ユーザー非表示
var bodyEditedByUser: Bool = false   // 訂正保護フラグ (FR-007)
```

init に 4 引数追加 (全 default)。

**Rationale**: spec 051 で CloudKit Production deploy 済。lightweight migration の安全条件は「optional または default 付きの追加」。String/Bool に default を付けるので完全に安全 (Article.essenceEmbedding 等の前例多数)。SharedSchema.swift は ConceptPage 登録済 (`:40`) ゆえ**無改修** = フィールド追加は schema 配列を変えない。これが CloudKit 安全性の核。

**Alternatives**: 新 WikiPage @Model (案 B) → 二重管理 + record type 孤児化リスク。ConceptPage が既に 6/8 フィールド持つので却下。

---

## R2: WikiPageKind enum

**Decision**: `enum WikiPageKind: String, CaseIterable { case person, concept, project }` + 表示プロパティ。

```swift
extension ConceptPage {
    var kind: WikiPageKind {
        get { WikiPageKind(rawValue: kindRaw) ?? .concept }
        set { kindRaw = newValue.rawValue }
    }
}
enum WikiPageKind: String, CaseIterable {
    case person, concept, project
    var displayNameKey: String { ... }   // 人物/概念/プロジェクト
    var symbolName: String { ... }       // person.fill / lightbulb.fill / folder.fill
}
```

**Rationale**: Apple Foundation Models は @Generable enum 非対応 (spec 044/057 既知)。String rawValue 保存 + Swift enum 変換パターンで型安全を確保。CaseIterable で編集 Picker に流用。

---

## R3: generateWikiBody plain string 生成 (token 回避の核)

**Decision**: `LanguageModelSessionProtocol` に `func generateWikiBody(prompt: String) async throws -> String` 追加。FoundationModelLanguageModelSession 実装は `generateTutorReply` (`:355-359`) と同型:
```swift
func generateWikiBody(prompt: String) async throws -> String {
    let session = LanguageModelSession()
    let response = try await session.respond(to: prompt)
    return response.content
}
```

**現状確認 (verified)**: `generateTutorReply` / `generateConceptSummaryChunk` が既に `session.respond(to: prompt)` で plain String を返している (`:355-364`)。**@Generable schema を渡さない呼び出し方が確立済**。

**Rationale**: @Generable (ExtractedKnowledgeOutput 等) は schema serialization で ~1500 token 消費 (spec 060/062 で判明)。plain string respond は schema ゼロ → 同じ入力でも token 大幅減。bodyMarkdown は長文だが、出力 schema コストが無いぶん入力に回せる。

**Mock**: MockLanguageModelSession に `nextWikiBodyResult: Result<String, Error>?` + `wikiBodyCallCount` 追加。

**Alternatives**: @Generable WikiBodyOutput → schema コストで token 圧迫、回避目的に反する。却下。

---

## R4: bodyMarkdown 生成 hook (ConceptSynthesisService)

**Decision**: `resynthesize` の summary 生成後に bodyMarkdown 生成を追加。

```
1. bodyEditedByUser == true → bodyMarkdown 生成スキップ (ユーザー訂正保護、FR-007)
2. availability.isAvailable:
   prompt = buildWikiBodyPrompt(conceptPage, relatedArticles)  // summary + essence 圧縮入力
   body = try await session.generateWikiBody(prompt: prompt)
   非空なら conceptPage.bodyMarkdown = body
   空なら既存 bodyMarkdown 保持 (防御)
3. availability なし or throw → bodyMarkdown が空なら summary を流用 (fallback)
4. kind = inferKind(from: relatedArticles の KnowledgeEntity.type)
```

**kind 判定**: relatedArticles → extractedKnowledge → entities の type を集計。person/organization 優勢 → .person、それ以外 → .concept (project は当面なし、将来拡張)。kindRaw が既にユーザー編集済なら維持。

**token**: buildWikiBodyPrompt は既存圧縮定数 (perArticleEssenceMaxChars 等) を流用して入力を絞る。hierarchical 経路 (記事多数) でも入力上限を設ける。

**Rationale**: resynthesize は既に Ingest の中核 hook。summary の隣に bodyMarkdown を足すのが自然。bodyEditedByUser でユーザー訂正を守る (VISION 原則 2)。

---

## R5/R6/R7: Markdown 表示 + 訂正 + フィルタ

**R5 (表示)**: ConceptPageDetailView の summary セクション下に:
```swift
if !conceptPage.bodyMarkdown.isEmpty,
   let attributed = try? AttributedString(markdown: conceptPage.bodyMarkdown,
       options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
    Text(attributed)
}
```
見出し・箇条書きを活かすには full markdown parsing が要る。`AttributedString(markdown:)` の `interpretedSyntax` を検証 (full は段落のみ、見出しは限定的 → 必要なら行分割レンダリング)。失敗時 plain text fallback。kind バッジ (symbol + 種別名) を header に。toolbar に isHidden トグル → 非表示で dismiss。

**R6 (訂正)**: ConceptPageEditSheet に bodyMarkdown TextEditor + kind Picker (WikiPageKind.allCases)。保存時 `bodyEditedByUser = true`。

**R7 (フィルタ)**: ConceptPageListView (KnowledgeClipView 内) / FollowingPeopleSection の `@Query` predicate に `isHidden == false`。`#Predicate<ConceptPage> { !$0.isHidden }`。

**注意**: `AttributedString(markdown:)` の見出し対応は iOS で限定的。spec の「見出し・箇条書き」を満たすには、bodyMarkdown を行単位で分割し見出し行を Text の font 変えてレンダリングする簡易レンダラが要るかもしれない (実装時に AttributedString full parsing の挙動を確認して判断)。

---

## R8: iknow-schema.md 追記

**Decision**: `Resources/iknow-schema.md` に「## Wiki 本文生成ルール」セクション追記。SchemaLoader (spec 058) が読む。
- 見出し構成 (## 概要 / ## 詳細 / ## 関連) の推奨
- 箇条書き活用、文字数目安 (300-800 字)
- 推測禁止 (relatedArticles に明示されたことのみ、source 追跡)
- 日本語

**Rationale**: spec 058 で schema 外出し機構 (SchemaLoader + bundle 同梱) が完成済。Wiki 本文の書き方を schema に置けば、prompt 内 embed でなく外部調整可能。

---

## R9: テスト戦略

**Decision**: `WikiBodyGenerationTests` 新規 5 ケース:
1. generateWikiBody 成功 → bodyMarkdown に反映
2. availability なし → summary を bodyMarkdown に fallback
3. bodyEditedByUser=true → 生成スキップ (既存 bodyMarkdown 維持)
4. kind 判定: person entity 優勢 → .person / concept → .concept
5. 空 AI 出力 → 既存 bodyMarkdown 保持

既存 ConceptSynthesisServiceTests は summary 生成不変ゆえ regression のみ。Mock 拡張 (nextWikiBodyResult) は default で既存テスト互換。

**検証コマンド**:
```bash
xcodebuild clean build -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO
```
