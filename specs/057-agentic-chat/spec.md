# Feature Specification: Agentic Chat — LLM が考えて聞いて調べて答える

**Feature Branch**: `056-uiux-redesign-v3` (spec 056 と一括 V3.0 release)
**Created**: 2026-05-24
**Status**: Draft
**Input**: 5 ラウンドのユーザー対話で確定。RAG「分かりません」問題を agentic loop で根本解決。

## 製品ビジョン (1 文)

**「LLM が考えて聞いて調べて答える、ChatGPT のように」**

ユーザーが質問を投げると、LLM が自分で「即答可能か / 聞き返し必要か / 記事検索必要か」を判断 → 必要なら自然な会話で intent を聞き出し (最大 3 round) → 最終的に必ず答えを出す。「分かりません」廃止。

## 設計原則

1. **LLM 自律**: 判断・聞き返し・検索・答え生成 すべて LLM 主導 (Apple Foundation Models @Generable enum で構造化)
2. **透過性**: ユーザーは「RAG mode / general mode」を意識しない、引用 chip の有無で自然に分かる
3. **必ず答える**: 「分かりません」廃止、最善努力答え (hedge phrase で hallucination 抑制)
4. **on-device 維持**: ChatGPT/Gemini API 不使用、Apple Intelligence のみ (Privacy first)
5. **既存 API 維持**: ChatService.send / ask の public API は無変更、内部だけ refactor (UI 改修ゼロを実現)

## User Scenarios & Testing *(mandatory)*

### User Story 1 — 明確な質問は即答 (Priority: P1)

ユーザーが明確な質問 (「Tim Cook って誰?」「Swift のオプショナルとは?」) を入力すると、LLM が **clarification なしで即答**する。Foundation Models の一般知識で答え、引用 chip は表示されない (透過的、ユーザーは「ChatGPT に聞いた」感覚)。

**Why this priority**: 体験の中核。「分かりません」が消えて「何でも答える」が達成される最大の差。

**Independent Test**: 「Swift のオプショナルとは?」を入力 → 3 秒以内に answer 表示 → clarification chip なし → 引用 chip なし → ChatGPT 体験。

**Acceptance Scenarios**:

1. **Given** Foundation Models 利用可能、**When** 「Tim Cook って誰?」入力、**Then** clarification 無しで即答 (Foundation Models 一般知識から)
2. **Given** AI 不可端末、**When** 同質問、**Then** 既存 spec 048 banner 表示 + fallback 答え (「Apple Intelligence が必要」案内)
3. **Given** 即答時、**When** answer 表示、**Then** 引用 chip / ConceptPage chip ともに非表示

---

### User Story 2 — 曖昧な質問は自然に聞き返し + chips (Priority: P1)

ユーザーが曖昧な質問 (「Apple について」「最近どう?」) を入力すると、LLM が **自然な聞き返し**と **3 つの suggested chip** を返す。例:

```
LLM: 「Apple について、どの面を知りたいですか?」
Chips: [Tim Cook の経歴] [Vision Pro] [株価のこと]
```

ユーザーは chip を tap で auto-fill or 自由入力で続行できる。

**Why this priority**: 透過性のある対話。ChatGPT/Gemini の体験に近い「聞き直してくれる賢さ」。

**Independent Test**: 「Apple について」入力 → 聞き返し text + 3 chips 表示 → chip 1 つ tap → 入力欄に auto-fill → 送信 → 答え生成。

**Acceptance Scenarios**:

1. **Given** Foundation Models 利用可能、**When** 「Apple について」入力、**Then** 聞き返し質問 + 3 つの chip 表示
2. **Given** chip 表示中、**When** chip tap、**Then** 入力欄に chip text auto-fill + 自動送信
3. **Given** chip 表示中、**When** ユーザーが自由入力、**Then** chip 非表示 + 通常の入力受付

---

### User Story 3 — 記事関連は内部的に検索 + 引用 chip (Priority: P1)

ユーザーが「保存した記事に Tim Cook 出てきた?」「最近保存した記事の動向は?」など **明らかに記事関連** な質問をすると、LLM が内部で embedding 検索 → 該当記事から答え生成 → 引用 chip + 関連 ConceptPage chip 表示。

