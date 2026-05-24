# Feature Specification: SavedAnswer.isStale 表示 + 「再生成」アクション (WikiLint Lite Phase 1)

**Feature Branch**: `045-stale-saved-answer-ui` (実装は `044-understanding-chat` ブランチ内に内包)
**Created**: 2026-05-23
**Status**: Draft

## なぜ (Why)

spec 043 で `SavedAnswer.isStale: Bool` を導入し、新記事 ingest 時に関連 ConceptPage を経由して連鎖更新する仕組みを実装した (KnowledgeExtractionService の hook 経由)。しかし **isStale フラグが UI に一切露出していない silent flag** のため、ユーザーは:

- 過去の AI 答えを読み返した時に、それが既に古くなっていることに気づけない
- 新しい記事を保存したのに、紐付く SavedAnswer が更新されない (現在 AI で再生成する手段なし)

これは Karpathy「保存した知識が compound する」原則を半分しか満たせていない (蓄積はするが、新情報で update されない)。本 spec で **isStale 表示 + 再生成アクション** を最小コストで実装する。

## ゴール

- ConceptPage 詳細「質問と答え」セクション / SavedAnswerHistoryView / SavedAnswerDetailView の 3 箇所で isStale を視覚マーク (control 抑制した穏やかな表示、calm UX)
- SavedAnswerDetailView toolbar に「再生成」Button — AI チャットタブで新 ChatSession を作って同 question を再送信、答えが返ってきたら spec 043 既存 hook で **新 SavedAnswer が auto-save** される (重複防止 logic は既存)
- 再生成後、古い SavedAnswer は `isStale=true` のまま残す (履歴保護)。ユーザーが手動で「削除」する判断は別、calm UX で勝手に消さない

## 非ゴール

- AI による「自動 merge」(古い answer と新 answer を AI が統合) — 別 spec
- isStale の根拠表示 (どの新記事が isStale 化した か) — 別 spec
- 「全 isStale 一括再生成」一括 batch — 別 spec、calm UX violations
- pull-to-refresh で全 isStale を表示 — 既に SavedAnswerHistoryView は全件表示なので追加不要

## ユーザストーリー

### US1 (P1) — ConceptPage 詳細で isStale バッジ表示

1. 知識 Clip タブ → ConceptPage 詳細を開く
2. 「この概念についての質問と答え」セクションの SavedAnswerRow に **オレンジの 🕒 マーク + 「更新が必要」chip** が表示される
3. タップで SavedAnswerDetailView に遷移、上部に「この答えは古くなっている可能性があります」notice 表示

### US2 (P1) — SavedAnswerDetailView から「再生成」

1. SavedAnswerDetailView (isStale=true) の toolbar に **「再生成」Button** (`arrow.clockwise` icon)
2. タップで AI チャットタブに遷移、新 ChatSession を作成して同 question (前回保存の question そのまま) を自動送信
3. AI が新しい答えを生成 → 既存 spec 043 hook で **新 SavedAnswer が自動保存** される (citedArticles も新規 fetch)
4. 古い SavedAnswer は `isStale=true` のまま残す (ユーザーが「削除」を判断、calm UX)

### US3 (P2) — SavedAnswerHistoryView で isStale フィルター chip

1. Settings → 「保存された答えの履歴」を開く
2. 上部に **「⚠️ 更新が必要 (N)」chip** が表示 (N>0 時のみ、0 件で非表示)
3. chip タップで isStale=true のみ表示にフィルター、もう一度タップで全件に戻る

### US4 (P3) — markFresh アクション (手動「更新済」マーク)

1. SavedAnswerDetailView の toolbar に「**…**」menu (`ellipsis.circle`)、その中に「更新済としてマーク」
2. タップで isStale=false に手動更新 (再生成せず「これは今でも有効」を明示)、calm UX、誤連鎖更新の手動修正

## 機能要件

- **FR-001**: SavedAnswerRow に isStale 視覚マーク (オレンジ 🕒 icon + 「更新が必要」chip) を追加。isPinned chip と共存。
- **FR-002**: SavedAnswerDetailView 上部に isStale=true 時の notice banner (「この答えは保存後に関連記事が追加されています。再生成で最新の AI 答えを得られます。」)
- **FR-003**: SavedAnswerDetailView toolbar に「再生成」Button (isStale=true 時のみ表示、`arrow.clockwise` icon)
- **FR-004**: 「再生成」タップで以下を順次実行:
  - (a) AI チャットタブを開く
  - (b) 新 ChatSession を作成
  - (c) 元 SavedAnswer.question を session に送信 (ChatService.send)
  - (d) AI 答えが返ってきたら spec 043 ChatService hook 経由で **新 SavedAnswer が自動保存** (重複判定は normalizedQuestion 完全一致なので、isStale 古 SavedAnswer と question 完全一致しても新 SavedAnswer は作られない)
