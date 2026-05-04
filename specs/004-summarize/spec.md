# Feature Specification: 知識抽出 + 要約 (Knowledge Extraction + Summarization with Apple Foundation Models)

**Feature Branch**: `004-extract-knowledge` *(計画中。spec 001-003 commit + Mac 検証完了後に実ブランチを切る)*
**Created**: 2026-05-04 (revised — 「要約」と「構造化知識抽出」を **同時に** 行う統合 spec として再設計)
**Status**: Draft (再々設計版)
**Input**: ユーザー説明: "本 spec はアプリ名 `KnowledgeTree` の核心。spec 003 で抽出した本文 (`ArticleBody.extractedText`) を入力に、Apple Foundation Models で **1 回の生成** で 4 つの出力を得る: (a) `essence` 一文要旨、(b) `summary` 説明的要約、(c) `keyFacts` 構造化された事実 (3〜5 件、種別タグ付き)、(d) `entities` 重要な固有名詞 (5〜10 件、種別タグ付き)。すべて元記事への non-optional 参照を持つ (Principle III)。**要約** はユーザーが「読む価値があるか」を判断する人間向けテキスト、**構造化抽出** は将来 spec で entity を横断検索 / knowledge graph 構築 / RAG する基礎データ。両方を 1 セッションで生成することで電力・時間効率も最適化。"

## なぜ要約 + 構造化抽出 の両方が必要か

| 観点 | 要約 (essence + summary) | 構造化抽出 (keyFacts + entities) |
|---|---|---|
| 主用途 | **人間が読む** ためのテキスト | **アプリが検索 / graph / RAG する** ためのデータ |
| 表示 | 一覧の essence、Reader 冒頭の summary 段落 | Reader の事実リスト + entity chips |
| 言語形 | 自然言語の文 | 構造化された discrete 要素 + 種別タグ |
| ユーザー価値 | 30 秒で何の記事か分かる | 後で「Apple について保存した記事」を即座に呼び出せる |
| 拡張性 | 将来別長さの要約 (長文要約等) | entity 横断 graph、cross-article 検索、RAG、カテゴリ自動学習 |
| アプリ名と整合 | `Tree` の **ノード名 / ラベル** に相当 | `Tree` の **構造 / 枝** に相当 |

**両方を 1 回の Foundation Models 生成で取得**: `@Generable struct` に 4 つのフィールドをまとめて宣言 → 1 セッションで一気に生成。電力・時間効率が最適、生成プロンプトに「これらは互いに整合する」制約を入れられる (essence と summary が矛盾しない、key facts が summary に反映される 等)。

## 4 つの出力

| フィールド | 内容 | 制約 | 主な用途 |
|---|---|---|---|
| **essence** | 一文要旨 | 1 文 / 150 文字以内 / 元記事に基づく | 一覧の行に 1 行プレビュー |
| **summary** | 説明的要約 | 2〜3 文 / 300 文字以内 / 元記事に基づく | Reader View の冒頭に段落表示 |
| **keyFacts** (3〜5 件) | 元記事に明示されている事実の文 + 種別タグ | 各 1 文 / 200 字以内 / type ∈ {event, claim, statistic, definition, quote} | Reader の「重要な事実」 list、将来 RAG の chunk |
| **entities** (5〜10 件) | 重要な固有名詞 + 種別タグ + 重要度 | 各 30 字以内 / type ∈ {person, organization, location, concept, product, work} / salience 1〜5 | 一覧の chip (上位 3)、Reader の「登場するもの」chip 群、将来 cross-article graph |

すべて Article への **non-optional 参照** を持つ (Principle III、構造的整合性)。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 自動で要約 + 知識抽出されて一覧に表示 (Priority: P1)

ユーザーが記事を保存すると、spec 002 の enrichment、spec 003 の本文抽出に続いて Apple Foundation Models が **1 回の生成** で essence + summary + keyFacts + entities をすべて作る。一覧画面では各記事行のタイトル下に essence (1 行) と Entity チップ (上位 3 つ) が表示され、ユーザーは記事を開かずに「何の話で誰 / 何が登場するか」を即座に把握できる。

