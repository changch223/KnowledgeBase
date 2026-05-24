# Implementation Plan: AI Chat MessageRow に関連 ConceptPage chips 追加

**Branch**: `047-chat-related-concept-chips` (実装は `044-understanding-chat` 内)
**Date**: 2026-05-24
**Spec**: [spec.md](./spec.md)

## Summary

`ChatMessageRow` assistant block の cited articles section 直下に `RelatedConceptsChips` を配置。@Query で全 ConceptPage を fetch し、message の citedArticleIDs と各 ConceptPage の relatedArticles overlap を in-memory で計算、top 3 を chip 表示。tap で `ConceptPageDetailDestination` 遷移。

新規 1 sub-view (~60 行) + 改修 1-2 行 = ~65 行、新規 schema/service ゼロ。

## Technical Context

- 既存 `ChatMessageRow.swift` 末尾に private struct を追加する形が clean
- ChatTabView は既に navigationDestination(for: ConceptPageDetailDestination.self) 配線済か要確認 → なければ追加
- 各 MessageRow が @Query を持つことになる (LazyVStack 内で複数 instance、計算コスト要注意 — でも ConceptPage は通常 50-200 件、軽い)

## Constitution Check 全 PASS

- I: ローカルのみ ✅
- II: 既存 chat 機能の delight 拡張 ✅
- III: ConceptPage は @Relationship.nullify で Article 紐付け保持 ✅
- IV: SwiftUI 標準 ✅
- V: 0 件で非表示 ✅
- VI: 既存 CitedArticlesSection と同パターン ✅
- VII: 「関連する概念 (%lld)」xcstrings 追加 ✅

## 主要技術判断

### R1: overlap 計算

```swift
private var relatedPages: [(ConceptPage, Int)] {
    let citedIDSet = Set(articleIDs.compactMap(UUID.init))
    return allConceptPages.compactMap { page in
        let overlap = page.relatedArticles.filter { citedIDSet.contains($0.id) }.count
        return overlap > 0 ? (page, overlap) : nil
    }
    .sorted { $0.1 > $1.1 }
    .prefix(3)
    .map { $0 }
}
```

`@Query private var allConceptPages: [ConceptPage]` を sub-view 内で持つ。LazyVStack で N 個の MessageRow が同 @Query を持つが、SwiftData は under-the-hood で同 query を de-duplicate するので問題なし。

### R2: chip スタイル

既存 `EntityChip` / spec 043 `SavedAnswerDetailView` の関連概念 chip と統一:
```swift
NavigationLink(value: ConceptPageDetailDestination(id: page.id)) {
    Text(page.name)
        .font(.caption)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Color.tagFill, in: Capsule())
        .foregroundStyle(.primary)
}
.buttonStyle(.plain)
```

`FlowingTagsLayout` で多 chip 折り返し対応。

### R3: navigationDestination

ChatTabView を grep 確認 → 既に `navigationDestination(for: Article.self)` あり、ConceptPageDetailDestination は **未配線** の可能性高。確認して必要なら 3 行追加 (`navigationDestination(for: ConceptPageDetailDestination.self) { dest in ConceptPageDetailLoader(destinationID: dest.id) }`)。

ChatTabView 内に既存の sidebar 経路があるので、配置場所も注意。

## タスク

- T001 xcstrings に「関連する概念 (%lld)」追加
- T002 ChatMessageRow.swift 末尾に `RelatedConceptsChips` private struct 追加 (~60 行)
- T003 ChatMessageRow assistant body の citedArticles 直下に `RelatedConceptsChips(articleIDs: message.citedArticleIDs)` 挿入 (~2 行)
- T004 ChatTabView に navigationDestination(for: ConceptPageDetailDestination.self) 追加 (必要なら、~3 行)
- T005 build + 既存 regression
- T006 CLAUDE.md / tasks.md 更新
- T007 実機検証 (SC-001〜SC-006、ユーザー)

## 規模

~65 行、7 タスク、~30 分相当。
