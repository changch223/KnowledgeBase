# Feature Specification: 既存記事への auto-tag backfill

**Feature Branch**: `013-auto-tag-backfill`
**Created**: 2026-05-05
**Status**: Draft

## なぜ (Why)

spec 012 で「新規記事保存 → knowledge 抽出 succeeded → 上位 5 タグ自動付与」を実装したが、対象は **新規 / 再抽出された記事** のみ。spec 008-011 までに保存済の **既存記事** は対象外で、これらの記事は:

- knowledge 抽出は完了済 (`status == .succeeded`)
- entity も既に持っている
- だがタグは 0 件のまま

という状態のままで、ユーザーが Detail を開いて手動で「AI が見つけたタグ」をタップして個別採用する必要がある。

これは spec 012 の理念 (「気付いたら整理されている」) と矛盾している。本 spec ではアプリ起動時に **1 回限り** 既存全記事をスキャンし、auto-apply 候補に該当するものに対して `AutoTagApplier.apply()` を実行する **backfill** 機能を追加する。

ユーザー体験:
- spec 013 リリース後の初回起動 → 「タグ整理中…」(BottomStatusBar) が短時間表示
- 完了後、AI ブレインタブの KnowledgeMap にタグノードがどっと増える
- それ以降は spec 012 の通常フローで新規記事のみ自動付与される

## ゴール

- spec 008-011 までに保存済かつタグ 0 件かつ knowledge succeeded の **全 article** に auto-apply タグを付ける
- 起動時 1 回のみ実行 (永続フラグで重複防止)
- BottomStatusBar に「タグ整理中…」を表示 (calm UX 範囲内)
- 既存スキーマ無改修 (新 @Model / 新 migration ゼロ)
- 既に手動タグ付いている記事 / auto-apply 済の記事 / knowledge 失敗記事は **触らない**

## 非ゴール

- 「タグ整理を再実行」ボタン (Settings 画面追加) — 将来 spec
- 段階的 backfill (起動ごとに 100 件ずつ分割実行) — 将来 spec
- backfill 結果のサマリ表示 ("N 件にタグを付けました") — calm UX に反する、将来 spec
- v2 backfill (限度を変える等の挙動変更時に再実行を発火する仕組み) — 将来 spec
- 起動以外のタイミング (例: Settings からのトリガー) で backfill を起動する — 将来 spec
- 「タグ整理中」を AI ブレインタブの PowerGauge / KnowledgeMap でも表示する — BottomStatusBar 共有のみ

## ユーザストーリー

### US1 (P1) — 既存全記事への 1 度限りの auto-apply

**As a** spec 008-011 を使ってきて何十件も記事を保存してきたユーザー
**I want** spec 013 リリース後の初回起動で、過去の記事にも自動的にタグが付く
**So that** Detail を開いていちいち「AI が見つけたタグ」をタップしなくても、自分の AI ブレインが整理された状態になる

#### 受け入れ基準

- spec 013 を含むビルドを最初に起動した瞬間、bootstrap 処理の最後で backfill が走る
- BottomStatusBar に「タグ整理中…」表示 (進行中のみ、完了で消える)
- backfill は対象 article (knowledge succeeded + tags 空) のみ処理
- 各 article で `AutoTagApplier.apply()` が呼ばれる (= spec 012 と同じロジック、上位 5 タグ付与)
- 完了後、AI ブレインタブの PowerGauge は不変 (Article / Entity / KeyFact 数は変わらない)、KnowledgeMap には新しいタグノードが多数 fade-in で出現
- 通知 / バッジ / 完了アラート / トースト → 一切なし (calm UX)

### US2 (P1) — 重複実行防止

**As a** spec 013 リリース後にアプリを 2 回目以降起動するユーザー
**I want** backfill が再実行されない
**So that** 起動時間が毎回 1 分も待たされない、また既に削除したタグが復活しない

#### 受け入れ基準

- 1 度 backfill が完了したら永続フラグ (UserDefaults キー) が true に設定される
- 2 回目以降の起動では bootstrap で early return → backfill 走らない
- 起動時間は spec 012 までと同じ (BottomStatusBar に「タグ整理中…」表示なし)

### US3 (P2) — 既に整理済の記事は触らない

