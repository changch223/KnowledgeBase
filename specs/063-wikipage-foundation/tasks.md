# Tasks: WikiPage 土台 — 概念ページに Markdown 本文を持たせる

**Branch**: `vision-llm-wiki` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

LLM Wiki 第 1 段階前半。全 US が P1。パス: `KnowledgeTree/KnowledgeTree/` 配下。
凡例: `[P]` = 別ファイル並列可

---

## Phase 1: Setup

- [x] **T001** `Localization/Localizable.xcstrings` に Wiki 文言追加 (~10)
  - `wiki.kind.person`/`.concept`/`.project` (人物/概念/プロジェクト)
  - `wiki.body.sectionTitle` (Wiki 本文見出し) / `wiki.body.editPlaceholder`
  - `wiki.hide.action` (非表示) / `wiki.kind.label` (種別)

---

## Phase 2: Foundational (Model + Service 土台)

- [x] **T002** `Models/ConceptPage.swift` に 4 フィールド + WikiPageKind
  - `bodyMarkdown: String = ""` / `kindRaw: String = "concept"` / `isHidden: Bool = false` / `bodyEditedByUser: Bool = false`
  - init に 4 引数 (default) 追加
  - `enum WikiPageKind: String, CaseIterable { case person, concept, project }` + displayNameKey + symbolName
  - `extension ConceptPage { var kind: WikiPageKind { get/set } }`
  - contract: contracts/conceptpage-fields.md
- [x] **T003** `Services/LanguageModelSessionProtocol.swift` に generateWikiBody (T002 後)
  - protocol: `func generateWikiBody(prompt: String) async throws -> String`
  - FoundationModelLanguageModelSession: `session.respond(to: prompt)` (generateTutorReply 同型)
  - MockLanguageModelSession: `nextWikiBodyResult` + `wikiBodyCallCount`
  - contract: contracts/generate-wikibody.md

**Checkpoint**: build (Model + Protocol compile)。

---

## Phase 3: US2 (token 安全な本文生成) + US3 (kind 判定)

- [x] **T004 [US2/US3]** `Services/ConceptSynthesisService.swift` bodyMarkdown 生成 hook (T002/T003/T005 後)
  - resynthesize の summary 設定後 (isStale=false 前) に挿入
  - bodyEditedByUser=true → 生成スキップ / availability あり → buildWikiBodyPrompt → generateWikiBody / 空 → 既存保持 / なし・失敗 → summary fallback
  - `buildWikiBodyPrompt`: name + summary + relatedArticles essence (既存圧縮定数 truncate) + schema.md ルール embed
  - `inferKind`: relatedArticles → extractedKnowledge → entities.typeRaw 集計、person/organization 優勢→.person、他→.concept。bodyEditedByUser 時は kind 維持
  - contract: contracts/wikibody-hook.md
- [x] **T005 [P]** `Resources/iknow-schema.md` に「## Wiki 本文生成ルール」追記 (見出し構成/箇条書き/300-800字/推測禁止/日本語)
- [x] **T006 [US2/US3]** `KnowledgeTreeTests/WikiBodyGenerationTests.swift` 新規 5 ケース (T003/T004 後)
  - 生成成功→反映 / availability なし→summary fallback / bodyEditedByUser=true→スキップ / kind 判定 person・concept / 空出力→既存保持

**Checkpoint**: WikiBodyGenerationTests PASS。

---

## Phase 4: US1 (Markdown 表示)

- [x] **T007 [US1]** `Views/ConceptPageDetailView.swift` (T002 後)
  - summary セクション下に bodyMarkdown を Markdown 整形表示 (AttributedString(markdown:)、失敗 plain fallback)
  - header に kind バッジ (symbol + 種別名) / toolbar に isHidden トグル → dismiss
  - bodyMarkdown 空なら summary のみ
  - contract: contracts/markdown-display.md
- [x] **T007a** AttributedString full parsing の見出し対応を build で確認、不足なら行分割簡易レンダラ (純粋関数、unit test 可) (T007 後)

---

## Phase 5: US4 (訂正) + US5 (非表示フィルタ)

- [x] **T008 [P] [US4]** `Views/ConceptPageEditSheet.swift` に bodyMarkdown TextEditor + kind Picker (WikiPageKind.allCases) + 保存で bodyEditedByUser=true (T002 後)
- [x] **T009 [P] [US5]** `Views/FollowingPeopleSection.swift` + `Views/KnowledgeClipView.swift` (ConceptPageListView) の @Query に `#Predicate { !$0.isHidden }` (T002 後)

---

## Phase 6: Polish & 検証

- [ ] **T010** clean build (iPhone 17 Simulator)、本 spec 由来 warning ゼロ
- [ ] **T011** 全 unit test serial regression PASS (WikiBodyGenerationTests + ConceptSynthesis regression)
- [ ] **T012** 静的検証 (4 フィールド / generateWikiBody / SharedSchema 無改修 / isHidden フィルタ grep)
- [ ] **T013** `CLAUDE.md` に spec 063 追記
- [ ] **T014** 実機検証 (ユーザー、SC-001〜006)

---

## 依存グラフ
```
T001 ─┬─ T004/T007/T008 (文言)
T002 ─┴─ T003/T004/T007/T008/T009 (Model 土台)
T003 ── T004/T006
T005 ── T004 (schema ルール)
T004 ── T006
T002+T007 ── T007a
全実装 → T010 → T011 → T012 → T013 → T014 (ユーザー)
```

## 並列例
- T002 後: **T007 / T008 / T009 / T005** 並列
- **T005 / T006** 独立

## 実装戦略
- T001+T002 (土台) → T003 → T004/T005/T006 (生成) + T007/T008/T009 (UI) → Polish。
- 本セッションは T001-T013 (build + unit test + static)、T014 実機検証はユーザー。
- 最終 commit はユーザー指示後。
