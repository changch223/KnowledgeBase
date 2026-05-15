# Tasks — spec 035 「最近のあなた」差分ダイジェスト

**Spec**: [spec.md](./spec.md) / **Plan**: [plan.md](./plan.md)

## Phase 1: Foundation

- [ ] T001 [P] LastOpenedStore.swift 新規 — `KnowledgeTree/Services/LastOpenedStore.swift`
- [ ] T002 [P] RecentDigestOutput @Generable + LanguageModelSession 拡張 — `KnowledgeTree/Services/LanguageModelSessionProtocol.swift`
- [ ] T003 MockLanguageModelSession に generateRecentDigest 追加 — `KnowledgeTreeTests/KnowledgeExtractorTests.swift`

## Phase 2: Service

- [ ] T004 [US1] RecentDigestService protocol + 実装 (Foundation + Fallback) — `KnowledgeTree/Services/RecentDigestService.swift`
- [ ] T005 [US1] RecentDigestServiceTests 5 ケース — `KnowledgeTreeTests/RecentDigestServiceTests.swift`

## Phase 3: UI

- [ ] T006 [US1] RecentDigestSection 新規 — `KnowledgeTree/Views/RecentDigestSection.swift`
- [ ] T007 [US1] KnowledgeClipView 改修 (最上部に section 挿入) — `KnowledgeTree/Views/KnowledgeClipView.swift`

## Phase 4: Default Tab Selection

- [ ] T008 [US2] KnowledgeTreeApp で TabView selection binding (起動時 .knowledgeClip) — `KnowledgeTree/KnowledgeTreeApp.swift`
- [ ] T009 [US2] ServiceContainer に recentDigestService 追加 — `KnowledgeTree/Services/ServiceContainer.swift`

## Phase 5: Polish

- [ ] T010 build 警告ゼロ + 既存テスト全回帰 PASS
- [ ] T011 CLAUDE.md / ROADMAP 更新

## 状態
📝 implement 待ち。
