# Implementation Plan: 本文抽出 (Reader View)

**Branch**: `003-extract-body` *(計画中、spec 001 / spec 002 の commit 後に実ブランチを切る)* | **Date**: 2026-05-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-extract-body/spec.md`

## Summary

spec 002 でキャッシュした `ArticleEnrichment.rawHTML` から、Foundation 標準 API + Readability 風ヒューリスティックで本文 plain text を抽出して新規エンティティ `ArticleBody` に保存する。一覧画面の行タップ時の遷移先を、ArticleBody が成功なら **アプリ内 Reader View**、それ以外なら従来通り **SFSafariViewController** に切り替える。新規ネットワークアクセスは行わない (本 spec の最大の強み — Principle I を完全維持)。

技術的アプローチ: 抽出は副作用ゼロの純関数 `BodyExtractor` (HTML String → ParsedBody)、orchestration は `BodyExtractionService` (enrichment 完了 observe → extractor 呼出 → store 保存)、永続化は `ArticleBodyStore`。Reader View は SwiftUI の `Text` + Dynamic Type + Dark Mode ネイティブ対応。画像 / 動画 / iframe は MVP では **表示しない** (plain text のみ)。

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 17+ / iOS 26 SDK)。spec 001 / 002 と同じ。
**Primary Dependencies**: SwiftUI、SwiftData、Foundation。**新規依存ゼロ** (URLSession 不要、WebKit 不要、サードパーティ禁止 — Constitution Additional Constraints)。
**Storage**: SwiftData。spec 001 / 002 で構築した App Group container に **新エンティティ `ArticleBody` を schema 追加**。schema は `[Article.self, ArticleEnrichment.self, ArticleBody.self]` に拡張。
**Testing**: XCTest / Swift Testing。`BodyExtractor` の HTML→ParsedBody 抽出を unit test (固定 HTML フィクスチャ、spec 002 の fixture を再利用 + 本文用に追加)。`BodyExtractionService` の orchestration を unit test (Mock Store + Mock Extractor)。Reader View の状態は SwiftUI Preview + UI test。
**Target Platform**: iOS 26+ / iPadOS 26+ (Constitution Principle IV)。本 spec も Foundation Models 不使用。
**Project Type**: モバイルアプリ (iOS + iPadOS)。spec 001 の 4 target 構成を変えない。
**Performance Goals**:
- 抽出完了まで median 1 s 以内 (50-200 KB HTML、SC-001)
- Reader View 表示まで 300 ms 以内 (SC-002)
- 抽出ジョブ中もメインスレッド応答 ≤ 100 ms (SC-004)
- 100 件 enriched 一覧 60 fps スクロール (SC-006)

**Constraints**:
- **新規ネットワークアクセスゼロ** (本 spec の中核制約。spec 002 のキャッシュのみ使用、Principle I を完全維持)
- Foundation 標準 API のみ (サードパーティ Readability ライブラリ禁止)
- 抽出結果は plain text のみ。画像 / 動画 / iframe は表示しない (FR-009)
- 抽出結果が 100 文字未満なら `failed` 扱い、Reader 表示は試みない (FR-005)
- 全 UI 文言は日本語 `Localizable.xcstrings` 経由 (Principle VII)

**Scale/Scope**: 単一ユーザー / 単一端末。spec 001 / 002 同様、保存件数 100〜数千。抽出は 1 件ずつ順次 (並列度 1、spec 002 と同じ方針)。

## Constitution Check

*GATE: Phase 0 research 前に通過必須。Phase 1 design 後に再評価。*

Reference: `.specify/memory/constitution.md` (v1.0.0)。

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — 本 spec は **新規ネットワークアクセスを一切持たない**。spec 002 がキャッシュした `ArticleEnrichment.rawHTML` のみを入力に取り、抽出処理は完全にローカル。Network Access Justification セクション不要 (spec 002 の justification はそのまま継続有効)。
- [x] **II. MVP ファースト開発** — 画像 / 動画 / iframe 表示、typography controls、読書位置記憶、TTS、Mozilla Readability 移植 を Out of Scope に明示。本 spec は plain text 抽出 + Reader 表示 + SVC フォールバック 3 点のみ。
- [x] **III. ソースに基づいた知識生成** — `ArticleBody` は `Article` への non-optional 参照 (cascade delete) を持つ。本 spec で AI 生成物は無いが、後続 spec 004 (要約) は本 spec の `ArticleBody.extractedText` を入力に取る前提。要約は Article への non-optional 参照を別途持つ (Principle III の構造的整合性は Article エンティティを source-of-truth に維持)。
- [x] **IV. iOS の実現可能性を重視する** — Foundation 標準 API のみ。`WebKit` (`WKWebView`) は使わない (重量級、main thread 制約)。`NSAttributedString` の HTML loader も使わない (重い + main thread)。サードパーティ readability 禁止。macOS 対象外。
- [x] **V. シンプルで落ち着いた UX** — 抽出失敗時は「読めません」空状態を見せず、サイレントに SVC フォールバック (US2)。Reader View 内に余計な controls を置かない (typography 設定、ハイライト等は将来 spec)。Dark Mode / Dynamic Type ネイティブ対応で目に優しい。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — 4 層分離: `BodyExtractor` (純関数、HTML→ParsedBody)、`BodyExtractionService` (orchestration)、`ArticleBodyStore` (SwiftData 永続化)、`ReaderView` (SwiftUI 表示)。Reader View は単一巨大 View にならないよう `ReaderToolbar` を別ファイル化。
- [x] **VII. 日本語ファースト** — 新規 UI 文言キー (`reader.doneButton`、`reader.openOriginalButton`、`reader.navigationTitle` 等) を `Localizable.xcstrings` に追加。spec / plan / research / contracts / quickstart はすべて日本語で記述。

### Quality Gates (二次ゲート)

- [x] **コード品質** — 新規型 (`ArticleBody`、`BodyExtractor`、`BodyExtractionService`、`ArticleBodyStore`、`ReaderView`、`ReaderToolbar`) はすべて単一責務。`fatalError` / `try!` / 強制アンラップ なし (新規分)。HTML パースは正規表現 + String 操作で safe (例外 throw でなく optional 返却)。
- [x] **テスト** — `BodyExtractorTests` (HTML フィクスチャ; semantic タグ優先 / text-density スコアリング / boilerplate 除去 / 短すぎる結果の `failed` 判定)、`BodyExtractionServiceTests` (Mock Extractor + Mock Store; enrichment 成功 trigger → extract → save)、`SwiftDataArticleBodyStoreTests` (in-memory ModelContainer)。Reader View / SVC 切替の UI test は launch arg seed で 2 状態確認。
- [x] **アクセシビリティ・UX 一貫性** — 新規 accessibilityIdentifier: `readerView`、`readerDoneButton`、`readerOpenOriginalButton`。Dynamic Type 全フォントサイズで layout 維持、Dark Mode で十分なコントラスト、VoiceOver で本文段落と toolbar が正しく読み上げられる。
- [x] **パフォーマンス** — 抽出は detached `Task` で実行 (main 一切ブロックしない、SC-004)。Reader View は `LazyVStack` で長文も 60 fps 維持。`@Query<Article>` は spec 001 から不変、`ArticleBody` は relationship 経由 lazy load。

**結論**: すべて check 通過。Complexity Tracking 不要。

## Project Structure

### Documentation (this feature)

```text
specs/003-extract-body/
├── plan.md                                  # This file
├── research.md                              # Phase 0 出力
├── data-model.md                            # Phase 1 出力 (ArticleBody)
├── quickstart.md                            # Phase 1 出力 (Reader View 含む)
├── spec.md                                  # /speckit-specify 出力
├── checklists/
│   └── requirements.md                      # /speckit-specify 出力
├── contracts/                               # Phase 1 出力 (内部プロトコル境界)
│   ├── body-extractor.md
│   ├── body-extraction-service.md
│   └── article-body-store.md
└── tasks.md                                 # Phase 2 出力 (/speckit-tasks で生成、本コマンドでは未作成)
```

### Source Code (repository root)

spec 001 / 002 の構造を **拡張する** (target 構成は不変、ファイル追加のみ):

```text
KnowledgeTree/
├── Models/
│   ├── Article.swift                        # 既存、要更新: body への optional relationship を追加
│   ├── ArticleEnrichment.swift              # 既存 (spec 002)、変更なし
│   └── ArticleBody.swift                    # 新規 (data-model.md)
├── Services/
│   ├── ArticleStore.swift                   # 既存 (spec 001)、変更なし
│   ├── ArticleSavingService.swift           # 既存 (spec 001)、変更なし
│   ├── ArticleEnrichmentStore.swift         # 既存 (spec 002)、変更なし
│   ├── ArticleEnrichmentService.swift       # 既存 (spec 002)、要更新: enrichment .succeeded を BodyExtractionService に通知 (delegate / Combine / 直接 call)
│   ├── MetadataParser.swift                 # 既存 (spec 002)、変更なし
│   ├── URLSessionProtocol.swift             # 既存 (spec 002)、変更なし
│   ├── ArticleBodyStore.swift               # 新規 (contracts/article-body-store.md)
│   ├── BodyExtractionService.swift          # 新規 (contracts/body-extraction-service.md)
│   └── BodyExtractor.swift                  # 新規 (contracts/body-extractor.md、純関数)
├── Views/
│   ├── ArticleListView.swift                # 既存、要更新: 行タップで ArticleBody.status による Reader / SVC 切替 (Phase 2 tasks)
│   ├── EmptyStateView.swift                 # 既存、変更なし
│   ├── SafariView.swift                     # 既存 (spec 001)、変更なし (Reader 失敗フォールバックで継続使用)
│   ├── ArticleRow.swift                     # 既存 (spec 002)、変更なし
│   ├── EnrichmentStatusBadge.swift          # 既存 (spec 002)、変更なし
│   ├── ThumbnailView.swift                  # 既存 (spec 002)、変更なし
│   ├── ReaderView.swift                     # 新規 (アプリ内 Reader UI)
│   └── ReaderToolbar.swift                  # 新規 (完了 + 元記事を開く ボタン群)
├── Localization/
│   └── Localizable.xcstrings                # 既存、要更新: reader.* キー追加
├── KnowledgeTreeApp.swift                   # 既存、要更新: BodyExtractionService の bootstrap を ArticleEnrichmentService と並べてキックオフ
├── AppGroup.swift                           # 既存、変更なし
└── KnowledgeTree.entitlements               # 既存、変更なし

