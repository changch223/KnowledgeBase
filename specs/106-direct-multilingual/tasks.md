# spec 106 — 翻訳なしで原文を読み、生成言語で書く（多言語の品質と速度）

> 共通ルールは `specs/REDESIGN-v2.md` §4（@Model 削除禁止・7 ロケール・ビルド/テスト手順・cc-crew）を準用する。
> ブランチ: `fix-extraction-resilience`（PR #84 に追加する。main から切り直さない）/ リスク: 中（生成プロンプトに触れる）
> @Model 変更: なし / `@Generable`・`@Guide`: 変更しない / AI 呼び出し: 通常時は増えない（翻訳が消える分むしろ減る）

## 背景（実機ログ・2026-11-19）
- 生成言語が日本語以外の端末で、日本語記事を chunk ごとに **先に翻訳**してから抽出している。1 chunk あたり翻訳 約 10 秒、`translationd` のクラッシュも出る。
- 翻訳文が `refusal` / `unsupportedLanguageOrLocale`（pl と誤判定）で落ちる（PR #84 で原文再試行を追加済み）。
- 生成言語が日本語以外なのに、新しく作られたトピック名が日本語（「AIデスクリング」= deskilling の誤記）。原因は **プロンプト本文がほぼ日本語**で、出力言語の指示が 1 行しかないこと。小さいモデルは指示文の言語に引っ張られる。

## 方針（ユーザー承認済み）
1. **原文を直接読む**: Foundation Models が読める言語の記事は翻訳しない。プロンプトで「生成言語で書け」と指示する。読めない言語だけ従来どおり翻訳する。
2. **非日本語パイプラインのプロンプトは英語の指示文にする**: 7 言語 × 全プロンプトを書くのではなく、「日本語版（現行・一字も変えない）」と「英語指示版（ja 以外の全パイプライン共通）」の 2 系統。英語版は冒頭と末尾の両方で出力言語を指定し、「概念名・要点は生成言語に訳す。製品名・社名・人名は原語表記のまま」を明記する。
3. **出力言語ガード**: 抽出結果の `essence` が生成言語でないと判定できたら、翻訳経路で 1 回だけやり直す。
4. **比較用スイッチ**: 設定に「先に翻訳してから整理する（従来の方式）」を置く（既定 OFF = 新方式）。実機で同じ記事を両方式で比べるため。

---

## タスク

### T1. 直接読める言語の判定
- 新規 `KnowledgeBase/Services/DirectReadPolicy.swift`（純関数 enum）
  - `static let modelReadableLanguageCodes: Set<String> = ["ja", "en", "zh", "ko", "es", "de", "fr", "it", "pt"]`（iOS 26 Foundation Models の対応言語。コメントに出典「Apple Intelligence 対応言語」と、増えたらここに足すと書く）
  - `static func canReadDirectly(_ detected: DetectedLanguage) -> Bool`: `.japanese` / `.english` は true、`.other(raw)` は raw の言語コード部（`zh-Hant` → `zh`）が集合に含まれれば true、`.unknown` は true（従来も翻訳しない）。
  - `static func shouldTranslateFirst(detected:, pipeline:, preferTranslate: Bool) -> Bool`: パイプライン言語と一致 → false / `preferTranslate == true` → 従来どおり（一致しなければ true）/ それ以外 → `!canReadDirectly(detected)`。
- 設定値: `UserDefaults(suiteName: AppGroup.identifier)` のキー `settings.translateBeforeExtraction`（Bool、既定 false）。読み出しヘルパー `DirectReadPolicy.prefersTranslateFirst() -> Bool` を 1 か所に。
- テスト `KnowledgeBaseTests/DirectReadPolicyTests.swift`: ja 記事 × en パイプライン → 翻訳しない / pl 記事 × en → 翻訳する / ja × ja → しない / ja × en × preferTranslate → する / zh-Hant 記事 × en → しない / unknown → しない。