**Why this priority**: 一覧体験が「URL のリスト」から「知識のリスト」に変わる、`KnowledgeTree` の中核体験の P1。spec 001-003 までの「保存 + 読む」に「即座に分かる + 構造化される」を加える。

**Independent Test**: spec 003 で本文抽出成功済の記事を 1 件保存 → 数秒待つ → 一覧の該当行に essence (1 文) と Entity チップ (例: 「Apple」「iOS」「WWDC」) が表示される。

**Acceptance Scenarios**:

1. **Given** spec 003 で本文抽出成功した記事 (ArticleBody .succeeded、extractedText 200 字以上) があり Apple Intelligence 有効、**When** バックグラウンドの抽出ジョブが完了 (median 5 秒以内目安)、**Then** ExtractedKnowledge.status が .succeeded となり、essence + summary + keyFacts + entities がすべて 元記事 (Article) への参照付きで保存される。
2. **Given** ExtractedKnowledge .succeeded の記事が一覧にある、**When** ユーザーが一覧を開く、**Then** 該当行のタイトル下に essence (2 行で打ち切り) と Entity チップ (上位 salience 3 つ、種別アイコン付き) + 「AI 生成」ラベル が表示される。
3. **Given** 抽出された各出力 (essence、summary、key facts、entities)、**When** UI に表示される、**Then** すべての箇所に小さな「AI 生成」ラベルが併記される (Principle III 透明性)。

---

### User Story 2 - Reader View で要約 + 知識を構造的に表示 (Priority: P2)

spec 003 の Reader View でアプリ内記事を読むとき、本文の **冒頭に「知識サマリ」セクション** が以下の構成で表示される: (a) essence (太字 1 行)、(b) summary (説明的 2〜3 文、本文の前置きとして読みやすく)、(c) 「重要な事実」見出し + key facts list (種別アイコン付き bullet)、(d) 「登場するもの」見出し + entity chips (種別アイコン付き)、(e) 区切り線、(f) 「本文」見出し、(g) spec 003 の本文。ユーザーは本文を読まなくても 30 秒で記事の輪郭を掴め、興味があれば本文に進める。

**Why this priority**: 抽出した知識を一覧の小さなプレビューだけで終わらせると勿体ない。Reader View の冒頭で structured に見せることで「読むべきか / 何に注目すべきか」を高速判断できる。spec 003 の Reader 機能を強化する自然な拡張。

**Independent Test**: ExtractedKnowledge .succeeded の記事を一覧でタップ → Reader View が開く → 本文の上に「知識サマリ (AI 生成)」ラベル + essence (太字) + summary (段落) + key facts list + entity chips + 区切り + 本文 の順で表示される。

**Acceptance Scenarios**:

1. **Given** ExtractedKnowledge .succeeded の記事、**When** Reader View を開く、**Then** Reader 最上部に「知識サマリ (AI 生成)」セクションが essence (太字 1 行) → summary (3 行までの段落) → 重要な事実 (bullet list、各行に種別アイコン) → 登場するもの (chip 群、種別アイコン) → 区切り線 → 「本文」見出し → 本文 の順で表示される。
2. **Given** Dynamic Type / Dark Mode を変更する、**When** Reader View を開く、**Then** knowledge セクションも本文と同じく追従する (typography 一貫性)。
3. **Given** ExtractedKnowledge が無い記事、**When** Reader View を開く、**Then** 知識セクション全体が表示されず、本文が冒頭から始まる (Principle V)。
4. **Given** 部分成功 (essence + summary はあるが key facts が空、等)、**When** Reader View を開く、**Then** 取れた要素のみ表示され、空のサブセクションは表示しない (Principle V)。

---

### User Story 3 - Apple Intelligence 不可能時のサイレントフォールバック (Priority: P3)