ユーザーは「mode 切替」を意識せず、答えに引用 chip が付いて返ってくることで自然に「記事から答えてくれた」と分かる。

**Why this priority**: iKnow の core 価値 (保存記事の知識ベース) を活かす経路。

**Independent Test**: 「保存記事に Tim Cook の話あった?」入力 → 引用 chip 付きの answer 表示 → chip tap で記事詳細遷移。

**Acceptance Scenarios**:

1. **Given** 「Tim Cook」を含む保存記事 1+ 件、**When** 「保存記事に Tim Cook の話あった?」入力、**Then** embedding 検索 → 引用 chip + ConceptPage chip 付き answer
2. **Given** 該当記事ゼロ、**When** 同質問、**Then** Foundation Models の一般知識で答え (「保存記事には見つかりませんでしたが、一般的に Tim Cook は…」hedge)、引用 chip なし
3. **Given** 答え生成中、**When** UI 表示、**Then** 「考えています…」spinner + 内部状態 hint (「検索中…」)

---

### User Story 4 — 最大 3 round で必ず答える (Priority: P1)

clarification が必要なら 1 round 聞き返し、それでも intent 不明確なら追加 1 round (最大 2 回聞き返し) → 3 round 目で必ず答えを生成する。情報不足でも **「私の理解では…」「一般的には…」** の hedge phrase 付きで最善努力答え。

「分かりません」「答えられません」「情報がありません」は **絶対に出力しない** (post-process filter + prompt 制約)。

**Why this priority**: 体験の品質保証。ユーザーが「ChatGPT は何でも答える、iKnow も同じ」と認識できる core 約束。

**Independent Test**: 曖昧質問を入力 → 3 round (最大) clarification 後、必ず answer 出力 → 答え内に「分かりません」「情報がありません」が含まれないこと。

**Acceptance Scenarios**:

1. **Given** 「これどう思う?」(極めて曖昧)、**When** 入力、**Then** 1 round 聞き返し → ユーザー回答 → 必要なら 2 round 目 → 3 round 目で最善努力答え (hedge 入り)
2. **Given** 3 round 完了、**When** answer 生成、**Then** 「分かりません」「答えられません」キーワードが含まれない (post-process filter で検証)
3. **Given** Foundation Models 完全 fail、**When** 例外、**Then** error UI 表示 + retry button (US14 と統合)

---

### User Story 5 — 既存 multi-turn context 維持 (Priority: P1)

session 内の過去 message (直前 4 message = 2 ペア) を毎 turn LLM に渡し、文脈を保持する (既存 spec 033 動作維持)。

agent loop でも context は保持され、`mode 混在` (一般会話 → RAG → 一般会話) でも自然な会話流れになる。

**Why this priority**: 会話の自然さの core。multi-turn が壊れたら ChatGPT 体験ではなくなる。

**Independent Test**: 「Tim Cook って誰?」→ 答え → 「彼の経歴は?」→ context から「彼 = Tim Cook」と理解して経歴答え。

**Acceptance Scenarios**:

1. **Given** session 内に「Tim Cook って誰?」+ 回答済、**When** 「彼の経歴は?」追加、**Then** Tim Cook の経歴を答える (context 解決)
2. **Given** session 内に「Apple について → Tim Cook → Vision Pro」3 turn、**When** 「最初の話に戻って」、**Then** Apple 全般の答え (3 turn context 保持)

---

### User Story 6 — 答え long press で保存/コピー/共有 (Priority: P2)

assistant 答えを **long press** すると context menu が表示される:
- **保存** (★ icon、SavedAnswer に明示保存、引用なしでも保存可能)
- **コピー** (pasteboard に answer text)
- **共有** (ShareSheet 表示)

ChatGPT/Gemini と同パターン。auto-save は廃止 (将来分のみ)、過去の auto-save SavedAnswer は維持。

**Why this priority**: 「気に入った答え」を能動的に残せる、ChatGPT 同等の基本操作。

**Independent Test**: 答え bubble を long press → menu 3 つ表示 → 「保存」tap → SavedAnswer 作成確認。

**Acceptance Scenarios**:

