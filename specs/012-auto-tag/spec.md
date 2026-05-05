# Feature Specification: タグ自動付与 (AI Auto-Tag)

**Feature Branch**: `012-auto-tag`
**Created**: 2026-05-05
**Status**: Draft

## なぜ (Why)

spec 008 で導入した「AI が候補タグを **提案する** → ユーザーが個別チップタップで **採用する**」フローは、ユーザーが Detail を開いて「いちいち判断する」手間を強いていた。spec 011 で AI ブレイン体験を強化したことで、ユーザー期待は **「自分の AI が育っていて、勝手に整理しておいてくれる」** に変わっている。

本 spec では「AI が **自動でタグを付与する** → ユーザーは編集 / 削除 / 追加で **微調整する**」フローに切り替える。手動タグ付けの主体性は残し、AI に「自動下書き」を任せる構造とする。

Constitution Principle V (シンプルで落ち着いた UX) に厳格に準拠: 自動付与の発火は静かに行い、push 通知 / バッジ / 音は導入しない (ユーザーが Detail を開いた時に「もうついてた」体験を提供)。

## ゴール

- 新規記事を共有保存 → knowledge 抽出が完了 → 該当 article に上位 5 タグが**自動で**付いている
- ユーザーは Detail を開いた瞬間、既にタグが付いていることを発見できる
- 不要なタグは x ボタンでいつでも削除できる
- 不足タグは入力欄でいつでも追加できる
- 「AI が見つけた他のタグ」(自動付与されなかった候補) は引き続き提案チップとして参考表示される
- 既に手動タグが付いている記事 (spec 008 までの既存記事) は AI が触らない (= 既存運用が壊れない)

## 非ゴール

- 自動付与のオン / オフ切替設定 (Settings 画面追加) — 将来 spec
- 信頼度別の付与挙動 (例: salience 5 のみ自動、4 は提案のまま) — 将来 spec
- ユーザー削除タグの永続的ブラックリスト (再抽出で復活させない仕組み) — 将来 spec
- 既存記事 (spec 011 までに保存済) への一括 backfill 自動付与 — 将来 spec、既存運用継続
- タグ自動付与の **理由表示** (どの entity から派生したか) — 既存提案チップ UI で salience は推定可能、別途 UI は将来 spec

## ユーザストーリー

### US1 (P1) — 新記事保存後に自動でタグが付いている

**As a** Safari で記事を共有保存したユーザー
**I want** Detail を開いた時に、既にタグが付いている状態を見たい
**So that** 個別にチップをタップする手間なく、整理された状態を即座に得られる

#### 受け入れ基準

- ユーザーが Share Sheet で記事 URL を共有 → 「知積」アプリ
- knowledge 抽出が裏で完了 (即時または BG task で 数秒〜数分)
- ユーザーが Detail を開く → 既に上位 5 タグ (salience desc) が付与されている
- タグは spec 008 既存の TagChip 表示形式 (x ボタン付き、削除可)
- 「AI が見つけた他のタグ」セクションには、auto-apply された 5 件以外の salience ≥ 4 候補が並ぶ (なければセクション非表示)
- 自動付与中の通知 / バッジ / 音は無し (calm UX)

### US2 (P1) — 既に手動タグが付いている記事は触られない

**As a** spec 008 の運用で既に手動タグを付けてきたユーザー
**I want** 既に整理済の記事に AI が勝手にタグを足さないでほしい
**So that** 自分の意図的なタグ付けが上書きされない

#### 受け入れ基準

- 既に `article.tags.count >= 1` の記事は、knowledge 再抽出が走っても auto-apply スキップ
- 既存タグはそのまま残る
- 「AI が見つけた他のタグ」提案チップは引き続き表示される (ユーザーが個別タップで追加可)
- このスキップ動作は spec 011 までの全既存記事に適用される (= backward compatible)

### US3 (P2) — 不要なタグを削除して整理する

**As a** AI が自動付与したタグの中に「これは要らない」と思うものがあるユーザー
**I want** 既存の x ボタンで即座に削除したい
**So that** 不要タグを除外して自分好みに整理できる

