# Research: Wiki ページ相互リンク + 関係発見

行番号は 2026-05-31 064 ブランチ時点 (spec 063 マージ後)。

## R1: embedding で relatedConceptIDs を補完 (Phase 1)

**Decision**: `resynthesize` (ConceptSynthesisService.swift) の embedding 再生成直後 (:235 後)、generateBodyMarkdown (:238) の前に、embedding 近傍で relatedConceptIDs を埋める。

```
// embedding 再生成 (:230-235) の後
let neighborIDs = nearestConceptIDs(for: conceptPage, in: context)  // top-8, threshold 0.5
conceptPage.relatedConceptIDs = Array(Set(conceptPage.relatedConceptIDs + neighborIDs))
```

**nearestConceptIDs (新 helper)**:
- conceptPage.embedding (Data?) → `.asFloatArray`。nil なら空配列で return (AI 不可端末 / 未生成、FR-008)。
- 全 ConceptPage fetch (isHidden 除外、self 除外、embedding あり) → `(id, embedding.asFloatArray)`。
- `EmbeddingService.cosineSimilarity(target, each)` で類似度、threshold 0.5 以上、降順 top-8 の id。
- 既存 relatedConceptIDs (LintEngine/merge 由来) と Set union で保全。

**Rationale**: AI 呼び出しゼロ (NLEmbedding はローカル)。FR-002 達成。resynthesize は resynthesizeAllStale で最大 5 件/起動なので 5×N dotpr = 数 ms、@MainActor で十分 (Task.detached 不要、SwiftData は MainActor 必須)。

**変換 API**: `Data.asFloatArray` / `[Float].asEmbeddingData` (EmbeddingService.swift 既存)。

## R2: AI 本文リンク (Phase 2)

**Decision**: `buildWikiBodyPrompt` に `linkCandidates: [(name: String, id: UUID)]` 引数を default 付きで追加 (既存 WikiBodyGenerationTests 後方互換)。候補は Phase 1 で計算した relatedConceptIDs を再利用 (二重計算回避) → 各ページ名 + ID を解決。

prompt に候補リスト (`- 名前 → concept-id://UUID`、name 30 字 truncate、最大 8 件 ≈ 400 字) + schema.md の「Wiki リンクルール」を embed。指示: 「本文に候補ページ名が出たら `[名前](concept-id://UUID)` リンクにせよ。候補に無い名前にリンクするな。UUID はコピーし創作するな。」

**Rationale**: 本文生成は既存 generateWikiBody 1 回のまま (FR-007)。候補は name+ID で軽く token 圧迫しない。plain string 出力で schema コストゼロ。

## R3: 捏造 UUID 検証 (Phase 2)

**Decision**: `sanitizeConceptLinks(in markdown: String, validIDs: Set<UUID>) -> String` 純関数。generateBodyMarkdown の trimmed 直後に適用。

regex `\[([^\]]+)\]\(concept-id://(UUID)\)` で全 concept link 抽出。UUID が validIDs (= 候補 ID 集合) に無ければ `[名前](concept-id://...)` → `名前` にプレーン化。validIDs は linkCandidates の ID 集合。

**Rationale**: ID 直書き + sanitize の二重防御で dead link 原理的にゼロ (FR-006)。同名ページ (category 違い) も ID で一意 → 誤リンクなし。

## R4: 表示遷移 (Phase 2、spec 033 流用)

**Decision**: ConceptPageDetailView の wikiBodySection の Text に `.environment(\.openURL, OpenURLAction { ... })` を attach。`extractConceptID(from:)` (extractArticleID のコピペ、scheme="concept-id") で UUID 復元 → `onConceptLinkTap?(ConceptPageDetailDestination(id:))` callback。

callback は ChatMessageRow の onArticleLinkTap パターン踏襲。DetailView を push する親 (KnowledgeClipView の ConceptPageDetailLoader 等) で受けて navigation。リンク先消失は ConceptPageDetailLoader の reactive guard で auto-dismiss (FR-009)。

**最小配線**: ConceptPageDetailView 自身が同 destination の navigationDestination を親に持つ。callback で `navigationPath.append` する経路を ConceptPageDetailLoader 周辺に通す。

## R5: テスト

**Decision**: `ConceptLinkingTests` 新規:
- nearestConceptIDs: self 除外 / threshold 未満除外 / top-k / embedding なし空 / isHidden 除外
- sanitizeConceptLinks: 有効保持 / 無効プレーン化 / 混在 / リンクなし
- extractConceptID: concept-id:// 解析 / scheme 不一致 nil

既存 WikiBodyGenerationTests に linkCandidates default 後方互換確認。

検証コマンド: `xcodebuild clean build` + `xcodebuild test -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO`。
