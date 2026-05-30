# Feature Specification: Sprint 1 P0 出荷ブロッカー修正

**Feature Branch**: `059-p0-shipping-blockers`
**Created**: 2026-05-30
**Status**: Draft
**Input**: code review FINAL report (`docs/code-review/FINAL-code-review-report.md`, 2026-05-30) の P0 5 件

## 背景

`main` @ `c592654` (PR #17 V3.0 merged) に対し、3 reviewer (Claude / OpenAI / Gemini) 合議の code review FINAL report が P0 5 件 / P1 10 件 / P2 15 件を抽出した。本 spec は最優先の **Sprint 1 = P0 出荷ブロッカー 5 件のみ**を 1 spec / 1 PR で解消する。P1-4 LintEngine staging 等は別 spec。

全 5 件は実コードで直接 verified 済 (本セッションで再確認)。

**1 文の本質**: 「出荷前の第一印象を損なう placeholder / 廃止タブ案内 / 矛盾 UI / 無反応リンク / 形骸化 UI test を一掃し、V3.0 を出荷品質にする」

## User Scenarios & Testing *(mandatory)*

### User Story 1 - ライブラリ空状態の placeholder 解消 (Priority: P1)

新規ユーザーが初めてライブラリ (記事一覧) を開くと、まだ記事が無いため空状態が表示される。現状そこに「アプリ名」という置換漏れの placeholder が出ており、第一印象を損なう。正しいアプリ名「iKnow」で保存方法を案内する。

**Why this priority**: 新規ユーザーが最初に見る画面の 1 つ。placeholder は「未完成のアプリ」という印象を与え、信頼を即座に損なう。修正は数行で効果は大。

**Independent Test**: 記事ゼロ状態でライブラリを開き、空状態の案内文に「アプリ名」リテラルが無く「iKnow」が含まれることを確認。

**Acceptance Scenarios**:

1. **Given** 記事が 1 件も保存されていない, **When** ライブラリの空状態を表示, **Then** 案内文に「iKnow」が表示され「アプリ名」リテラルは表示されない

---

### User Story 2 - Onboarding の廃止タブ案内を現行導線に修正 (Priority: P1)

初回起動時の onboarding (4 ページ) の最終ページが、V3.0 で廃止された「学習タブ」を案内している。新規ユーザーは存在しないタブを探して混乱する。現行の 3 タブ構成 (知識 Clip / ライブラリ / AI チャット) に沿った導線を案内する。

**Why this priority**: onboarding は全新規ユーザーが通過する。存在しない機能の案内は最初の体験を破綻させ、離脱要因になる。

**Independent Test**: onboarding を最初から最後まで進め、全ページのコピーに「学習タブ」「AIブレイン」等の廃止タブ名が含まれず、最終ページが現行導線 (知識 Clip → 「続きが気になる」→ 家庭教師との対話) を案内することを確認。

**Acceptance Scenarios**:

1. **Given** onboarding 未完了の初回起動, **When** 最終ページまで進む, **Then** 「学習タブ」「AIブレイン」の文言が onboarding 全体に存在しない
2. **Given** onboarding の最終ページ, **When** 内容を読む, **Then** 現行 3 タブ構成に沿った家庭教師導線が案内される

---

### User Story 3 - Settings の重複 iCloud Section 解消 (Priority: P1)

Settings 画面で、上部に動作する iCloud sync の toggle (実装済) があるのに、下部に「近日対応 — 次のバージョンで予定」という旧 placeholder Section が残っており、相反する 2 つの iCloud 記述が並ぶ。矛盾を見たユーザーは信頼を損ない、サポート問い合わせを誘発する。

**Why this priority**: 既存ユーザーが設定を開くたびに目にする矛盾。機能が「動くのか動かないのか分からない」状態は信頼に直結。

**Independent Test**: Settings を開き、iCloud に関する Section が 1 つだけ (動作する toggle) で、「近日対応」placeholder が存在しないことを確認。

**Acceptance Scenarios**:

1. **Given** Settings 画面, **When** iCloud 関連項目を確認, **Then** iCloud Section は 1 つだけ表示され「近日対応」placeholder は存在しない
2. **Given** iCloud toggle を切替後, **When** Settings を表示, **Then** 再起動案内 banner が条件付きで表示される (既存挙動維持)

---

### User Story 4 - Chat 引用リンクのタップ遷移を回復 (Priority: P1)

AI チャットの回答には引用記事への inline リンクが含まれ、タップ可能に見える。しかし現状タップしても何も起きない (リンクは認識されるが画面遷移が配線されていない)。タップで該当記事の詳細画面へ遷移するようにする。

**Why this priority**: 「タップできそうに見えて反応しない」は期待違反であり、AI の回答全体の信頼を損なう。source 追跡 (引用元へ辿れること) はプロダクトの核 (Constitution III) でもある。

**Independent Test**: 引用リンクを含む AI 回答を表示し、リンクをタップすると該当記事の詳細画面が表示されることを確認。

**Acceptance Scenarios**:

1. **Given** 引用リンク付きの AI 回答が表示されている, **When** 引用リンクをタップ, **Then** 該当記事の詳細画面へ遷移する
2. **Given** 引用先の記事が存在しない (削除済等), **When** 引用リンクをタップ, **Then** 遷移は起きず、アプリは正常状態を保つ (クラッシュしない)

---

### User Story 5 - UI test を現行 3 タブ構成へ刷新 (Priority: P1)

UI test が V3.0 で削除されたタブ (学習タブ / AIブレインタブ) の識別子を参照しており、実行すると失敗する。テストが出荷製品を検証しない状態 = CI シグナルが形骸化している。削除済タブ参照の旧 test を整理し、現行 3 タブ構成を検証する新 UI test に置き換える。

**Why this priority**: 形骸化した UI test は「green = 安全」の前提を崩し、以降の全リグレッション検知を無効化する。出荷判断の根拠を回復する必要がある。

**Independent Test**: UI test suite に削除済タブ識別子 (`tab.learning` / `tab.aibrain`) への参照が無く、現行 3 タブ識別子 (`tab.knowledgeClip` / `tab.library` / `tab.chat`) を検証するシナリオが存在することを確認。

**Acceptance Scenarios**:

1. **Given** UI test suite, **When** 全テストを走査, **Then** `tab.learning` / `tab.aibrain` への参照が存在しない
2. **Given** 新 UI test suite, **When** 現行アプリに対し実行, **Then** 3 タブの基本導線 (タブ load / Add Article / Library navigate / Chat empty-state / Settings) が検証される

---

### Edge Cases

- **P0-2**: onboarding を「スキップ」ボタンで途中離脱した場合も、廃止タブ案内に触れずに完了できる (スキップ導線は既存維持)。
- **P0-3**: iCloud toggle が ON の状態で旧 placeholder を削除しても、動作する toggle の状態・再起動 banner は影響を受けない。
- **P0-4**: 引用リンクの UUID が不正・該当記事が削除済の場合、遷移せず安全に無視する (クラッシュしない)。
- **P0-4**: 擬似 streaming 表示中はリンクが plain text にフォールバックする既存挙動を壊さない (streaming 完了後にリンクが有効化)。
- **P0-5**: UI test 実行検証は本セッションの sandbox 制約で不可。compile 通過まで担保し、実機実行はユーザー後追い。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: ライブラリ空状態の案内文は、置換漏れの placeholder「アプリ名」ではなく正しいアプリ名「iKnow」を表示しなければならない (P0-1)。
- **FR-002**: ライブラリ空状態の案内文は、ローカライズ可能な文字列リソース (xcstrings) として管理されなければならない (P0-1、触る view のみ key 化)。
- **FR-003**: Onboarding の全ページのコピーには、V3.0 で廃止されたタブ名 (「学習タブ」「AIブレイン」) を含めてはならない (P0-2)。
- **FR-004**: Onboarding の最終ページは、現行 3 タブ構成に沿った導線 (知識 Clip タブの「続きが気になる」セクションから家庭教師との対話へ) を案内しなければならない (P0-2)。
- **FR-005**: Onboarding の全ページ文言は、ローカライズ可能な文字列リソース (xcstrings) として管理されなければならない (P0-2、触る view のみ key 化)。
- **FR-006**: Settings 画面には iCloud sync に関する Section を 1 つ (動作する toggle) のみ表示し、矛盾する旧「近日対応」placeholder Section を表示してはならない (P0-3)。
- **FR-007**: 旧 placeholder 削除後も、iCloud toggle の動作・確認 alert・再起動案内 banner の既存挙動は維持されなければならない (P0-3)。
- **FR-008**: AI チャットの引用リンク (記事参照) をタップしたとき、該当記事の詳細画面へ遷移しなければならない (P0-4)。
- **FR-009**: 引用リンクが指す記事が存在しない場合、遷移せずアプリは正常状態を維持しなければならない (クラッシュしない) (P0-4)。
- **FR-010**: 引用リンクのタップ遷移は、擬似 streaming 表示・引用記事一覧 (DisclosureGroup)・関連 ConceptPage chips 等の既存 chat 表示挙動を壊してはならない (P0-4)。
- **FR-011**: UI test suite には、V3.0 で削除されたタブの識別子 (`tab.learning` / `tab.aibrain`) への参照が存在してはならない (P0-5)。
- **FR-012**: UI test suite には、現行 3 タブ構成 (`tab.knowledgeClip` / `tab.library` / `tab.chat`) の基本導線を検証するシナリオが存在しなければならない (P0-5)。
- **FR-013**: 本 spec の変更は SwiftData の永続化スキーマ (@Model) を変更してはならない (CloudKit Production schema deploy 不要)。

### Key Entities

本 spec はデータモデルを変更しない (UI 文言 / navigation 配線 / test refactor のみ)。関与する既存概念:

- **Article (記事)**: 引用リンクの遷移先 (詳細画面)。本 spec では参照のみ、変更なし。
- **ChatMessage (チャット回答)**: 引用リンクを含む AI 回答。本 spec では表示挙動のみ調整、永続化変更なし。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 記事ゼロ状態のライブラリ空状態に「アプリ名」リテラルが 0 箇所、「iKnow」が表示される。
- **SC-002**: onboarding 全 4 ページに「学習タブ」「AIブレイン」の文言が 0 箇所、最終ページが現行導線を案内する。
- **SC-003**: Settings 画面の iCloud 関連 Section が 1 つ、「近日対応」placeholder が 0 箇所。
- **SC-004**: 引用リンク付き AI 回答でリンクをタップすると、該当記事の詳細画面が表示される (遷移成功率 100%、該当記事存在時)。
- **SC-005**: UI test suite 内の削除済タブ識別子 (`tab.learning` / `tab.aibrain`) 参照が 0 件、現行 3 タブ検証シナリオが 5 件以上。
- **SC-006**: クリーンビルドが成功し、本 spec 由来の警告が 0 件 (iPhone 17 Simulator)。
- **SC-007**: 既存 unit test が全て regression なく PASS する。

## Assumptions

- 本セッションでは UI test の**実行**検証は sandbox 制約で不可。compile 通過 + コード品質まで担保し、実機での実行検証はユーザーが後追いで実施する。
- xcstrings の key 化は本 spec で**触る view (EmptyStateView / OnboardingView) の文言のみ**を対象とする。127 empty key 全体整理 (P2-10) は別 spec。
- P0-4 の遷移先は `ArticleDetailView` であり、ChatTabView に既存の navigation 基盤 (`NavigationStack` + `.navigationDestination(for: Article.self)`) を再利用する。新規 navigation 基盤は作らない。
- P0-5 の旧 UI test は、削除済タブ識別子を参照する関数 (またはファイル) を削除し、新 V3 UI test suite を新規追加する。`SaveArticleUITests` の pre-existing flaky 1 件は本 spec の対象外。
- 危険操作 (記事削除 / Tag merge・delete / iCloud toggle / Chat 履歴全削除) の確認ダイアログは Apple HIG 準拠で維持する (本 spec で削除しない)。

## Dependencies

- **spec 056** (V3.0 3 タブ化、学習/AIブレインタブ廃止) — 本修正の前提。
- **spec 051** (iCloud sync 実装済) — P0-3 で旧 placeholder を削除する根拠。
- **spec 033** (Chat inline 引用 link) — P0-4 のリンク生成側。
- **spec 043** (ArticleDetailView の embedNavigationStack 対応) — P0-4 の遷移先。
- **spec 049** (Onboarding) — P0-2 の対象。

## Out of Scope

- P1-4 LintEngine 破壊操作の staging 化 (最重要・最リスク、別 spec)。
- P1-1〜P1-10 の残り (Sprint 2-3)。
- P2-1〜P2-15 (Sprint 3-4)。
- P2-10 xcstrings 127 empty key 全体整理 (本 spec は触る view のみ key 化)。
- UI/UX 改善ロードマップ 6.1〜6.10 (Sprint 4)、特に 6.10「AI が最近やったこと」フィード。
- UI test の実機実行検証 (sandbox 制約、ユーザー後追い)。
