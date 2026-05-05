# Quickstart: spec 012 (タグ自動付与) 実機検証手順

**Created**: 2026-05-05
**Branch**: `012-auto-tag`
**前提**: iPhone 17 Pro 等の Apple Intelligence 対応端末。Apple Intelligence 有効化済。spec 011 までのデータ + コードがインストール済。

---

## 検証 1: 新規記事 → 上位 5 タグ自動付与

### 手順

1. アプリを起動 (実装後の build をデプロイ)
2. Safari で適当な日本語記事 URL を開く (例: tech 系ブログ記事)
3. Share Sheet → 「知積」をタップ → 投稿
4. メインアプリに戻る
5. 一覧で新規記事行をタップ → ArticleDetailView 表示
6. 数秒待機 (knowledge 抽出完了まで)
7. タグセクションを確認

### 期待結果

| 項目 | 期待 |
|---|---|
| knowledge 抽出 status | succeeded (status badge) |
| 自動付与タグ数 | 1〜5 件 (entity の salience ≥ 4 件数次第) |
| タグ表示形式 | 既存 TagChip (x ボタン付き、青〜灰色背景) |
| 「AI が見つけた他のタグ」セクション | salience ≥ 4 で auto-apply 漏れた候補があれば表示 (なければ非表示) |
| 通知 / バッジ / サウンド / トースト | **発生しない** (calm UX) |

✅ **SC-001 検証**: 1 秒以内 Detail 反映 (knowledge 抽出完了直後)

---

## 検証 2: 手動タグ既存記事 → 自動付与スキップ

### 前提

- spec 008 / 011 までで手動タグを 1 件以上付けた記事が 1 つ以上存在
- もしくは、検証 1 で auto-apply された記事から 4 件削除して 1 件残す

### 手順

1. ArticleDetailView を開く (上記の記事)
2. 既存タグが 1 件以上残っていることを確認
3. 「再抽出」ボタンをタップ
4. knowledge 抽出が再実行される
5. タグセクションを再度確認

### 期待結果

| 項目 | 期待 |
|---|---|
| knowledge 抽出 status | succeeded (再抽出成功) |
| タグ count | **変化なし** (auto-apply スキップ) |
| 既存タグ | 全て残ったまま |

✅ **SC-002 検証**: 既存タグありで auto-apply スキップ

---

## 検証 3: タグ全削除 → 再抽出で復活

### 手順

1. 検証 1 で auto-apply されたタグが 5 件付いている記事を選択
2. ArticleDetailView を開く
3. 全タグの x ボタンを順次タップして全削除
4. タグセクションが空になる (article.tags.count == 0)
5. 「再抽出」ボタンをタップ
6. knowledge 抽出が再実行される
7. タグセクションを再度確認

### 期待結果

| 項目 | 期待 |
|---|---|
| 全削除直後 | tag count = 0、提案チップに以前のタグが復活表示される (salience ≥ 4 のため) |
| 再抽出後 | tag count = 5 (or 候補数次第)、auto-apply で復活 |

✅ **SC-003 検証**: 全削除後の再 auto-apply で復活

---

## 検証 4: knowledge 失敗時の非付与

### 手順 (機内モード経由)

1. 設定 → 機内モード ON (knowledge 抽出に必要なネットワークなし、ただし Apple Foundation Models はオンデバイスなので影響軽微)

または、Apple Intelligence 一時無効化:

1. 設定 → Apple Intelligence & Siri → Apple Intelligence OFF
2. アプリを起動 (Apple Intelligence 状態は `SystemLanguageModel.availability` 経由で `unavailable` になる)
3. Safari で記事 URL を共有 → 「知積」
4. アプリで一覧を確認 → 新規記事行
5. 一覧の status badge / 詳細を確認

### 期待結果

| 項目 | 期待 |
|---|---|
| knowledge 抽出 status | `failed` または `skipped` (Apple Intelligence 未利用可) |
| Article.tags | 空 (auto-apply 非発火) |
| 提案チップセクション | 空 (entity 取れていない) |

検証後、Apple Intelligence を ON に戻して継続。

✅ **SC-004 検証**: 失敗時の非付与

---

## 検証 5: spec 011 PowerGauge / KnowledgeMap への波及

### 手順

1. AI ブレインタブを開く
2. 検証 1 を実行 (新規記事保存 → auto-apply で 5 タグ付与)
3. AI ブレインタブに切替

### 期待結果

| 項目 | 期待 |
|---|---|
| PowerGaugeCard | Article 数 +1、KnowledgeEntity / KeyFact 数も増加 (knowledge 抽出経由) |
| KnowledgeMap | 新タグ 5 件のノードが 0.4 秒フェードインで出現 |
| RecentActivityCards | 「今週 N+1 件」更新、「育ったテーマ」に新タグ |

✅ spec 011 回帰確認

---

## 検証 6: 既存ライブラリタブの完全保持

### 手順

1. ライブラリタブを開く
2. 検索バーで適当な単語を入力
3. タグ一覧画面 → タグタップで TagFilteredListView 遷移
4. 任意記事タップ → Detail シート
5. シート内の x ボタンでタグ削除
6. 入力欄でタグ手動追加

### 期待結果

| 項目 | 期待 |
|---|---|
| 検索 / タグフィルタ / シート / 削除 / 追加 | spec 011 までと完全一致 |
| 「AI が見つけた他のタグ」提案チップ | spec 008 までと同じ表示・タップ動作 |

✅ **SC-005 検証**: 既存全機能回帰なし

---

## 検証 7: 連続 100 件保存の取りこぼしチェック (高負荷)

### 手順 (時間がある場合のみ)

1. テスト用に 100 件の URL リストを準備 (例: 公開ブログのトップ記事)
2. Share Sheet で 1 件ずつ連続保存 (or Shortcuts で半自動化)
3. 数十分待機 (BG task で順次 knowledge 抽出 + auto-apply)
4. AI ブレインタブの PowerGauge と KnowledgeMap を確認

### 期待結果

| 項目 | 期待 |
|---|---|
| Article 数 | 100 件 +N (元の件数) |
| 全 100 件で auto-apply 発火 (or 手動タグ既存ならスキップ) | knowledge 抽出 succeeded した記事は **必ず** 1〜5 タグが付いている |
| 取りこぼしゼロ | knowledge succeeded で tags == 0 の記事がない (entity 0 件 / salience < 4 のみのケースは除く) |

✅ **SC-007 検証**: 100 件取りこぼしゼロ

---

## 検証完了基準

すべて ✅ → spec 012 の MVP は出荷可能

| SC | 検証項目 |
|---|---|
| SC-001 | 検証 1 (1 秒以内 5 タグ反映) |
| SC-002 | 検証 2 (既存タグスキップ) |
| SC-003 | 検証 3 (全削除復活) |
| SC-004 | 検証 4 (失敗時非付与) |
| SC-005 | 検証 6 (既存挙動回帰) |
| SC-006 | (パフォーマンス) Instruments で auto-apply の Time Profiler に 100ms 超のものがないことを確認 |
| SC-007 | 検証 7 (連続 100 件取りこぼしゼロ、時間がある場合のみ) |

実機で実行できない場合は、Simulator + AutoTagApplierTests の unit test で代用可能。実機検証は SC-006 (パフォーマンス) と SC-007 (大規模取りこぼし) を確認するためにのみ必須。
