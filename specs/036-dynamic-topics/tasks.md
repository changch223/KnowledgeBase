# Tasks — spec 036 動的トピック自動発見

**Spec**: [spec.md](./spec.md) / **Plan**: [plan.md](./plan.md)

## Phase 1: Foundation

- [ ] T001 [P] UserTopic @Model 新規 — `KnowledgeTree/Models/UserTopic.swift`
- [ ] T002 [P] SharedSchema.all に UserTopic 追加 — `KnowledgeTree/SharedSchema.swift`
- [ ] T003 [P] TopicNameOutput @Generable + LanguageModelSession 拡張 — `KnowledgeTree/Services/LanguageModelSessionProtocol.swift`
- [ ] T004 MockLanguageModelSession に generateTopicName 追加

## Phase 2: Storage

- [ ] T005 UserTopicStore 新規 (CRUD + 重複 centroid check) — `KnowledgeTree/Services/UserTopicStore.swift`
- [ ] T006 UserTopicStoreTests 5 ケース — `KnowledgeTreeTests/UserTopicStoreTests.swift`

## Phase 3: Clustering

- [ ] T007 [US1] K-means 実装 (Accelerate vDSP、cosine similarity ベース) — `KnowledgeTree/Services/TopicClusteringService.swift` 内
- [ ] T008 [US1] TopicClusteringService.runIfDue() (起動時 + 7 日 batch、UserDefaults flag)
- [ ] T009 [US1] TopicClusteringServiceTests 7 ケース — `KnowledgeTreeTests/TopicClusteringServiceTests.swift`

## Phase 4: UI - 候補

- [ ] T010 [US1] DynamicTopicsSection 候補リスト UI — `KnowledgeTree/Views/DynamicTopicsSection.swift`
- [ ] T011 [US1] UserTopicCandidateRow 新規 (採用/却下/後でボタン) — `KnowledgeTree/Views/UserTopicCandidateRow.swift`

## Phase 5: UI - 採用済 + 詳細

- [ ] T012 [US2] DynamicTopicsSection 採用済リスト (重要度順)
- [ ] T013 [US3] UserTopicDetailView (3 段落要約 + KeyFact + Entity + 元記事) — `KnowledgeTree/Views/UserTopicDetailView.swift`

## Phase 6: 統合

- [ ] T014 [US1] KnowledgeClipView 改修 (DynamicTopicsSection 追加)
- [ ] T015 [US1] ServiceContainer に topicClusteringService / userTopicStore 追加
- [ ] T016 [US1] KnowledgeTreeApp で起動時 batch run

## Phase 7: Polish

- [ ] T017 build 警告ゼロ + 既存テスト全回帰
- [ ] T018 CLAUDE.md / ROADMAP 更新

## 状態
📝 implement 待ち。