- **FR-005**: 再生成失敗時 (AI 不可 / network 不能 / Foundation Models 拒否) は AI チャットタブの既存 error UI に乗る (本 spec で追加 UI なし、graceful degradation)
- **FR-006**: SavedAnswerHistoryView 上部に isStale フィルター chip (件数 0 で非表示、calm UX)
- **FR-007**: SavedAnswerDetailView toolbar に「更新済としてマーク」menu item (`ellipsis.circle` menu 内)、タップで `SavedAnswerService.markFresh(_:)` 経由で isStale=false に更新
- **FR-008**: SavedAnswerService に `markFresh(_ answer:) throws` method を追加 (isStale=false + updatedAt=.now + try save)
- **FR-009**: 「再生成」後、古い SavedAnswer は自動削除しない (履歴保護)
- **FR-010**: 重複防止: 既存 SavedAnswerService.captureIfWorthy の question 完全一致 skip 動作で、新規 SavedAnswer 作成は 1 回のみ
- **FR-011**: calm UX: 「再生成」push 通知 / 効果音 / streak バッジ ゼロ (Constitution V)
- **FR-012**: 全 chip / icon に `accessibilityIdentifier` (`savedAnswer.stale.chip` / `savedAnswer.stale.notice` / `button.regenerate` / `button.markFresh` / `chip.stale.filter`)

## 重複防止の議論 (FR-010 の課題と解決)

現状の `captureIfWorthy` は **question 完全一致** で重複を skip する。「再生成」フローで同 question を送信した場合、新規 SavedAnswer は作られず、古い isStale SavedAnswer がそのまま残る → 再生成の意味がない。

**解決方針**:
- `captureIfWorthy` を改修して: 「同 question で `isStale=true` の既存 SavedAnswer は **置き換え** (古を delete + 新を insert)」
- もしくは追加 method: `captureIfWorthyOrReplaceStale(question:answer:citedArticleIDs:sessionID:)` を追加
- 採用: 後者 (既存 contract を壊さない、再生成経路のみ別 method)

(Plan の R6 で詳細詰める)

## 成功基準

- SC-001: isStale SavedAnswer を含む ConceptPage 詳細を開く → SavedAnswerRow にオレンジ 🕒 + chip 表示 (1 秒以内)
- SC-002: isStale SavedAnswer の詳細を開く → notice banner + 「再生成」Button 表示
- SC-003: 「再生成」タップ → AI チャットタブ遷移 + 新 ChatSession 作成 + question 送信 (3 秒以内、Apple Intelligence 利用可時)
- SC-004: AI 答え受信後 5 秒以内に新 SavedAnswer が DB 永続化 (置換 path 経由)
- SC-005: 古い SavedAnswer は isStale=true のまま履歴に残る (削除しない、calm UX)
- SC-006: SavedAnswerHistoryView 上部に「⚠️ 更新が必要 (N)」chip 表示 (N>0)、N=0 で非表示
- SC-007: chip タップで isStale=true のみフィルター、再タップで全件
- SC-008: 「更新済としてマーク」タップで isStale=false に DB 反映 (1 秒以内)
- SC-009: 再生成失敗時 (Apple Intelligence 不可) は AI チャットタブの既存 fallback UI に乗り、user 操作可能
- SC-010: streak / バッジ / 通知 ゼロ (Constitution V binary check)

## アサンプション

- spec 043 SavedAnswer + isStale + ChatService.send hook が稼働中
- spec 044 学習タブ / DeepDiveChatService とは独立 (相互影響なし)
- 再生成は AI チャットタブ経由 (DeepDiveChat ではない、retrieval 必要)
- ユーザーは「再生成」が手動操作であることを理解 (自動再生成は不要 / 通知 calm UX 違反)

## 依存

- spec 043 (SavedAnswer.isStale フィールド + captureIfWorthy + ChatService.ask 末尾 hook)
- spec 021 (ChatService.createSession + send)
- spec 014/017 (DesignSystem の orange + adaptive Color)
- spec 016 (SavedAtFormatter 流用)

## 想定実装規模

- 改修 4 view (SavedAnswerRow / SavedAnswerDetailView / SavedAnswerHistoryView / ConceptPageDetailView 経由は SavedAnswerRow の更新で波及) + 改修 1 service (SavedAnswerService + 2 new method) + 改修 1 store (ChatService 経路への isStale 削除フック追加? 不要、再生成は別経路)
- 新規ファイル ゼロ
- ~300-400 行
- 新規テストケース 5-7 (markFresh + captureIfWorthyOrReplaceStale 動作検証)
