# Tasks: 知識 Clip タブに「確認が必要な答え」セクション追加

- [X] T001 Add 「確認が必要な答え」 to `KnowledgeTree/Localization/Localizable.xcstrings` (「+%lld すべて見る」 は spec 044 既存活用)
- [X] T002 Create `KnowledgeTree/Views/StaleSavedAnswersSection.swift` with `@Query` for isStale=true SavedAnswer + 上位 5 + 「+N すべて見る」リンク + 0 件で `EmptyView()` (~80 行、FactConflictsSection を template に)
- [X] T003 Insert `StaleSavedAnswersSection()` into `KnowledgeTree/Views/KnowledgeClipView.swift` 直後 of `FactConflictsSection()` (line 53)
- [X] T004 `xcodebuild build -scheme KnowledgeTree` SUCCEEDED + SavedAnswerServiceTests / DeepDiveChatServiceTests / UnderstandingTrackerServiceTests regression PASS
- [X] T005 CLAUDE.md に spec 046 を「🔧 実装完了」追記 + tasks.md チェック
- [ ] T006 実機検証 (ユーザー、SC-001〜SC-006、spec 044/045/030 と一緒に)
