# Implementation Plan: 長文記事の Chunked Summarization

**Branch**: `006-chunked-summarize` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-chunked-summarize/spec.md`

## Summary

本文 (ArticleBody.extractedText) が 1000 文字を超える場合、1000 文字単位 (句点 graceful split) の chunk に分割し、各 chunk を Foundation Models (`LanguageModelSession`) で逐次処理して essence / keyFacts / entities を取得。最終 chunk として全 chunk の essence を入力に meta-summary を生成し、それを ExtractedKnowledge.essence + summary に保存する。keyFacts と entities は全 chunk から重複排除して統合。1000 文字以下の本文は spec 004 で実装済の単発生成パスをそのまま使う。chunked 処理中は BottomStatusBar に「N/M」進捗を表示し、partial success 時は得られた情報のみ `.partiallySucceeded` で保存。

技術アプローチ: 既存 `KnowledgeExtractor` (純粋ラッパ) と `DefaultKnowledgeExtractionService` (orchestration) の境界を維持しつつ、新規 `ChunkSplitter` (分割アルゴリズム純粋関数) と `ChunkedKnowledgeAggregator` (重複排除統合) を導入。Service 側に chunked パスの分岐を追加し、ProcessingMonitor の API を「N/M 進捗」を持てるよう拡張。

## Technical Context

**Language/Version**: Swift 6.x (Xcode 16+, iOS 26+)
**Primary Dependencies**: SwiftUI, SwiftData, FoundationModels (Apple)
**Storage**: SwiftData (`@Model`, `ModelContainer`、App Group group container)
**Testing**: Swift Testing (`#expect`) + XCTest UI testing
**Target Platform**: iOS 26+ / iPadOS 26+ (Apple Intelligence 対応端末のみ)
**Project Type**: mobile-app (single iOS app + Share Extension)
**Performance Goals**: 5000 文字記事で総処理時間 ≤ 3 分 (5 chunk + meta-summary、各 25 秒前後)。chunk 進捗 UI は完了から 0.5 秒以内に反映
**Constraints**:
- Foundation Models on-device context window 4096 token (実測 1000 char 日本語 ≒ 1700 token、prompt overhead ~500 token = 安全)
- メインスレッドブロック禁止 (chunk 生成は async)
- Apple Intelligence availability チェック必須 (Constitution Principle IV)
- ハルシネーション抑止 prompt 制約は per-chunk + meta-summary 両方に適用 (Principle III)
**Scale/Scope**: 1 記事あたり最大 10 chunk + 1 meta-summary = 最大 11 回の LM 呼び出し。1 ユーザーあたり数百記事想定 (一括 backfill 時の serialize は spec 005 の重複抑止ガードで制御済)

## Constitution Check

Reference: `.specify/memory/constitution.md` (v1.0.0)

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — 全 chunk 処理はオンデバイス Foundation Models で完結。本文・essence・keyFacts・entities は SwiftData にローカル保存。外部送信無し。
- [x] **II. MVP ファースト開発** — chunk 数上限 10 / 並列処理せず逐次 / 階層的要約 (chunk → 中間 → 最終) は未実装と明示。RAG・チャット・タグ自動生成等の高度機能は将来 spec として spec.md Assumptions に分離。
- [x] **III. ソースに基づいた知識生成** — chunk から生成された keyFact / entity も最終的に ExtractedKnowledge → Article への非 optional 参照を保持 (spec 004 既存スキーマを継承)。各 chunk の prompt にもハルシネーション抑止 instructions (元記事に明示されている内容のみ等) を含める。
- [x] **IV. iOS の実現可能性を重視する** — `SystemLanguageModel.availability` チェックを継承 (spec 005 既存)。chunk 1 の段階で `.unavailable` を検出したら全体を `.skipped` 保存。Share Sheet 起動経路は変更無し。macOS 対象外。
- [x] **V. シンプルで落ち着いた UX** — BottomStatusBar に「N/M」表示を追加するだけ。Detail 画面の追加 UI 変更は注記 (10000 文字超の冒頭のみ要約) のみ。プッシュ通知 / バッジ等の不安喚起 UI は導入しない。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — 新規 `ChunkSplitter` (純粋関数) と `ChunkedKnowledgeAggregator` (重複排除) を Service 層から分離。Foundation Models 呼び出しは既存 `LanguageModelSessionProtocol` を 1 回ずつ使うだけで境界変更無し。chunked パスと単発パスは Service 内 if 分岐で切り替え可能。
- [x] **VII. 日本語ファースト** — spec.md / plan.md / per-chunk prompt / meta-summary prompt / BottomStatusBar 文言 / Localizable.xcstrings 文言 全て日本語。英語混在記事も対象だが純英語最適化は将来。

