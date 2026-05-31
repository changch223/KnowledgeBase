# Implementation Plan: Wiki ページ相互リンク + 関係発見

**Branch**: `064-wiki-links-discovery` | **Date**: 2026-05-31 | **Spec**: [spec.md](./spec.md)

## Summary

WikiPage (ConceptPage) 間の関係を作る。**Phase 1**: embedding cosine 類似で `relatedConceptIDs` を自動補完 (AI 呼び出しゼロ、純数値演算)。**Phase 2**: bodyMarkdown 生成時に関連候補を AI に渡し本文に `[名](concept-id://UUID)` リンクを書かせ、表示時に spec 033 機構で tap 遷移。捏造 UUID は sanitize で除去。@Model 変更ゼロ (relatedConceptIDs / embedding 既存) = CloudKit 安全。

## Technical Context

**Language**: Swift 6 / SwiftUI (iOS 26) / SwiftData / Foundation Models
**Storage**: SwiftData + CloudKit、@Model 変更なし (lightweight migration 不要)
**Testing**: Swift Testing。純関数 (nearestConceptIDs / sanitizeConceptLinks / extractConceptID) でテスト容易
**Constraints**: AI 呼び出しを増やさない (embedding はローカル数値、本文リンクは既存 prompt 拡張)。token 超過しない
**Scale**: 改修 ~4 + 新規テスト 1 = ~300-400 行

## Constitution Check
- I privacy: on-device、embedding ローカル ✅ / II 引き算: 関係を WikiPage に集約 (GraphNode 退役の前提) ✅ / III source: relatedArticles 不変 ✅ / IV iOS: NLEmbedding + AttributedString + OpenURLAction 標準 ✅ / V calm: AI 呼び出し増やさない ✅ / VI: @Model 変更ゼロ、純関数 ✅ / VII 日本語 ✅

## Phase 0: Research (research.md)
- R1 (embedding 補完): resynthesize の embedding 再生成直後に `nearestConceptIDs` で全 ConceptPage と cosine top-k → relatedConceptIDs に union 設定。@MainActor で十分 (5 page × N dotpr = 数 ms)。
- R2 (AI 本文リンク): buildWikiBodyPrompt に linkCandidates 引数追加 (embedding 近傍 8 件、name+ID)。schema.md にリンク記法ルール追記。
- R3 (捏造検証): generateBodyMarkdown で `sanitizeConceptLinks(in:validIDs:)` post-process、候補外 UUID をプレーン化。
- R4 (表示遷移): ConceptPageDetailView wikiBodySection に OpenURLAction + extractConceptID (spec 033 流用)。
- R5 (テスト): nearestConceptIDs / sanitizeConceptLinks / extractConceptID の純関数テスト。

## Phase 1: Design & Contracts
- data-model.md: @Model 変更ゼロ。relatedConceptIDs / embedding 既存利用。
- contracts/: relationship-discovery.md (embedding) / wiki-links.md (AI リンク + 表示)
- quickstart.md: SC-001〜007

## 検証 (このセッション)
- clean build + 全 unit test serial regression
- 実機 (関連表示 / 本文リンク tap / 既存破綻なし) はユーザー後追い
