# Tasks: AI Chat MessageRow に関連 ConceptPage chips 追加

- [X] T001 Add 「関連する概念 (%lld)」 to `KnowledgeTree/Localization/Localizable.xcstrings`
- [X] T002 Add `RelatedConceptsChips` private struct to `KnowledgeTree/Views/ChatMessageRow.swift` (末尾、@Query for ConceptPage + overlap top 3、FlowingTagsLayout + capsule chip + NavigationLink で ConceptPageDetailDestination)
- [X] T003 Insert `RelatedConceptsChips(articleIDs: message.citedArticleIDs)` directly after `CitedArticlesSection` call in `ChatMessageRow` body
- [X] T004 Check/Add `navigationDestination(for: ConceptPageDetailDestination.self) { ConceptPageDetailLoader(...) }` to `ChatTabView` if not already present
- [X] T005 `xcodebuild build` SUCCEEDED + ChatServiceTests / SavedAnswerServiceTests regression PASS
- [X] T006 CLAUDE.md に spec 047 を「🔧 実装完了」追記 + tasks.md チェック
- [ ] T007 実機検証 (ユーザー、SC-001〜SC-006、spec 044/045/046/030 と一緒に)
