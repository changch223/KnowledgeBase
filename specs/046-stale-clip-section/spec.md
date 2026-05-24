# Feature Specification: 知識 Clip タブに「確認が必要な答え」セクション追加

**Feature Branch**: `046-stale-clip-section` (実装は `044-understanding-chat` 内)
**Created**: 2026-05-24
**Status**: Draft

## なぜ

spec 045 で `SavedAnswer.isStale` を **SavedAnswerHistoryView** (Settings 配下) と **ConceptPage 詳細** で表示するようにしたが、知識 Clip タブ (起動時に頻繁に開く主タブの 1 つ) では一切露出していない。ユーザーは「Settings → 履歴」まで掘らないと確認待ちの答えに気づけない。

spec 037 で導入した `FactConflictsSection` (知識 Clip タブ上部に「事実更新の提案」を表示) と同パターンで、`SavedAnswer.isStale=true` 件を **「確認が必要な答え (N)」セクション** として 並列配置する。

## ゴール

- 知識 Clip タブで `FactConflictsSection` の直後 (or 直前) に新セクション追加
- 0 件で非表示 (calm UX、FactConflictsSection と同パターン)
- 各行: SavedAnswerRow (spec 045 で isStale chip 表示済) + タップで SavedAnswerDetailView
- 上位 5 件 + 6+ 件なら「+N すべて見る」リンクで `SavedAnswerHistoryView` (showStaleOnly=true で開く)

## 非ゴール

- 各行 inline で「再生成」action (SavedAnswerDetailView に行けば 1 tap 増えるだけ、UI 圧迫回避)
- 並び替え / フィルター chip (履歴画面で対応済)
- 自動非表示 (1 度 user が「更新済」した答えが再 isStale 化した時の挙動 — 既存 markFresh / isStale 連鎖がそのまま機能)

## ユーザストーリー

### US1 (P1) — 知識 Clip タブで確認待ちが見える

1. ユーザーが知識 Clip タブを開く
2. RecentDigestSection / FactConflictsSection の隣 (or 直後) に **「⚠️ 確認が必要な答え (N)」** セクション表示
3. 上位 5 件の SavedAnswer が orange 🕒 icon + 「更新が必要」chip 付きで並ぶ
4. タップで SavedAnswerDetailView (既存 navigation)、ユーザーは notice + 「再生成」 Button (spec 045) で対応可能

### US2 (P2) — +N すべて見る

1. 確認待ち 6+ 件あれば「+N すべて見る」リンク
2. タップで `SavedAnswerHistoryView` (showStaleOnly=true initial state) に遷移

## 機能要件

- **FR-001**: 新規 `StaleSavedAnswersSection.swift` を `KnowledgeTree/Views/` に作成、`@Query(filter: #Predicate<SavedAnswer> { $0.isStale == true }, sort: [SortDescriptor(\.updatedAt, order: .reverse)])` で fetch
- **FR-002**: 0 件で `EmptyView()` (FactConflictsSection と同パターン)
- **FR-003**: 上位 5 件を `ForEach` で表示、6+ 件で「+N すべて見る」 NavigationLink
- **FR-004**: Section header: 「⚠️ 確認が必要な答え」 + 件数、calm UX (orange 控えめ)
- **FR-005**: `KnowledgeClipView` line 53 (FactConflictsSection の直後) に `StaleSavedAnswersSection()` 配置
- **FR-006**: 「+N すべて見る」遷移先は `SavedAnswerHistoryView` (既存 navigationDestination 経由、initial filter は妥協で全件表示で OK — ユーザーが上部 chip で絞り込み)
- **FR-007**: 各行は既存 `SavedAnswerRow` + NavigationLink (`SavedAnswerDetailDestination(id:)` 既存)
- **FR-008**: calm UX: push 通知ゼロ / バッジゼロ / 効果音ゼロ (Constitution V)

## 成功基準

- SC-001: isStale な SavedAnswer 1+ 件存在 → 知識 Clip タブを開く → 1 秒以内に「⚠️ 確認が必要な答え (N)」セクション表示
- SC-002: 0 件 → セクション完全非表示 (calm UX)
- SC-003: 各行タップ → SavedAnswerDetailView 遷移
- SC-004: 6+ 件で「+N すべて見る」リンク表示、タップで SavedAnswerHistoryView 遷移
- SC-005: spec 045「再生成」した直後 isStale=false → 知識 Clip タブを reload → 該当行が即消える
- SC-006: spec 045「更新済としてマーク」した直後も同様に消える

## 依存

- spec 045 (SavedAnswerRow の isStale chip 表示済)
- spec 043 (SavedAnswer.isStale フィールド + markStaleForArticle 連鎖)
- spec 037 (FactConflictsSection の同パターン参照)
- spec 035 (RecentDigestSection 配置と同 KnowledgeClipView)

## 規模

- 新規 1 ファイル (StaleSavedAnswersSection.swift、~80 行)
- 改修 1 ファイル (KnowledgeClipView.swift、1 行追加)
- xcstrings ~2 文言 (「確認が必要な答え」「+%lld すべて見る」既存活用)
- テスト: なし (純 UI、@Query 動作は SwiftData 標準で動作、既存 SavedAnswerServiceTests でカバー済)
- 合計 ~85 行
