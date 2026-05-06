# Data Model — AI Chat (RAG)

**spec**: 021 / **date**: 2026-05-06

## 新 @Model

### ChatSession

```swift
@Model
final class ChatSession {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var lastMessageAt: Date
    var title: String  // 最初の user message の先頭 30 文字、空なら "新しいチャット"

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage] = []

    init(id: UUID = UUID(), createdAt: Date = .now, lastMessageAt: Date = .now, title: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
        self.title = title
    }
}
```

**制約**:
- `id` unique
- `messages` cascade delete (session 削除で全 message も削除)
- 50 件上限 FIFO (R9): ChatService.createSession() 内で enforced

---

### ChatMessage

```swift
@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var session: ChatSession?  // inverse は ChatSession.messages
    var role: String  // "user" | "assistant"
    var text: String
    var citedArticleIDs: [String]  // Article.id (UUID 文字列) 配列、role=="assistant" 時のみ意味あり
    var timestamp: Date

    init(id: UUID = UUID(), session: ChatSession?, role: String, text: String, citedArticleIDs: [String] = [], timestamp: Date = .now) {
        self.id = id
        self.session = session
        self.role = role
        self.text = text
        self.citedArticleIDs = citedArticleIDs
        self.timestamp = timestamp
    }
}
```

**制約**:
- `id` unique
- `role` は "user" or "assistant" (enum 化は SwiftData 制約あり、検証は Service 層)
- `citedArticleIDs` は `[String]`、Article.id (UUID 文字列)、Article 削除追従なし (R8)
- `session` が delete された時 cascade で本 message も削除

**Why citedArticleIDs is `[String]` not `@Relationship`**:
- 履歴の不変性 — 引用元 Article が削除されても会話履歴は残るべき (R8)
- 循環参照回避 (Article ↔ ChatMessage の双方向 relationship は SwiftData で扱いづらい)

---

## 既存 @Model 改修

### Article (既存) — `essenceEmbedding` 追加

```swift
@Model
final class Article {
    // ... 既存 attributes ...

    /// spec 021: NLEmbedding.sentenceEmbedding(for: .japanese) で生成した
    /// L2 正規化済み 文章 embedding。Data 形式 (Float Array byte 表現)。
    /// nil = 未生成 (Apple Intelligence 不可 or 旧データ)。
    @Attribute(.externalStorage) var essenceEmbedding: Data?
}
```

**Why `Data?` not `[Float]?`**:
- SwiftData `[Float]` は Codable 経由で内部 JSON 化 → サイズ膨張
- `Data` + `.externalStorage` は別 blob file 保存 → SQLite 軽量化
- `[Float]` ↔ `Data` zero-copy 変換 (`withUnsafeBufferPointer`) で性能影響なし

**Migration**:
- SwiftData lightweight migration (新 optional attribute、既存記事は nil 開始)
- backfill 不要 — 起動時 / 新規保存時に都度生成
- 将来 spec で「全記事 backfill」追加可 (spec 013 AutoTagBackfillRunner と同パターン)

---

## SharedSchema 拡張

```swift
enum SharedSchema {
    static let all: [any PersistentModel.Type] = [
        Article.self,
        ArticleEnrichment.self,
        ArticleBody.self,
        ExtractedKnowledge.self,
        KeyFact.self,
        KnowledgeEntity.self,
        Tag.self,
        KnowledgeChunkProgress.self,
        BackgroundExtractionQueueEntry.self,
        KnowledgeDigest.self,
        ChatSession.self,   // 【新規】spec 021
        ChatMessage.self,   // 【新規】spec 021
    ]
}
```

App Group 共有 — Share / Safari / App Intent extension からも触れる (将来拡張のため)。

---

## Transient 構造

### ChatRetrievalResult (Service 層、永続化なし)

```swift
struct ChatRetrievalResult {
    let articles: [(article: Article, similarity: Float)]  // top-k=5、similarity 降順
    let mode: RetrievalMode

    enum RetrievalMode {
        case embedding   // 通常
        case keyword     // NLEmbedding 不可 fallback
    }
}
```

### ChatAnswerOutput (`@Generable`)

```swift
@Generable
struct ChatAnswerOutput {
    @Guide(description: "ユーザーの質問への回答。3 段落以内。参考記事に答えがない場合は『分かりません』と回答。")
    let answer: String

    @Guide(description: "回答に使った記事の ID 配列 (Article.id 文字列)。参考記事に答えがない場合は空配列。")
    let citedArticleIDs: [String]
}
```

---

## SwiftData migration 計画

| 段階 | 変更 | 影響 |
|---|---|---|
| 1 | `Article.essenceEmbedding: Data?` 追加 | lightweight、既存 nil |
| 2 | `ChatSession` / `ChatMessage` @Model 追加 | 新 schema、empty 開始 |
| 3 | SharedSchema.all に 2 model 追加 | App + 全 extension target で同期 |

**回帰リスク**: lightweight migration なので既存データ保持。新規 attribute (Article) + 新規 model (Chat*) のみ。

---

## エンティティ関係図

```
ChatSession 1 ──< (cascade) ChatMessage *
                                      ↓ citedArticleIDs: [String]
                                      ↓ (loose, no relationship)
                            Article (id: UUID)
                                      ↓ essenceEmbedding: Data?
                                      ↓ (新規 attribute)
```

ChatMessage と Article は loose link — Article 削除追従なし、UI 側で「記事が見つかりません」表示。