#### 受け入れ基準

- 各タグの x ボタン (spec 008 既存挙動) で削除可
- 削除後、即座に UI 反映 (タグ消失)
- knowledge 再抽出が再度走った時、削除タグが salience ≥ 4 を保てば **再度 auto-apply される** (= 復活する。シンプル化のため、本 spec では永続的ブラックリストは導入しない)
- ユーザーが「再抽出 → 復活」が嫌なら、そのまま削除を維持するか、別の手動タグに置き換える

### US4 (P2) — 知識抽出が失敗したら自動付与は走らない

**As a** ネットワーク不安定 / Foundation Models 未利用可な状態で記事を保存したユーザー
**I want** 自動付与が「ゴミタグ」を勝手に付けないでほしい
**So that** ノイズが入らない

#### 受け入れ基準

- knowledge 抽出 status が `failed` / `skipped` / `pending` の場合、auto-apply は走らない
- `succeeded` または `partiallySucceeded` のみ auto-apply 発火
- 後で再抽出に成功した時、auto-apply が遡って実行される (= 1 度成功すれば付く)

### Edge Cases

- **記事の entity が 5 件未満**: 上位全件を付与 (4 件・3 件・0 件など)
- **entity が 0 件**: タグは付かない、提案チップも空
- **salience が全て 4 未満**: タグは付かない、提案チップも空
- **重複正規化**: 「OpenAI」「openai」「  OpenAI  」が混在 → TagNormalizer で同一視 → 1 つに統一して付与 (spec 008 既存)
- **既存タグ名と AI 提案が衝突**: 既存タグ名 (TagNormalizer 済) と一致する候補は除外して提案 (spec 008 既存挙動)
- **同 article への knowledge 再抽出**: tags ≥ 1 件なら auto-apply スキップ (US2)、tags == 0 件 (ユーザーが全削除した状態) なら再 auto-apply あり
- **chunked summarization 経路 (spec 010)**: lvl3 最終 meta-summary 完了で knowledge.status = .succeeded となるタイミングで発火 (BG task / メイン実行のいずれでも同じ)
- **spec 009 BG task で抽出完了**: メインプロセス復帰時の追従ではなく、BG task 内で同じ MainActor フローで auto-apply まで完了させる
- **アプリ強制終了中に knowledge 完了**: 次回起動時、bootstrap backfill で auto-apply 漏れがあれば補完される (新規対応)、または提案チップから手動採用 (既存挙動)

## 機能要件

### 1. 自動付与の発火タイミング

- **FR-001**: knowledge 抽出 (`KnowledgeExtractionService.run()` または同等パス) が `succeeded` / `partiallySucceeded` 状態に遷移した直後、同じ実行コンテキスト内で auto-apply ステップを呼び出す
- **FR-002**: spec 009 の BG task 経由 (`BackgroundExtractionRunner`) で knowledge 抽出が完了した場合も、同じ auto-apply ステップが実行される
- **FR-003**: spec 010 の階層的 chunked summarization (lvl1 → lvl2 → lvl3) で最終 meta-summary が確定した直後の status 遷移で発火する
- **FR-004**: knowledge 抽出 status が `failed` / `skipped` / `pending` / `extracting` の場合は **発火しない**
- **FR-005**: auto-apply は同 article に対して **冪等** (idempotent) — 既存タグ名と一致する候補は TagStore.addTag の既存スキップ挙動で no-op

### 2. 自動付与のスキップ条件 (Skip-on-existing)

- **FR-006**: auto-apply 開始時に `article.tags.count >= 1` なら **早期 return** で完全スキップ (US2)
- **FR-007**: スキップ時、ログ等で「skipped: existing tags」を記録してデバッグ可能にする (Constitution テストゲート向け)
- **FR-008**: スキップは knowledge 抽出 status とは独立に判定する (status = succeeded でも tags ≥ 1 ならスキップ)

### 3. 候補の選定と付与