**As a** spec 008-011 で既に手動タグを付けてきた記事や、spec 012 で auto-apply 済の記事を持つユーザー
**I want** これらの記事に余計なタグを足したり削除したりしないでほしい
**So that** 自分の意図的なタグ付けが保たれる

#### 受け入れ基準

- backfill 対象は `tags.isEmpty == true` の article のみ
- `tags.count >= 1` の article は完全スキップ (spec 012 の AutoTagApplier 既存 early return ロジックを再利用)
- knowledge.status が `.failed` / `.pending` / `.skipped` / `.extracting` の article もスキップ
- 既存タグ / 既存挙動への破壊的変更ゼロ

### US4 (P2) — 失敗時の継続性

**As a** 大量の記事を持っているユーザー
**I want** 1 件で失敗しても backfill 全体が止まらない
**So that** ほとんどの記事は確実に整理される

#### 受け入れ基準

- 個別 article の処理で例外発生 → log のみ記録、次の article に進む
- 全件処理完了後、永続フラグ true セット
- ログには `[backfill] processed N/M articles, skipped X` のサマリ

### Edge Cases

- **既存記事 0 件 (新規インストール)**: 候補 0 件 → backfill は即座に完了、フラグ true
- **既存記事 10000 件のような極端ケース**: 各記事 ~50ms × 10000 = 500 秒 → アプリ使用不能の懸念。本 spec では「全件処理」を選択しているので、本当に長時間かかったら BottomStatusBar 「タグ整理中…」だけが表示される。crash しないこと、aborting で止めないこと
- **backfill 中にユーザーが新記事を Share Sheet で追加**: 新規 article は spec 012 の通常フローで auto-apply されるため backfill とは独立 (順序的な競合はあるが両者の effect は冪等)
- **backfill 中にアプリが background に行って終了**: フラグはまだ false → 次回起動で再実行 (= 進行中のだけは再処理になるが冪等性で問題なし)
- **backfill 中に scenePhase 変化**: 中断せず最後まで完走させる (一旦走り始めたら停止しない)
- **フラグ手動リセット (デバッグ用)**: アプリの設定アプリで「データを削除」など。再インストール後はもちろん再実行
- **knowledge.status が .extracting で stale state の article**: spec 008 の自動回復 + spec 009 BG task で別途処理されるため、本 backfill では対象外 (skip)

## 機能要件

### 1. 発火タイミングと重複防止

- **FR-001**: アプリ起動時の `KnowledgeTreeApp.bootstrap()` 末尾、`knowledgeService.backfillAll()` および `tagStore.cleanupOrphans()` の後に backfill ステップを 1 回呼ぶ
- **FR-002**: 永続フラグ (UserDefaults キー: `auto_tag_backfill_v1_done`) を最初にチェック、既に true なら早期 return
- **FR-003**: backfill 完了後、フラグを true にセット (個別 article の失敗があっても全体完了とみなして true)
- **FR-004**: 2 回目以降の起動で bootstrap が走るたびに FR-002 で早期 return → backfill ステップ自体が走らない
- **FR-005**: フラグ key 名に `_v1` 接尾辞を含める。将来 spec で v2 backfill (例: limit を変更) を追加する場合に新キーで再実行できる

### 2. 対象記事の選定

- **FR-006**: backfill は SwiftData 全 Article を fetch (predicate なし) → メモリで filter
- **FR-007**: 対象条件 (全部 AND):
  - `article.tags.isEmpty == true`
  - `article.extractedKnowledge != nil`
  - `article.extractedKnowledge.status == .succeeded || .partiallySucceeded`
- **FR-008**: 上記条件を満たさない article は処理せず skip
- **FR-009**: 対象 article 数を log に記録 (例: `[backfill] starting: 47 candidates`)

### 3. 各 article への処理

- **FR-010**: 各対象 article について `AutoTagApplier.apply(to: article, using: tagStore)` を順次呼ぶ (spec 012 既存ロジック再利用)
- **FR-011**: AutoTagApplier 内の早期 return ロジックは backfill でも有効: tags 既存 / status 不適合 / suggestions 空 → no-op
- **FR-012**: 個別の AutoTagApplier.apply の例外 (TagStore.addTag 失敗等) は AutoTagApplier 内で捕捉済 (spec 012 既存 graceful failure)
- **FR-013**: backfill ループ自体に try/catch を被せ、想定外の例外 (例: SwiftData fetch 失敗) で全体停止しない

