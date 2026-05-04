# Feature Specification: 要約 (Apple Foundation Models)

**Feature Branch**: `004-summarize` *(計画中。spec 001 / spec 002 / spec 003 commit 後に実ブランチを切る)*
**Created**: 2026-05-04
**Status**: Draft
**Input**: ユーザー説明: "spec 003 で抽出した本文 (`ArticleBody.extractedText`) を入力に、Apple Foundation Models (`SystemLanguageModel` / `LanguageModelSession`) で 1〜3 文の日本語要約を生成し、新規エンティティ `ArticleSummary` に保存する。一覧画面では行下に要約 1〜2 行プレビュー表示。Reader View では本文の冒頭に「要約」セクションを表示。Apple Intelligence が無効・端末非対応の場合はサイレントに skip し既存機能 (spec 001/002/003) は完全動作。新規ネットワーク非依存 (オンデバイス AI のみ)。"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 自動要約生成と一覧での表示 (Priority: P1)

ユーザーが記事を保存すると、spec 002 の enrichment、spec 003 の本文抽出に続いて自動的に Apple Foundation Models が本文から 1〜3 文の日本語要約を生成する。一覧画面では各記事行のタイトル下に要約のプレビュー (2 行以内) が表示され、ユーザーは記事を開かなくても「これは何の記事か」を即座に把握できる。要約には小さな「AI 生成」ラベルが付き、AI 由来であることが透明に示される。

**Why this priority**: KnowledgeTree が「単なるブックマーク + リーダー」から「AI 補助知識ベース」に進化する核心機能。Constitution Principle II (MVP 中の AI 機能の最優先項目) と Principle III (ソース追跡可能な AI 出力) を初めて実践する spec。これが動かなければ後続 spec 005 (カテゴリ分類) の前提も成立しない。

**Independent Test**: spec 003 で本文抽出成功済の記事を 1 件保存 → 数秒待つ → アプリを開く → 一覧の該当行のタイトル下に 2 行の要約テキスト + 「AI 生成」ラベルが表示される。

**Acceptance Scenarios**:

1. **Given** spec 003 で本文抽出成功した記事 (ArticleBody .succeeded) があり、Apple Intelligence が有効な端末である、**When** バックグラウンド要約ジョブが完了する (3 秒以内目安)、**Then** 一覧の該当行に要約テキスト (1〜3 文、150 文字以内) が表示され、行末または行下に「AI 生成」の小さなラベルが付く。
2. **Given** 要約生成済の記事が一覧にある、**When** ユーザーが一覧をスクロールする、**Then** 60 fps でスムーズにスクロールでき、要約表示で layout 崩れが起きない。
3. **Given** 要約結果に元記事に無い内容が含まれる懸念がある、**When** ユーザーが要約を読む、**Then** UI 上に「AI 生成」ラベルが常に併記され、ユーザーは「これは AI による要約であり元記事を確認すべき」と認識できる (Principle III 透明性)。

---

### User Story 2 - Reader View で要約を冒頭に表示 (Priority: P2)

spec 003 の Reader View でアプリ内記事を読むとき、本文の冒頭に「要約」セクションが目立つように表示される。ユーザーは本文を読み始める前に要約で全体像を掴んでから、興味があれば本文を読み進められる。要約と本文は明確な区切り線で分離される。

**Why this priority**: 要約があっても Reader View に表示されないと、ユーザーが要約に気づかず価値を享受できない。一覧表示 (US1) だけだと「タイトル横の小さな文字」になりがちなので、Reader View 内の冒頭表示で要約の存在感を高める。MVP コア体験の一部。

**Independent Test**: 要約生成済の記事を一覧でタップ → Reader View が開く → 本文の上に「要約 (AI 生成)」のラベル + 要約テキスト + 区切り線 + 本文 が縦に並んで表示される。

**Acceptance Scenarios**:

1. **Given** ArticleSummary .succeeded の記事が一覧にある、**When** その行をタップして Reader View を開く、**Then** Reader View の最上部に「要約 (AI 生成)」ラベル + 要約テキスト + 視覚的な区切り (細線または余白) + 本文 の順で表示される。
2. **Given** Reader View で要約を読んでいる、**When** Dynamic Type 設定や Dark Mode を変更する、**Then** 要約セクションも本文と同じく追従する (typography 一貫性)。
3. **Given** 要約は無いが本文だけある記事 (要約生成失敗 / Apple Intelligence 無効中に保存)、**When** Reader View を開く、**Then** 要約セクション全体が表示されず、本文がそのまま冒頭から始まる (Principle V — 落ち着いた UX、空セクションを見せない)。

