# Feature Specification: AI 処理削減 (軽さ優先)

**Feature Branch**: `064-wiki-links-discovery` (spec 064 と同ブランチで継続)
**Created**: 2026-05-31
**Status**: Draft
**Input**: VISION v2「軽さ優先」+ Plan エージェント設計 (記事保存あたり AI 呼び出し ~20 → 2-3 を目標)

## 背景

VISION v2 (LLM Wiki) の核心問題は「重い」。診断で **1 記事保存あたり AI を最大 ~20 回**呼んでいた (知識抽出 + 矛盾検出最大 10 + グラフ抽出 + カテゴリ分類最大 5 + 概念合成 + …)。VISION の軽さ目標は「記事保存で AI 2-3 回」。

spec 064 で関係発見が WikiPage (relatedConceptIDs + 本文リンク) に移ったため、**GraphNode の関係発見役は不要**になった。これを機に、ユーザーにほぼ見えていない裏の AI 生成を止めて「重い」を解消する。

**重要な原則**: @Model は一切削除しない (CloudKit 破壊リスク回避)。**生成を止めるだけ**。既存データは残り、新規生成が増えないだけ。@Model の退役は spec 066。

**1 文の本質**: 「ユーザーにほぼ見えない裏の AI 生成 (矛盾検出 10 回 / グラフ抽出 / トピック / 起動ダイジェスト) を止めて、記事保存と起動を軽くする」

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 記事保存が軽くなる (Priority: P1)

ユーザーが記事を保存したとき、裏で走る AI 処理が大幅に減り、保存後の整理が速く完了する。これまで 1 記事で最大 ~20 回の AI 呼び出しがあったが、不要な処理を止めて数回に減らす。

**Why this priority**: 「重い」の最大原因が記事保存時の AI 呼び出し過多。これを減らすのが軽量化の本丸。

**Independent Test**: 記事を保存し、AI 呼び出し回数 (ログ) が従来より大幅に減っていることを確認。保存後の処理完了が速い。

**Acceptance Scenarios**:

1. **Given** 記事保存, **When** 矛盾検出が走る, **Then** AI 呼び出しは最大 1 回 (旧最大 10 回)
2. **Given** 記事保存, **When** 取り込み完了, **Then** グラフ抽出の AI 呼び出しが発生しない
3. **Given** 既存の知識 (要約・概念ページ・関連リンク), **When** 保存処理が軽くなった後, **Then** 既存機能は壊れず動く

---

### User Story 2 - 起動が軽くなる (Priority: P1)

アプリ起動時に裏で走る一括処理 (ダイジェスト再生成・トピック分析) を止め、起動時の負荷を減らす。ダイジェストは必要なときに (画面を開いたとき・引っ張って更新) 生成する。

**Why this priority**: 起動時の一括 AI 処理が起動を重くしている。表示 UI の無い処理 (トピック) は特に無駄。

**Independent Test**: アプリを起動し、起動時のトピック分析・ダイジェスト一括生成が走らないことを確認。ダイジェストは画面表示時に出る。

**Acceptance Scenarios**:

1. **Given** アプリ起動, **When** 起動 backfill が走る, **Then** UserTopic クラスタリングが実行されない
2. **Given** アプリ起動, **When** 起動 backfill が走る, **Then** ダイジェストの一括再生成が実行されない
3. **Given** Category 詳細画面を開く, **When** ダイジェストが無い, **Then** その場で生成される (オンデマンドは維持)

---

### Edge Cases

- **既存 GraphNode**: 新規生成は止まるが、既存ノードは残り、AI チャットの関連エンティティや Digest で引き続き使われる (痩せるだけ、crash なし)。
- **矛盾検出の責務**: 記事保存時の即時検出は最小化されるが、週次 Lint で点検は継続 (VISION「Lint で整える」と一致)。
- **ダイジェスト初回**: 新規インストール直後は空になり得るが、画面表示・pull-to-refresh で生成される。
- **ロールバック**: すべて「生成を止める」だけなので、品質劣化が判明したら設定を戻すだけで復旧できる。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 記事保存時の矛盾検出は、AI 呼び出しを最大 1 回までに削減しなければならない。
- **FR-002**: 記事保存時のグラフ (エンティティ関係) 抽出の AI 呼び出しを停止しなければならない。
- **FR-003**: アプリ起動時の UserTopic クラスタリングを停止しなければならない。
- **FR-004**: アプリ起動時のダイジェスト一括再生成を停止しなければならない。
- **FR-005**: ダイジェストのオンデマンド生成 (画面表示・pull-to-refresh) は維持しなければならない。
- **FR-006**: 永続化スキーマ (@Model) を削除・変更してはならない (生成停止のみ、退役は別 spec)。
- **FR-007**: 停止した処理に依存する既存機能 (AI チャット・ダイジェスト表示) は、既存データでクラッシュせず動かなければならない。
- **FR-008**: 既存のテストは全て回帰 PASS しなければならない。

### Key Entities

- **ConflictProposal / GraphNode / GraphEdge / UserTopic / KnowledgeDigest** (既存 @Model): いずれも**削除しない**。新規生成の頻度/有無のみ変更。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 記事保存時の矛盾検出 AI 呼び出しが最大 1 回 (旧 10 回)。
- **SC-002**: 記事保存時にグラフ抽出の AI 呼び出しが発生しない。
- **SC-003**: 起動時に UserTopic クラスタリング / ダイジェスト一括生成が走らない。
- **SC-004**: Category 詳細でダイジェストがオンデマンド生成される。
- **SC-005**: AI チャット・ダイジェスト表示が既存 GraphNode で破綻しない。
- **SC-006**: クリーンビルド成功 + 全 unit test 回帰 PASS。

## Assumptions

- 停止手段は、bootstrap での依存注入を外す (graph 抽出 hook を nil で no-op 化) + 起動 backfill から該当処理を除外する、の最小変更で行う。hook コード・サービスクラス・@Model は残す。
- 矛盾検出は「完全停止」ではなく「最大 1 回に削減」(ユーザー選択)。週次 Lint の矛盾点検は別途継続。
- グラフ抽出停止後も、AI チャット RAG と Digest は既存 GraphNode を参照して動く (optional 設計で nil 安全)。
- カテゴリ分類 (最大 5 回) は本 spec では止めない (Tag.categoryRaw 依存 UI が広いため、次段階判断)。

## Dependencies

- **spec 064** (関係発見の WikiPage 移行) — グラフ抽出を止める前提。
- **spec 037/058** (ConflictProposal / auto-resolve) — 矛盾検出の既存挙動。
- **spec 040/041** (GraphNode / Graph UI) — 既存ノードは残す。

## Out of Scope

- @Model の SharedSchema からの削除 / 関連 View・Service の物理削除 (spec 066)。
- カテゴリ分類の頻度削減 (次段階判断)。
- News+ フィード (spec 066) — ダイジェストの役割継承先。
- 知識抽出本体 (KnowledgeExtractor) の token 削減 (spec 062、別途)。