Apple Intelligence 非対応端末 / 設定 OFF でもアプリは完全に動作する。抽出はサイレントに skip され、UI 上は知識セクション全体が現れない (一覧では essence / chip なし、Reader View でも本文のみ)。「Apple Intelligence を有効にしてください」のような押しつけメッセージは表示しない (Principle V)。

**Why this priority**: Constitution Principle IV と Principle V の両方が要求する graceful degradation。AI 機能ありき で UX が崩壊する設計を防ぐ。`SystemLanguageModel.availability` チェックを必須化。

**Independent Test**: シミュレータで Apple Intelligence をオフ → 記事を保存 → 知識セクションが出ない、spec 001-003 の他機能はすべて正常動作。

**Acceptance Scenarios**:

1. **Given** `SystemLanguageModel.availability != .available`、**When** 新規記事を保存、**Then** 抽出ジョブはサイレントに skip され、ExtractedKnowledge は作成されない。一覧の行は spec 003 の状態。
2. **Given** Apple Intelligence 無効状態で過去保存した記事、**When** Apple Intelligence 有効化後にアプリ再起動、**Then** 既存記事の backfill が起動時に実行され順次抽出完了。
3. **Given** Apple Intelligence 不可能状態、**When** アプリ全体の動作、**Then** spec 001-003 の全機能は 100% 動作。

---

### Edge Cases