---

### User Story 3 - Apple Intelligence 不可能時のサイレントフォールバック (Priority: P3)

iPhone 14 や iPad mini 5 等の Apple Intelligence 非対応端末、または Apple Intelligence が設定で OFF にされた状態でもアプリは完全に動作する。要約生成はサイレントに skip され、UI 上は要約セクション全体が現れない (一覧でもタイトル + URL の最低表示、Reader View でも本文だけ)。「Apple Intelligence を有効にしてください」のような押しつけメッセージは表示しない (Principle V)。

**Why this priority**: Constitution Principle IV (iOS の実現可能性) と Principle V (落ち着いた UX) の両方が要求する graceful degradation。AI 機能ありき で UX が崩壊する設計を防ぐ。Constitution Additional Constraints「`SystemLanguageModel.availability` を必ずチェックする」を実装で遵守する。

**Independent Test**: シミュレータで Apple Intelligence をオフ (または非対応端末プロファイル) に切替 → 記事を保存 → 要約セクションが出ないことを確認、spec 001/002/003 の他機能 (保存・一覧表示・enrichment・Reader View) はすべて正常動作。

**Acceptance Scenarios**:

1. **Given** `SystemLanguageModel.availability != .available` (端末非対応 / Apple Intelligence OFF / モデル未ダウンロード)、**When** 新規記事を保存し ArticleBody .succeeded まで進む、**Then** 要約ジョブはサイレントに skip され、ArticleSummary は作成されない。一覧の行は spec 003 の状態で表示される (要約セクションなし)。
2. **Given** Apple Intelligence 無効状態で過去に保存した記事がある、**When** 後日 Apple Intelligence を有効化してアプリを再起動する、**Then** 既存記事 (ArticleBody 持ちで ArticleSummary 不在) に対する要約 backfill が起動時に実行され、順次要約が生成される。
3. **Given** Apple Intelligence 不可能状態でアプリを使い続けるユーザー、**When** アプリ全体の動作、**Then** spec 001 (保存・一覧・閲覧・削除・重複検出) と spec 002 (enrichment) と spec 003 (本文抽出 + Reader View) はすべて 100% 動作する。要約機能の欠落は「不便」を生まず、UX に空白を作らない (Principle V)。

---

### Edge Cases

