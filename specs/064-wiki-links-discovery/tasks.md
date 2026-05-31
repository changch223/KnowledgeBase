# Tasks: Wiki ページ相互リンク + 関係発見

**Branch**: `064-wiki-links-discovery` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

全 US が P1。Phase 1 (embedding、低リスク) → Phase 2 (AI リンク)。パス: `KnowledgeTree/KnowledgeTree/` 配下。

---

## Phase 1: 関係発見 embedding 補完 (US1 / US3)

- [x] **T001 [US1]** `Services/ConceptSynthesisService.swift` に `nearestConceptIDs(for:in:)` + 定数 (relatedConceptLimit=8 / relatedConceptThreshold=0.5) 追加 (embedding cosine top-k、self/isHidden/embedding-nil 除外)
- [x] **T002 [US1]** resynthesize の embedding 再生成直後 (generateBodyMarkdown 前) に relatedConceptIDs union 補完を挿入
- [x] **T003 [US1/US3]** `KnowledgeTreeTests/ConceptLinkingTests.swift` 新規: nearestConceptIDs テスト (self 除外 / threshold / top-k / embedding なし)

**Checkpoint**: build + nearestConceptIDs テスト PASS。relatedConceptsSection が埋まる。

---

## Phase 2: AI 本文リンク + 表示遷移 (US2)

- [x] **T004 [US2]** `Resources/iknow-schema.md` の「Wiki 本文生成ルール」にリンク記法 (`[名](concept-id://UUID)`、候補外禁止、UUID コピー) を追記
- [x] **T005 [US2]** `Services/ConceptSynthesisService.swift`: buildWikiBodyPrompt に `linkCandidates` 引数 (default `[]`) + 候補リスト embed。generateBodyMarkdown で relatedConceptIDs → 候補解決して渡す + `sanitizeConceptLinks` post-process。`sanitizeConceptLinks(in:validIDs:)` static 追加
- [x] **T006 [US2]** `Views/ConceptPageDetailView.swift`: wikiBodySection に OpenURLAction + `extractConceptID(from:)` static + `onConceptLinkTap` callback prop
- [x] **T007 [US2]** DetailView を push する親 (ConceptPageDetailLoader / KnowledgeClipView 等) で onConceptLinkTap → navigation 配線
- [x] **T008 [US2]** ConceptLinkingTests に sanitizeConceptLinks (有効/無効/混在/なし) + extractConceptID (解析/scheme不一致) 追加

**Checkpoint**: build + 全テスト PASS。

---

## Phase 3: Polish & 検証

- [x] **T009** clean build (iPhone 17 Simulator) warning ゼロ
- [x] **T010** 全 unit test serial regression PASS (ConceptLinkingTests + WikiBodyGenerationTests + ConceptSynthesis regression)
- [x] **T011** 静的検証 (nearestConceptIDs / sanitizeConceptLinks / extractConceptID / concept-id grep + @Model 差分ゼロ)
- [x] **T012** CLAUDE.md に spec 064 追記
- [ ] **T013** 実機検証 (ユーザー、SC-001/003/004/006)

---

## 依存
T001 → T002 → T003 / T002 → T005 (relatedConceptIDs 候補再利用) / T004 → T005 / T005 → T006 → T007 / T005+T006 → T008 / 全 → T009→T010→T011→T012→T013

## 実装戦略
Phase 1 (embedding、AI ゼロ、低リスク) を先に build+test 通す → Phase 2 (AI リンク) を上に積む。一度に大量 Edit せず 1 つずつ build 確認。最終 commit はユーザー指示後。