- **ArticleBody が無い**: 抽出ジョブを起動しない (入力なし)。
- **ArticleBody.extractedText が短すぎる** (< 200 字): 抽出価値が低いため skip。
- **Foundation Models 生成失敗**: ExtractedKnowledge.status を `.failed` で保存。MVP では再試行なし。
- **部分成功**: 4 出力のうち essence + summary が取れ key facts や entities が空 → `.partiallySucceeded` で保存、得られた要素のみ表示。
- **ハルシネーション疑い**: MVP では検出なし。「AI 生成」ラベル + Reader で本文と並べて見比べる動線で緩和。
- **生成出力が長すぎる**: essence > 150 / summary > 300 / fact > 200 / entity name > 30 文字 等は @Generable Guide で制約 + クライアント側で切り詰め。
- **safety filter で blocked**: failed 扱い、UI には何も出さない。
- **同 entity が複数回出現** (key fact 内 + entity リスト両方に「Apple」): MVP では deduplication しない。将来 spec で正規化。
- **Apple Intelligence のモデルダウンロード中**: `availability == .unavailable(.modelNotReady)` → skip、起動時 backfill で再開。
- **Article 削除時**: 関連 ExtractedKnowledge + KeyFact + KnowledgeEntity が cascade delete される。
- **知識 UI 文言**: 新規キー (「知識サマリ」「要約」「重要な事実」「登場するもの」「AI 生成」「entity 種別 6 種類」「fact 種別 5 種類」) を Localizable.xcstrings に登録。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: アプリは新規 `ArticleBody.status == .succeeded` (extractedText 200 字以上) 時に、その Article の **抽出ジョブ** をバックグラウンドキューに登録する。spec 003 のキューに後続。
- **FR-002**: 抽出は **Apple Foundation Models のみを使用** (`import FoundationModels`)。サードパーティ AI / 外部 API への送信は禁止 (Principle I + Additional Constraints)。
- **FR-003**: ジョブ起動前に必ず `SystemLanguageModel.availability == .available` をチェック。`.available` 以外なら skip。
- **FR-004**: 抽出は `LanguageModelSession` + `@Generable struct ExtractedKnowledge` で **1 回の生成セッション** で 4 つの出力を取得する: `essence: String`、`summary: String`、`keyFacts: [KeyFact]`、`entities: [KnowledgeEntity]`。
- **FR-005**: `essence` は @Guide で「日本語 1 文 / 150 文字以内 / 元記事の主題と核心 / 元記事に明示されている内容のみ (推測禁止)」と制約。
- **FR-006**: `summary` は @Guide で「日本語 2〜3 文 / 300 文字以内 / 元記事の構造を維持した説明的要約 / 元記事に明示されている内容のみ (推測禁止) / essence と一貫性がある」と制約。
- **FR-007**: `keyFacts` は @Guide で「3〜5 件 / 各 1 文・200 字以内 / 元記事に明示されている事実のみ / type ∈ {event, claim, statistic, definition, quote}」と制約。
- **FR-008**: `entities` は @Guide で「5〜10 件 / 各 30 字以内 / 重要な固有名詞 / type ∈ {person, organization, location, concept, product, work} / salience 1〜5」と制約。
- **FR-009**: 抽出結果は SwiftData の 3 つの新規エンティティ `ExtractedKnowledge` (essence + summary 含む)、`KeyFact`、`KnowledgeEntity` として永続化。すべて Article への non-optional 参照を持つ (Principle III)。
- **FR-010**: 一覧画面は ExtractedKnowledge.essence が存在する場合、タイトル + URL の下に **essence (2 行以内) + Entity チップ (上位 salience 3 つ、種別アイコン付き) + 「AI 生成」ラベル** を表示。
- **FR-011**: Reader View は ExtractedKnowledge が存在する場合、本文の上に **「知識サマリ (AI 生成)」セクション** を表示。構成: essence (太字) → summary (段落) → 「重要な事実」見出し + key facts list (種別アイコン付き bullet) → 「登場するもの」見出し + entity chips (種別アイコン) → 区切り線 → 「本文」見出し → spec 003 の本文。
- **FR-012**: 「AI 生成」ラベルは知識が UI 表示される全箇所に併記 (一覧、Reader、将来の検索結果)。視認可能だが控えめ。
- **FR-013**: ArticleBody.extractedText が 200 字未満なら抽出を skip (FR-001 のキューイング時に判定)。
- **FR-014**: 生成結果が完全空または safety filter で blocked された場合、`.failed` で保存し UI 表示しない。部分成功 (4 出力のうち 1 つ以上取れた) は `.partiallySucceeded` で保存し得られた要素のみ表示。
- **FR-015**: 抽出処理中もアプリ本体の UI 応答性は ≤ 100 ms (パフォーマンスゲート)。Foundation Models 呼び出しは detached `Task` で実行。
- **FR-016**: 失敗 / skip / pending 状態を UI に明示しない (知識セクション全体が非表示になるだけ)。Principle V — 不安喚起 UI 禁止。
- **FR-017**: 全 UI 文言 (`知識サマリ`、`AI 生成`、`要約`、`重要な事実`、`登場するもの`、`本文`、entity 種別 6 種類、fact 種別 5 種類) は `Localizable.xcstrings` から日本語キーで取得 (Principle VII)。
- **FR-018**: 起動時 backfill: ArticleBody .succeeded だが ExtractedKnowledge 不在の Article を全件キューイング。Apple Intelligence の availability 変化 (端末アップグレード / 設定 ON 切替) も backfill のトリガ。
- **FR-019**: 1 記事あたり抽出は 1 回のみ。再抽出は将来 spec。`extractionVersion: Int` で将来のヒューリスティック更新時の再抽出判定に使う。
- **FR-020**: 抽出 prompt には extractedText に加えて以下を必ず含める: 「元記事に明示されている内容のみを抽出。推測・補完・常識による補強は行わない。事実が見つからない場合は空配列を返す。essence と summary と key facts は互いに矛盾しないこと。」(ハルシネーション抑止 + 整合性プロンプト)。
- **FR-021**: 知識データは「`Article` → `ExtractedKnowledge` → `KeyFact` / `KnowledgeEntity`」の階層構造で永続化。Article 削除時は cascade delete (Principle III の構造的整合性)。

### Key Entities *(include if feature involves data)*

3 つの新規エンティティを導入し、Article を root とする階層型 knowledge tree を構築。

