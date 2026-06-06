# Feature Specification: token 実測基盤 (TokenBudgetProbe)

**Feature Branch**: `071-token-probe`
**Created**: 2026-06-06
**Status**: 実装完了 (実機検証残)
**Input**: コア品質ブラッシュアップ 第1段階。2 エージェント監査 + Plan 設計より。

## 背景

KnowledgeTree の AI 知識生成 (essence/summary/keyFacts/entities/ConceptPage) は、Foundation Models の 4096 token 制限を逃れるため入力を極端に truncate している (記事本文 400 字 / per-article essence 80 字 / KeyFact 30 字…)。これらの数値は spec 042/051/060/062 を通じて「勘 + 実機 overflow ログ」で 1000→600→400 と削られてきた。schema コスト「~1500 token」も未検証の推定値。

**新発見 (SDK swiftinterface で確認、iOS 26.5 SDK arm64e-apple-ios.swiftinterface)**:
- `SystemLanguageModel.tokenCount(for: some PromptRepresentable) async throws -> Int`
- `tokenCount(for: GenerationSchema)` / `(for: Instructions)` / `(for: [any Tool])` / `(for: some Collection<Transcript.Entry>)` — **@Generable schema の実 token も測れる**
- `SystemLanguageModel.contextSize: Int` (計算プロパティ) — context window 上限を実値取得

全て async throws。deployment target 26.4 ゆえ `@available` 分岐不要。

本 spec は **token を実測する診断基盤**を作る。生成経路は無改修・token リスクゼロ。これが後続段階 (入力 truncate 緩和 = spec 073) の意思決定根拠になる。特に `tokenCount(for: GenerationSchema)` で schema 実 token を確定できるのが価値。

**1 文の本質**: 「現状の prompt / schema が実際に何 token 消費しているかを実機ログで可視化し、勘の truncate から実測ベースの調整へ移行する土台を作る」

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 開発者が実 token を把握できる (Priority: P1)

開発者がデバッグビルドで起動すると、代表的な prompt (知識抽出 / カテゴリ分類 / Wiki 本文) と @Generable schema 3 種の実 token + contextSize + 残余 budget が Xcode コンソールに出る。「本文 400 字 = 何 token か」「schema が何 token か」が数字で分かる。

**Independent Test**: デバッグ起動でコンソールに `TokenBudgetProbe:` ログが token 数付きで出ることを確認。

**Acceptance Scenarios**:
1. **Given** AI 利用可能端末, **When** デバッグ起動, **Then** 代表 prompt + schema の実 token がログ出力
2. **Given** AI 不可端末, **When** 起動, **Then** probe スキップ・クラッシュなし
3. **Given** Release ビルド, **When** 起動, **Then** probe は走らない

### Edge Cases
- AI 不可端末: `availability` guard でスキップ。
- probe のコスト: 所要時間もログ → 重ければ常設しない判断材料。
- 生成経路への影響: probe は `respond` を呼ばない、副作用ゼロ。

## Requirements *(mandatory)*

- **FR-001**: `tokenCount(for:)` で prompt の実 token を測る wrapper を提供する。
- **FR-002**: 代表 prompt + @Generable schema の実 token をログ出力する。
- **FR-003**: probe は生成 (`respond`) を呼ばない (AI 呼び出し増やさない)。
- **FR-004**: AI 不可端末でスキップ・クラッシュしない。
- **FR-005**: デバッグビルド限定 (`#if DEBUG`)、本番動作に影響しない。
- **FR-006**: @Model を変更しない。

### Key Entities
- **TokenBudgetProbe** (enum、新規): `SystemLanguageModel.default.tokenCount(for:)` を `try await` で呼び、代表 prompt + schema の token + contextSize をログ化。

## Success Criteria *(mandatory)*

- **SC-001**: デバッグ起動で代表 prompt + schema の実 token がコンソールに出る。
- **SC-002**: probe で `respond` が呼ばれない。
- **SC-003**: AI 不可端末でクラッシュしない。
- **SC-004**: クリーンビルド成功 + 全 unit test 回帰 PASS。

## Assumptions
- `tokenCount(for:)` は async throws。`contextSize` も実在 (上限を実値取得)。
- probe は `KnowledgeTreeApp.bootstrap` の `#if DEBUG` で `await runDiagnostics()` (async ゆえ init でなく bootstrap)。
- 代表 prompt は KnowledgeExtractor.buildPrompt 等 + 自前組み立て。schema は `@Generable.generationSchema`。

## Dependencies
- Foundation Models (iOS 26.4)、KnowledgeExtractor.buildPrompt、CategorySeed、各 @Generable Output。

## Out of Scope
- 入力 truncate の実際の引き上げ (spec 073)。
- 生成前 token ガード (適応 truncate) の常設 (probe の実測を見てから判断)。
- @Model 変更。
