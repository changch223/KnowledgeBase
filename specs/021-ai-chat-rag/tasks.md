# Tasks — AI Chat (RAG)

**spec**: 021 / **plan**: [plan.md](./plan.md) / **branch**: `019-chrome-app-intent` (継続) → 後で 021 専用ブランチ

## Phase 1: Setup

- [x] T001 Localizable.xcstrings に 15 文言追加 (R12) — `KnowledgeTree/Localization/Localizable.xcstrings`
- [x] T002 [P] SharedSchema.all に ChatSession / ChatMessage 追加 — `KnowledgeTree/SharedSchema.swift`

## Phase 2: Foundational (実装の前提)

- [x] T003 [P] ChatSession @Model 新規 — `KnowledgeTree/Models/ChatSession.swift`
- [x] T004 [P] ChatMessage @Model 新規 — `KnowledgeTree/Models/ChatMessage.swift`
- [x] T005 Article.essenceEmbedding `Data?` 追加 (lightweight migration) — `KnowledgeTree/Models/Article.swift`
- [x] T006 [P] [Float] ↔ Data extension — `KnowledgeTree/Models/Article.swift` 末尾 (zero-copy 変換)
- [x] T007 EmbeddingService 新規 (NLEmbedding + Accelerate vDSP_dotpr) — `KnowledgeTree/Services/EmbeddingService.swift`
- [x] T008 [P] EmbeddingServiceTests 6 ケース PASS — `KnowledgeTreeTests/EmbeddingServiceTests.swift`

## Phase 3: US1 — 質問 → 回答 (P1)

- [x] T009 [US1] ChatAnswerOutput @Generable 構造体 — `LanguageModelSessionProtocol.swift` (既存集約ファイル)
- [x] T010 [US1] ChatService protocol + 実装 (retrieval + Foundation Models + post-process) — `KnowledgeTree/Services/ChatService.swift`
- [x] T011 [US1] ChatServiceTests 8 ケース PASS — `KnowledgeTreeTests/ChatServiceTests.swift`
- [x] T012 [US1] KnowledgeExtractionService に embedding 生成 hook 追加 (単一 + chunked パス) — `KnowledgeTree/Services/KnowledgeExtractionService.swift`

## Phase 4: US1 + US2 — Chat UI + 履歴永続化 (P1)

- [x] T013 [US1] ChatMessageRow 新規 — `KnowledgeTree/Views/ChatMessageRow.swift`
- [x] T014 [US1] ChatInputField 新規 — `KnowledgeTree/Views/ChatInputField.swift`
- [x] T015 [US1] [US2] ChatTabView 新規 (.task で session 復元 + LazyVStack messages + 入力欄) — `KnowledgeTree/Views/ChatTabView.swift`
- [x] T016 [US2] ServiceContainer に chatService 追加 + KnowledgeTreeApp で inject — `KnowledgeTree/KnowledgeTreeApp.swift` / `Services/ServiceContainer.swift`

## Phase 5: US3 — 引用記事タップ (P1)

- [x] T017 [US3] ChatMessageRow CitedArticlesSection に NavigationLink → ArticleDetailView (既存 spec 005) — `KnowledgeTree/Views/ChatMessageRow.swift`

## Phase 6: US4 — Fallback (P2)

- [x] T018 [US4] ChatService 内 availability 分岐 (Embedding 不可 → keyword、FM 不可 → KeyFact 並べ) — `KnowledgeTree/Services/ChatService.swift`
- [x] T019 [US4] Fallback テストケース (testSendUsesFallbackWhenFoundationModelsUnavailable + testSendFallsBackOnFoundationModelsError 2 ケース) — `KnowledgeTreeTests/ChatServiceTests.swift`

## Phase 7: US5 — 履歴削除 + セッション切替 (P2)

- [x] T020 [US5] SettingsView に「チャット履歴を全削除」エントリ + 確認 alert — `KnowledgeTree/Views/SettingsView.swift`
- [x] T021 [US5] ChatService.deleteAllSessions 実装 + テスト — `KnowledgeTree/Services/ChatService.swift`

## Phase 8: KnowledgeTreeApp + Polish

- [x] T022 [P] 4 タブ目「AI チャット」追加 — `KnowledgeTree/KnowledgeTreeApp.swift`
- [x] T023 build 警告ゼロ確認 (xcodebuild) — Build SUCCEEDED
- [x] T024 既存テスト全回帰 PASS (シリアル実行で All tests passed、並列実行は既存 BodyExtractor flaky、本 spec と無関係)
- [ ] T025 CLAUDE.md / ROADMAP.md 更新 + 実機検証 (ユーザー、quickstart 12 シナリオ)

## 依存関係

```
T001, T002 → T003-T008 (Foundational) → T009-T012 (Phase 3) → T013-T016 (Phase 4) → T017 (Phase 5) → T018-T019 (Phase 6) → T020-T021 (Phase 7) → T022-T025 (Phase 8)
```

`[P]` 並行可:
- Phase 1: T002 (T001 と同時)
- Phase 2: T003, T004, T006, T008 (T005, T007 とは順序問わず)
- Phase 8: T022 (他と並行)

## MVP 範囲 (Phase 1-2 のみ、本セッション)

本 conversation で完了するのは **T001-T008** (~300 行):
- xcstrings 文言、SharedSchema、ChatSession/ChatMessage @Model、Article.essenceEmbedding migration、Float↔Data ext、EmbeddingService、EmbeddingServiceTests

Phase 3 以降は次 conversation。

## 状態

📝 specify+plan+research+contracts+quickstart+tasks 完了。Phase 1-2 実装は本セッションで commit。
