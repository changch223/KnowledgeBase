# Implementation Plan: SavedAnswer.isStale 表示 + 「再生成」アクション

**Branch**: `045-stale-saved-answer-ui` (実装は `044-understanding-chat` 内に内包)
**Date**: 2026-05-23
**Spec**: [spec.md](./spec.md)

## Summary

spec 043 の `SavedAnswer.isStale` フラグを UI に露出し、新記事到来で古くなった答えをユーザーに気づかせる。**再生成 (regenerate)** で AI チャットタブで同 question を送信、新 SavedAnswer を auto-save。古い SavedAnswer は履歴保護で残す (calm UX)。

純 UI 拡張 + Service に 2 method 追加。新規 @Model / @Generable / service ゼロ。既存 4 view 改修 + 1 service 拡張 = ~350 行。

## Technical Context

**Language/Version**: Swift 6
**Primary Dependencies**: SwiftUI、SwiftData
**Storage**: 既存 `SavedAnswer` schema (isStale 既存フィールド) のみ、改修なし
**Testing**: 既存 SavedAnswerServiceTests に 3-4 ケース追加 (markFresh + captureIfWorthyOrReplaceStale)
**Target Platform**: iOS 26+ / iPadOS 26+
**Performance Goals**:
- isStale バッジ表示 1 秒以内 (SC-001)
- 「再生成」遷移 + AI 答え 3 秒以内 (SC-003)
- 新 SavedAnswer DB 反映 5 秒以内 (SC-004)
- 「更新済」マーク 1 秒以内 (SC-008)
**Constraints**:
- ChatService 既存契約変更しない (`captureIfWorthy` だけ拡張、別 method 追加)
- 古い isStale SavedAnswer は **自動削除しない** (履歴保護、ユーザー判断)
- streak / バッジ / 通知 ゼロ (FR-011)
**Scale/Scope**: ~350 行、5-8 task

## Constitution Check

- [x] **I. プライバシー** — SwiftData ローカル、新外部送信ゼロ。AI チャット経路は既存 ChatService (on-device Foundation Models)。
- [x] **II. MVP** — isStale UI 表示は spec 043 の自然な続編、最小スコープで完成。auto-merge / 一括 batch は明示分離。
- [x] **III. ソース追跡** — 再生成は ChatService の RAG 経路を経由するため citedArticles は既存仕様で適切に紐付く。古い SavedAnswer の citedArticles も @Relationship.nullify で保持。
- [x] **IV. iOS 実現可能性** — SwiftUI 標準 (NavigationLink + chip + menu)、新 API ゼロ。
- [x] **V. calm UX** — chip / banner は色を抑えた orange + 控えめな text。再生成は明示的ユーザー操作、自動再生成 / 通知 / 一括 batch 禁止 (FR-011)。
- [x] **VI. architecture** — Service 拡張は単方向 (View → Service → DB)、新 protocol ゼロ。既存 hook pattern を維持。
- [x] **VII. 日本語ファースト** — 新 xcstrings ~6 文言追加 (「更新が必要」「再生成」「更新済としてマーク」「この答えは保存後に関連記事が追加されています…」「⚠️ 更新が必要 (%lld)」「絞り込み解除」)

**Quality Gates 全 PASS**:
- コード品質: 既存 inline 削除パターン踏襲、新規抽象化ゼロ
- テスト: in-memory ModelContainer + Mock 不要 (純 SwiftData)
- accessibility: 全 chip/icon に identifier
- パフォーマンス: @Query filter で isStale 件数を境界付き

## Project Structure

```text
KnowledgeTree/Views/
├── SavedAnswerRow.swift              # ★ 改修 (~15 行追加): isStale chip + icon
├── SavedAnswerDetailView.swift       # ★ 改修 (~50 行追加): notice banner + 再生成 Button + 更新済 menu
├── SavedAnswerHistoryView.swift      # ★ 改修 (~30 行追加): isStale フィルター chip + filter state

KnowledgeTree/Services/
├── SavedAnswerService.swift          # ★ 改修 (~40 行追加): markFresh + captureIfWorthyOrReplaceStale
├── ChatService.swift                 # 改修ナシ (既存 hook で auto-save される)

KnowledgeTree/Localization/Localizable.xcstrings  # ★ 改修: ~6 文言追加

KnowledgeTreeTests/
└── SavedAnswerServiceTests.swift     # ★ 改修 (~80 行、3-4 ケース追加)
```

新規ファイル ゼロ。

## 主要技術判断 (R1-R7)

### R1: isStale chip / icon の色とアイコン

- `Image(systemName: "clock.badge.exclamationmark")` (iOS 16+ 確立) を orange で表示
- 並び: 既存 pin chip の隣 (両 chip は計 0-2 個、UI 圧迫なし)
- DesignSystem.adaptive 経由で Dark Mode 対応

### R2: SavedAnswerDetailView notice banner