1. **Given** assistant answer 表示中、**When** bubble を long press、**Then** context menu 表示 (保存 / コピー / 共有)
2. **Given** menu 表示、**When** 「保存」tap、**Then** SavedAnswer 作成 (引用なしでも保存可)
3. **Given** menu 表示、**When** 「コピー」tap、**Then** answer text が pasteboard に
4. **Given** menu 表示、**When** 「共有」tap、**Then** ShareSheet 表示

---

### User Story 7 — agent loop の処理 UI (Priority: P2)

agent loop の各 phase で適切な UI feedback:
- intent 判定中: 「考えています…」+ spinner
- 検索中: 「(記事を検索中…)」hint
- 答え生成中: 「(まとめ中…)」hint
- clarification 表示: chip 即時表示、scroll 自動
- 最終答え streaming: 既存 spec 033 擬似 streaming 維持

**Why this priority**: 「何が起きてるか」がユーザーに伝わる、待ち時間の体感短縮。

**Independent Test**: 質問 → 「考えています…」表示 → (検索があれば)「検索中…」→ 答え streaming 開始。

**Acceptance Scenarios**:

1. **Given** 質問送信直後、**When** UI 表示、**Then** 「考えています…」spinner
2. **Given** RAG 経路、**When** 検索中、**Then** 「(記事を検索中…)」hint 追加表示
3. **Given** 答え生成開始、**When** 最初の文字、**Then** 既存 streaming 開始

---

### User Story 8 — error retry (Priority: P3)

Foundation Models が例外 (cancellation 以外) を throw した時、error UI + retry button 表示。

```
⚠️ もう一度試してください
[再試行]
```

**Why this priority**: edge case 対応、core flow ではない。

**Independent Test**: Foundation Models を mock で fail させる → error UI 表示 → retry button tap → 再実行。

**Acceptance Scenarios**:

1. **Given** Foundation Models error throw、**When** UI 受け取り、**Then** error bubble 表示 + retry button
2. **Given** retry button tap、**When** 同 question 再送信、**Then** agent loop 最初から再実行

---

### Edge Cases

- **Apple Intelligence 不可端末**: 既存 spec 048 banner 表示 + agent loop は fallback (Foundation Models 不在 = 直接 fallback で「お使いの端末では Apple Intelligence が利用できません」hedge 答え)
- **session 跨ぎの context**: session 切替で context リセット (既存 spec 033 動作維持)
- **clarification 中にユーザーが session 切替**: pending agent loop は cancel、新 session で fresh start
- **3 round 完了後、ユーザーが新質問**: 新 agent loop が独立に開始 (context は連続 message として渡される)
- **chip tap 後の cancel**: chip auto-fill → ユーザーが消去 → 自由入力なら通常受付
- **「分かりません」が hedge 内に紛れた場合**: post-process filter で「分かりません」「答えられません」を「私の理解では明確ではありませんが」等に置換
- **長文質問 (4096 token 超過リスク)**: prompt が token 上限超えそうな時、context message 数を 4 → 2 に reduce (graceful)
- **複雑な質問の embedding 検索 0 件**: threshold (0.7) 下げず、fallback で Foundation Models 一般知識答え (引用なし)
- **agent loop 中の Foundation Models token overflow**: 既存 spec 010/044 同様、@Generable schema を小さく保つ + retry 1 回

## Requirements *(mandatory)*

### Functional Requirements

**Agent Loop Core (P1)**

- **FR-001**: System MUST execute an agent loop on every user question, with max 3 iterations of clarification + 1 final answer iteration
- **FR-002**: System MUST use `@Generable enum AgentAction` for LLM intent structuring (Apple Foundation Models constraint)
- **FR-003**: System MUST support 4 AgentAction cases: immediate / askClarification / searchArticles / finalAnswer
- **FR-004**: System MUST handle `.askClarification` by displaying question text + 3 suggested chips
- **FR-005**: System MUST handle `.searchArticles` by invoking embedding search and including matched articles in next LLM context
- **FR-006**: System MUST handle `.finalAnswer` by displaying the answer text + citation chips (if cited articles non-empty)
- **FR-007**: System MUST handle `.immediate` by displaying answer text without clarification or search