### T2. KnowledgeExtractor を新方式に
ファイル: `KnowledgeBase/Services/KnowledgeExtractor.swift`
- `prepareForExtraction` の先頭で、`DirectReadPolicy.shouldTranslateFirst(...)` が false なら翻訳せず原文を返す（ログ `translate skip: direct read source=…`）。true のときは現行ロジック（unsupported 言語スキップ、notInstalled、キャッシュ、短すぎ fallback）をそのまま通す。
- テストのために `KnowledgeExtractor` の init に `preferTranslateFirst: (() -> Bool)? = nil`（nil なら `DirectReadPolicy.prefersTranslateFirst()`）を追加してよい。
- **逆向きの fallback**: 原文直読みで `generateKnowledge` / `generateChunkKnowledge` が `unsupportedLanguageOrLocale` で失敗したら、翻訳してから 1 回だけやり直す（PR #84 の「翻訳文が失敗したら原文で再試行」と対になる。両方向で最大 1 回ずつ、無限ループにしない）。
- **出力言語ガード（T2 の一部）**: 抽出結果の `essence`（空でなく 20 文字以上のとき）を `LanguageDetector.detect` にかけ、結果が `.unknown` でなく、かつ `PipelineLanguage.current.matches(detected:)` が false なら、翻訳経路で 1 回だけやり直す（翻訳済みだった場合はやり直さない）。chunk 経路も同様。ログ `output language guard: expected=… got=… → retry with translation`。
- 既存テストのうち「ja 記事 × en/zh/es パイプラインで翻訳が呼ばれる」系（`extractInvokesTranslationForJapaneseWhenPipelineIs…`）は、新方式では翻訳されないのが正しい。**`preferTranslateFirst: { true }` を渡す形に書き換えて従来方式のテストとして残し**、新方式のテスト（翻訳が呼ばれず、prompt に日本語原文が入る）を追加する。

### T3. 英語指示版プロンプト（ja 以外のパイプライン共通）
- 新規 `KnowledgeBase/Services/PromptLocalizer.swift`:
  - `static func usesJapaneseInstructions(_ language: PipelineLanguage) -> Bool { language == .ja }`
  - `static func outputLanguageHeader(_ language: PipelineLanguage) -> String`（英語）: `"Output language: \(language.englishName). Write every field in \(language.englishName), even though the schema descriptions are in Japanese. Translate concept names and key points into \(language.englishName). Keep product, company and person names in their original spelling."`
  - `static func outputLanguageFooter(_ language: PipelineLanguage) -> String` = `language.outputInstruction`（目標言語での一文。既存）
  - `PipelineLanguage` に `englishName`（`Japanese` / `Simplified Chinese` / `Traditional Chinese` / `English` / `Korean` / `Spanish` / `German`）を追加。
- 次のプロンプトに **英語版の分岐**を足す。`language == .ja` のときは現行文字列を **一字も変えずに**返す（既存テストが通ること + 新しい ja スナップショットテストで固定）:
  1. `KnowledgeExtractor.buildPrompt`
  2. `KnowledgeExtractor.buildChunkPrompt`
  3. `KnowledgeExtractor.buildMetaSummaryPrompt`
  4. `ConceptSynthesisService.buildConceptHierarchyPrompt`（トピック名。最重要）
  5. `ConceptSynthesisService.buildOneShotPrompt` / `buildBroadConceptPrompt` / `buildChunkPrompt` / `buildMetaPrompt`（概念の summary・要点）
  6. `ConceptSynthesisService.buildWikiBodyPrompt`（Wiki 本文）
  7. `LintEngine` の新カテゴリ命名プロンプト（`generateTopicName` に渡す prompt、634 行付近）
- 英語版の書き方:
  - 冒頭に `outputLanguageHeader`、末尾に `outputLanguageFooter`。
  - ルールは現行の日本語ルールを **意味を変えずに英訳**（推測禁止、件数上限、コード片除外、一般語除外、体言で書く等）。日本語の例示（NG/OK 例、「生成AI」「Text-to-SQL」等）は英語の例に置き換える。
  - `SchemaLoader.shared.section(named:)`（日本語の `iknow-schema.md`）は **ja のときだけ**使う。英語版はコード内の英語ルール定数を使う（`iknow-schema.md` は変更しない）。
  - `BroadConceptSeed.promptHint`（日本語の広い概念候補）は英語版では渡さない（日本語名に引っ張られるため）。代わりに「Prefer a short field-level noun」と指示。
  - 記事本文・タイトル・essence などデータ部分は原文のまま（翻訳しない）。見出しラベル（`# 記事` → `# Article` 等）は英語に。
  - 字数制限（「〜字以内」）は英語版でも同じ数値を「characters」で書く。
