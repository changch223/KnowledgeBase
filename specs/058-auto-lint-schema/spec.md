# Feature Specification: Auto-Lint + Schema 外出し + Confirm UX 廃止

**Feature Branch**: `056-uiux-redesign-v3` (spec 056 + 057 + 058 統合、PR #17 update で V3.0 一括 release)
**Created**: 2026-05-24
**Status**: Draft
**Input**: 4 ラウンドの対話で確定。Autoresearch + LLM Wiki のチューニング思想を iKnow に完全移植。

## 製品ビジョン (1 文)

**「ユーザーに聞かず、AI が裏で勝手に整理する」**

Apple Photos Memories 風 calm UX。ユーザーは「整理された結果」だけを見る。

## 設計哲学 (Autoresearch + LLM Wiki から借用)

| Autoresearch / LLM Wiki | iKnow 対応 |
|---|---|
| `program.md` (LLM への指示書) | `docs/iknow-schema.md` (起動時 load + production fallback) |
| `val_bpb` (単一評価指標) | `healthScore` (孤立 ConceptPage 数 + 矛盾未解決数) |
| Raw sources は不変 | Article (ユーザーが保存したもの、削除以外で変更しない) |
| The wiki は LLM が書き換え | ConceptPage / Tag / GraphNode / KnowledgeDigest |
| NEVER STOP loop | 週 1 BGTask + Settings 「今すぐ整理」button |
| 「改善したら keep、しなければ skip」 | Lint loop の各 step は idempotent、改善計測で deterministic |
| `log.md` 取り込み履歴 | `LintLog` @Model + Settings 内 30 件表示 |

## User Scenarios & Testing *(mandatory)*

### User Story 1 — ConflictProposal 自動採用 + 旧情報の DisclosureGroup 閲覧 (Priority: P1)

新記事保存で既存記事と矛盾検出された場合、ユーザーに「上書き / 両方残す / 却下」を聞かず、AI が自動で「両方残す」を採用する。新情報を主表示、旧情報は ArticleDetailView の「過去の見解 (N) ▼」 DisclosureGroup から閲覧可能。データロスゼロ。

**Why this priority**: 「ユーザーに聞かない」哲学の最大の象徴。現状 spec 037 で confirm を出してたが calm UX 違反だった、これを根本解決。

**Independent Test**: 同 entity を含む 2 記事で矛盾発生 → confirm UI 出ない → 新情報を default 表示 + 「過去の見解」展開で旧情報閲覧可能。

**Acceptance Scenarios**:

1. **Given** entity 「Tim Cook」を含む 2 記事 (古 + 新)、**When** 新記事を保存、**Then** ConflictProposal が自動 status=autoResolved に、UI に confirm 表示なし
2. **Given** auto-resolved な ConflictProposal、**When** ArticleDetailView を開く、**Then** 末尾に「過去の見解 (1) ▼」 DisclosureGroup
3. **Given** DisclosureGroup tap、**When** 展開、**Then** 旧 Article の essence + 「{N} 日前の情報」表示

---

### User Story 2 — StaleSavedAnswer 自動再生成 (Priority: P1)

isStale=true な SavedAnswer は週 1 BGTask で agent loop (spec 057) 経由で自動再生成される。新 SavedAnswer 作成、旧は isStale=true のまま archive。ユーザーに「再生成しますか?」を聞かない。

**Why this priority**: spec 045/046 で「⚠️ 更新が必要」と confirm 表示してたが calm UX 違反。完全自動化で解決。

**Independent Test**: SavedAnswer を isStale=true に → 週 1 BGTask 発火 → 新 SavedAnswer 作成、旧は履歴に残る。

**Acceptance Scenarios**:

1. **Given** isStale=true な SavedAnswer 3 件、**When** 週 1 BGTask 発火、**Then** 3 件全て agent loop 経由で再生成、新 SavedAnswer 3 件追加
2. **Given** auto-refresh 完了、**When** 履歴画面、**Then** 新答え default 表示、旧答えは「過去の答え」section で表示

---

### User Story 3 — Confirm UI / Section の完全削除 (Priority: P1)

以下の UI を完全削除:
- ActionItemsReviewView (spec 056、FactConflicts + StaleSavedAnswer の統合 review)
- GraphProposalsSection (spec 041、Knowledge Graph 提案レビュー)
- 「⚠️ 更新が必要 (N)」badge (spec 056、FollowingPeopleSection)

機能は全て AI 自動採用に移行、確認 UI の存在意義を消す。

**Why this priority**: UI を削除しないと「自動化された」のに「まだ confirm がある」状態が残り、setting 上の inconsistency が生まれる。

**Independent Test**: 知識 Clip タブ / Settings を確認 → 上記 UI が存在しない → 機能は裏で AI 自動採用済。

**Acceptance Scenarios**:

1. **Given** spec 056 で配置した ActionItemsReviewView、**When** Settings or 知識 Clip タブを探す、**Then** 該当 view が見つからない
2. **Given** spec 041 GraphProposalsSection、**When** Category 詳細画面を確認、**Then** UI section が削除されている
3. **Given** spec 056 FollowingPeopleSection、**When** 知識 Clip タブを開く、**Then** ⚠️ badge が表示されない (件数 0 で非表示ではなく、UI 自体が削除)

---

### User Story 4 — ConceptPage 自動 merge (重複統合) (Priority: P1)

ConceptPage の重複が検出されたら AI が自動 merge:
- 判定 1: 編集距離 ≤ 2 (例: 「OpenAI」 ≈ 「Open AI」 ≈ 「OpenAi」)
- 判定 2: embedding similarity ≥ 0.85 (例: 「Claude Opus」 ≈ 「Anthropic Claude」)
- どちらか OR 条件で merge 実行

merge ロジック: 新しい updatedAt の方を winner、relatedArticles / relatedConceptIDs を union、源 ConceptPage は delete。

**Why this priority**: 重複が放置されると Wiki の体系性が崩れる、自動 merge で知識ベースが綺麗に保たれる。

**Independent Test**: 「OpenAI」と「Open AI」を強制的に作成 → 週 1 BGTask 発火 → 1 ページに merge、片方の relatedArticles が他方に移動。

**Acceptance Scenarios**:

1. **Given** ConceptPage 「OpenAI」(関連記事 3) と 「Open AI」(関連記事 2)、**When** Lint loop 実行、**Then** 「OpenAI」 1 ページに統合、関連記事 5
2. **Given** 編集距離 3 以上で意味的に近い 2 ページ (embedding sim 0.9)、**When** Lint loop、**Then** embedding 条件で merge
3. **Given** 編集距離 1 だが意味的に違う 2 ページ (embedding sim 0.3)、**When** Lint loop、**Then** 編集距離条件で merge (両者 OR)

---

### User Story 5 — 孤立 ConceptPage / Tag の auto-delete (Priority: P1)

以下を自動削除 (60 日穏当 cleanup):
- ConceptPage: 関連記事 ≤ 1 件 + 60 日参照ゼロ + isFollowing=false
- Tag: 関連 Article 0 件

**Why this priority**: 1 記事のみで使われた一過性の概念は wiki の体系性を汚すノイズ、自動 cleanup で集中度を保つ。

**Independent Test**: 関連記事 1 件 + 60 日前 updatedAt + isFollowing=false な ConceptPage を作成 → Lint loop → 削除確認。

**Acceptance Scenarios**:

1. **Given** ConceptPage 関連記事 1 件 + updatedAt 60 日前 + isFollowing=false、**When** Lint loop、**Then** auto-delete + LintLog 記録
2. **Given** ConceptPage 関連記事 1 件 + isFollowing=true、**When** Lint loop、**Then** 削除されない (ユーザー保護)
3. **Given** Tag.articles 0 件、**When** Lint loop、**Then** auto-delete

---

### User Story 6 — 孤立 ConceptPage への AI auto-link (Priority: P2)

relatedConceptIDs が空 / 1 件のみな ConceptPage に AI が自動でリンク追加:
- 同 categoryRaw のページから embedding similarity 上位 N 件を選定
- relatedConceptIDs に追加 (max 5 件)

**Why this priority**: リンクが少ない ConceptPage はナビゲーションが死ぬ、auto-link で wiki の繋がりを補強。

**Independent Test**: relatedConceptIDs 空な ConceptPage → Lint loop → 関連ページ 3 件 auto-link。

**Acceptance Scenarios**:

1. **Given** ConceptPage 「Tim Cook」 (relatedConceptIDs 空)、**When** Lint loop、**Then** 同 category「Apple」「Vision Pro」「iPhone」が auto-link
2. **Given** ConceptPage 既に 5 件 link 済、**When** Lint loop、**Then** 追加なし (max 5 制約)

---

### User Story 7 — Tag/Category 再分類 (Priority: P2)

既存 Tag の Category を週 1 BGTask 内で AutoCategoryClassifier 経由で再判定。ズレてたら自動修正。

**Why this priority**: 初回分類で間違った Category がそのまま残るのを防ぐ、知識体系の精度を維持。

**Independent Test**: Tag を意図的に間違った Category に設定 → Lint loop → 自動修正される。

**Acceptance Scenarios**:

1. **Given** Tag 「Swift」 categoryRaw=「経済」(誤分類)、**When** Lint loop、**Then** categoryRaw=「テクノロジー」に自動修正 + LintLog
2. **Given** Tag categoryRaw が AI 判定と一致、**When** Lint loop、**Then** 変更なし (idempotent)

---

### User Story 8 — Settings 内 健全性スコア + 整理ログ表示 (Priority: P2)

Settings に以下を追加:
- 「健全性スコア (孤立 12 件 + 矛盾 3 件 = 15)」を上部に静かに表示
- 「整理ログ (直近 30 件)」section: 日時 + 操作 + 対象
- 「今すぐ整理する」button: tap で Lint loop 即時実行

**Why this priority**: 「裏で何が起きているか」をユーザーに見せる透明性、Apple HIG「ユーザーに control を返す」原則と合致。

**Independent Test**: Settings を開く → 健全性スコア / 整理ログ / 「今すぐ整理」 button が表示される。

**Acceptance Scenarios**:

1. **Given** 孤立 12 件 + 矛盾 3 件、**When** Settings を開く、**Then** 「健全性スコア 15」表示
2. **Given** 過去 30 件の Lint 操作履歴、**When** Settings の「整理ログ」section、**Then** 30 件全表示、日時 desc ソート
3. **Given** 「今すぐ整理」 button tap、**When** tap、**Then** Lint loop 即時実行、完了後「整理しました N 件」表示

---

### User Story 9 — 週 1 BGTask 自動実行 (Priority: P1)

日曜 3 AM に BGTask 発火、Lint loop 全 6 ステップ自動実行:
1. ConceptPage merge
2. ConceptPage delete
3. Tag delete
4. リンク強化
5. Tag/Category 再分類
6. SavedAnswer auto-refresh + ConflictProposal auto-resolve

**Why this priority**: NEVER STOP loop の実体化、ユーザーが意識しなくても wiki が綺麗に保たれる。

**Independent Test**: BGTaskScheduler.submit 発火確認 → Lint loop 全 6 step 実行 → LintLog 記録。

**Acceptance Scenarios**:

1. **Given** 日曜 3 AM 到来、**When** BGTask 発火、**Then** 全 6 ステップ実行、所要時間 < 30 秒 (data 規模 1000 article 想定)
2. **Given** BGTask 発火失敗 (低電力 / 通信圏外)、**When** 翌日まで延期、**Then** 翌週日曜に再発火 (1 週 skip)

---

### User Story 10 — Schema 外出し (docs/iknow-schema.md) (Priority: P3)

`docs/iknow-schema.md` 新規、LLM への指示書を 1 ファイルに集約:
- AgentAction prompt template (spec 057 と同期)
- Conflict resolution rule
- Lint merge criteria
- Health score formula
- NEVER STOP loop instruction

起動時 SchemaLoader が読み込み → memory cache → service が参照。production fallback で schema.md 不在 / parse 失敗時は code 内 constants 使用。

**Why this priority**: Autoresearch の「program.md」思想を完全移植、開発者が AB test 可能になる。production には影響ゼロ (fallback で保護)。

**Independent Test**: docs/iknow-schema.md を編集 → アプリ再起動 → SchemaLoader が新 schema を反映 → LLM 動作が変化。

**Acceptance Scenarios**:

1. **Given** docs/iknow-schema.md 存在、**When** アプリ起動、**Then** SchemaLoader.shared.loadedSchema に内容 cache
2. **Given** docs/iknow-schema.md 不在、**When** アプリ起動、**Then** code 内 constants で fallback、エラーなし起動
3. **Given** schema.md parse 失敗 (syntax error)、**When** 起動、**Then** fallback + warning log、エラーなし起動

---

### User Story 11 — 危険操作 confirm は維持 (Priority: P1)

以下は引き続き confirm を出す (Apple HIG「destructive action は confirm」原則):
- 記事削除 swipe → confirm
- Tag merge / delete → confirm (spec 024 既存)
- ConceptPage delete → confirm (spec 042 既存)
- iCloud sync toggle ON/OFF → confirm (spec 051 既存)
- AI チャット履歴全削除 → confirm (spec 021 既存)

**Why this priority**: 「ユーザーに聞かない」哲学は「無意味な confirm」を排除するが、危険操作の confirm は維持。

**Independent Test**: 上記 5 操作を順に実行 → 全て confirm alert 表示。

**Acceptance Scenarios**:

1-5. **Given** 各操作、**When** 実行、**Then** confirm alert 表示 (詳細は spec 024/042/051/021 参照)

---

### Edge Cases

- **Lint loop 実行中にアプリ kill**: BGTaskScheduler の `expirationHandler` で graceful stop、次回実行で resume
- **データ規模が極端に大きい (10000+ ConceptPage)**: Lint loop 30 秒以内で完了しなければ部分実行、次回継続
- **schema.md と code constants の inconsistency**: production は code を信頼、debug log で warn
- **embedding similarity 計算に必要な essence が空**: skip (該当 ConceptPage は merge 対象外)
- **同一 ConceptPage に複数の merge 候補**: updatedAt 最新を winner、残りを順次 merge
- **isFollowing=true な ConceptPage の重複検出**: merge 実行、winner 側に isFollowing=true 引き継ぎ
- **auto-link で関連 0 件 (適切な候補なし)**: skip、孤立のまま (削除候補に回す)
- **Tag 再分類で AI 判定不能 (categoryRaw="その他")**: 既存値維持 (上書きしない)
- **ConflictProposal の旧 Article が削除済**: DisclosureGroup 自動非表示 (relationship nullify)
- **SavedAnswer auto-refresh で agent loop が `.askClarification` 返す**: skip (question 情報不足、ユーザー手動で再実行依頼)
- **schema.md 編集中に起動**: file lock 不要 (Foundation File API は atomic read)
- **NSCloudKitMirroringDelegate が schema.md を sync しようとする**: docs/ は App Bundle 内、CloudKit 対象外 (安全)

## Requirements *(mandatory)*

### Functional Requirements

**Confirm UX 廃止 (P1)**

- **FR-001**: System MUST auto-resolve ConflictProposal as `autoResolved` (両方残す) status without user confirmation
- **FR-002**: System MUST display new article information as primary in ArticleDetailView
- **FR-003**: System MUST display old conflict article in ArticleDetailView trailing DisclosureGroup「過去の見解 (N) ▼」
- **FR-004**: System MUST auto-refresh isStale=true SavedAnswer via agent loop in weekly BGTask
- **FR-005**: System MUST archive old SavedAnswer (isStale=true) when new SavedAnswer is generated, not delete
- **FR-006**: System MUST delete ActionItemsReviewView from KnowledgeClipView navigation destinations
- **FR-007**: System MUST delete GraphProposalsSection from CategoryDetailView
- **FR-008**: System MUST delete `⚠️ 更新が必要 (N)` badge from FollowingPeopleSection
- **FR-009**: System MUST auto-resolve Knowledge Graph proposals (`isUncertain=true` edges): high confidence (≥ 0.7) → 採用, low confidence → skip (remain `isUncertain`)
- **FR-010**: System MUST retain confirm alerts for: 記事削除 / Tag merge/delete / ConceptPage delete / iCloud toggle / AI チャット履歴全削除

**Lint Loop Core (P1)**

- **FR-011**: System MUST execute Lint loop 6 steps in weekly BGTask: merge → delete ConceptPage → delete Tag → link → reclassify → refresh
- **FR-012**: System MUST auto-merge ConceptPages where (editDistance ≤ 2 OR embeddingSim ≥ 0.85) is true, name case-insensitive
- **FR-013**: System MUST select merge winner as the ConceptPage with most recent updatedAt
- **FR-014**: System MUST union relatedArticles / relatedConceptIDs / nameAliases on merge
- **FR-015**: System MUST inherit isFollowing=true to winner on merge if either source is followed
- **FR-016**: System MUST auto-delete ConceptPage where relatedArticles.count ≤ 1 AND updatedAt < (now - 60 days) AND isFollowing=false
- **FR-017**: System MUST auto-delete Tag where Tag.articles.count == 0
- **FR-018**: System MUST auto-link ConceptPage: when relatedConceptIDs.count ≤ 1, add top N (max 5) by embedding similarity within same categoryRaw
- **FR-019**: System MUST re-classify Tag.categoryRaw via AutoCategoryClassifier in weekly Lint loop, update if differs from current
- **FR-020**: System MUST NOT change Tag.categoryRaw to "その他" if already non-"その他" (avoid degradation)

**Health Score (P2)**

- **FR-021**: System MUST compute healthScore = orphanedConceptPageCount + pendingConflictProposalCount
- **FR-022**: System MUST display healthScore in Settings as `健全性スコア (N 件の整理対象)` with target = 0
- **FR-023**: System MUST update healthScore on every Lint loop execution + Settings tab visit
- **FR-024**: System MUST support future score extension (coverage rate / 分かりません率) via protocol-based metric registry

**LintLog & Transparency (P2)**

- **FR-025**: System MUST persist all Lint operations in LintLog @Model: timestamp, action (merge/delete/link/reclassify/refresh), target name, before/after state (max 200 chars)
- **FR-026**: System MUST display latest 30 LintLog entries in Settings 「整理ログ」 section, sorted by timestamp desc
- **FR-027**: System MUST display weekly summary at Settings top: `今週: 12 件 merge / 3 件 delete / 5 件 link`
- **FR-028**: System MUST cap LintLog to 100 entries total, FIFO delete oldest on overflow

**Manual Trigger (P2)**

- **FR-029**: System MUST provide 「今すぐ整理する」button in Settings
- **FR-030**: System MUST execute Lint loop immediately on button tap, show progress indicator, display completion summary
- **FR-031**: System MUST debounce manual trigger: ignore taps within 60 seconds of last completion (avoid abuse)

**BGTask Schedule (P1)**

- **FR-032**: System MUST register `app.KnowledgeTree.weeklyLint` in Info.plist `BGTaskSchedulerPermittedIdentifiers`
- **FR-033**: System MUST schedule weekly Lint BGTask for Sunday 3 AM (local time)
- **FR-034**: System MUST handle BGTask `expirationHandler` gracefully: stop in-progress step, schedule next week
- **FR-035**: System MUST resume from last completed step on next run (no full restart if interrupted)

**Schema 外出し (P3)**

- **FR-036**: System MUST load `docs/iknow-schema.md` at app launch via SchemaLoader (Foundation file API)
- **FR-037**: System MUST cache loaded schema in memory for the app lifetime
- **FR-038**: System MUST fallback to code-internal constants if schema.md is missing or parse fails
- **FR-039**: System MUST NOT crash if schema.md has syntax errors, log warning instead
- **FR-040**: System MUST support hot reload (`#if DEBUG`) for development: detect schema.md mtime change, reload cache

**「過去の見解」DisclosureGroup (P1)**

- **FR-041**: System MUST display 「過去の見解 (N) ▼」 DisclosureGroup at ArticleDetailView body bottom when N >= 1
- **FR-042**: System MUST list old conflict Articles inside DisclosureGroup with essence + 「{N} 日前」 relative timestamp
- **FR-043**: System MUST hide DisclosureGroup entirely when N == 0 (no past view)
- **FR-044**: System MUST handle Article cascade nullify gracefully (deleted old Article skip-render)

### Key Entities

- **LintLog** (@Model): 操作履歴 永続化、フィールド: id (UUID) / timestamp / actionRaw (String: merge/delete/link/reclassify/refresh) / targetName (String) / beforeState (String?) / afterState (String?)、`@Attribute(.preserveValueOnDeletion)` で参照保護なし (純記録)
- **LintLoopResult** (transient struct): 1 回の Lint loop 実行結果、merge/delete/link/reclassify/refresh の各 step 件数 + 所要時間
- **HealthScore** (transient struct): 現状スコア + 将来拡張用 metric registry (orphanedCount / conflictCount / coverageRate / unknownRate)
- **MergeCandidate** (transient struct): merge 判定対象 2 ページ + 判定理由 (editDistance / embeddingSim) + winner / loser
- **LintAction** (enum): `.merge / .deleteConceptPage / .deleteTag / .linkConceptPage / .reclassifyTag / .refreshSavedAnswer`
- **LoadedSchema** (transient struct): SchemaLoader が cache する schema 内容、section ごとに String 保持 (AgentAction prompt / Conflict rule / Lint criteria 等)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: ConflictProposal 検出時に confirm UI が表示されない (100% 自動 resolve)
- **SC-002**: ActionItemsReviewView / GraphProposalsSection / ⚠️ badge が UI から完全消失 (grep でコードベース内のみ存在、view 階層には出ない)
- **SC-003**: isStale SavedAnswer が週 1 BGTask 内で 80% 以上 auto-refresh される (10 sample で 8+ 件成功)
- **SC-004**: 重複 ConceptPage (編集距離 ≤ 2 のペア) を 90% 以上 auto-merge (10 ペア sample test)
- **SC-005**: 関連記事 1 件 + 60 日参照ゼロな ConceptPage が 95% 以上 auto-delete (20 sample で 19+ 件)
- **SC-006**: 孤立 Tag が 100% auto-delete (Tag.articles=空、deterministic)
- **SC-007**: 孤立 ConceptPage に AI が 80% 以上 relatedConceptIDs 追加 (10 sample で 8+ 件)
- **SC-008**: Tag/Category 再分類率 ≤ 5% (95% は既存値維持、idempotent 確認)
- **SC-009**: 週 1 BGTask が定刻 ±30 分以内に発火、6 ステップ全実行所要時間 < 30 秒 (1000 article 規模)
- **SC-010**: Settings 健全性スコア = 孤立 + 矛盾 の合算で表示、Lint loop 後に減少することを観測 (BEFORE/AFTER 差分テスト)
- **SC-011**: Settings 整理ログ 30 件表示、日時 desc ソート、tap で詳細表示 (UI test)
- **SC-012**: 「今すぐ整理」button tap → Lint loop 完了まで < 10 秒、完了後 toast 表示
- **SC-013**: docs/iknow-schema.md が存在しても production fallback 動作 (code constants が優先 or 同等動作)
- **SC-014**: 危険操作 confirm 5 種 (記事削除 / Tag merge/delete / ConceptPage delete / iCloud toggle / Chat 履歴削除) が全て confirm alert 表示
- **SC-015**: ArticleDetailView 過去の見解 DisclosureGroup 動作 (N >= 1 で表示、N == 0 で非表示)
- **SC-016**: LintLog の FIFO 動作 (101 件目で最古を delete、100 件維持)
- **SC-017**: 既存 unit test suite 全 PASS (regression なし、新規 + 既存合算)
- **SC-018**: V3.0 release で「自動化された / 確認 UI 消えた」とユーザーフィードバック 80% 以上 (定性、release 後 2 週間)

## Assumptions

- **対象ユーザー**: 「AI 任せ」哲学に賛同する既存ユーザー + 新規ユーザー。「自分で判断したい」power user 向けには「今すぐ整理」manual trigger で代替
- **iOS バージョン**: iOS 26+、BGTaskScheduler 標準動作前提
- **Lint loop 実行時間**: 1000 article 規模で 30 秒以内、それ以上で部分実行 (Apple Background Time Limit 30s 想定、現実は無制限ではないが BGTaskScheduler の expirationHandler で graceful stop)
- **BGTask 発火タイミング**: iOS 任意 (Apple は exact time 保証しない)、日曜 3 AM ± 数時間以内が期待値
- **schema.md format**: Markdown (人間可読)、最低限の syntax (h2 section、code block)、validation は緩い
- **schema.md production deployment**: App Bundle に含める (Xcode の Build Phases で `Copy Bundle Resources` に追加)、CloudKit / 動的 download はしない
- **embedding similarity threshold 0.85**: NLEmbedding cosine、経験則、後で調整可能 (SchemaLoader 経由で外出し)
- **編集距離 2 の意味**: Levenshtein、case insensitive、空白も 1 char として cnt (「OpenAI」「Open AI」は distance 1)
- **60 日無参照 ConceptPage**: updatedAt 基準、user が isFollowing=true にしてれば protected
- **auto-link max 5 件**: relatedConceptIDs の限界、これ以上はノイズ
- **健全性スコアの単位**: 整数件数、後で重み付き合算に拡張可能
- **LintLog 100 件 cap**: 100 件超過時 FIFO delete、運用上 30 件表示で十分
- **「過去の見解」 DisclosureGroup**: ConflictProposal.oldArticle 経由で表示、複数 conflict あれば全部 list
- **危険操作 confirm の判定**: 「データロス」「不可逆」「課金影響」「セキュリティ」のいずれかなら confirm 維持
- **manual trigger debounce 60 秒**: 「今すぐ整理」連打防止、API 呼びすぎ回避
- **release 戦略**: spec 056 + spec 057 + spec 058 を `056-uiux-redesign-v3` 同 branch で開発、PR #17 を update、1 PR で V3.0 一括 release
- **依存 spec の影響**: spec 037/041/042/045/046 で実装した UI 群は削除 or hidden、機能は本 spec の Lint loop に統合
- **テスト戦略**: LintEngine は 6 step 個別に test、各 step は idempotent (2 回実行で同結果)、Mock LM + in-memory ModelContainer + Date 注入
- **Apple HIG 準拠**: 「destructive action は confirm」原則維持、「無意味な確認」のみ廃止、Apple Photos の「整理は裏で勝手にやる」UX に倣う
- **Privacy 維持**: Lint loop は完全 on-device、外部 API 呼び出しなし、SchemaLoader も local docs/ のみ参照
- **CloudKit 影響**: LintLog @Model は new schema → CloudKit Production schema deploy 必要 (V3.0 release タイミングで実施)、ConflictProposal.status enum 拡張 (`autoResolved` case 追加) は CloudKit lightweight migration 対応
- **言語**: 日本語 first 維持、Lint log の文言も日本語、英語 / 多言語化は範囲外