- **ArticleBody が無い (spec 003 で抽出失敗 / rawHTML 不在)**: 要約ジョブを起動しない (入力なし)。
- **ArticleBody.extractedText が短すぎる** (< 200 文字): 要約価値が低いため skip。要約生成しない。
- **Foundation Models が generation 中に失敗** (rate limit、内部エラー、context size 超過): ArticleSummary.status を `.failed` で保存。MVP では再試行しない (将来 spec で扱う)。Reader View / 一覧では要約セクション非表示。
- **ハルシネーション** (元記事に無い情報を出力): MVP では検出ロジックなし。「AI 生成」ラベル + ユーザーが Reader / SVC で元記事を確認できる動線で緩和 (Principle III の精神)。検出は将来 spec で扱う。
- **要約結果が長すぎる** (`@Generable` の Guide 制約を超える 150 文字超): クライアント側で 150 文字に切り詰めて保存。
- **要約結果が空文字 / 1 文字以下**: failed 扱い。
- **要約結果に有害コンテンツ** (Apple Foundation Models の safety filter で blocked): failed 扱い、UI には何も出さない (落ち着いた UX)。
- **Apple Intelligence のモデルダウンロード中**: `availability == .unavailable(.modelNotReady)` を検出して skip。モデル準備完了後、起動時 backfill で順次処理。
- **Article 削除時**: 関連 ArticleSummary も cascade delete される (Principle III の構造的整合性)。
- **`Localizable.xcstrings` の要約 UI 文言**: 「要約」「AI 生成」「本文」を新規キーで日本語登録 (Principle VII)。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: アプリは新規 `ArticleBody.status == .succeeded` (extractedText が存在) になった時点で、その Article の要約生成ジョブをバックグラウンドキューに登録する。spec 003 の抽出キューと並列ではなく後続として直列実行可能。
- **FR-002**: 要約生成は **Apple Foundation Models のみを使用** する (`import FoundationModels`)。サードパーティ AI SDK / 外部 API への送信は禁止 (Constitution Principle I + Additional Constraints)。
- **FR-003**: 要約ジョブ起動前に必ず `SystemLanguageModel.availability == .available` をチェックする。`.available` 以外なら ジョブを skip し、ArticleSummary は作成しない (Constitution Principle IV / Additional Constraints)。
- **FR-004**: 要約は `LanguageModelSession` + `@Generable struct` (構造化出力) で生成する。schema は最低 `text: String` フィールドを持ち、Guide で「1〜3 文の日本語要約、150 文字以内、記事の主題と核心を伝える」と制約する。
- **FR-005**: 抽出結果は新規エンティティ `ArticleSummary` として保存し、対応する `Article` への non-optional 参照を持つ (Constitution Principle III)。
- **FR-006**: 一覧画面の各行は ArticleSummary が存在する場合、タイトル + URL の下に要約テキスト (2 行以内) + 「AI 生成」ラベル を表示する。存在しない場合は spec 002/003 の表示にフォールバック (Principle V)。
- **FR-007**: Reader View (spec 003) は ArticleSummary が存在する場合、本文の上に「要約 (AI 生成)」ラベル + 要約テキスト + 区切り線 + 本文 の順で表示する。存在しない場合は本文のみ表示 (Principle V)。
- **FR-008**: 「AI 生成」ラベルは要約テキストが表示される **すべての箇所** に併記する (一覧 / Reader View)。ラベルは小さく控えめ (例: caption フォント、グレートーン) だが視認可能。Constitution Principle III 透明性要件。
- **FR-009**: ArticleBody.extractedText が 200 文字未満なら要約生成を skip (FR-001 のキューイング時に判定)。
- **FR-010**: 要約結果が空文字 / 1 文字以下、または safety filter で blocked された場合、ArticleSummary.status を `.failed` で保存し UI には表示しない。
- **FR-011**: 要約結果が 150 文字を超えた場合、クライアント側で 150 文字に切り詰めて保存する (Guide 制約の安全網)。
- **FR-012**: 要約処理中もアプリ本体の UI 応答性は ≤ 100 ms (Constitution パフォーマンスゲート)。Foundation Models 呼び出しは detached `Task` で実行。
- **FR-013**: 要約失敗 / skip / pending 状態を UI に明示しない (一覧の行・Reader View ともに、要約セクション全体が非表示になるだけ)。Principle V — 不安喚起 UI 禁止。
- **FR-014**: 全 UI 文言 (`要約`、`AI 生成`、`本文`、エラー表示等) は `Localizable.xcstrings` から日本語キーで取得する (Principle VII)。
- **FR-015**: 起動時 backfill: ArticleBody .succeeded だが ArticleSummary 不在の Article を全件スキャンしてキューイング。Apple Intelligence 利用可能性の状態変化 (端末アップグレード / 設定 ON 切替) も backfill のトリガとして扱う。
- **FR-016**: 1 記事あたり要約生成は 1 回のみ。再生成 (異なる長さやトーンでの再要約) は将来 spec で扱う。

### Key Entities *(include if feature involves data)*

- **ArticleSummary**: 1 件の `Article` に紐づく AI 生成要約。
  - 必須属性: 一意識別子、対応する `Article` への non-optional 参照 (Constitution Principle III)、ステータス (`pending` / `summarizing` / `succeeded` / `failed` / `skipped`)。
  - オプション属性: text (String?、生成された要約)、generatedAt (Date?)、modelVersion (String?、Apple Foundation Models のモデルバージョン記録、将来再生成判定用)、generationDurationMs (Int?、計測値)。
  - 関係: `Article` ↔ `ArticleSummary` は 1-to-1 (cascade delete: Article 削除時に ArticleSummary も削除)。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: ArticleBody .succeeded から ArticleSummary .succeeded まで Apple Intelligence 対応端末で **median 3 秒以内** に完了する。
- **SC-002**: Apple Intelligence 不可能端末 / 設定 OFF 状態でも、spec 001 + spec 002 + spec 003 の **全機能 100% 利用可能** (graceful degradation)。アプリ起動・保存・一覧・Reader View すべて正常動作。
- **SC-003**: 典型的な日本語ニュースサイト 20 サイトのサンプルで、要約生成成功率 (ArticleSummary .succeeded) **90% 以上**。
- **SC-004**: 要約ジョブ実行中もアプリ本体の UI 応答性は **≤ 100 ms** (Constitution パフォーマンスゲート)。Foundation Models 呼び出しがメインスレッドをブロックしない。
- **SC-005**: 100 件の記事一覧 (各々 ArticleSummary を持つ) で **60 fps スクロール維持** (Constitution パフォーマンスゲート)。
- **SC-006**: Reader View 表示時間は spec 003 と同じ **300 ms 以内** (要約セクションを含む追加レンダリングがあっても劣化なし)。
- **SC-007**: 要約が UI に表示される全箇所で「AI 生成」ラベル付与漏れ **0 件** (Principle III 透明性、自動 grep で確認可能)。
- **SC-008**: 要約 UI 全文言が日本語、英語混在 / ローカライズ漏れ **0 件** (Principle VII / FR-014)。