### Quality Gates (二次ゲート)

- [x] **コード品質** — `ChunkSplitter` / `ChunkedKnowledgeAggregator` は純粋関数 (state を持たない)。fatalError 使用無し。新規抽象化は 2 箇所以上の利用 (chunked パス + 将来 spec 008 検索での同等処理) 想定。
- [x] **テスト** — `ChunkSplitter` の境界テスト (1000 ちょうど / 1001 / 999 / 句点無し連続文字列等)、`ChunkedKnowledgeAggregator` の重複排除テスト、Service の chunked パス integration test (Mock LanguageModelSession で 5 chunk + meta-summary シナリオ)、partial success の Mock テスト。SwiftData は in-memory `ModelContainer`。
- [x] **アクセシビリティ・UX 一貫性** — BottomStatusBar の N/M 文言は `Localizable.xcstrings` 経由 (`status.phase.knowledgeWithProgress` 等の新キー)。`accessibilityIdentifier` は既存 `bottomStatusBar` を継承。Detail 画面の超長文注記も `LocalizedStringKey`。
- [x] **パフォーマンス** — chunk 処理は逐次なので 1 chunk 完了 → ProcessingMonitor 更新 → BottomStatusBar 即時反映 (0.5 秒以内)。100 件超リスト無し。escaping closure は既存 spec 005 の `[weak self]` パターン継承。

**結論**: Constitution Check 全項目 ✓ パス。Complexity Tracking への記載は不要 (新規抽象化は純粋関数 2 つで境界明確)。

## Project Structure

### Documentation (this feature)

```text
specs/006-chunked-summarize/
├── plan.md                       # This file
├── research.md                   # Phase 0 output (chunk 分割 / meta-summary / partial success の調査)
├── data-model.md                 # Phase 1 output (ExtractedKnowledge 列追加 / 内部 entities)
├── contracts/
│   ├── chunk-splitter.md         # 分割アルゴリズム契約
│   ├── chunked-aggregator.md     # 重複排除・meta-summary 統合契約
│   └── knowledge-extractor.md    # 既存 KnowledgeExtractor の chunked extension 契約
├── quickstart.md                 # Phase 1 output (実機検証手順)
├── checklists/
│   └── requirements.md           # spec 完成度 (✓ 全 pass、spec 段階で生成済)
└── tasks.md                      # Phase 2 output (`/speckit-tasks` で生成、本コマンドでは作成しない)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Models/
│   └── ExtractedKnowledge.swift              # 既存 + 列追加 (chunkProcessedCount / chunkTotalCount / skippedTailChars)
├── Services/
│   ├── KnowledgeExtractor.swift              # 既存 + extractChunked(...) 拡張 + meta-summary 生成
│   ├── KnowledgeExtractionService.swift      # 既存 + chunked パス分岐 + chunk 進捗 monitor 更新
│   ├── ChunkSplitter.swift                   # 新規 (純粋関数: text → [Chunk])
│   ├── ChunkedKnowledgeAggregator.swift      # 新規 (純粋関数: [ChunkResult] → 統合 essence/summary/keyFacts/entities)
│   ├── ProcessingMonitor.swift               # 既存 + ActiveTask に progressIndex / progressTotal フィールド追加
│   └── ArticleKnowledgeStore.swift           # 既存 + 新列の永続化対応
├── Views/
│   ├── BottomStatusBar.swift                 # 既存 + N/M 表示文言切り替え
│   └── ArticleDetailView.swift               # 既存 + 超長文注記 (skippedTailChars > 0 の場合)
└── Localization/
    └── Localizable.xcstrings                 # 新規キー追加 (status.phase.knowledgeProgress / detail.body.truncatedNotice)

KnowledgeTreeTests/
├── ChunkSplitterTests.swift                  # 新規
├── ChunkedKnowledgeAggregatorTests.swift     # 新規
└── KnowledgeExtractionServiceTests.swift     # 既存 + chunked 経路 case 追加
```

**Structure Decision**: 既存の Models / Services / Views / Localization 配置を踏襲。新規 `ChunkSplitter` / `ChunkedKnowledgeAggregator` は Services 配下の純粋関数群として独立ファイル化 (Constitution Principle VI: 層分離)。Foundation Models 呼び出しは既存 `KnowledgeExtractor` 内に閉じ込め、chunked 用の追加メソッドを生やすだけ (LanguageModelSessionProtocol 境界は変更しない)。

## 設計判断 (Phase 0 → Phase 1 への橋渡し)

### #1 chunk 数上限 10 / chunk サイズ 1000 文字は固定