- 対象外（今回触らない）: ChatService・DeepDiveChatService・KnowledgeDigestService・RecentDigestService・ConflictDetectionService・GraphExtractionService・AutoCategoryClassifier（ユーザーの質問言語やカテゴリ固定リストに従うため影響が小さい）。報告に「次の候補」として列挙。
- テスト: 各プロンプトについて ① ja パイプラインで現行と同一（既存テスト + `buildConceptHierarchyPrompt` 等の ja 版が主要フレーズを含む）② en / zhHant パイプラインで `Output language: English` / `Traditional Chinese` と目標言語の footer を含み、日本語の指示文（例「抽出してください」「厳守」）を含まない。private 関数はテストから呼べる internal static にしてよい。

### T4. 設定のスイッチ
- `KnowledgeBase/Views/LanguageSettingsView.swift`（生成言語の設定画面）に Toggle を 1 つ追加: 新キー `settings.translateFirst.title`（ja「先に翻訳してから整理する」/ en「Translate before organizing」/ zh-Hans「先翻译再整理」/ zh-Hant「先翻譯再整理」/ ko「먼저 번역한 뒤 정리」/ es「Traducir antes de organizar」/ de「Vor dem Ordnen übersetzen」）と footer `settings.translateFirst.footer`（ja「オフ: AI が原文を直接読み、生成言語で整理します（速い）。オン: 先に生成言語へ翻訳してから整理します（従来の方式）。」/ en「Off: the AI reads the original and writes in your generation language (faster). On: translates into your generation language first (previous method).」/ zh-Hans「关闭：AI 直接读原文，用生成语言整理（更快）。开启：先翻译成生成语言再整理（旧方式）。」/ zh-Hant「關閉：AI 直接讀原文，用生成語言整理（更快）。開啟：先翻譯成生成語言再整理（舊方式）。」/ ko「끔: AI가 원문을 직접 읽고 생성 언어로 정리합니다(더 빠름). 켬: 먼저 생성 언어로 번역한 뒤 정리합니다(기존 방식).」/ es「Desactivado: la IA lee el original y escribe en tu idioma de generación (más rápido). Activado: primero traduce a tu idioma de generación (método anterior).」/ de「Aus: Die KI liest das Original und schreibt in deiner Generierungssprache (schneller). An: übersetzt zuerst in deine Generierungssprache (bisherige Methode).」）。
- 生成言語が日本語のときは Toggle を出さない（翻訳は起きないため）。
- 変更は次に保存・再抽出する記事から有効（再起動不要）。

### T5. 記録
- `specs/106-direct-multilingual/tasks.md` 末尾に「## 実装メモ」。
- ルートの `CLAUDE.md` の Active features に spec 106 を 1 項目追記（既存の書き方に合わせる）。

---

## 受け入れ基準
- [ ] 生成言語 = English の状態で日本語記事を抽出すると、翻訳が呼ばれず、prompt に日本語原文と `Output language: English` が入る
- [ ] 同条件で pl など読めない言語の記事は従来どおり翻訳される
- [ ] スイッチ ON で従来方式（翻訳してから抽出）に戻る
- [ ] 原文直読みが `unsupportedLanguageOrLocale` で落ちたら翻訳して 1 回だけ再試行、翻訳文が `refusal` 等で落ちたら原文で 1 回だけ再試行（無限ループしない）
- [ ] essence が生成言語でないと判定されたら翻訳経路で 1 回だけやり直す
- [ ] 生成言語 = 日本語のとき、全プロンプトが変更前と一字一句同じ
- [ ] `@Generable` / `@Guide` に差分なし（`git diff main -- KnowledgeBase | grep -nE "^[+-].*(@Generable|@Guide)"` が空）
- [ ] 新規キーが 7 ロケールすべてに値（state translated）
- [ ] ビルド成功・ユニットテスト全件成功・新規 warning なし

