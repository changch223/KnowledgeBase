# Contract: ActionItemsReviewView

## Purpose

⚠️ 「更新が必要」 badge tap から push される、ConflictProposal + isStale SavedAnswer を 1 画面に統合した review 画面。

## View Structure

```swift
struct ActionItemsReviewView: View {
    @Query(filter: #Predicate<ConflictProposal> { $0.decisionStatusRaw == "pending" })
    private var conflicts: [ConflictProposal]
    
    @Query(filter: #Predicate<SavedAnswer> { $0.isStale == true })
    private var staleAnswers: [SavedAnswer]
    
    var body: some View {
        List {
            if !conflicts.isEmpty {
                Section(header: Text("actionItems.section.factConflicts")) {
                    ForEach(conflicts) { conflict in
                        ConflictProposalRow(proposal: conflict)  // 既存 spec 037
                    }
                }
            }
            if !staleAnswers.isEmpty {
                Section(header: Text("actionItems.section.staleSavedAnswers")) {
                    ForEach(staleAnswers) { answer in
                        SavedAnswerRow(answer: answer)  // 既存 spec 043
                    }
                }
            }
            if conflicts.isEmpty && staleAnswers.isEmpty {
                ContentUnavailableView(
                    "actionItems.empty.title",
                    systemImage: "checkmark.circle"
                )
            }
        }
        .navigationTitle("actionItems.title")
        .accessibilityIdentifier("view.actionItems")
    }
}
```

## 既存 component 流用

- `ConflictProposalRow` (spec 037) — そのまま
- `SavedAnswerRow` (spec 043) — そのまま

## Hashable destination

```swift
struct ActionItemsReviewDestination: Hashable {}
```

KnowledgeClipView に navigationDestination 追加:

```swift
.navigationDestination(for: ActionItemsReviewDestination.self) { _ in
    ActionItemsReviewView()
}
```

FollowingPeopleSection 内で badge tap:

```swift
NavigationLink(value: ActionItemsReviewDestination()) {
    Text("⚠️ 更新が必要 (\(badgeData.total))")
}
```

## 旧 view との関係

- 旧 FactConflictsSection (KnowledgeClipView 内) — 削除
- 旧 StaleSavedAnswersSection (KnowledgeClipView 内) — 削除
- 機能は本 view に完全移行、片方が 0 件なら section 非表示

## xcstrings 追加

- `actionItems.title` = "更新が必要"
- `actionItems.section.factConflicts` = "事実の更新提案"
- `actionItems.section.staleSavedAnswers` = "確認が必要な答え"
- `actionItems.empty.title` = "更新が必要な項目はありません"