- **FR-009**: 候補の取得は spec 008 既存の `SuggestedTagFinder.find(for:existingTagNames:limit:)` を **そのまま再利用**する
- **FR-010**: salience ≥ 4 のみ候補 (spec 008 既存閾値、本 spec で変更しない)
- **FR-011**: salience desc で sort、上位 **5 件** を auto-apply (spec 008 既存 default 5 と一致、本 spec でも 5 件で固定)
- **FR-012**: 各候補に対し `TagStore.addTag(rawName: candidate.displayName, to: article)` を呼ぶ
- **FR-013**: TagStore.addTag は内部で TagNormalizer.normalize を実行し、既存タグへの重複追加を防ぐ (spec 008 既存挙動)
- **FR-014**: 5 件未満しか候補が無い場合、ある分だけ付与 (Edge case)
- **FR-015**: 候補 0 件 (entity ゼロ / salience 全部 < 4) の場合、auto-apply は no-op で終了

### 4. UI への反映

- **FR-016**: auto-apply で付与されたタグは spec 005 の `RefreshTrigger.bump()` 経由で UI 即時更新 (Detail を開いている場合は live update、ライブラリ一覧でもタグセクション更新)
- **FR-017**: spec 011 の AI ブレインタブ KnowledgeMap も RefreshTrigger 経由で再構築され、新タグがノードとして fade-in 表示される
- **FR-018**: PowerGaugeCard の数字には影響しない (Article / KnowledgeEntity / KeyFact 数の変動なし、Tag 数だけ増える)
- **FR-019**: 「AI が見つけた他のタグ」提案チップセクション (`ArticleDetailView` 既存実装) は **廃止せず残す**。auto-apply された 5 件は existingTagNames に含まれるため、SuggestedTagFinder の重複排除で結果として除外される
- **FR-020**: 提案チップの個別タップで追加 (spec 008 既存挙動) は引き続き動作する

### 5. ユーザー操作

- **FR-021**: ユーザーは TagChip の x ボタンで auto-apply タグを削除できる (spec 008 既存挙動、変更なし)
- **FR-022**: ユーザーは TagInputField で手動タグ追加できる (spec 008 既存挙動、変更なし)
- **FR-023**: 削除したタグは再抽出時に salience ≥ 4 を保てば **再度 auto-apply される** (本 spec の許容仕様、永続ブラックリストは将来 spec)
- **FR-024**: ユーザーが auto-apply タグを 1 件でも残す → 残った時点で article.tags.count ≥ 1 → 次回再抽出で auto-apply スキップ (US2 / FR-006)

### 6. ストレスゼロ原則

- **FR-025**: auto-apply 発火時に push 通知を出さない
- **FR-026**: auto-apply 発火時にバッジを出さない
- **FR-027**: auto-apply 発火時にサウンド / 触覚フィードバックを出さない
- **FR-028**: auto-apply の進捗状況を BottomStatusBar に表示しない (knowledge 抽出 status の延長として静かに完了)
- **FR-029**: 「○件のタグが付きました」系のトーストやアラートを出さない (calm UX、ユーザーが Detail を開いた時に「もうついてた」体験を狙う)

### 7. 既存挙動の保持

- **FR-030**: spec 008 の `SuggestedTagFinder` のロジックは変更しない
- **FR-031**: spec 008 の `TagStore.addTag` / `removeTag` のロジックは変更しない
- **FR-032**: spec 008 の手動タグ入力 UX (TagInputField) は変更しない
- **FR-033**: spec 011 の TabView / AIBrainView / KnowledgeMap / RecentActivityCards は変更しない (auto-apply は KnowledgeExtractionService 内の追加ステップで完結)

## 主要エンティティ

新規スキーマ追加なし。既存 entity を読み書き:

| 操作 | 既存モデル / プロパティ |
|---|---|
| 候補入力 | `Article.extractedKnowledge.entities` (各 entity の name + salience) |
| スキップ判定 | `article.tags` (Array<Tag>) の count |
| 付与結果 | `article.tags` に Tag 追加 (TagStore 経由) |
| 既存タグ重複排除 | `Set(article.tags.map(\.name))` |
| 提案チップ表示 | spec 008 既存 SuggestedTag transient struct |

### Transient (永続化しない)

