# Quickstart: spec 013 (既存記事への auto-tag backfill) 実機検証手順

**Created**: 2026-05-05
**Branch**: `013-auto-tag-backfill`
**前提**: iPhone 17 Pro 等の Apple Intelligence 対応端末。spec 008-012 までで何件か記事を保存済 (タグ 0 件 + knowledge succeeded のものが含まれる状態) のアプリインスタンス。

---

## 検証 1: 既存記事への 1 度限り backfill

### 前提

- spec 008-012 ビルドで保存した記事が 10 件以上
- そのうち少なくとも数件は **タグ 0 件 + knowledge succeeded** (= backfill 候補)

### 手順

1. spec 013 を含むビルドを Xcode から build & install
2. アプリを起動
3. ログを Xcode の console で観察
4. BottomStatusBar の表示を確認 (タブ切替して両タブで)
5. backfill 完了まで待機 (~30 秒目安)
6. 記事一覧で 1 件 tap して Detail を開く

### 期待結果

| 項目 | 期待 |
|---|---|
| Console ログ | `[auto-tag-backfill] starting: N/M candidates` (N=候補、M=全件) |
| BottomStatusBar | 「タグ整理中 1/N」のような表示 (進行中のみ) |
| 完了後の Console | `[auto-tag-backfill] completed: processed N articles` |
| BottomStatusBar | 完了で非表示に戻る |
| 既存タグ 0 件記事の Detail | 上位 5 タグが付与されている |
| 既存タグ ≥ 1 件記事の Detail | 既存タグそのまま (触られていない) |
| AI ブレインタブの KnowledgeMap | 新タグノードが fade-in でどっと出現 |
| AI ブレインタブの PowerGauge | 数字は変化なし (Article / Entity / KeyFact 数は変わらない) |
| 通知 / バッジ / トースト | **発生しない** (calm UX) |

✅ **SC-001 検証**: 80% 以上の対象記事に上位 5 タグ自動付与

---

## 検証 2: 2 回目起動でフラグ early return

### 手順

1. 検証 1 完了後、アプリを完全終了 (App Switcher で swipe up)
2. アプリを再起動
3. ログを観察
4. BottomStatusBar を確認

### 期待結果

| 項目 | 期待 |
|---|---|
| Console ログ | `[auto-tag-backfill] skipped: already completed` (debug level、Filter で見る) |
| BottomStatusBar | 起動時から「タグ整理中」表示は **出ない** |
| 起動時間 | spec 012 までと同じ (1 秒以内 main 表示) |
| Article.tags | 検証 1 時点と同じ状態を維持 |

✅ **SC-004 検証**: 1ms 以内 early return

---

## 検証 3: 100 件規模の実行時間

### 前提

- 100 件以上の対象記事 (タグ 0 + knowledge succeeded) を持つアプリ環境
- backfill フラグを reset (アプリ再インストール、または `UserDefaults` から `auto_tag_backfill_v1_done` を Xcode で手動削除)

### 手順

1. backfill フラグ reset
2. アプリ起動
3. ストップウォッチで backfill 開始から完了までの時間を計測 (Console ログで判定)

### 期待結果

| 項目 | 期待 |
|---|---|
| 実行時間 | 30 秒以内 (SC-002) |
| 全候補処理 | candidates.count == processedIndex |
| 進行中 BottomStatusBar 表示 | 30 秒間「タグ整理中」継続表示 |
| Article.tags | 100 件中 80% 以上に 5 タグ付与 (entity が salience 4+ で 5 件以上ある記事の比率) |

✅ **SC-002 検証**: 100 件 30 秒以内

---

## 検証 4: 整理済記事は触らない (回帰)

### 手順

1. 検証 1 完了後の状態
2. 任意の既存タグ ≥ 1 件記事 (例: 手動でタグ付けした記事) を Detail で確認
3. 任意の auto-apply 5 タグ付き記事を Detail で確認
4. backfill フラグ reset
5. アプリ再起動 (= backfill 再実行)
6. 同記事を再度 Detail で確認

### 期待結果

| 項目 | 期待 |
|---|---|
| 既存タグ ≥ 1 件記事 | タグ count 不変、内容変化なし |
| auto-apply 5 タグ付き記事 | タグ count 不変 (= 5)、内容変化なし |
| knowledge failed 記事 | タグ 0 件のまま (誤付与なし) |
| AI ブレインタブ | 整理済記事のタグは KnowledgeMap で同じ位置 |

✅ **SC-007 検証**: 整理済記事の保持

---

## 検証 5: backfill 中の新記事保存との非競合

### 手順

1. backfill フラグ reset
2. アプリを起動 (backfill 開始)
3. 実機で別アプリ (Safari) に切り替え、適当な記事を Share Sheet → 「知積」で保存 (backfill 進行中の最中に)
4. 「知積」アプリに戻る
5. 一覧と Detail を確認

### 期待結果

| 項目 | 期待 |
|---|---|
| 新記事の Article 行 | 一覧に即追加される |
| 新記事の Detail | knowledge 抽出が完了したら spec 012 の通常フローで上位 5 タグ自動付与 |
| backfill 進行 | 中断せず継続、最終的に完了 |
| 競合 | なし (両者の effect は冪等性で吸収) |

✅ **SC-005 検証**: 新記事保存との非競合

---

## 検証 6: アプリ強制終了からの復帰

### 手順

1. backfill フラグ reset
2. アプリ起動 (backfill 開始)
3. 進行中 (~5 秒経過) でアプリを App Switcher で強制終了
4. 数秒待機
5. アプリ再起動

### 期待結果

| 項目 | 期待 |
|---|---|
| 1 回目強制終了直前 | flagStore.markCompleted() がまだ呼ばれていない (フラグ false) |
| 2 回目起動 | 再度 backfill が走る (フラグ false なので) |
| 2 回目完了後 | 全件処理完了、フラグ true |
| 副作用 | 個別 article で重複付与なし (TagStore.addTag 内部で重複防止) |

✅ **SC-006 検証**: 中断 → 次回再開

---

## 検証 7: 新規インストール (記事 0 件) の挙動

### 手順

1. アプリを完全アンインストール
2. spec 013 ビルドで再インストール
3. 何も操作せずアプリ起動

### 期待結果

| 項目 | 期待 |
|---|---|
| Console ログ | `[auto-tag-backfill] starting: 0/0 candidates` → `completed: processed 0 articles` (即時) |
| 起動時間 | 通常 (1 秒以内) |
| BottomStatusBar | 一瞬「タグ整理中 0/0」が出るかも、即座に消える |
| flagStore | flag = true セット (1 度限り、以降 skip) |
| crash | なし |

---

## 検証完了基準

すべて ✅ → spec 013 の MVP は出荷可能

| SC | 検証項目 |
|---|---|
| SC-001 | 検証 1 (80% 自動付与) |
| SC-002 | 検証 3 (100 件 30 秒) |
| SC-003 | (1000 件規模、本検証では時間が許せば) |
| SC-004 | 検証 2 (2 回目 early return) |
| SC-005 | 検証 5 (新記事保存との非競合) |
| SC-006 | 検証 6 (強制終了復帰) |
| SC-007 | 検証 4 (整理済記事の保持) |

実機で実行できない場合は、Simulator + AutoTagBackfillRunnerTests の unit test で代用可能。実機検証は SC-002 (実行時間) と SC-005 (実時間競合) を確認するためにのみ必須。
