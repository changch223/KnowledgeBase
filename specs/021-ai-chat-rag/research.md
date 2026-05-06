# Research — AI Chat (RAG)

**spec**: 021 / **branch**: `019-chrome-app-intent` (継続) / **date**: 2026-05-06

plan.md `Technical Context` の NEEDS CLARIFICATION を全て解決する。

---

## R1: Apple Intelligence Embedding API か NLEmbedding か

**Decision**: **NaturalLanguage `NLEmbedding.sentenceEmbedding(for: .japanese)`** を採用。

**Rationale**:
- iOS 14+ で確立 API、Apple Intelligence 不可端末でも動作 (constitution IV)
- 文章 embedding (512 次元) を直接取得、単語平均 (mean pooling) の自前実装不要
- on-device、外部送信ゼロ (constitution I)
- Foundation Models (iOS 26+) には現状 public な embedding API は確認できず、`@Generable` 経由の generate のみ

**Alternatives considered**:
- Foundation Models embedding API: API 不在、pending Apple announcement
- NLEmbedding wordEmbedding + mean pooling: 300 次元、文脈無視の単語平均で精度低下
- NLContextualEmbedding (iOS 17+): BERT 系 contextual、より高精度だが Japanese サポート未確認 + 複雑
- 外部 LLM API (OpenAI text-embedding-3 等): constitution I 違反、却下

---

## R2: embedding 次元数

**Decision**: **NLEmbedding.sentenceEmbedding(for: .japanese) のネイティブ次元数** をそのまま使う (典型 512 次元、実機ロード時に `embedding.dimension` で取得して動的に判定)。

**Rationale**:
- ネイティブ次元のまま使うのが API 設計上シンプル
- 1000 articles × 512 floats × 4 bytes ≈ 2.0 MB (ストレージ余裕)

**Alternatives considered**:
- 64 / 128 次元に PCA 圧縮: 精度劣化 + 実装コスト、却下
- 300 次元 (word embedding) に統一: sentence embedding 採用で不要

**Note**: 実機ロード失敗時 (`NLEmbedding.sentenceEmbedding(for:)` が nil 返却) → Fallback service へ委譲 (R10 参照)。

---

## R3: Article.essenceEmbedding 永続化方式

**Decision**: **`@Attribute(.externalStorage) var essenceEmbedding: Data?`** で `Data` 型として外部 file 保存。`[Float]` ↔ `Data` 変換は extension で提供。

**Rationale**:
- SwiftData `[Float]` 直接サポートは脆弱 (Codable 変換時 JSON で膨れる)
- `Data` + `.externalStorage` は iOS 17+ 確立、SwiftData が自動で別 blob file に保存 → SQLite 軽量化
- `[Float]` ↔ `Data` は `withUnsafeBufferPointer` で zero-copy 変換可能

**Alternatives considered**:
- `[Float]` 直接: SwiftData transformable / Codable で内部 JSON 化、サイズ膨張
- 別 @Model `ArticleEmbedding`: 1:1 relation で SwiftData クエリオーバーヘッド + lifecycle 管理コスト

**Implementation**:
```swift
extension [Float] {
    var asData: Data {
        withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
extension Data {
    var asFloatArray: [Float] {
        withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}
```

---

## R4: cosine similarity 高速計算

**Decision**: **Accelerate framework の `vDSP_dotpr`** を使った内積計算。embedding は事前に L2 正規化しておくため `dot product == cosine similarity`。

**Rationale**:
- 1000 articles × 512 dim の dot product を ~10ms 以下で計算可能 (Accelerate SIMD)
- L2 正規化込みで保存 → query 側でも正規化 → dot product 1 回で類似度

**Implementation**:
```swift
import Accelerate

func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    precondition(a.count == b.count)
    var result: Float = 0
    vDSP_dotpr(a, 1, b, 1, &result, vDSP_Length(a.count))
    return result
}
```

正規化は保存時に一度のみ。

**Alternatives considered**:
- Swift naive loop: 1000 articles で 100ms+ (10x 遅い)
- FAISS / Annoy: over-engineering、~1000 規模で不要

---

## R5: prompt エンジニアリング (引用厳守 + ハルシネーション抑止)

**Decision**: 以下の prompt 構造を `ChatService.foundationGenerate()` で使用:

