# Tasks — spec 037 時系列事実上書き提案

**Spec**: [spec.md](./spec.md) / **Plan**: [plan.md](./plan.md)

## Phase 1: Foundation

- [ ] T001 [P] ConflictProposal @Model 新規 — `KnowledgeTree/Models/ConflictProposal.swift`
- [ ] T002 [P] Article.isObsolete 追加 (lightweight migration) — `KnowledgeTree/Models/Article.swift`
- [ ] T003 [P] SharedSchema.all に ConflictProposal 追加 — `KnowledgeTree/SharedSchema.swift`
- [ ] T004 [P] ConflictDetectionOutput @Generable + LanguageModelSession 拡張
- [ ] T005 MockLanguageModelSession に generateConflictDetection 追加

## Phase 2: Detection

- [ ] T006 [US1] ConflictDetectionService 新規 (entity 抽出 + 過去記事 fetch + AI 判定) — `KnowledgeTree/Services/ConflictDetectionService.swift`
- [ ] T007 [US1] KnowledgeExtractionService に hook 追加 (succeeded 後 fire-and-forget)
- [ ] T008 [US1] ConflictDetectionServiceTests 7 ケース — `KnowledgeTreeTests/ConflictDetectionServiceTests.swift`

## Phase 3: KnowledgeDigest 改修

- [ ] T009 [US3] KnowledgeDigestService prompt で isObsolete を考慮
- [ ] T010 既存 KnowledgeDigestServiceTests に isObsolete ケース追加

## Phase 4: UI

- [ ] T011 [US2] FactConflictsSection 新規 (候補リスト) — `KnowledgeTree/Views/FactConflictsSection.swift`
- [ ] T012 [US2] ConflictProposalRow 新規 (3 ボタン UI) — `KnowledgeTree/Views/ConflictProposalRow.swift`
- [ ] T013 [US2] KnowledgeClipView 改修 (section 追加)

## Phase 5: Bootstrap + Polish

- [ ] T014 ServiceContainer に conflictDetectionService 追加
- [ ] T015 KnowledgeTreeApp で inject
- [ ] T016 build 警告ゼロ + 既存テスト全回帰
- [ ] T017 CLAUDE.md / ROADMAP 更新

## 状態
📝 implement 待ち。