KnowledgeTreeShareExtension/                 # 全ファイル変更なし (本 spec はアプリ本体のみ)

KnowledgeTreeTests/
├── (既存: spec 001 / 002 のテスト群)
├── BodyExtractorTests.swift                 # 新規 (HTML フィクスチャから body 抽出を検証)
├── BodyExtractionServiceTests.swift         # 新規 (Mock Extractor + Mock Store + enrichment trigger)
└── SwiftDataArticleBodyStoreTests.swift     # 新規 (in-memory ModelContainer)

KnowledgeTreeUITests/
├── SaveArticleUITests.swift                 # 既存、要更新: Reader View 表示 / SVC フォールバック の 2 状態 assertion を追加
```

**Structure Decision**:
- spec 001 / 002 の構造を継承。target 追加なし、新規 Service と View を追加するのみ。
- 既存 `ArticleEnrichmentService` を要更新 (enrichment 成功時に BodyExtractionService に通知)。最小変更にとどめ、`onSuccess: ((Article) -> Void)?` のような callback を追加する形が候補。
- `ReaderView.swift` と `ReaderToolbar.swift` を分離して単一巨大 View 回避 (Principle VI)。

## Complexity Tracking

> **Constitution Check で violations が無いため未記入。**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (なし) | — | — |

## 設計上の意思決定 (Plan-level Decisions)

spec.md で定めず本 plan で決めた事項を明示:

1. **抽出 trigger 機構**: spec 002 の `ArticleEnrichmentService` が enrichment .succeeded に遷移したタイミングで `BodyExtractionService.extract(article:)` を呼ぶ。直接 call (Service → Service の依存) を採用。理由: (a) Combine は overkill、(b) NotificationCenter は依存隠蔽で test 困難、(c) 直接 call は protocol 抽象で十分テスト可能。`ArticleEnrichmentService` の init に optional `bodyExtractionService` を inject。
2. **既存記事の backfill body extraction**: spec 003 リリース直後、起動時に `ArticleBody` が紐づいていない & rawHTML 持ちの既存 Article を全件スキャン → 順次キューイング。spec 002 の backfill と同じパターン。
3. **抽出結果が短すぎる判定**: 100 文字未満 → `failed`。理由: 「タイトルだけ抽出できた」「meta description しか取れなかった」状態を Reader 表示すると価値が無く UX が壊れる。SVC フォールバックの方がユーザーには有益。閾値 100 は典型的な記事冒頭 (1 段落 = 100-300 文字) を救うラインで設定。
4. **Reader View の data flow**: SwiftUI `@Query` で `Article` を取得し、tap 時に `Article.body?.status` を判定して Reader (`succeeded`) or SVC (それ以外) を `.sheet` で出す。`@Query` の自動更新が SwiftData の relationship 経由で ArticleBody 更新も拾うはず (要検証 — 万一拾わなければ `@Bindable Article` で対応)。
5. **抽出ヒューリスティック バージョニング**: `ArticleBody.extractionVersion: Int` を持つ。将来ヒューリスティックを改善したとき、古いバージョンで抽出した記事を再抽出する判定に使う。本 spec では `extractionVersion = 1` で固定。
6. **画像参照の扱い**: 抽出時に `<img>` タグは plain text 上「[画像]」のような placeholder に置換するか、完全に削除するかで悩む。MVP は **完全に削除** (FR-009 厳守、UI ノイズなし)。「[画像]」placeholder は将来の画像インライン spec で復活時にする。
