# spec 107: Make the remaining prompts follow the generation language too (finishing spec 106)

Branch: `107-multilingual-prompts` (cut from main `1548bc4`). Created 2026-11-21.

## Background

Spec 106 made extraction prompts (3) + concept synthesis (6) + the Lint naming prompt use **English instructions when the generation language is not Japanese**.
Three gaps remain:

1. **Field-specific hints (`CategoryPrompts`) never apply outside ja.**
   - The keys of `englishByCategory` are Japanese seed names (テクノロジー etc.).
   - In non-ja pipelines, `categoryRaw` is a name in that language (en=`Technology`, zh=`科技`...), so the lookup always fails and an empty block is returned.
2. **These prompts still use Japanese instructions + a trailing `outputInstruction`:**
   - AI chat (agent decision / RAG answer / general answer)
   - Deep-dive chat
   - Category digest
   - Contradiction detection
   - "Recent you" digest
   - Category classification
   - Speech transcription correction

   Small models get pulled toward the language of the instructions and answer in Japanese. Classification can also return a Japanese category name, fail the `validNames` check, and fall back to その他.
3. **Recency questions are Japanese-only.**
   - `ChatService.isRecencyQuery` only knows Japanese keywords (最近 / 記事 ...).
   - So questions like "What did I save recently?" or 「最近存了什麼文章」 never trigger the recent-articles summary (spec 084) and drop to a general-knowledge answer.

## Common rules (absolute)

- **When the generation language is ja, every prompt must stay byte-for-byte identical.**
  - For each builder you change, compute the SHA-256 of the ja output **on the code before your change**.
  - Add that value to `KnowledgeBaseTests/PromptJapaneseSnapshotTests.swift`.
  - Then make your change and confirm the hash does not move.
  - Don't change the golden values of existing tests.
- Do not change `@Generable` / `@Guide` / `@Model` / `Resources/iknow-schema.md`. Do not add AI calls (switch prompt text only).
- English instruction versions use the same pattern as spec 106:
  - Branch with `PromptLocalizer.usesJapaneseInstructions(language)`.
  - Start with `PromptLocalizer.outputLanguageHeader(language)` and end with `PromptLocalizer.outputLanguageFooter(language)`.
  - For chat and other cases where "concept names" don't fit, you may add a general-purpose header (e.g. `PromptLocalizer.outputLanguageHeaderGeneral`). Don't change the existing header (spec 106 tests depend on it).
- **Keep strings that code parses exactly as they are:**
  - The agent action names (immediate / searchArticles / askClarification ...)
  - The bare citation marker `(article-id://UUID)` and the `concept-id://` link syntax
  - The `[High / Medium / Low]` confidence values
  - The rule that the category name is returned exactly as written in the candidate list
- Keep the meaning of every rule: the citation contract, "don't put IDs in the body", no hallucination, the banned phrases / hedge phrases (`language.bannedPhraseExamples` / `hedgePhraseExamples`), the character / item caps (convert Japanese character counts to a natural English unit such as words or sentences, but no longer), and the agent rules from specs 082-084 (search first, rewrite to a standalone query, rarely ask back).
- The English version must not be longer than the Japanese version in tokens. As a guide, aim for no more than the ja version's character count × 1.3; English is fewer tokens per character.
- Don't touch `docs/app-store/APP-STORE-METADATA-v1.1.md`. It contains the user's uncommitted edit.

## T1 — Apply CategoryPrompts in every language

- **`CategoryPrompts.block(forCategoryRaw:language:)`:** resolve `raw` to a seed position (order) regardless of language, then use the profile for that position.
  - Example: `Technology` / `科技` / `기술` / `Tecnología` / `Technologie` / `テクノロジー` → all map to the "Technology" profile.
  - Look this up from the seeds of every language via `CategorySeed.allSeeds(for:)` (index or `englishName`).
  - When the generation language is ja, return the `byCategory` (Japanese) profile. Otherwise return the `englishByCategory` profile. "Other" and dynamic categories return an empty block, same as now.