## 実機で確認（ユーザー）
- 生成言語 English / 繁體中文 で日本語記事を数本保存 → トピック名・要点・essence が生成言語で出るか、固有名詞が原語のままか
- 1 記事あたりの処理時間（ログの `durationMs`）がスイッチ OFF で短くなるか
- スイッチ ON/OFF で同じ記事の要点の質を比べる
- token 超過（`exceededContextWindowSize`）が増えていないか

---

## 実装メモ（2026-11-21）
- T1: `DirectReadPolicy`（canReadDirectly / shouldTranslateFirst / prefersTranslateFirst）。`.unknown` は preferTranslate でも翻訳しない（`prepareForExtraction` が従来 unknown を即 return するため整合）。
- T2: `KnowledgeExtractor` に `preferTranslateFirst` 注入、`prepareForExtraction(forceTranslate:)` を追加（フォールバック用に直読み判定を飛ばす）。直読み失敗（`unsupportedLanguageOrLocale`）→翻訳して 1 回、翻訳文失敗→原文で 1 回、出力言語ガード→翻訳で 1 回。翻訳済みなら再翻訳しない・やり直しに失敗しても最初の結果を捨てない。chunk 経路も同様。
- 出力言語ガードの補足: essence にかな（ja パイプライン）/ハングル（ko）が含まれるなら一致扱い（英単語の多い日本語 essence を英語と誤判定して無駄な翻訳再試行をしないため）。
- 食い違い: 「pl など読めない言語は従来どおり翻訳」は、既存の誤検知ガード（`isTranslationSupported` 外はスキップ）が先に効くため、実際は raw のまま直読みになる（従来も pl はスキップだった = 挙動不変）。`modelReadableLanguageCodes` は翻訳対応集合を包含するため、現状「翻訳先行」になるのはスイッチ ON のときだけ。
- T3: `PromptLocalizer` / `PipelineLanguage.englishName`。ja 以外は英語指示版（KnowledgeExtractor 3 本・ConceptSynthesis 6 本・LintEngine 命名）。`CategoryPrompts.englishByCategory` も追加（日本語の分野ヒントが混ざらないように）。ConceptSynthesis の build* は private instance → internal static に変更（テスト可能化、文字列は不変）。LintEngine の命名 prompt は `buildCategoryNamingPrompt` に抽出。
- ja 一字一句不変: `PromptJapaneseSnapshotTests`（SHA-256 ゴールデン、英語版追加前のコードで算出）。
- T4: `LanguageSettingsView` に Toggle（生成言語 ja のときは非表示）。xcstrings 2 キー × 7 ロケール translated。
- 次の候補（今回対象外）: ChatService / DeepDiveChatService / KnowledgeDigestService / RecentDigestService / ConflictDetectionService / GraphExtractionService / AutoCategoryClassifier の英語指示版。

## オーケストレーター修正（QA 前）
- builder 報告「ja パイプラインでも英語記事が直読みになる」はユーザーへの説明（日本語利用者は影響なし）と食い違うため、`DirectReadPolicy.shouldTranslateFirst` で **pipeline == .ja は常に翻訳先行**（従来どおり）に変更。テスト `japanesePipelineKeepsTranslateFirst` 追加。直読みは ja 以外の生成言語のみ。

### QA 修正
- `KnowledgeExtractor.prepareDetailed`（`Prepared{text, didDirectRead, didTranslate}`）を追加。`prepareForExtraction` は text だけ返す薄いラッパ。逆向き fallback と出力言語ガードは `didDirectRead` のときだけ、「翻訳文失敗 → 原文再試行」は `didTranslate` のときだけ動く。翻訳を試みて失敗・短すぎ・unavailable で原文に戻った場合はどちらも false（再翻訳しない）。ja パイプラインとスイッチ ON は PR #84 の原文再試行以外 main と同じ動き。
- 出力言語ガード: zhHans / zhHant は漢字を含みかな・ハングルを含まなければ一致扱い。
- `englishWikiBodyRules` に UUID を一字一句コピーする指示を追加。
- `extractFallsBackToRawTextWhenTranslationFails` を ja パイプライン固定の元の意図に戻した。