ユーザー入力で明示。Foundation Models context window 4096 token に対し 1000 char × 1.7 token/char + prompt overhead で安全マージン確保。10 × 1000 = 10000 文字 = 平均的長文記事を全カバー。それ以上は冒頭優先で割り切り、`skippedTailChars` で UI 注記。

### #2 chunk 境界は句点 graceful split

1000 文字 hard cut では文の途中で切れて意味が壊れる。冒頭 1000 文字までで最後の `。` または `\n` を境界とする。両方無ければ 1000 文字 hard cut。`ChunkSplitter` 純粋関数で実装、テストで境界条件カバー。

### #3 chunk 処理は逐次 (並列禁止)

並列化メリット: 総処理時間短縮 (10 chunk × 25s = 250s → 25s)。
並列化デメリット:
- LanguageModelSession のスレッド safety 不明 (FoundationModels framework iOS 26 の現状ドキュメント不足)
- 進捗表示 (N/M) が乱れる
- partial success のロジックが複雑化
- メモリピーク 10 倍

MVP は逐次。将来の最適化候補として記録。

### #4 meta-summary は 1 回追加生成

代替案 (A) 全 chunk の essence を文字列連結 → ExtractedKnowledge.summary に保存 (LM 不使用) は実装簡単だが冗長な要約になる。
代替案 (B) 階層的 (10 chunk → 中間 5 chunk × 2 → 最終 1 chunk) は精度高いが複雑度高くチャンク 10 のスケールでは過剰。
採用 (C): 全 chunk の essence をリスト化して 1 回 LM に渡し meta-summary を生成。シンプルかつ Foundation Models の文脈統合能力を活用。

prompt 例:
```
以下は記事の各部分から抽出した要点です。これらを統合して 150 字以内の essence と 300 字以内の summary を生成してください。

# 各部分の要点
1. <chunk 1 essence>
2. <chunk 2 essence>
...
N. <chunk N essence>
```

10 essence × 150 char = 最大 1500 char = ~2550 token、prompt overhead 込でも 4096 内。

### #5 keyFacts / entities の重複排除戦略

**keyFacts**: `statement` の trim 済完全一致で重複判定。1 文字違い (例: 句読点) は別 fact。理由: 厳密性優先で保守的に。
**entities**: `name` の `lowercased() + trim` で一致判定。重複時は salience 最大値、type は多数決 (同票時は salience 最大の type)。
両方とも `ChunkedKnowledgeAggregator` に純粋関数として実装、テストで網羅。

### #6 partial success の閾値

- 全 chunk 失敗 → `.failed`、failureReason に「全 chunk 失敗」
- 1 件以上の chunk 成功 + meta-summary 失敗 → `.partiallySucceeded`、最初の成功 chunk の essence を fallback、各 chunk essence 連結を summary
- 全 chunk 成功 + meta-summary 成功 → `.succeeded`
- 1 件以上の chunk 成功 + meta-summary 成功 → `.succeeded` (足りない情報は無視、reasonable to call it succeeded)

`ExtractedKnowledge.failureReason` には「N/M chunk 失敗」のような形式でログ。

### #7 ProcessingMonitor 拡張

既存 `ActiveTask` 構造体に `progressIndex: Int?` / `progressTotal: Int?` を追加。chunked パスのみ非 nil に設定。BottomStatusBar 表示は両方 nil なら従来 "知識抽出中"、両方非 nil なら "知識抽出中 N/M"。

### #8 既存単発パス互換

本文 ≤ 1000 文字は `KnowledgeExtractor.extract(extractedText:)` (既存) を呼ぶだけ。chunked パスは `extractChunked(extractedText:)` を呼び、内部で `ChunkSplitter.split(text:)` → 各 chunk per `session.respond` → `ChunkedKnowledgeAggregator.merge(chunks:)` → meta-summary `session.respond` → 返す。Service の `extract(article:)` は本文長で if 分岐するだけ。spec 005 の重複抑止ガード / availability チェック / 本文未取得 skip は分岐前で処理されるので影響なし。

## Complexity Tracking

> Constitution Check 全項目 ✓ のため Complexity Tracking への記載は不要。

## 次フェーズ

1. **Phase 0** (research.md): chunk 分割アルゴリズムのベストプラクティス調査 / meta-summary prompt の出力安定性 / 並列 vs 逐次のトレードオフ詳細
2. **Phase 1** (data-model.md / contracts/ / quickstart.md): ExtractedKnowledge 新列定義、ChunkSplitter / ChunkedKnowledgeAggregator / KnowledgeExtractor の interface contract、5000 文字記事と 800 文字記事と 15000 文字記事の検証手順
3. **Phase 2** (`/speckit-tasks`): 実装タスク分解
