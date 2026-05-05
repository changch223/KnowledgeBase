# Quickstart: 振り返り支援 (Phase 1)

**Feature**: spec 008
**Date**: 2026-05-05

実機での手動検証手順。

## 前提

- spec 001-007 が main app に取り込まれビルド成功
- 30+ 件の記事を保存済 (検索 / 関連記事の有意義な検証のため)
- `xcodebuild test` で `KnowledgeTreeTests` 全 pass

## 検証シナリオ

### S1: 全文検索が複数フィールドにヒット

**目的**: title / essence / keyFact / entity / tag を横断検索して結果が返る。

1. アプリ起動 → 一覧画面
2. 検索バーに「Apple」を入力
3. 結果に Apple について書かれた記事が複数表示される
4. 各行で:
   - title にマッチした記事は title が bold ハイライト
   - essence にマッチした記事は title 下に「essence: ...Apple...」が excerpt 表示
   - entity にマッチした記事は「entity: Apple」が表示
5. 検索バー消去 → 全記事表示に戻る
6. 「該当しないキーワード」を入力 → 「該当する記事がありません」表示

**期待結果**: SC-001 (1000 記事以下で 200 ms 以内)、SC-006 (ハイライト正確)

---

### S2: タグ手動追加・削除

1. 任意の記事の Detail 画面を開く
2. タグセクションの入力フィールドに「読み返したい」と入力 → Enter or 「追加」タップ
3. タグセクションに「読み返したい」チップが表示
4. ナビゲーションバーの右側「タグ一覧」ボタンをタップ
5. タグ一覧画面に「読み返したい (1)」が表示
6. 「読み返したい」をタップ → 該当記事 1 件のみ表示される画面 (navigation title: 「tag: 読み返したい」)
7. 戻る → 元 Detail に戻る
8. 「読み返したい」チップの × ボタンタップ
9. タグ削除 → タグ一覧から消える (孤児削除)

**期待結果**: SC-002 (タグ追加 0.5 秒以内)、SC-003 (タグ一覧反映 / 絞り込み 0.5 秒以内)、SC-008 (孤児削除)

---

### S3: タグ正規化

1. 任意の記事 Detail を開く
2. タグ入力で「  OAuth  」(前後空白付き、大文字) と入力
3. → 「oauth」タグとして保存される
4. 別記事 Detail で「oauth」と入力 → 同じ既存 tag を再利用 (DB に重複なし)
5. タグ一覧で「oauth」が 2 articles と表示

**期待結果**: SC-007 (正規化 10 ケース pass、ユニットテストで担保)

---

### S4: エンティティ横断 (関連記事)

1. 同じ entity (例: 「OpenAI」) を持つ 3 件の記事を保存済とする
2. うち 1 件の Detail を開く
3. body セクションの **上** に「関連記事」セクションが表示
4. 残り 2 件が共通 entity 数で sort されて表示 (各行: タイトル + 共通 entity チップ + count)
5. 行をタップ → 該当記事の Detail に遷移
6. 共通 entity を持たない記事の Detail では関連記事セクション自体が非表示

**期待結果**: SC-004 (1 秒以内)、FR-021 (共通 0 件で非表示)

---

### S5: Entity 絞り込み

1. Detail 画面の knowledge セクションで entity チップ「OpenAI」をタップ
2. EntityFilteredListView に遷移 (navigation title: 「entity: OpenAI」)
3. 「OpenAI」を含む全記事が saved 日時降順で表示
4. 行タップ → Detail (sheet)

**期待結果**: FR-022 / FR-023

---

### S6: 自動タグ提案

1. salience 4 以上の entity を持つ記事 (例: knowledge.entities = [Apple (s5), OpenAI (s4)] の記事) を Detail で開く
2. タグセクションの「自動提案」サブセクションに「+ Apple」「+ OpenAI」チップが表示
3. 「+ Apple」タップ → 「apple」タグが手動扱いで追加され、提案チップから消える
4. 既に手動で「openai」タグを付けてある場合、「+ OpenAI」は表示されない

**期待結果**: SC-005 (0.5 秒以内表示)、FR-026 / FR-027

---

### S7: 検索 + spec 005 live update 共存

1. 検索バーに「Apple」入力 → 結果表示
2. 別の記事を Chrome から共有保存 (内容に Apple 含む)
3. enrichment + body + knowledge 抽出進行 → 完了
4. 検索結果に新規記事が live update で追加される (アプリ閉じる必要無し)

**期待結果**: spec 005 の RefreshTrigger / NotificationCenter / Timer fallback が検索結果でも機能する

---

### S8: 大量タグの一覧 sort

1. 50+ タグを持つ状態で「タグ一覧」を開く
2. name 昇順で表示される
3. 各 row に articles count (右側) が表示される
4. スクロールがスムーズ (LazyVStack 効果)

**期待結果**: パフォーマンスゲート遵守

---

## 自動テスト

```bash
xcodebuild test -only-testing:KnowledgeTreeTests/TagNormalizerTests
xcodebuild test -only-testing:KnowledgeTreeTests/TagStoreTests
xcodebuild test -only-testing:KnowledgeTreeTests/SearchPredicateTests
xcodebuild test -only-testing:KnowledgeTreeTests/RelatedArticleFinderTests
xcodebuild test -only-testing:KnowledgeTreeTests/SearchHighlighterTests
xcodebuild test -only-testing:KnowledgeTreeTests/SuggestedTagFinderTests

# 既存テスト互換性
xcodebuild test -only-testing:KnowledgeTreeTests
```

すべて pass で PR merge 条件。

---

## 受け入れ基準サマリ

| Spec ID | シナリオ | 期待 |
|---|---|---|
| SC-001 | S1 | 1000 記事で 200 ms 以内検索 |
| SC-002 | S2 | タグ追加 0.5 秒以内 |
| SC-003 | S2 | タグ一覧反映 / 絞り込み 0.5 秒以内 |
| SC-004 | S4 | 関連記事 1 秒以内 |
| SC-005 | S6 | 自動提案 0.5 秒以内 |
| SC-006 | S1 | ハイライト正確 (10 サンプル) |
| SC-007 | S3 + ユニットテスト | 正規化 10 ケース |
| SC-008 | S2 | 孤児タグ自動削除 |

すべて pass で spec 008 完了。
