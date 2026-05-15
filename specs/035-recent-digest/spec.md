# Feature Specification: 「最近のあなた」差分ダイジェスト (機能 X)

**Feature Branch**: `035-recent-digest` (実装時に作成)
**Created**: 2026-05-08
**Status**: Draft (specify+plan のみ)
**Vision**: [VISION.md](../VISION.md) 機能 X

## なぜ (Why)

VISION.md コア価値「**読んだ知識を AI が自動で体系化・更新し、必要な時だけ開けば最新の自分が見える、優しい第二の脳**」のうち、**「必要な時だけ開けば最新の自分が見える」** を最も visible に実現する機能。

ユーザー要望 (2026-05-08):
- 朝に開いた瞬間「**最近保存したものの AI 要約 2-3 行**」が見えてほしい
- 期間: 「**前回開いた時から今まで**」の差分
- 中身: 「**全体を統合して 3 段落**」("最近のあなたが学んだこと")

## ゴール

- 知識 Clip タブの **最上部に「最近のあなた」セクション** を追加
- 前回タブを開いた時刻 〜 now の間に保存された記事を、AI で **3 段落統合要約** に整形
- 通知 / アラートなし (calm UX、Constitution V)
- 起動時は知識 Clip タブが default selection (見えるべきものを最初に見せる)

## 非ゴール

- アプリ起動時の modal / popup → 強制的、Constitution V 違反
- 「未読カウント」表示 → 罪悪感を生む、Constitution V 違反
- 通知 / バッジ → constitution V
- 過去 N 日固定 (e.g., 7 日) → 「前回開いた時」差分の方がパーソナル
- 「マスト読」「優先度」表示 → カオスを増やす、自然な要約のみ

## ユーザストーリー

### US1 (P1) — 開いた瞬間に最近の差分が見える

1. 知識 Clip タブを開く
2. 最上部に「最近のあなた」セクション
3. AI 統合 3 段落 (前回開いた時 〜 now の差分)
4. 「N 件の記事から」のような meta 表示

### US2 (P1) — 起動時に知識 Clip タブが選択される

1. アプリ起動 (cold start)
2. デフォルトで知識 Clip タブが選択された状態
3. 「最近のあなた」が即見える

### US3 (P2) — 差分が空でも醜くない

1. 前回開いた時から今まで保存記事 0 件
2. 「最近のあなた」セクションは **見せない / 既存 Category Digest だけ表示**
3. もしくは「お帰りなさい、新しい記事はまだありません」(任意)

### US4 (P2) — タブを開いた時刻を更新

1. 知識 Clip タブを開く
2. その時刻が `lastOpenedAt` に保存される
3. 次回開いた時はこの時刻からの差分

## 機能要件

### Last Opened Tracking

- **FR-001**: `LastOpenedStore` (UserDefaults wrapper) で `chatTab.lastOpenedAt: Date` を管理
- **FR-002**: 知識 Clip タブが onAppear した瞬間、現在時刻を記録
- **FR-003**: 初回起動 (timestamp なし) → デフォルトを `Date.distantPast` にして「全件」扱い

### Differential Article Fetch

- **FR-004**: `Article.savedAt > lastOpenedAt` の Article を fetch
- **FR-005**: 最大 N 件 (default 30、過剰な場合は最新優先)
- **FR-006**: 0 件の場合 → セクション非表示

### AI 統合 3 段落要約

- **FR-007**: 新 `RecentDigestService` protocol + Foundation/Fallback 2 実装 (spec 015 / 018 と同パターン)
- **FR-008**: `@Generable RecentDigestOutput { paragraphs: [String] }` (3 段落、各 80-150 字)
- **FR-009**: prompt: 「以下の N 件の記事の要点を、自然な日本語の 3 段落で統合してください」
- **FR-010**: Foundation Models 不可端末 → Fallback (各記事 essence を順序通り並べた擬似 3 段落)
- **FR-011**: 結果はキャッシュ (lastOpenedAt が変わらない限り再生成しない、起動毎の API 呼び出し抑止)

### UI

- **FR-012**: KnowledgeClipView 最上部に `RecentDigestSection` 新規 view を挿入
- **FR-013**: 表示要素:
  - ヘッダ「最近のあなた」(H2 風)
  - meta「N 件の記事から (期間: X 月 X 日 〜 X 月 X 日)」(small caption)
  - 段落 1 / 段落 2 / 段落 3 を縦並びで表示 (DS.Color 既存トークン)
- **FR-014**: スワイプ / ジェスチャー対応:
  - DisclosureGroup で展開 / 収納 (1 段落だけ default 表示も検討)
  - リフレッシュ pull-to-refresh で再生成 (spec 018 同パターン)

### Default Tab Selection

- **FR-015**: KnowledgeTreeApp の TabView に `selection` Binding を追加
- **FR-016**: 起動時 `selection = .knowledgeClip` (knowledge Clip タブを default に)
- **FR-017**: ユーザーが他タブを選択した状態を維持しない (cold start で常に Clip タブから)

## 成功基準

- SC-001: 記事保存後、知識 Clip タブを閉じて再度開く → 「最近のあなた」セクションに新記事が反映 (3 段落)
- SC-002: 同 lastOpenedAt 内で 2 回開く → AI 再生成なし (キャッシュ動作)
- SC-003: 差分 0 件 → セクション非表示、既存 Category Digest が普通に見える
- SC-004: アプリ cold start → 知識 Clip タブが default selection
- SC-005: Foundation Models 不可端末 → Fallback で 3 段落擬似要約 (記事 essence 並び)
- SC-006: 既存 Category Digest 表示に regression なし
- SC-007: 5 秒以内に 3 段落表示 (Apple Intelligence 端末、N=10 件)

## アサンプション

- 1 セッションあたりの差分は通常 1-30 件 (週 1-2 回開く想定)
- 30 件超は最新優先で truncate (chunk 不要、1 prompt に収まる)
- 各記事 essence 100-150 字 × 30 件 = ~4500 字 → Foundation Models 4096 token に収まる前提

## 依存・前提

- spec 018 (KnowledgeDigest 実装、`@Generable` パターン参考)
- spec 021 (Foundation Models prompt パターン参考)
- spec 015 (`AvailabilityChecker` 既存)

## 想定実装規模

- 新規 4 ファイル:
  - `Models/LastOpenedStore.swift` (~50 行、UserDefaults wrapper)
  - `Services/RecentDigestService.swift` (~150 行、protocol + Foundation + Fallback)
  - `Views/RecentDigestSection.swift` (~100 行、UI section)
- 改修 2 ファイル:
  - `Views/KnowledgeClipView.swift` (~20 行、最上部に section 追加)
  - `KnowledgeTreeApp.swift` (~15 行、TabView selection binding)
- 新規テスト 1 ファイル:
  - `RecentDigestServiceTests.swift` (~5 ケース)
- 合計 ~340 行、~6-8 タスク

## Constitution

- I (privacy): on-device、外部送信ゼロ
- II (MVP): 単一機能 (差分 3 段落のみ)、複雑な期間設定 / 並べ替えは将来 spec
- III (source 追跡): 段落生成元 Article ID は内部保持、UI で「N 件の記事から」表示
- IV (実現可能性): Foundation Models + Fallback で全端末対応
- V (calm UX): 通知ゼロ、差分 0 件は静かに非表示
- VI (architecture): protocol + DI、spec 018 と同パターン
- VII (日本語): 全 UI 日本語、prompt 日本語

## 状態

📝 specify+plan 完了 (2026-05-08)、`/speckit-tasks` + `/speckit-implement` は次セッションで。