## Assumptions

- **対象 OS / 端末**: iOS 26+ / iPadOS 26+。本 spec は Foundation Models を使用するため、Apple Intelligence 対応端末 (iPhone 15 Pro / 16 シリーズ以降、iPad mini A17 Pro、M1 以降の iPad Pro / iPad Air) を主対象とする。非対応端末でも graceful degradation で動作。
- **Foundation Models on-device 実行**: Apple Foundation Models はオンデバイスで実行され、ネットワーク送信を伴わない。本 spec は Constitution Principle I を完全維持する (新規ネットワークアクセスゼロ)。
- **モデルバージョン管理**: Apple Foundation Models のモデルバージョンを `ArticleSummary.modelVersion` に記録し、将来モデル更新時に再生成判定に使う。MVP では再生成しないが将来用に永続化。
- **要約品質の限界**: Apple Foundation Models は汎用言語モデル。日本語要約品質は ChatGPT / Claude / Gemini 等のクラウド大モデルに劣る可能性が高い。MVP では SC-003 の 90% 成功率を「ある程度読める要約が生成される」レベルで設定し、品質改善は反復で対応。
- **safety filter の挙動**: Apple Foundation Models は内蔵 safety filter で有害コンテンツ生成を block する。block 時は failed 扱いとし、UI には表示しない。
- **schema migration**: spec 001/002/003 と同様、production リリース前のため新エンティティ `ArticleSummary` 追加は SwiftData lightweight migration で吸収できる想定。
- **Apple Intelligence 設定変化の検出**: `SystemLanguageModel` の availability は OS 設定変化で動的に変わる。アプリは起動ごとに再チェックする (リアルタイム subscription は MVP では行わない、起動時 backfill で十分カバー)。
- **生成コスト / 電力**: Apple Foundation Models 1 回の要約生成は数秒・数 mWh オーダー (Apple ドキュメント参考値)。1 ユーザーが 1 日数十件保存する想定では問題ないが、数百件一気に backfill する場合の電力/熱は実機検証が必要 (plan で対応)。

## Out of Scope

本 spec では以下を **明示的に扱わない**。すべて将来 spec で扱う想定。

- **カテゴリ分類** (Apple Foundation Models の別 task): 次の spec 005 で扱う。
- **AI チャット** (記事を query して回答生成): 後続の spec で扱う (RAG 含む)。
- **ハルシネーション検出 / source 整合性チェック**: AI 出力が元記事に基づいているかの自動検証は将来 spec。MVP では「AI 生成」ラベル + ユーザーが元記事を確認できる動線で緩和。
- **要約の手動編集 / 再生成 UI**: ユーザーが「この要約は良くない」「もう少し短く」等で再生成を求める UI は将来 spec。
- **複数長さの要約** (短文 / 中文 / 長文 で切替): MVP は 1〜3 文 (150 文字以内) のみ。
- **箇条書き要約**: テキストブロックのみ。bullet list は将来 spec。
- **多言語要約** (英語記事を英語要約 / 日本語要約 / 言語選択): MVP は日本語入力 → 日本語出力のみ。英語記事の扱いは Best-effort (Foundation Models が日本語要約を試みる)。
- **要約のオフライン読み込み中表示** (Reader 開いた時に summary がない場合に「生成中」を見せる): MVP は表示しない (Principle V、Reader 開いた時に既に存在するか・無いかのバイナリ)。
- **要約検索 / 要約による絞り込み**: 一覧の検索/フィルタリング機能は spec 001 から Out of Scope のまま継続。
- **Widget / Lock Screen への要約表示**: 完全に別 spec。
- **要約の SNS 共有 / エクスポート**: 別 spec。
- **モデル A/B テスト** (Apple Foundation Models vs 将来サードパーティモデル): MVP は Apple Foundation Models 一択。
- **設定画面で AI 機能 ON/OFF**: spec 002 でも保留中の設定 spec で扱う (要約の有効/無効も同 spec で扱う想定)。
- **生成のリアルタイム streaming 表示** (`PartiallyGenerated<T>` を UI に流す): バックグラウンド生成のためユーザー目前で生成しない。streaming は将来 AI チャット spec で初導入。
