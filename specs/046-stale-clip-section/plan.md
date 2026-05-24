# Implementation Plan: 知識 Clip タブに「確認が必要な答え」セクション追加

**Branch**: `046-stale-clip-section` (実装は `044-understanding-chat` 内)
**Date**: 2026-05-24
**Spec**: [spec.md](./spec.md)

## Summary

spec 037 `FactConflictsSection` の同パターンで、`SavedAnswer.isStale=true` を 知識 Clip タブ上部に surface するセクションを新規追加。0 件で非表示、6+ 件で「+N すべて見る」リンクで `SavedAnswerHistoryView` へ。

## Technical Context

- 新規 1 view (`StaleSavedAnswersSection.swift`、~80 行)
- 改修 1 view (`KnowledgeClipView.swift`、1 行)
- xcstrings 2 文言
- 新規テストなし (既存パターンの再利用)
- 規模 ~85 行

## Constitution Check

- I (privacy): SwiftData ローカル ✅
- II (MVP): 既存 isStale flag の UI surface 追加のみ ✅
- III (source 追跡): SavedAnswer の citedArticles は既存仕様で残る ✅
- IV (実現可能性): SwiftUI 標準 ✅
- V (calm UX): 0 件で非表示、通知 / バッジ / 効果音ゼロ ✅
- VI (architecture): 既存 FactConflictsSection の同パターンで層分離維持 ✅
- VII (日本語): xcstrings 経由 ✅

## 主要技術判断

### R1: `@Query` predicate + sort

```swift
@Query(
    filter: #Predicate<SavedAnswer> { $0.isStale == true },
    sort: [SortDescriptor(\.updatedAt, order: .reverse)]
)
private var staleAnswers: [SavedAnswer]
```

`updatedAt` desc で最近 stale 化されたものを上位に。

### R2: 上位 5 + 「+N すべて見る」

```swift
let topN = Array(staleAnswers.prefix(5))
let remaining = staleAnswers.count - topN.count

VStack {
    header
    ForEach(topN) { answer in
        NavigationLink(value: SavedAnswerDetailDestination(id: answer.id)) {
            SavedAnswerRow(answer: answer)
        }
        .buttonStyle(.plain)
    }
    if remaining > 0 {
        NavigationLink(value: SavedAnswerHistoryDestination()) {
            Text("+\(remaining) すべて見る")
        }
    }
}
```

ただし `SavedAnswerHistoryDestination` は別ファイル定義済 (settings 経由)、`SettingsView` で定義されているかも。既存 `SavedAnswerListByConceptDestination` は ConceptPage 用なので別。

実装時に確認: SavedAnswerHistoryView へ NavigationLink で行く既存パターン (Settings 経由) を踏襲。KnowledgeClipView から直接遷移は新 destination が必要なら追加 (1 行)。

### R3: KnowledgeClipView 配置

```swift
LazyVStack(spacing: DS.Spacing.xxl) {
    // RecentDigestSection (既存)
    if let since = lastOpenedSince { RecentDigestSection(since: since) }
    FactConflictsSection()             // spec 037 既存
    StaleSavedAnswersSection()         // ★ spec 046 新規 (FactConflictsSection と並列)
    // ... 既存続く
}
```

## Project Structure

```text
KnowledgeTree/Views/
├── StaleSavedAnswersSection.swift   # ★ 新規 ~80 行
├── KnowledgeClipView.swift          # ★ 改修 1 行
└── Localization/Localizable.xcstrings  # ★ 改修 2 文言
```

## タスク分解

- T001 xcstrings に「確認が必要な答え」/「+%lld すべて見る」追加
- T002 StaleSavedAnswersSection.swift 新規作成
- T003 KnowledgeClipView に配置 (line 53 前後)
- T004 build SUCCEEDED + 既存 regression test (SavedAnswerServiceTests + DeepDiveChatServiceTests)
- T005 CLAUDE.md / tasks.md 更新
- T006 実機検証 (SC-001〜SC-006、ユーザー、spec 044/045/030 と一緒に)

## 実装規模

新規 1 ファイル / 改修 1 view + 1 xcstrings = ~85 行、6 タスク、~30-45 分相当。