**Anti-「分かりません」 (P1)**

- **FR-008**: System MUST NOT output text containing the phrases 「分かりません」「答えられません」「情報がありません」 in any answer
- **FR-009**: System MUST apply post-process filter to replace such phrases with hedge phrases (e.g., 「私の理解では…」「一般的には…」)
- **FR-010**: System MUST enforce max 3 clarification rounds before generating final answer (best effort)
- **FR-011**: System MUST include hedge phrase in final answer when source information is insufficient (LLM prompt instruction)

**Intent Clarification UI (P1)**

- **FR-012**: System MUST display 3 suggested chips when LLM returns `.askClarification`
- **FR-013**: System MUST auto-fill input field and auto-send when chip is tapped
- **FR-014**: System MUST allow free text input as alternative to chip tap
- **FR-015**: System MUST clear chip display when user starts typing free text

**Citation & Transparency (P1)**

- **FR-016**: System MUST display citation chips only when LLM returns `citedArticleIDs` (transparent mode indication)
- **FR-017**: System MUST display related ConceptPage chips (spec 047 logic preserved) only when citations exist
- **FR-018**: System MUST NOT display any mode badge / indicator (transparent UX, FR-016/017 implicit indication only)

**Multi-turn Context (P1)**

- **FR-019**: System MUST preserve last 4 messages (= 2 user/assistant pairs) as context for each agent loop iteration
- **FR-020**: System MUST allow free mode switching within a session (general → RAG → general)
- **FR-021**: System MUST maintain spec 033 sidebar / streaming / inline link functionality

**ChatService Internal Refactor (P1)**

- **FR-022**: System MUST preserve public ChatService API (`send(question:in:contextMessages:)`, `ask(message:in:)`) without breaking changes
- **FR-023**: System MUST refactor ChatService internal implementation to use agent loop
- **FR-024**: System MUST NOT require any UI view changes for the refactor (ChatTabView / ChatMessageRow integration via existing API)

**SavedAnswer Migration (P2)**

- **FR-025**: System MUST stop auto-save of SavedAnswer for future answers (captureIfWorthy hook becomes no-op)
- **FR-026**: System MUST preserve all existing auto-saved SavedAnswer data (no migration / cleanup)
- **FR-027**: System MUST add explicit save API to SavedAnswerService for manual save from long press menu
- **FR-028**: System MUST allow saving an answer without citations (relaxed validation: 50+ chars only, no citation requirement)

**Long Press Menu (P2)**

- **FR-029**: System MUST display context menu on assistant answer bubble long press
- **FR-030**: System MUST include 3 menu items: 保存 / コピー / 共有
- **FR-031**: System MUST create new SavedAnswer on 保存 tap (explicit save, no auto-save)
- **FR-032**: System MUST copy answer text to pasteboard on コピー tap
- **FR-033**: System MUST present iOS ShareSheet on 共有 tap with answer text

**Agent Loop UI Feedback (P2)**

- **FR-034**: System MUST display "考えています…" spinner during agent loop processing
- **FR-035**: System MUST display "(記事を検索中…)" hint when search action is in progress
- **FR-036**: System MUST display "(まとめ中…)" hint when final answer generation is in progress

**Error Handling (P3)**

- **FR-037**: System MUST display error UI + retry button when Foundation Models throws non-cancellation error
- **FR-038**: System MUST re-execute agent loop from start on retry tap (same question)
- **FR-039**: System MUST log agent loop state transitions for debugging (Console.app visible, production conditional)

**On-Device Constraint (P1)**

- **FR-040**: System MUST NOT use any external LLM API (ChatGPT / Gemini / Claude API)
- **FR-041**: System MUST use Apple Foundation Models exclusively
- **FR-042**: System MUST fallback gracefully when Apple Intelligence is unavailable (spec 048 banner + simple Foundation Models direct call)

### Key Entities