### 4. UI / 進捗表示

- **FR-014**: BottomStatusBar に「タグ整理中…」表示 (進行中のみ)
- **FR-015**: 表示は spec 011 の `ProcessingMonitor` 経由。新フェーズ (例: `.tagBackfilling`) を追加するか、既存メカニズムで「現在処理中の article」表示として代用する (実装で詰める)
- **FR-016**: backfill 中も spec 011 の AI ブレインタブ (PowerGauge / KnowledgeMap / RecentActivity) は表示可能。タグが付与されると即座に RefreshTrigger.bump で UI 更新 (KnowledgeMap でノード fade-in)
- **FR-017**: backfill 完了で BottomStatusBar 「タグ整理中…」表示が消える (進行中状態クリア)
- **FR-018**: backfill 中の処理時間がユーザーに不快にならないよう、最大の article から処理 (例: 最新の 50 件を先に) — ユーザーは新しい記事に最も興味を持つため早く UI に反映される

### 5. ストレスゼロ原則

- **FR-019**: backfill 開始時の通知 / バッジ / サウンド / アラート 一切なし
- **FR-020**: backfill 完了時の通知 / バッジ / トースト「N 件にタグを付けました」一切なし
- **FR-021**: AI ブレインタブの KnowledgeMap で新タグが fade-in 出現するのは spec 011 既存挙動 (calm UX 内、許容)
- **FR-022**: BottomStatusBar の「タグ整理中…」は控えめなテキスト + ProgressView (spec 005 既存スタイル踏襲)

### 6. 既存挙動の保持

- **FR-023**: spec 012 の AutoTagApplier の挙動は **改変しない**
- **FR-024**: spec 008 の TagStore / SuggestedTagFinder / TagNormalizer の挙動は変更しない
- **FR-025**: spec 002 / 003 / 004 の enrichment / body / knowledge backfill の挙動は変更しない (本 spec の backfill は最後に追加されるだけ)
- **FR-026**: spec 011 の TabView / AIBrainView / KnowledgeMap / PowerGauge は本 spec で改変しない
- **FR-027**: spec 005 の RefreshTrigger / scenePhase / NotificationCenter / Timer の live update メカニズムは変更しない

### 7. 失敗ハンドリング

- **FR-028**: 個別 article 処理での例外は AutoTagApplier 内で `try?` 経由で吸収 (spec 012 既存)、本 backfill は影響を受けない
- **FR-029**: backfill ループ内での fetch 失敗 / context.save 失敗 → log + 全体停止せず次の article へ
- **FR-030**: 全件完了後、フラグ true セット (個別失敗があっても完了扱い、再実行はしない方針 — Constitution Principle II MVP)
- **FR-031**: フラグセットが失敗 (UserDefaults 書き込み失敗) は実質起こらないが、起こった場合は次回起動で再実行される (= 副作用は冪等性で吸収)

## 主要エンティティ

新規 @Model 追加なし。既存 entity を読み書き:

| 操作 | 既存モデル / プロパティ |
|---|---|
| 全 article 取得 | `Article` 全件 (`FetchDescriptor<Article>()` predicate なし) |
| 候補判定 | `article.tags.count` (skip 判定) / `article.extractedKnowledge.status` (status 判定) |
| 付与結果 | `article.tags` への Tag 追加 (TagStore 経由、spec 008 / 012 既存) |
| 永続フラグ | `UserDefaults.standard` キー: `auto_tag_backfill_v1_done` (Bool) |

### Transient (永続化しない)

なし (backfill の中間状態は持たない)。

## 成功基準 (Success Criteria)

- **SC-001**: spec 013 を含むビルドの初回起動 → bootstrap 完了後、対象既存記事 (タグ 0 + knowledge succeeded) のうち少なくとも 80% に上位 5 タグが自動付与される
- **SC-002**: 100 件規模の対象記事を持つ実機環境で backfill 全完了が **30 秒以内**
- **SC-003**: 1000 件規模で **5 分以内** (Constitution パフォーマンスゲート的に許容範囲、起動を妨げない)
- **SC-004**: 2 回目以降の起動で bootstrap がフラグ判定で 1ms 以内に early return → spec 012 までと同じ起動時間に戻る
- **SC-005**: backfill 中に新記事を Share Extension で保存 → 新記事は spec 012 の通常フローで auto-apply される (backfill との競合なし)
- **SC-006**: backfill が中断 (アプリ強制終了 / scenePhase 復帰) → 次回起動で再実行され完走する
- **SC-007**: 既に手動タグ付き article / auto-apply 済 article / knowledge failed article のいずれも backfill で触られない (回帰なし)

