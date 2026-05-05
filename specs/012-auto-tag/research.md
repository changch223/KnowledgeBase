# Phase 0 Research: spec 012 (タグ自動付与)

**Created**: 2026-05-05
**Branch**: `012-auto-tag`

技術不確実性を 5 つの研究項目 (R1〜R5) に分割し、各項目で **Decision / Rationale / Alternatives considered** を記録する。

---

## R1: 自動付与の発火 hook 位置 (単一 hook で BG / 階層化を全網羅)

### Decision

`DefaultKnowledgeExtractionService` 内の **`upsertSucceeded` 呼び出し直後** 2 箇所に hook を置く:

1. **単一パス (短文 ≤ 1000 chars)**: `KnowledgeExtractionService.swift:140-146` の `try? store.upsertSucceeded(...)` 直後
2. **chunked パス (長文 > 1000 chars)**: `KnowledgeExtractionService.swift:294-305` の `case .succeeded, .partiallySucceeded:` ブランチの `try? store.upsertSucceeded(...)` 直後

両 hook 共通の helper:

```swift
private func applyAutoTagsIfPossible(article: Article) {
    guard let tagStore else { return }
    AutoTagApplier.apply(to: article, using: tagStore)
}
```

### Rationale

- spec 009 の `BackgroundExtractionRunner` は `knowledgeService.extract(article:)` を呼び出す → 同 service の上記 hook を共有 → BG 経路も自動波及
- spec 010 の階層的 chunk summarization は `performChunkedExtraction` 内 → 同じ `upsertSucceeded` を通る → 自動カバー
- メインアクター内で同期的に hook 実行 → race condition 不要
- `tagStore` は optional (nil なら no-op) → 既存テスト互換性維持

### Alternatives considered

- **A**: `BackgroundExtractionRunner` 側にも独立 hook → 二重実行リスク + 重複実装、却下
- **B**: NotificationCenter で `.knowledgeSucceeded` を post し、ListenerView 経由で auto-apply → 非同期化で MainActor 保証が崩れる、計算量増加、却下
- **C**: SwiftData の `@Model` willSet observer で article.extractedKnowledge.status 変化を捕捉 → SwiftData の observer はまだ stable でなく、tests も書きにくい、却下

---

## R2: AutoTagApplier の API 形 (純粋関数 vs class)

### Decision

`enum AutoTagApplier` の `static func apply(to:using:limit:)` 1 つだけ公開:

```swift
@MainActor
enum AutoTagApplier {
    static func apply(
        to article: Article,
        using tagStore: TagStore,
        limit: Int = 5
    )
}
```

戻り値なし (副作用のみ)。`@MainActor` で TagStore 内 SwiftData ops を保証。

### Rationale

- 純粋関数 enum は instance state 不要、テスト容易 (毎回新しい ModelContainer で実行)
- `@MainActor` 注釈で呼び出し側 (KnowledgeExtractionService の MainActor 文脈) と一致
- `limit: Int = 5` は spec 012 確定値、将来 spec で設定化する場合は引数で柔軟対応
- 戻り値なしで「何件付いたか」を返さない → calm UX (UI 通知なし、ログのみ)

### Alternatives considered

- **A**: `AutoTagApplier` を class にして `addTagAttempts: Int` 等の状態保持 → 純粋関数で十分、却下
- **B**: 非同期 `static func apply(...) async` → SwiftData ops は同期 + MainActor、async 不要、却下
- **C**: `[Tag]` を返す → calm UX 的に呼び出し側で「N 件付与しました」表示しないため、戻り値廃止 → no-op return type

---

## R3: スキップ条件の判定順序 (early return 設計)

### Decision

以下の順序で early return:

```swift
static func apply(to article: Article, using tagStore: TagStore, limit: Int) {
    // 1. FR-006 / US2: 既存タグがあるならスキップ (最優先、最頻ヒット)
    guard article.tags.isEmpty else {
        logger.debug("auto-tag skipped: existing tags=\(article.tags.count)")
        return
    }
    
    // 2. FR-004 / US4: knowledge が succeeded/partiallySucceeded でないならスキップ
    guard let knowledge = article.extractedKnowledge,
          knowledge.status == .succeeded || knowledge.status == .partiallySucceeded else {
        logger.debug("auto-tag skipped: knowledge status not succeeded")
        return
    }
    
    // 3. 候補取得 (entity 0 件 / salience < 4 のみ → suggestions 空 → ループ no-op)
    let suggestions = SuggestedTagFinder.find(
        for: article,
        existingTagNames: [],  // article.tags が空なので空 set で OK
        limit: limit
    )
    
    // 4. 各候補に addTag (失敗 1 件は skip + log、ループ継続)
    for suggestion in suggestions {
        do {
            _ = try tagStore.addTag(rawName: suggestion.displayName, to: article)
        } catch {
            logger.error("auto-tag addTag failed for \(suggestion.displayName): \(error)")
        }
    }
}
```

### Rationale

- 既存タグチェックを最優先 → 大半の再抽出ケースで早期 return (=性能最大化)
- knowledge status チェックを 2 番目 → entity 取得前に確定で skip 可能
- SuggestedTagFinder.find() は既に salience ≥ 4 + 重複排除済 → 追加 filter 不要
- TagStore.addTag は内部で TagNormalizer + 既存 Tag 検索 + 重複追加防止 → 安全
- ループ内 `try? + log` で 1 件失敗が全体停止しない (FR-014 graceful failure)

### Alternatives considered