- **ExtractedKnowledge**: 1 件の Article に紐づく抽出セッションのメタ + essence + summary。
  - 必須: 一意識別子、対応 `Article` への non-optional 参照 (Principle III)、`status` (`pending` / `extracting` / `succeeded` / `partiallySucceeded` / `failed` / `skipped`)。
  - オプション: `essence: String?` (150 字以内、リスト用 1 行)、`summary: String?` (300 字以内、Reader 用説明文)、`generatedAt: Date?`、`modelVersion: String?`、`extractionVersion: Int = 1`、`generationDurationMs: Int?`。
  - 関係: `Article` ↔ `ExtractedKnowledge` は 1-to-1。`ExtractedKnowledge` → `[KeyFact]` と `[KnowledgeEntity]` の親 (cascade delete)。

- **KeyFact**: 元記事に明示されている事実の 1 文。
  - 必須: 一意識別子、親 `ExtractedKnowledge` への non-optional 参照、`statement` (String、200 字以内)、`typeRaw` (`event/claim/statistic/definition/quote`)、`order` (Int、表示順)。
  - 関係: `ExtractedKnowledge` ↔ `[KeyFact]` は 1-to-many (cascade delete)。
  - 将来 (Out of Scope): 文中の Article 内位置への span 参照 (highlight 機能用)。

- **KnowledgeEntity**: 重要な固有名詞 1 件。
  - 必須: 一意識別子、親 `ExtractedKnowledge` への non-optional 参照、`name` (String、30 字以内)、`typeRaw` (`person/organization/location/concept/product/work`)、`salience` (Int、1〜5)。
  - 関係: `ExtractedKnowledge` ↔ `[KnowledgeEntity]` は 1-to-many (cascade delete)。
  - 将来 (Out of Scope): cross-article で同名 entity を集約する `EntityCanonical` 表 (knowledge graph の起点)。

すべて Article を root とする削除カスケード。Principle III の「ソースに基づいた知識生成」を構造レベルで保証。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: ArticleBody .succeeded から ExtractedKnowledge .succeeded まで Apple Intelligence 対応端末で **median 6 秒以内** (4 出力を 1 セッションで生成するため、要約のみより少し長め見積)。
- **SC-002**: Apple Intelligence 不可能端末 / 設定 OFF でも spec 001-003 の **全機能 100% 利用可能**。
- **SC-003**: 典型的な日本語ニュースサイト 20 サイトサンプルで、抽出成功率 (`.succeeded` または `.partiallySucceeded`) **85% 以上**。内訳目標:
  - essence 取得率 **≥ 95%** (最も簡単な出力)
  - summary 取得率 **≥ 90%**
  - keyFacts ≥ 3 件取得率 **≥ 70%**
  - entities ≥ 5 件取得率 **≥ 75%**
- **SC-004**: 抽出ジョブ実行中もアプリ本体の UI 応答性は **≤ 100 ms** (パフォーマンスゲート)。
- **SC-005**: 100 件の記事一覧 (各 ExtractedKnowledge 持ち、entity chip 表示) で **60 fps スクロール維持**。
- **SC-006**: Reader View 表示時間は spec 003 と同じ **300 ms 以内** (知識セクション + summary 段落の追加レンダリング劣化なし)。
- **SC-007**: 知識が UI 表示される全箇所で「AI 生成」ラベル付与漏れ **0 件** (自動 grep audit、Principle III)。
- **SC-008**: 知識 UI 全文言 (新規 ~12 キー) が日本語、英語混在 / ローカライズ漏れ **0 件**。
- **SC-009**: 抽出された key facts の **80% 以上** が extractedText に文字列として大半含まれる (ハルシネーション率の代替指標、手動 sampling 検証)。
- **SC-010**: essence と summary の一貫性: essence の主題が summary 冒頭の主題と矛盾しないケースが **95% 以上** (手動 sampling)。

## Assumptions

