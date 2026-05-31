# Tasks: UserTopic 退役 (死蔵コード削除)

**Branch**: `067-retire-usertopic` (066 の上) | **Spec**: [spec.md](./spec.md)

@Model UserTopic / SharedSchema 登録 / Article.userTopics inverse は**残す** (CloudKit 安全)。死蔵コードのみ削除。

## Phase 1: 死蔵コード削除
- [x] **T001** `Views/UserTopicCandidateRow.swift` 削除 (孤児)
- [x] **T002** `Views/UserTopicDetailView.swift` 削除 (孤児)
- [x] **T003** `Services/TopicClusteringService.swift` 削除 (生成停止済、参照は ServiceContainer のみ)
- [x] **T004** `KnowledgeTreeTests/TopicClusteringServiceTests.swift` 削除
- [x] **T005** `ServiceContainer.swift` から `topicClusteringService` field 削除
- [x] **T006** `KnowledgeTreeApp.swift` から TopicClusteringService 構築 (:268) + 登録 (:426) 削除。spec 065 で起動 backfill からは既に除外済 (コメントのみ整理)
- [x] **T007** pbxproj 確認 (TopicClusteringService が Share/Safari/Widget extension target に属していたら build entry 削除。app target のみなら file-system-synchronized で自動)

## Phase 2: 検証
- [x] **T008** clean build (iPhone 17 Simulator)
- [x] **T009** 全 unit test serial regression PASS
- [x] **T010** 静的検証 (UserTopicCandidateRow/UserTopicDetailView/TopicClusteringService 参照ゼロ + @Model UserTopic/SharedSchema 登録/Article.userTopics 残存確認)
- [x] **T011** CLAUDE.md に spec 067 追記
- [ ] **T012** 実機検証 (ユーザー、SC-004: 画面・動作が削除前と一致)

## 依存
T001-T004 (削除) 独立 → T005/T006 (配線削除) → T007 → T008 → T009 → T010 → T011 → T012

## 実装戦略
@Model は触らない (CloudKit 安全)。削除 → ビルドで参照漏れを潰す → 全テスト。最終 commit はユーザー指示後。
