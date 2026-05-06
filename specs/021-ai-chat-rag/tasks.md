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

- [ ] T009 [US1] ChatAnswerOutput @Generable 構造体 — `KnowledgeTree/Services/ChatService.swift` 同ファイル先頭
- [ ] T010 [US1] ChatService protocol + 実装 (retrieval + Foundation Models + post-process) — `KnowledgeTree/Services/ChatService.swift`
- [ ] T011 [US1] ChatServiceTests 8 ケース — `KnowledgeTreeTests/ChatServiceTests.swift`
- [ ] T012 [US1] KnowledgeExtractionService に embedding 生成 hook 追加 — `KnowledgeTree/Services/KnowledgeExtractionService.swift`

## Phase 4: US1 + US2 — Chat UI + 履歴永続化 (P1)

- [ ] T013 [US1] ChatMessageRow 新規 — `KnowledgeTree/Views/ChatMessageRow.swift`
- [ ] T014 [US1] ChatInputField 新規 — `KnowledgeTree/Views/ChatInputField.swift`
- [ ] T015 [US1] [US2] ChatTabView 新規 (.task で session 復元 + LazyVStack messages + 入力欄) — `KnowledgeTree/Views/ChatTabView.swift`
- [ ] T016 [US2] ChatService EnvironmentKey + ChatService inject — `KnowledgeTree/KnowledgeTreeApp.swift`

## Phase 5: US3 — 引用記事タップ (P1)

- [ ] T017 [US3] ChatMessageRow CitedArticlesSection に NavigationLink → ArticleDetailView (既存 spec 005) — `KnowledgeTree/Views/ChatMessageRow.swift`

## Phase 6: US4 — Fallback (P2)

- [ ] T018 [US4] ChatService 内 availability 分岐 (Embedding 不可 → keyword、FM 不可 → KeyFact 並べ) — `KnowledgeTree/Services/ChatService.swift` (T010 で部分実装済の場合は完成)
- [ ] T019 [US4] FallbackChatServiceTests 2 ケース — `KnowledgeTreeTests/ChatServiceTests.swift` 末尾追記

## Phase 7: US5 — 履歴削除 + セッション切替 (P2)

- [ ] T020 [US5] SettingsView に「チャット履歴を全削除」エントリ + 確認 alert — `KnowledgeTree/Views/SettingsView.swift`
- [ ] T021 [US5] ChatService.deleteAllSessions 実装 — `KnowledgeTree/Services/ChatService.swift`

## Phase 8: KnowledgeTreeApp + Polish

- [ ] T022 [P] 4 タブ目「AI チャット」追加 — `KnowledgeTree/KnowledgeTreeApp.swift`
- [ ] T023 build 警告ゼロ確認 (xcodebuild)
- [ ] T024 既存テスト全回帰 PASS
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