```swift
if answer.isStale {
    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Image(systemName: "clock.badge.exclamationmark")
            Text("更新が必要")
                .font(.subheadline.weight(.medium))
        }
        Text("この答えは保存後に関連記事が追加されています。再生成で最新の AI 答えを得られます。")
            .font(.caption)
    }
    .padding(12)
    .background(Color.orange.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

### R3: 「再生成」 Button → AI チャットタブ遷移

最大の設計ポイント。複数案あり:

**(a) NavigationLink で AI チャットタブを直接 push** — できない (NavigationStack が独立)
**(b) AppTab selection を `.chat` に切替 + 新 ChatSession 作成 + 自動 send** — 採用候補
**(c) 新 ChatSession 作成だけして「AI チャットタブで確認してください」toast** — UX 劣化

**採用: (b)**。実装は:
- `ServiceContainer` に「pending regenerate」を持つ (target question + sessionID? の transient struct)
- 「再生成」タップで `serviceContainer.pendingRegenerate = .init(question:answer:)` + AI チャットタブに切替 (`@AppStorage("selectedTab")` を更新)
- AI チャットタブ起動時に pending を検知 → 新 ChatSession 作成 + 自動 send → pending clear

NOTE: spec 044 で AppTab selection を `@State` で管理しているため、ServiceContainer 経由の trigger は KnowledgeTreeApp で binding 結合する必要あり。詳細は契約で詰める。

### R4: captureIfWorthyOrReplaceStale (新 method)

```swift
func captureIfWorthyOrReplaceStale(
    question: String,
    answer: String,
    citedArticleIDs: [String],
    sessionID: UUID?
) async
```

ロジック:
1. 既存 captureIfWorthy と同じ前処理 (question trim、minCitedCount、minAnswerChars チェック)
2. 同 normalizedQuestion の **isStale=true** な既存 SavedAnswer を fetch
3. あれば:
   - 古を保持 (isStale=true のまま、履歴保護)
   - relatedConceptIDs は新規 resolve (引用記事から overlap top 5)
   - 新 SavedAnswer を insert (isStale=false)
4. なければ既存 captureIfWorthy と同経路 (重複防止で skip も含む)

→ 「古は残す、新を別 record で追加」。ユーザーが detail で見比べ可能。

### R5: markFresh (新 method)

```swift
func markFresh(_ answer: SavedAnswer) throws {
    answer.isStale = false
    answer.updatedAt = .now
    try context.save()
    refreshTrigger?.bump()
}
```

シンプル。calm UX 通知ゼロ。

### R6: SavedAnswerHistoryView filter state

```swift
@State private var showStaleOnly: Bool = false

private var filteredAnswers: [SavedAnswer] {
    let base = sortedAnswers
    return showStaleOnly ? base.filter(\.isStale) : base
}
```

chip タップで toggle、件数 0 で chip 非表示。

### R7: 再生成 trigger アーキテクチャ

最小実装: ServiceContainer に `pendingRegenerateRequest: PendingRegenerateRequest?` を追加。

```swift
struct PendingRegenerateRequest: Equatable {
    let question: String
    let originalAnswerID: UUID  // 追跡用、未使用でも持っておく
}
```

ChatTabView の `.task` で services.pendingRegenerateRequest を消費 → 新 ChatSession + send。送信後 clear。

KnowledgeTreeApp の AppTab @State に "regenerate triggered → .chat 切替" の onChange を仕込む:
```swift
.onChange(of: serviceContainer.pendingRegenerateRequest) { _, new in
    if new != nil { selectedTab = .chat }
}
```

## Phase 構成 (tasks.md の元)

- **T001** xcstrings に新 6 文言追加
- **T002** SavedAnswerService に markFresh + captureIfWorthyOrReplaceStale を追加 (~40 行)
- **T003** ServiceContainer に `pendingRegenerateRequest` を追加 + `PendingRegenerateRequest` struct (~10 行)
- **T004** SavedAnswerRow に isStale chip + icon 追加 (~15 行)
- **T005** SavedAnswerDetailView に notice banner + 再生成 Button + 更新済 menu 追加 (~50 行)
- **T006** SavedAnswerHistoryView に isStale フィルター chip 追加 (~30 行)
- **T007** KnowledgeTreeApp / ChatTabView に pendingRegenerateRequest 検知 + .chat 切替 + send 自動化 (~20 行)
- **T008** SavedAnswerServiceTests 拡張 3-4 ケース (markFresh / captureIfWorthyOrReplaceStale 動作)
- **T009** Build SUCCEEDED + 既存 SavedAnswerServiceTests / ChatServiceTests 全 regression PASS
- **T010** CLAUDE.md 更新

## MVP 範囲

T001-T009 全部 MVP。T010 は polish。

## 実装規模

新規 0 / 改修 4 view + 1 service + 1 container + 1 app + 1 xcstrings + 1 test = **~350 行**。

## 検証 (quickstart 簡略)

SC-001〜SC-010 を本 plan の `## 検証` で網羅:
1. isStale SavedAnswer 含む ConceptPage 詳細を開く → 🕒 chip 表示
2. detail 開く → notice banner + 「再生成」Button
3. 「再生成」タップ → AI チャットタブ自動切替 + 新 ChatSession + question 自動送信
4. AI 答え受信 → 新 SavedAnswer auto-save (5 秒以内)、古いも残る
5. SavedAnswerHistoryView に「⚠️ 更新が必要 (N)」chip 表示
6. chip タップで isStale フィルター
7. 「更新済」menu でフラグ手動解除
8. AI 不可 simulator では既存 fallback UI に乗る

実機検証はユーザー実施 (本セッションは Simulator build + unit test まで)。

## 規模

新規ファイル ゼロ、~350 行、10 タスク、~2-3 時間相当。
