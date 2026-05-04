# Specification Quality Checklist: 知識抽出 + 要約

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-04 (revised — 「ただの要約」→「knowledge 抽出」→ 最終的に **両方** を 1 セッションで生成する統合 spec として再々設計)
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- **再々設計版**: 旧 draft「ただの要約」→ 中間 draft「knowledge 抽出のみ」→ **最終: 4 出力 (essence + summary + key facts + entities) を 1 セッションで生成する統合 spec**。要約と構造化抽出の両方をユーザーは欲しい (要約 = 人間が読む / 構造化抽出 = アプリが処理する) ため、`@Generable struct` に 4 つのフィールドを並べて 1 回の Foundation Models 生成で全部得る方式に統一。電力・時間効率も最適。
- **3 つの新規エンティティ** (`ExtractedKnowledge`、`KeyFact`、`KnowledgeEntity`) を導入。`ExtractedKnowledge` が essence と summary を直接持ち、子に `KeyFact` と `KnowledgeEntity` を持つ階層構造。すべて Article への non-optional 参照で Principle III を構造レベルで遵守。
- **将来 spec の基礎データ層**: cross-article entity 集約 (spec 005)、knowledge graph、AI チャット (RAG)、カテゴリ自動学習、検索 — すべて本 spec のデータに依存。
- **新規ネットワーク非依存**: Foundation Models on-device 実行のため Constitution Principle I の Network Access Justification は不要。spec 002 の justification はそのまま継続有効。
- **ハルシネーション抑止**: 主に 3 層で対応 — (1) `@Generable` の Guide で field 単位制約、(2) prompt 末尾で「推測・補完禁止 + essence と summary と key facts は互いに矛盾しない」(FR-020)、(3) 「AI 生成」ラベル + Reader View で本文と並べて見比べる動線。自動検証は MVP 外 (SC-009 で sampling 計測のみ)。
- **部分成功 `.partiallySucceeded`** を導入: 4 出力のうち 1 つ以上取れた中間状態を扱う。完全失敗より価値があるため UI 表示する (空サブセクションは隠す)。
- **Apple Intelligence 不可能時 (US3)** は Principle IV と V の両方が要求する graceful degradation。spec 001-003 の機能を一切壊さない。
- 用語ポリシー: ユーザー視点の機能名 (Apple Intelligence、知識サマリ、Reader View) は記述、フレームワーク識別子 (`SystemLanguageModel`、`LanguageModelSession`、`@Generable`、`@Guide` 等) は plan.md / tasks.md で扱う。
- **ディレクトリ名 `004-summarize` と spec 内容 (knowledge 抽出 + 要約) の不一致**: 後で `git mv` で `004-extract-knowledge` 等にリネーム可能。本 commit では directory name は据え置き、spec.md / branch_name (spec 内記載) のみ更新。
- **Out of Scope**: knowledge graph、AI チャット、ハルシネーション自動検証、本文ハイライト、設定画面、多言語、widget、export 等。MVP を 1 記事ごとの抽出 + 表示に厳格に絞り、後続 spec に拡張余地を残す。