```
あなたは知積 (KnowledgeTree) の AI アシスタントです。ユーザーが保存した記事を元に質問に答えます。

## ルール
1. 必ず以下の【参考記事】の内容のみに基づいて回答してください。一般知識から推測してはいけません。
2. 回答に使った記事の ID を citedArticleIDs に含めてください。
3. 参考記事に答えがない場合は「分かりません」と回答し、citedArticleIDs を空配列にしてください。
4. 簡潔に、3 段落以内で回答してください。

## 参考記事
[{i}] ID: {article.id}
タイトル: {article.title}
要点: {article.essence}
KeyFacts: {article.keyFacts.joined()}

## ユーザーの質問
{question}
```

**Rationale**:
- 「一般知識から推測してはいけません」でハルシネーション抑止
- citedArticleIDs を `@Generable` で型強制 → 出力フォーマット崩壊防止
- 「分かりません + 空配列」で fallback 経路を明示

**Alternatives considered**:
- few-shot (例文付き): token 増、MVP では不要
- chain-of-thought: 出力構造化を阻害

---

## R6: マルチターン handling

**Decision**: **MVP では single-turn (1 質問 = 1 retrieval + 1 回答)**。直前の 1 message も context に **含めない**。

**Rationale**:
- spec 021 spec.md 非ゴール「マルチターン高度文脈追跡」明記
- token 節約 + 実装シンプル
- 「先ほどの記事について詳しく」のような follow-up は将来 spec

**Alternatives considered**:
- 直前 1 ペア (ユーザー + assistant) を context: トークン倍増、retrieval が雑になる
- 全履歴: context limit 超過確実、却下

---

## R7: ハルシネーション検出

**Decision**: **ChatService 側で post-process 検証**:
1. Foundation Models 回答の `citedArticleIDs` が空 → 回答テキストを「分かりません。保存された記事の中に該当する情報が見つかりませんでした。」に置換
2. citedArticleIDs に存在しない Article ID が含まれる → そのIDだけ filter out (回答テキストはそのまま)
3. retrieval 段階で top-k=5 全ての similarity が `< 0.3` → Foundation Models 呼び出しせず、即「分かりません」回答

**Rationale**:
- prompt の「分かりません」指示が無視されるケースの保険
- 存在しない ID の引用は致命的、必ず filter
- low-similarity 早期 return で latency 短縮

---

## R8: ChatSession / ChatMessage @Model 設計

**Decision**:
- `ChatSession` 親、`ChatMessage` 子 (`@Relationship(deleteRule: .cascade)`)
- ChatMessage.role は `String` で `"user" | "assistant"` (enum 化は SwiftData 制約あり、簡素化)
- citedArticleIDs は `[String]` で Article.id (UUID 文字列) 配列を保存 (Article への直接 @Relationship は循環参照 + 削除時の cascade 複雑化を避け、ID 配列で疎結合)

**Rationale**:
- ID 配列方式は spec 018 KnowledgeDigest.sourceArticles と異なるが、ChatMessage は **「会話履歴」** の性質上、引用元 Article が削除されても message 自体は残ってよい (spec 022 で Article 削除実装済)
- spec 018 は逆 (Digest は元記事必須、削除追従) → spec ごとに整合判断

**Alternatives considered**:
- `@Relationship` + `.nullify`: 削除追従できるが、message に「(記事削除済)」表示が必要 → UX 複雑化
- 削除不可: constitution V 違反

---

## R9: 50 セッション制限の実装

**Decision**: **ChatService.createSession() で `count` 取得 → 50 超過なら `createdAt` ASC 順で先頭 1 件を削除**。FIFO。

**Rationale**:
- 削除タイミングが create と紐づき、leak しない
- ユーザー設定での「全削除」は spec.md US5 範囲、SettingsView から実施

**Alternatives considered**:
- バックグラウンドジョブ: 過剰、startup でやる必要も低い
- LRU (lastMessageAt 基準): 古いセッションでもアクティブなら残す → MVP では FIFO で十分

---

## R10: Apple Intelligence Fallback の発動条件

**Decision**: **3 段階の availability check**:

1. **Embedding 不可** (`NLEmbedding.sentenceEmbedding(for: .japanese) == nil`): Article 保存時の embedding 生成を skip、retrieval 時は title / essence のキーワードマッチに切替
2. **Foundation Models 不可** (`SystemLanguageModel.default.availability != .available`): キーワードマッチ retrieval 結果の Top KeyFact を "回答" として並べる (生成スキップ)
3. **両方 OK**: 通常 RAG 経路

実装は `ChatService` protocol を 1 つの実装で 3 経路分岐、または Foundation/Fallback 別実装は spec 015 と整合。spec 021 では **1 つの `ChatService` 実装内で `availability` を見て分岐** する (spec 015 KnowledgeExtractor との対比で simple)。

**Rationale**:
- ユーザーが embedding 端末から fallback 端末に変更したケースもカバー (storeに古い embedding 残存、retrieval 時 nil-check で対応)
- 起動時に NLEmbedding を 1 度だけロード、cache (heavy 初期化を回避)

**Alternatives considered**:
- 別 `FallbackChatService`: 実装重複、却下
- Embedding 強制必須: Apple Intelligence 不可端末で機能完全停止 → constitution IV 違反

---

## R11: テスト戦略

**Decision**: 10 ケース分散:

| # | ケース | テスト対象 |
|---|---|---|
| 1 | EmbeddingService.cosineSimilarity 正確性 | EmbeddingService |
| 2 | EmbeddingService L2 正規化 | EmbeddingService |
| 3 | ChatService 質問 → 引用付き回答 | ChatService (mock LanguageModelSession) |
| 4 | ChatService low-similarity → 「分かりません」 | ChatService |
| 5 | ChatService citedArticleIDs 空 → 「分かりません」 | ChatService (post-process) |
| 6 | ChatService 存在しない ID filter | ChatService (post-process) |
| 7 | ChatService Embedding 不可 → keyword fallback | ChatService |
| 8 | ChatService FoundationModels 不可 → KeyFact 並べ | ChatService |
| 9 | ChatService createSession で 50 件超過 → FIFO 削除 | ChatService |
| 10 | ChatMessage.citedArticleIDs 永続化 round-trip | SwiftData |

**Rationale**:
- spec 015 / 018 同様、Foundation Models 呼び出しは MockLanguageModelSession で代替
- Article fixture (5-10 件) を in-memory ModelContainer で setup
- NLEmbedding は実 API 使用 (mock 不要、~50ms / call、test 全体 ~5 秒以内)

---

## R12: Localizable.xcstrings 新規文言

| Key | 日本語 |
|---|---|
| `chat.tab.title` | AI チャット |
| `chat.input.placeholder` | 質問を入力 |
| `chat.input.send` | 送信 |
| `chat.empty.title` | まだチャット履歴がありません |
| `chat.empty.subtitle` | 質問を入力して、保存した記事から回答を得てみましょう |
| `chat.message.assistant.thinking` | 考え中… |
| `chat.message.assistant.unknown` | 分かりません。保存された記事の中に該当する情報が見つかりませんでした。 |
| `chat.message.cited.section` | 参考にした記事 |
| `chat.message.cited.count %lld` | %lld 件の記事を参考にしました |
| `chat.message.error` | 回答の生成に失敗しました。もう一度お試しください。 |
| `chat.session.new` | 新しいチャット |
| `chat.settings.deleteAllHistory` | チャット履歴を全削除 |
| `chat.settings.deleteAllHistory.confirmTitle` | チャット履歴を削除しますか? |
| `chat.settings.deleteAllHistory.confirmMessage` | 全てのチャット履歴が削除されます。この操作は取り消せません。 |
| `chat.settings.deleteAllHistory.confirmAction` | 削除する |

15 文言、spec 015/018 と同規模。

---

## まとめ — Phase 1-2 のための確定事項

- **NLEmbedding.sentenceEmbedding(for: .japanese)** をロード、`Data` 型 + `.externalStorage` で永続化
- **Accelerate vDSP_dotpr** で cosine similarity (L2 正規化前提)
- **ChatSession / ChatMessage @Model** + cascade delete + citedArticleIDs は `[String]` (ID 配列、疎結合)
- 50 セッション FIFO は ChatService.createSession() で実装
- Fallback は 1 ChatService 内で availability 分岐
- ハルシネーション 3 段階 post-process
- prompt は「一般知識禁止 + citedArticleIDs 必須 + 分かりません fallback」