- Make the dictionary keys position-based or `englishName`-based. Don't break existing callers.
- The ja + `テクノロジー` output must keep the same hash as the existing snapshot (it is covered indirectly by conceptPromptsJa's oneShot/broad/meta).
- Tests:
  - en `Technology` → the block contains `Focus for this field`.
  - zh-Hant `科技` (use the actual zhHant seed name) → same.
  - ja `テクノロジー` → `この分野での重視点`.
  - `Other` → empty.
  - An unknown dynamic name → empty.

## T2 — English instruction versions for the remaining prompts

First, list every prompt-building site in `KnowledgeBase/Services` with grep (`session.respond`, `generate*(prompt:`, `static func build*Prompt`, and prompts assembled inline). Put the list in the implementation notes.

Targets (at minimum):

| File | Prompt |
|---|---|
| `ChatService.swift` | `buildAgentPrompt` / `buildPrompt` (RAG) / `buildFallbackPrompt` / any other inline prompts (general answer, tutor reply path, etc.) |
| `DeepDiveChatService.swift` | `buildInitialPrompt` / `buildContinuationPrompt` (if private, make them `static` internal so tests can call them) |
| `KnowledgeDigestService.swift` | `buildPrompt` |
| `ConflictDetectionService.swift` | `buildPrompt` |
| `RecentDigestService.swift` | `buildPrompt` |
| `AutoCategoryClassifier.swift` | The classification prompt (add a builder like `static func buildPrompt(...)` and get it under test). The English version must also state clearly: "Return exactly one name from the candidate list, using the exact spelling written there. Do not translate it." |
| `TranscriptCorrectionService.swift` | `buildPrompt` / `buildInstructionPrompt` — see note below |

**Transcription correction note.**
- The goal is to fix the transcription in its **original language**, not to translate it. So when generating, don't use the output-language header, which means "write in the generation language".
- For non-ja, use English instructions that say: "Keep the same language as the input text. Do not translate. Do not summarize."
- Currently `buildPrompt` has no language argument. Add `language: PipelineLanguage = .current` so it is backward compatible.

Out of scope: `GraphExtractionService` (generation has been stopped since spec 065).

Tests:
- For every builder above, add an assert that the ja version's SHA is unchanged (golden value computed beforehand).
- For each builder in en / zh-Hant, add a check that the English instructions are used, e.g. it contains the header, and Japanese-specific instruction phrases such as `してください` are absent from the instruction part.
- Check that strings code parses are kept: chat includes `article-id://`; the agent prompt includes the action names; classification includes `High / Medium / Low` and the candidate names.

## T3 — Multilingual recency questions

- Add keywords for en / zh-Hans / zh-Hant / ko / es / de to `ChatService.isRecencyQuery` (not language-dependent: OR across all languages).
  - Example recency words: recent, recently, latest, this week, 最近, 最新, 本週/本周, 최근, 이번 주, reciente, últimos, esta semana, kürzlich, neueste, diese Woche.
  - Example meta words: article, saved, summary, read, 文章, 保存/保存的, 摘要/重點/重点, 기사, 저장, 요약, artículo, guardado, resumen, Artikel, gespeichert, Zusammenfassung.
- Compare case-insensitively (English/Spanish/German).
- All existing Japanese test cases must still pass.
- Avoid false positives: keep the condition that both a recency word and a meta word are required.
  - "What is the latest iPhone?" has no meta word, so it must be false.
  - "最近的AI文章" contains 文章, so true is fine (topic search runs first, so the content-aware placement from spec 084 is preserved).
- Tests: true/false in each language, plus a false-positive guard.

## T4 — Wrap-up

- Build: `xcodebuild build -scheme KnowledgeBase -destination 'platform=iOS Simulator,name=iPhone 17'`. If the scheme name is different, check it in `docs/HANDOFF.md` §3.
- Run all unit tests (`-only-testing:KnowledgeBaseTests` or equivalent) twice, and confirm no flaky failures.
- Append implementation notes to the end of this file: the inventory list, the files changed, and the test results.
- Don't commit (the orchestrator decides after QA).

## Hard limits

- Don't change ja output by even one character.
- Don't change code-parsed strings or the citation contract.
- Don't add AI calls.
- Don't change `@Generable` / `@Guide` / `@Model`.

## 実装メモ (2026-11-21)

### T2 プロンプト棚卸し (`KnowledgeBase/Services`、`session.respond` / `generate*(prompt:` / `build*Prompt`)
- 対応済み (spec 106): KnowledgeExtractor 3 / ConceptSynthesisService 6 (+ hierarchy・wikiBody) / LintEngine.buildCategoryNamingPrompt
- 対応済み (本 spec、英語指示版を追加): ChatService.buildAgentPrompt / buildPrompt (RAG) / buildFallbackPrompt、DeepDiveChatService.buildInitialPrompt / buildContinuationPrompt (+ buildContextBlock / formatHistory)、KnowledgeDigestService.buildPrompt、ConflictDetectionService.buildPrompt、RecentDigestService.buildPrompt、AutoCategoryClassifier (インラインだった prompt を `static buildPrompt` に抽出 + `buildExampleBlock(language:)`)、TranscriptCorrectionService.buildPrompt / buildInstructionPrompt
- 対象外: GraphExtractionService.buildPrompt (spec 065 から生成停止)。LanguageModelSessionProtocol.swift の `session.respond` は prompt を受けて呼ぶだけで組み立てなし。DeepDiveChatService の fallback 固定文 (`fallbackInitial` / `fallbackContinuation`) は prompt ではなく UI 表示文 (別件)。

### 変更ファイル
- `Services/CategoryPrompts.swift`: `profileKey(forCategoryRaw:)` を追加。全言語シードを order で突き合わせて日本語シード名に解決し、`block(forCategoryRaw:language:)` がどの言語の分野名でも解決 (ja は `byCategory`、ja 以外は `englishByCategory`、その他/動的/nil は空)。辞書キー・既存 caller は不変。
- `Services/PromptLocalizer.swift`: `outputLanguageHeaderGeneral` (概念名を含まない汎用ヘッダ) と `quotedList` を追加。既存ヘッダは不変。
- `Services/ChatService.swift`: 3 builder に英語指示版 (`buildEnglishAgentPrompt` / `buildEnglishPrompt` / fallback は inline 分岐)。action 名・`(article-id://UUID)`・citedArticleIDs はそのまま。`isRecencyQuery` を ja/zh/en/ko/es/de の recency 語 × meta 語 (両方必須) に拡張。大文字小文字無視、ラテン文字語は語頭境界必須 (`read` が `thread` に誤一致しない)。
- `Services/DeepDiveChatService.swift`: builder 群を `static` internal 化 (文字列は不変)、英語指示版 + 英語ラベル / 履歴ラベル。
- `Services/KnowledgeDigestService.swift` / `ConflictDetectionService.swift` / `RecentDigestService.swift`: 英語指示版を追加 (ja 分岐は元の文字列のまま)。
- `Services/AutoCategoryClassifier.swift`: prompt を `static buildPrompt(...)` に抽出 (ja は逐語、検証はハッシュ)。英語版は「Return exactly one name from the candidate list, using the exact spelling written there. Do not translate it.」+ `High / Medium / Low` + 候補名そのまま。
- `Services/TranscriptCorrectionService.swift`: `language: PipelineLanguage = .current` 引数を追加。非 ja は英語指示で「Keep the same language as the input text. Do not translate. Do not summarize.」。出力言語ヘッダ・フッタは付けない。
- Tests: `PromptJapaneseSnapshotTests` に `remainingPromptsJa` (17 ケースの ja SHA-256 ゴールデン。builder の static 化 / 抽出のみの機械的リファクタ後、英語分岐を足す前に算出。既存ゴールデンは無変更)、新規 `PromptMultilingualTests` (分野ヒント / 英語版 en・zhHant / 解析対象文字列の保持 / recency 多言語 + 誤検知ガード)。
- 意図的に更新した既存テスト: `PipelinePromptLanguageTests` と `DeepDiveChatServiceTests` が非 ja で日本語ヘッダ「出力言語: 繁體中文」等を期待していた箇所を、英語ヘッダ「Output language: Traditional Chinese」等に変更 (spec 106 と同じ扱い。ja 側の assert は不変)。

### 検証
- Build: SUCCEEDED (iPhone 17)。
- `-only-testing:KnowledgeBaseTests -parallel-testing-enabled NO` を 2 回: 824 tests / 99 suites 両回 PASS、flaky なし。
- `@Generable` / `@Guide` / `@Model` / `iknow-schema.md` に差分なし。AI 呼び出し追加なし。

### QA 指摘対応 (2026-11-21)
1. `KnowledgeDigestService.buildGraphSection` に `language` 引数を追加し、整形を `static formatGraphSection(entries:language:)` に分離。ja は従来文字列と同一 (テストで全文一致を確認)、ja 以外は英語の見出し / `N articles` / 指示文。
2. `ChatService.isRecencyQuery`: ラテン語は語頭境界 + 語末境界 (末尾 `*` で屈折許可、直前が CJK なら境界扱い)。`read` は `ready` / `readings` に一致しない。`último` / `last week` / `past few days` / `letzte*` / `semana pasada` 等を追加。zh 固有語 (文章 / 重点 / 摘要 / 本週 / 近期 等) はかなを含む質問には適用しない (「最近の文章術は?」「最新の重点課題」は false = main と同じ)。テスト追加。
3. quick モード: 「about 70 words (or about 200 characters for Chinese, Japanese or Korean)」。
4. ユーザーに表示される日本語固定文を `Localizable.xcstrings` (7 ロケール translated、ja 値は元リテラルと同一) へ: DeepDive fallback 4 + `chat.agent.forceFinalFallback` + `recent.fallback.headline` + `digest.fallback.summary.empty/essences` + `conflict.graph.description/fact` (fact は同箇所の newFact/oldFact も追加) + `understanding.deepDive.title`。解決は既存の慣習 (`chat.general.*` 等) に合わせ `String(localized:)` = UI ロケール。`UnderstandingInteraction.swift` は Share/Safari/Widget にも入るため `defaultValue: "「%@」を深掘り"` 付きで、catalog が無い target でも ja に解決。KnowledgeBase / iKnowWidgetExtension / KnowledgeBaseShareExtension の 3 scheme ビルド成功。
5. 英語 agent prompt の重複する 2 組の rule 行を統合 (ルールは落としていない)。
- テスト: 824 → 826 tests、2 回とも PASS。

## QA 2 回目の残り対応 (オーケストレーター)

- `isRecencyQuery`: `últimamente` / `ultimamente`、`guardé` / `guarde` / `guardaste`、`reads` を追加。`letzte*` は `letzte` / `letzten` / `letztes` / `letzter` の語全体一致に変更 (`letztendlich` に誤一致しない)。テスト 3 件追加。
- `digest.fallback.summary.empty` の en / de / es を件数が 1 でも文法が崩れない形 (`… (%lld)`) に変更。
- 単体テスト 826 件 PASS (直列)。