- **対象 OS / 端末**: iOS 26+ / iPadOS 26+。Apple Intelligence 対応端末を主対象、非対応でも graceful degradation で動作 (US3)。
- **Foundation Models on-device 実行**: ネットワーク送信なし。本 spec は Constitution Principle I を完全維持 (新規ネットワークアクセスゼロ)。
- **`@Generable` の構造化出力品質**: iOS 26 SDK の Apple Foundation Models は構造化出力に対応。配列フィールド (keyFacts、entities) も生成可能。複雑すぎる nested schema は失敗確率が上がるため MVP は flat に近い構造に留める。4 つのトップレベルフィールド (essence、summary、keyFacts、entities) で 1 セッション生成。
- **抽出品質の限界**: Apple Foundation Models は汎用言語モデル。日本語の知識抽出品質はクラウド大モデル (ChatGPT / Claude / Gemini) に劣る可能性が高い。MVP では SC-003 の 85% 成功率を「ある程度使える」レベルで設定し、品質改善は反復で対応。
- **ハルシネーション抑止**: MVP は (1) `@Generable` Guide で field 単位の制約、(2) prompt で「元記事に明示されている内容のみ」を強制 (FR-020)、(3) UI で「AI 生成」ラベル + 本文と並べて見比べる動線、で対応。自動検証は将来 spec。
- **生成コスト / 電力**: 4 出力を 1 セッションで生成するため、別々に 4 回呼ぶより効率的。1 ユーザー数百件 backfill は実機検証必要 (plan で対応)。
- **schema migration**: spec 001-003 と同様、新エンティティ 3 つ追加は SwiftData lightweight migration で吸収。
- **Apple Intelligence 設定変化検出**: アプリは起動ごとに `SystemLanguageModel.availability` 再チェック。リアルタイム subscription は MVP 外。
- **entity 種別と fact 種別**: MVP では固定の小さな種別セット (entity 6 種、fact 5 種) を使う。後で増やすときはマイグレーション要。

## Out of Scope

本 spec では以下を **明示的に扱わない**。すべて将来 spec で扱う想定。

- **cross-article の entity 集約 (knowledge graph)**: 同名 entity を `EntityCanonical` に正規化、関連記事リンク。**spec 005 (knowledge graph 基礎) で扱う予定**。
- **AI チャット / RAG**: ExtractedKnowledge を context に質疑応答。後続 spec。
- **自動カテゴリ分類**: entity / fact 種別から派生する自動カテゴリ機能。別 spec。
- **ハルシネーション自動検証** (key fact が本文に存在するか): Out of Scope、MVP では sampling 計測のみ (SC-009)。
- **複数長さの要約** (短文 1 行 / 中文 3 行 / 長文 1 段落 を切替): MVP は essence (1 行) + summary (2-3 文) の 2 段階固定。3 段階以上は別 spec。
- **箇条書き要約**: summary はテキストブロックのみ。bullet 化は別 spec。
- **ユーザーによる手動編集 / 削除 / 再抽出**: 個別 KnowledgeNode の修正 UI は別 spec。
- **knowledge fact のタップで本文ハイライト**: 本文 span 参照 + ハイライト UI は別 spec。
- **抽出再実行 / 異なるプロンプトでの再生成**: 別 spec。
- **entity 種別の拡張** (現状 6 種から増やす): 別 spec。
- **多言語抽出** (英語記事 → 英語知識ノード): MVP は日本語入力 → 日本語出力のみ。英語記事は best-effort で日本語出力。
- **ON/OFF 設定**: 別 spec (設定画面 spec)。
- **streaming 表示** (`PartiallyGenerated<T>` を UI に流す): バックグラウンド生成のため不要。将来 AI チャット spec で初導入。
- **Widget / Lock Screen 表示**: 別 spec。
- **エクスポート (knowledge を Markdown / JSON で書き出し)**: 別 spec。
- **knowledge の検索 / 絞り込み UI**: cross-article entity 集約 spec の前提となるため、それと一緒に別 spec。