- なし (auto-apply の中間状態は持たない、純粋関数 + TagStore 副作用のみ)

## 成功基準 (Success Criteria)

- **SC-001**: 新規 article 保存 → knowledge 抽出 succeeded → 1 秒以内に上位 5 タグが Detail に表示される (spec 005 RefreshTrigger 経由 live update)
- **SC-002**: 手動タグ 1 件以上付いている既存記事を再抽出 → タグ count 変化なし (auto-apply スキップが正しく動作)
- **SC-003**: タグ全削除 (count = 0) 後に再抽出 → 上位 5 タグが復活する
- **SC-004**: knowledge 抽出 failed の記事 → タグは付かない (誤付与なし)
- **SC-005**: spec 008 までの既存全記事に対して回帰なし (既存タグはそのまま、提案チップは引き続き表示、手動入力可)
- **SC-006**: auto-apply の実行時間は knowledge 抽出時間に対して +5% 以下のオーバーヘッド (上位 5 件の TagStore.addTag は十分高速)
- **SC-007**: 100 件の連続記事保存 → 全件で auto-apply が発火 / スキップが正しく判定される (取りこぼしなし)

## 依存・前提

- **spec 001-011** までの全機能が稼働済 (spec 011 が main ブランチまだ未マージなので `011-ai-brain-tab` ブランチ前提)
- **iOS 26+** (既存依存と同じ)
- **既存 SwiftData schema** で全データ取得可能 (新 @Model 追加なし、migration なし)
- spec 008 の `SuggestedTagFinder` / `TagStore` / `TagNormalizer` を再利用
- spec 005 の `RefreshTrigger` でライブ更新

## アサンプション

- **付与数 5 件**: SuggestedTagFinder の既存 default `limit = 5` をそのまま使う。MVP で固定値、将来 spec で設定化可
- **salience 閾値 4**: SuggestedTagFinder の既存 `salienceThreshold = 4` をそのまま使う。MVP で変更しない
- **付与順序**: SuggestedTagFinder が salience desc で sort 済 → そのまま順次 addTag を呼ぶ。tags の表示順序 (article.tags Array) は SwiftData が挿入順を保持
- **MainActor 実行**: knowledge 抽出は既に @MainActor、auto-apply もメインアクターで完結 (新たな concurrency 検討不要)
- **失敗ハンドリング**: TagStore.addTag が throw しても auto-apply ループは継続 (1 件失敗で全体失敗にしない)。失敗したタグはスキップし次の候補に進む
- **冪等性**: TagStore.addTag が既存タグへの重複を内部スキップするので、auto-apply の二重実行は安全 (=`succeeded` 状態が 2 回 trigger されても問題なし)
- **bootstrap backfill 経路**: spec 004 の `knowledgeService.backfillAll()` が既存記事の knowledge を再生成する場面でも、auto-apply は通常通り発火する (= bootstrap backfill 後に既存記事のタグが増えうる)。これは US2 のスキップ条件 (`tags >= 1`) で大半が回避されるため許容

## ロールアウト

- ユーザーへの破壊的変更は無い (既存タグ削除 / 提案チップ消失 / 手動入力消失なし)
- 「タグが勝手に増えた」体験はあるが、calm UX 原則と整合する (押し付けがましくない)
- 既存記事 (count ≥ 1) は触られない → backward compatible

## 非機能

- **パフォーマンス**: auto-apply は knowledge 抽出完了直後の 100ms 以内、TagStore.addTag × 5 で 50ms 以内 (Constitution パフォーマンスゲート 100ms 以下準拠)
- **メモリ**: SuggestedTagFinder は entity リストを 1 回ループするだけ、O(N)
- **アクセシビリティ**: 自動付与されたタグも既存 TagChip と同じ accessibilityLabel / VoiceOver 動作 (spec 008 既存)
- **Dynamic Type**: 既存 TagChip / FlowingTagsLayout が既に対応済
- **Dark Mode**: 既存挙動 (色変更なし)

## オープン質問

なし (確定済の 4 仕様判断: 5 件 / 復活許容 / 手動タグ優先スキップ / 提案チップ残す)