- **A**: knowledge status を最優先チェック → 失敗記事は絶対稀なため、既存タグチェック優先で性能向上、却下
- **B**: SuggestedTagFinder を経由せず直接 entity 走査 → spec 008 のロジック重複、保守性悪化、却下

---

## R4: TagStore への DI (KnowledgeExtractionService 経由)

### Decision

`DefaultKnowledgeExtractionService` のイニシャライザに **optional な `tagStore: TagStore?`** を追加。`KnowledgeTreeApp.bootstrap()` で TagStore 構築後に inject。

```swift
// KnowledgeExtractionService.swift
final class DefaultKnowledgeExtractionService: KnowledgeExtractionServiceProtocol {
    private let extractor: KnowledgeExtractor
    private let store: ArticleKnowledgeStoreProtocol
    private let processingMonitor: ProcessingMonitor?
    private let chunkProgressStore: ChunkProgressStoreProtocol?
    private let tagStore: TagStore?    // ← 新規

    init(
        extractor: KnowledgeExtractor,
        store: ArticleKnowledgeStoreProtocol,
        processingMonitor: ProcessingMonitor? = nil,
        chunkProgressStore: ChunkProgressStoreProtocol? = nil,
        tagStore: TagStore? = nil    // ← 新規、default nil
    ) {
        // ...
        self.tagStore = tagStore
    }
}

// KnowledgeTreeApp.swift bootstrap
let knowledgeService = DefaultKnowledgeExtractionService(
    extractor: knowledgeExtractor,
    store: knowledgeStore,
    processingMonitor: processingMonitor,
    chunkProgressStore: chunkProgressStore,
    tagStore: tagStore    // ← spec 012 で 1 行追加
)
```

### Rationale

- 既存テストは `tagStore: nil` (default) で動作変更なし → 後方互換
- bootstrap で TagStore 構築 → 既に作成済の `tagStore` を knowledgeService にも渡すだけ → 重複コストなし
- TagStore は @MainActor + RefreshTrigger 持参なので、auto-apply 後の RefreshTrigger.bump も自動実行 (TagStore.addTag 内で bump 済)
- 抽象化は将来必要なら `TagStoreProtocol` 導入 (本 spec では具体型で十分)

### Alternatives considered

- **A**: `AutoTagApplier.apply(to:context:refreshTrigger:)` で TagStore を経由しない → SwiftData ops を再実装 + TagNormalizer / 重複排除を AutoTagApplier 側に持つ → spec 008 既存ロジック重複、却下
- **B**: NotificationCenter で「knowledge succeeded」を broadcast し、別の Listener (TagAutoApplyService) が TagStore を持つ → 余計な間接層、却下
- **C**: AutoTagApplier を class 化して TagStore を保持 → instance state 不要、却下

---

## R5: テスト戦略 (in-memory + 時刻独立)

### Decision

`AutoTagApplierTests.swift` で 7 ケース:

| Test | 検証 |
|---|---|
| `testAppliesTopFiveWhenNoExistingTags` | tags 空 + entities 6 件 (salience 5,5,4,4,4,3) → 上位 5 (salience ≥4) が付与、salience=3 は除外 |
| `testSkipsWhenArticleHasManualTag` | 手動タグ 1 件 → apply 後も tag count 変わらず (US2) |
| `testSkipsWhenKnowledgeStatusIsFailed` | status = .failed → tag 0 (FR-004 / US4) |
| `testSkipsWhenKnowledgeStatusIsPending` | status = .pending → tag 0 (Edge case) |
| `testIdempotentOnDoubleInvocation` | apply 2 回連続 → 結果同じ (TagStore.addTag の重複防止に依存) |
| `testReappliesAfterAllTagsRemoved` | apply → 全削除 → 再 apply で同じ 5 件復活 (US3) |
| `testEmptyEntitiesNoTagsApplied` | entities 0 件 → tag 0 (Edge case) |

各テストで:
- `private typealias Tag = KnowledgeTree.Tag` で SwiftUI 衝突解消 (spec 011 パターン)
- `ModelConfiguration(isStoredInMemoryOnly: true)` で全 entity スキーマ込み container 構築
- 直接 `Article` / `KnowledgeEntity` / `ExtractedKnowledge` を insert + status 設定
- `TagStore(context:, refreshTrigger: nil)` で TagStore を構築 (refreshTrigger は test では nil OK)
- `AutoTagApplier.apply(to:using:)` 呼び出し → `article.tags.count` / `article.tags.map(\.name)` で検証

### Rationale

- 純粋関数 + TagStore 副作用なので状態は ModelContext 内で完結 → 外部依存なし
- 時刻注入は不要 (本 spec では時刻による分岐なし)
- 7 ケースで FR-001〜015 + US1〜US4 + 主要 edge case を網羅

### Alternatives considered

- **A**: BackgroundExtractionRunner 経由の integration test → 構築コスト高 + spec 009/010 の挙動確認は別 spec のスコープ、却下
- **B**: UI test で実機 Detail を開いてタグ確認 → spec 008 既存 UI test で十分、AutoTagApplier 自体の logic は unit test で十分、却下

---

## まとめ

すべての R1〜R5 で技術判断を確定。NEEDS CLARIFICATION 残存ゼロ。Phase 1 (data-model / contracts / quickstart) に進める。

**コア発見**:
- 既存 `KnowledgeExtractionService` が **単一 + chunked + 階層化** の全経路で `upsertSucceeded` を経由 → **2 箇所の hook で全網羅**
- `BackgroundExtractionRunner` は同 service を呼ぶため **自動波及**
- 新 service / 新抽象化 / 新 schema / 新 UI ゼロで spec 012 完成