## 依存・前提

- **spec 001-012** までの全機能が稼働済 (spec 011 + 012 は `012-auto-tag` ブランチに commit 済、本 spec は `013-auto-tag-backfill` ブランチで 012 の続き)
- **iOS 26+** / iPadOS 26+ (既存と同じ)
- **既存 SwiftData schema** で全データ取得可能 (新 @Model / 新 migration ゼロ)
- spec 012 の `AutoTagApplier`、spec 008 の `TagStore` / `SuggestedTagFinder` を再利用
- spec 005 の `ProcessingMonitor` / `RefreshTrigger` を BottomStatusBar 表示と UI 更新に利用

## アサンプション

- **永続フラグ key**: `auto_tag_backfill_v1_done` (Bool, UserDefaults.standard)。Constitution Additional Constraints の「UserDefaults の非自明な用途禁止」例外: 「1 度だけ実行する migration / backfill フラグ」は典型的な使い方として許容
- **App Group 共有**: フラグは main app プロセスのみで使うため、App Group container ではなく `UserDefaults.standard` で十分
- **fetch の order**: `FetchDescriptor<Article>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])` で **最新の article 優先** で処理 (FR-018、ユーザー最近関心への早期 UI 反映)
- **batch size**: 全件をメモリ load → 1 件ずつ処理。1000 件 × Article (≤1KB) = 1MB 程度なので OK。10000 件で 10MB は許容範囲
- **MainActor 実行**: AutoTagApplier は `@MainActor`、bootstrap も `@MainActor`、なので backfill ループも MainActor で順次同期実行
- **`Task.detached`**: 検討したが、SwiftData の MainActor 制約 + AutoTagApplier の MainActor 注釈で、結局 MainActor に bounce する。素直に `await` で順次実行する (起動時間のブロッキングは BottomStatusBar 表示で許容)
- **進行中の UI 更新頻度**: TagStore.addTag が内部で `RefreshTrigger.bump()` を呼ぶ → 1 article で最大 5 回 bump → 100 件で 500 回。これは spec 005 の bump 既存実装で `&+= 1` の Int オーバーフロー安全 + Observable で 1 frame 内に集約されるため許容
- **新ユーザー (記事 0 件)**: 候補 0 件 → backfill は 1ms で完了、フラグ true → 以降 spec 012 の通常フローのみ

## ロールアウト

- ユーザーへの破壊的変更は無い (既存タグ削除 / 既存挙動消失なし)
- 「タグが勝手に増えた」体験は **意図通り** (spec 012 の延長、calm UX 範囲内)
- 既存記事 (count ≥ 1 タグ) は触られない → backward compatible
- 永続フラグで初回のみ実行、以降のリソース消費はゼロ

## 非機能

- **パフォーマンス**: 100 件で 30 秒、1000 件で 5 分以内 (SC-002 / SC-003)。各 article ~50ms (spec 012 と同じ)
- **メモリ**: 1000 件 article × ~1KB = 1MB ピーク使用 (Constitution パフォーマンスゲート 100MB 以内 ✅)
- **電池**: 起動時 1 回のみ、UI 表示中の処理 → 影響軽微
- **アクセシビリティ**: BottomStatusBar の「タグ整理中…」テキストは spec 005 既存 accessibilityLabel に従う
- **Dark Mode**: BottomStatusBar の既存スタイル踏襲、新規変更なし
- **Dynamic Type**: 同上

## オープン質問

なし (確定済の 7 仕様判断)。実装時に詰める細かい論点:

- ProcessingMonitor の新フェーズ (`.tagBackfilling`) を追加するか、既存メカニズムで代用するか
  - 新フェーズ追加 = BottomStatusBar に専用ラベル「タグ整理中…」が出やすい
  - 既存メカニズム代用 = ProcessingMonitor は「現在処理中の article」モデルなので、backfill 全体を 1 つの仮想 article として表示する
- → plan.md で詰める
