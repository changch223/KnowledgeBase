# Contract: AutoTagApplier

**Created**: 2026-05-05
**File**: `KnowledgeTree/Services/AutoTagApplier.swift`

## 責務

knowledge 抽出が成功した Article に対し、salience ≥ 4 の `KnowledgeEntity` から **上位 5 件**を自動でタグ付与する純粋関数モジュール。手動タグが既に付いている記事はスキップ。spec 008 の `SuggestedTagFinder` + `TagStore` の薄い合成。

## API

```swift
@MainActor
enum AutoTagApplier {
    /// Article に対して auto-apply を試みる。
    /// 既存タグあり / knowledge 未完了の場合は no-op で早期 return。
    /// - Parameter article: 対象の Article (extractedKnowledge.entities + tags を読む)
    /// - Parameter tagStore: TagStore (TagNormalizer + 既存 Tag 再利用 + RefreshTrigger.bump 担当)
    /// - Parameter limit: 付与上限。MVP では 5 固定。将来 spec で設定化する場合に活用
    static func apply(
        to article: Article,
        using tagStore: TagStore,
        limit: Int = 5
    )
}
```

## 入力契約

| パラメータ | 型 | 制約 |
|---|---|---|
| `article` | `Article` | 任意の Article。`tags` / `extractedKnowledge` を読む |
| `tagStore` | `TagStore` | spec 008 既存。`addTag(rawName:to:)` を呼ぶ |
| `limit` | `Int` | 1 以上 (MVP デフォルト 5)。0 以下 / 負数なら no-op |

## 出力契約

戻り値なし (副作用のみ)。`tagStore.addTag` が成功した分だけ `article.tags` に Tag が追加される。

副作用:
- `article.tags` に 0〜5 件の Tag が append される
- 新 Tag が必要な場合、`Tag(name:)` が SwiftData context に insert される
- `RefreshTrigger.bump()` が `TagStore.addTag` 内で各 add ごとに 1 回ずつ呼ばれる (= 最大 5 回 bump)
- 失敗ケースで `Logger` (`Logger.knowledge` 推奨) に `.error` ログが出る

## 早期 return 条件

以下のいずれかに該当する場合、何もせず return:

1. **`article.tags.isEmpty == false`** (FR-006 / US2)
   - ログ: `"auto-tag skipped: existing tags=\(count)"` (debug level)

2. **`article.extractedKnowledge == nil`** (entity 取れない)
   - ログ: `"auto-tag skipped: no extractedKnowledge"` (debug level)

3. **`knowledge.status` が `.succeeded` でも `.partiallySucceeded` でもない** (FR-004)
   - ログ: `"auto-tag skipped: knowledge status=\(status)"` (debug level)

4. **`limit <= 0`** (防御的)
   - ログ: なし (no-op)

## 候補取得 + 付与アルゴリズム

```
1. early return チェック (上記)
2. let suggestions = SuggestedTagFinder.find(
       for: article,
       existingTagNames: [],  // article.tags は空なので空 set
       limit: limit
   )
3. for suggestion in suggestions {
       do {
           _ = try tagStore.addTag(rawName: suggestion.displayName, to: article)
       } catch {
           logger.error("auto-tag addTag failed for \(suggestion.displayName): \(error)")
       }
   }
4. return (logger.notice で完了サマリ "auto-tag applied N/M for article ...")
```

`SuggestedTagFinder.find` は spec 008 既存:
- `entity.salience >= 4` で filter
- `TagNormalizer.normalize` 経由で正規化
- `existingTagNames` と重複排除 (本 spec では空)
- salience desc で sort
- 上位 `limit` 件返却

## 副作用のべき等性

- `apply()` を同 article に 2 回連続呼ぶと、2 回目は **`article.tags.isEmpty == false`** (1 回目で付与済) で早期 return → 重複付与なし
- 半分手動 + 半分 auto-apply 状態 (例: 5 件中 1 件手動削除済) → tags.count = 4 (≥1) → 早期 return で更なる auto-apply なし

## エラーハンドリング

- TagStore.addTag が throw する場合 (例: SwiftData save 失敗) → 該当 candidate のみ skip + error log、ループ継続
- 例外が apply() 全体を中断することはない (FR-014 graceful failure)

## ロギング

- `os.Logger(subsystem: "app.KnowledgeTree", category: "auto-tag")` を使用 (spec 005 既存パターン推奨)
- skip ケース → `.debug` level
- 完了ケース → `.notice` level (件数とタイトルを含む)
- addTag 失敗ケース → `.error` level

## 依存

- `Article`, `Tag`, `KnowledgeEntity`, `ExtractedKnowledge` (既存 @Model)
- `SuggestedTagFinder.find()` (spec 008 既存純粋関数)
- `TagStore.addTag()` (spec 008 既存)
- `TagNormalizer.normalize()` (TagStore 内部経由、本 spec では直接呼ばない)

## 副作用の境界

`AutoTagApplier` は SwiftData の `ModelContext` を直接触らない。すべての永続化操作は `TagStore` 経由で実行 → Constitution Principle VI (クリーン境界) 準拠。

## テスト

`KnowledgeTreeTests/AutoTagApplierTests.swift`:

| Test | 検証 |
|---|---|
| `testAppliesTopFiveWhenNoExistingTags` | tags 空 + entities 6 件 (salience 5,5,4,4,4,3) → tag 5 件付与、salience=3 entity は除外 |
| `testSkipsWhenArticleHasManualTag` | 手動タグ 1 件 → tag count 不変 (US2) |
| `testSkipsWhenKnowledgeStatusIsFailed` | status = .failed → tag 0 (FR-004) |
| `testSkipsWhenKnowledgeStatusIsPending` | status = .pending → tag 0 |
| `testIdempotentOnDoubleInvocation` | apply 2 回連続 → 結果同じ (1 回目で tags 充填、2 回目で early return) |
| `testReappliesAfterAllTagsRemoved` | apply → tagStore.removeTag 全削除 → 再 apply で同じ 5 件復活 (US3) |
| `testEmptyEntitiesNoTagsApplied` | entities 0 件 → tag 0 |

## 副作用パフォーマンス

- TagStore.addTag は内部で 1 回 fetch (`FetchDescriptor` with predicate) + 1 回 save → ~10ms 想定
- 5 回呼び出しで ~50ms (Constitution パフォーマンスゲート 100ms 以内 ✅)
- knowledge 抽出本体 (~1-5 秒) と比べて十分小さい