- **AgentAction** (Generable enum): LLM の出力構造、4 case + 関連 payload (answer text / clarification text + suggestions / search query + threshold / final answer text + cited article IDs)
- **AgentState** (transient struct): 現在の agent loop iteration count + 蓄積された context + clarification history
- **SuggestedChip** (transient struct): clarification 時に表示する 1 つの suggestion text、tap で auto-fill
- **HedgePhrase** (transient constants): 「私の理解では…」「一般的には…」「あくまで概要ですが…」等の filter 置換用文言集
- **AgentLoopResult**: 最終 ChatMessage (assistant) + 引用 article IDs + clarification rounds used (debug info)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 明確な質問 (10 サンプル) に対し、clarification なしで 90% 以上即答 (Foundation Models 利用可能端末)
- **SC-002**: 曖昧な質問 (10 サンプル) に対し、適切な clarification chip を 90% 以上生成 (chip 3 個 + 自然な question)
- **SC-003**: 「分かりません」「答えられません」「情報がありません」が答え本文に含まれない (100 質問 sample test、post-process filter で検証)
- **SC-004**: 平均 agent loop iteration <= 1.5 round (single-shot clarification 中心)
- **SC-005**: 「私の理解では…」等の hedge phrase が情報不足時の答えに含まれる (10 ambiguous question で 80% 以上)
- **SC-006**: 引用 chip + ConceptPage chip が記事関連質問でのみ表示 (10 一般質問 + 10 記事関連質問の混在 test で 95% 以上正確)
- **SC-007**: 既存 multi-turn context 動作維持 (spec 033 regression test 全 PASS)
- **SC-008**: 既存 ChatService public API 互換 (spec 021 既存 unit test 全 PASS)
- **SC-009**: 答え long press → menu 表示 → 「保存」tap → SavedAnswer 作成、95% 以上の操作成功率
- **SC-010**: agent loop 平均応答時間 = 2.5 sec 以内 (即答時)、5 sec 以内 (clarification 含む)、8 sec 以内 (RAG 検索含む)
- **SC-011**: external LLM API への呼び出しゼロ (network monitoring で確認、privacy 保証)
- **SC-012**: V3.0 release で「ChatGPT 体験に近づいた」とユーザーフィードバック 70% 以上 (定性、release 後 2 週間)

## Assumptions

- **対象ユーザー**: iKnow を「ChatGPT 風に何でも聞ける + 必要なら記事から答えてくれる」AI 助手として使いたい既存ユーザー + 新規ユーザー
- **iOS バージョン**: iOS 26+、Apple Foundation Models 利用可能端末を default 想定 (不可端末は fallback)
- **Foundation Models 制約**: @Generable enum で agent state 構造化、tool calling 不在の代替手段
- **token overflow 対策**: 既存 spec 010/044 の token 縮小ノウハウ (chunkSizeChars / essence chars 等) を agent loop でも適用
- **Privacy 維持**: 完全 on-device、external LLM API 不使用、これを将来も維持 (CLAUDE.md / Privacy Policy で明示)
- **既存 RAG 動作の継承**: spec 021 embedding search ロジック + spec 047 ConceptPage chip ロジックは agent loop 内で再利用
- **既存 spec 044 DeepDiveChatService**: Foundation Models 直接呼び実装の参考、agent loop の implementation 模範
- **release strategy**: spec 056 と同 branch (`056-uiux-redesign-v3`) で開発、1 PR で V3.0 として一括 release
- **migration 戦略**: 既存ユーザーのデータロスゼロ (SavedAnswer / ChatSession / ChatMessage 全保持)、auto-save 動作変更のみ将来分から
- **テスト戦略**: 新規 service は protocol + Mock LM (`MockLanguageModelSession`) で deterministic test、agent loop の各 case を分岐 test
- **commit 単位**: Phase A (Agent loop core + 「分かりません」廃止) → Phase B (Long press menu + clarification chips) → Phase C (Error handling + polish) で段階 commit、最終 1 PR に統合
- **token efficiency**: Generable enum schema を小さく保つ (case names short, payload minimal) で 4096 token 制約に余裕を持たせる
- **debug log**: agent loop の state 遷移を NSLog で出力 (production では DEBUG flag conditional)
- **既存 spec 044 DeepDiveChatService との関係**: 学習タブ用、本 spec で扱う ChatService とは独立 (両者並存、互いに無影響)
- **spec 056 との同梱 release**: spec 057 完成までは PR #17 (spec 056) を merge せず、両者統合した PR を V3.0 として release
