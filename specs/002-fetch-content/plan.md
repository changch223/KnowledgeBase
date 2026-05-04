# Implementation Plan: 本文取得・メタデータエンリッチメント

**Branch**: `002-fetch-content` *(計画中、Round 1 of spec 001 commit 後に実ブランチを切る)* | **Date**: 2026-05-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-fetch-content/spec.md`

## Summary

spec 001 で保存済みの `Article` ごとに、その URL を 1 回 HTTPS GET で fetch し、HTML から canonical title / meta description / OG image を抽出して新規エンティティ `ArticleEnrichment` に保存する。一覧 View はサムネイル + canonical タイトル + 説明文を含む enriched カードで表示し、enrichment が無い (取得中・失敗) 場合は spec 001 の最低表示にフォールバックする。raw HTML もキャッシュし、後続 spec 003 (本文抽出) / spec 004 (要約) が再 fetch なしで動作できる土台を作る。

技術的アプローチ: `URLSession` の background configuration で fetch ジョブを非同期実行。HTML パースは Foundation 標準のみ (regex + 軽量 parser、サードパーティ禁止)。Service / Parser / Store の 3 層分離で、将来 fetch / parse / persistence を独立に差し替え可能にする。spec 001 の Share Extension は変更なし (新 Article 挿入を契機に App 本体プロセスでジョブが起動する設計)。

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 17+ / iOS 26 SDK)。spec 001 と同じ。
**Primary Dependencies**: SwiftUI、SwiftData、`URLSession` (NEW)、Foundation。サードパーティ依存なし (Constitution Additional Constraints)。HTML パースに `WebKit` (`WKWebView`) は使わず、軽量に Foundation の `String` API + 正規表現で `<title>` / `<meta>` を抽出。
**Storage**: SwiftData。spec 001 で構築した App Group container に **新エンティティ `ArticleEnrichment` を schema 追加**。スキーマバージョン管理: dev は wipe で対応、production は SwiftData 自動マイグレーション (新規 entity 追加は backward-compatible)。
**Testing**: XCTest / Swift Testing。`MetadataParser` の HTML→fields 抽出を unit test (固定 HTML フィクスチャ)。`ArticleEnrichmentService` の retry / fallback ロジックを unit test (Mock URLSession + Mock Store)。一覧 View の enriched / 取得中 / 失敗 状態は SwiftUI Preview + UI test。実 HTTP fetch を伴う end-to-end は手動 quickstart で担保 (CI 上では URLProtocol stub で代替)。
**Target Platform**: iOS 26+ / iPadOS 26+。spec 001 と同じ Apple Intelligence 対応端末縛り (本 spec は Foundation Models 不使用だがプロジェクト全体の制約に従う)。
**Project Type**: モバイルアプリ (iOS + iPadOS)。spec 001 の 4 target 構成を変えない (Share Extension に変更なし、enrichment はアプリ本体プロセスのみで動作)。
**Performance Goals** (spec 002 spec.md / SC + Constitution パフォーマンスゲート):
- Enriched カード表示まで Wi-Fi で **median 5 s 以内** (SC-001)
- enrichment ジョブ中もメインスレッド応答 ≤ 100 ms (SC-004)
- 1 件 enrichment あたり HTTP リクエストは正確に 1 回 (リダイレクト除く、SC-006)
- 100 件リスト 60 fps スクロール (SC-007 / Constitution パフォーマンスゲート)

**Constraints**:
- HTTPS のみ (FR-002 / ATS 既定遵守)
- HTTP リクエストには固定 User-Agent + 標準 Accept ヘッダのみ (Cookie / Authorization / IDFA 等は送信しない、FR-003)
- ダウンロード上限 5 MB / 1 リクエスト (FR-010)
- 最大 3 回リトライ、exponential backoff (FR-009)
- raw HTML キャッシュは 2 MB 超は破棄 (FR-012)
- ネットワーク切断時も spec 001 の全機能は 100% 利用可能 (SC-002)
- 全 UI 文言は日本語 `Localizable.xcstrings` 経由 (Principle VII / FR-008)

**Scale/Scope**: 単一ユーザー / 単一端末。spec 001 の保存件数 (数百〜数千) に対応。enrichment は 1 件ずつ順次実行 (並列度は当面 1、将来必要なら拡張)。

## Constitution Check

*GATE: Phase 0 research 前に通過必須。Phase 1 design 後に再評価。*

Reference: `.specify/memory/constitution.md` (v1.0.0)。すべて check するか、未 check 項目は **Complexity Tracking** で justification 必須。

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — 本 spec は **初めて network access を導入する**。spec 002 spec.md 内の「Network Access Justification (Principle I)」セクションで送信先 (ユーザー保存 URL のオリジンのみ)・送信内容 (HTTPS GET + 固定 User-Agent + 標準ヘッダ)・送信されないもの (Cookie / IDFA / 他記事リスト / 第三者サーバー) を明記済み。本 plan では実装側に「FR-003 を violate しない HTTP request 構築」を技術的に固定する (`URLRequest` を直接組み立て、`URLSession` の `httpAdditionalHeaders` で IDFA を含む推奨ヘッダを抑止)。
- [x] **II. MVP ファースト開発** — 本文抽出 (Readability) / 要約 / 分類 / ON-OFF 設定 / 手動再取得 / ローカル画像キャッシュ / URL 正規化 を Out of Scope に明示。本 spec は metadata 抽出 + raw HTML キャッシュまで。
- [x] **III. ソースに基づいた知識生成** — `ArticleEnrichment` は `Article` への non-optional 参照 (cascade delete) を持つ。本 spec は AI 生成物を扱わないが、後続 spec 003/004 の AI artifacts はすべて `Article` への non-optional 参照を持つ前提で `ArticleEnrichment` の id 主キー設計を整える。
- [x] **IV. iOS の実現可能性を重視する** — `URLSession` background configuration を使用 (Apple 公式の長時間実行サポート)。サードパーティ HTTP クライアントや readability ライブラリを使わない。`WebKit` は重量級なので避ける (Foundation 軽量パーサで対応)。macOS 対象外。
- [x] **V. シンプルで落ち着いた UX** — 取得中 / 未取得 / 取得失敗 の状態インジケータは行内の小さい控えめなアイコン (画面全体スピナー禁止 / 進捗バー禁止)。失敗してもアプリ全体の体験 (spec 001 の保存・閲覧・削除) は継続。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — 3 層分離: `ArticleEnrichmentService` (オーケストレーション、retry/backoff)、`MetadataParser` (HTML→fields の純関数)、`ArticleEnrichmentStore` (SwiftData 永続化)。`URLSession` も `URLSessionProtocol` で抽象化 (テスト容易性)。
- [x] **VII. 日本語ファースト** — 新規 UI 文言キー (`enrichment.statusFetching`、`enrichment.statusUnfetched`、`enrichment.statusFailed` 等) を `Localizable.xcstrings` に追加。spec / plan / research / contracts / quickstart はすべて日本語で記述。

### Quality Gates (二次ゲート)

- [x] **コード品質** — 新規型 (`ArticleEnrichment`、`ArticleEnrichmentService`、`MetadataParser`、`ArticleEnrichmentStore`、`URLSessionProtocol`) はすべて単一責務。`fatalError` / `try!` / 強制アンラップ なし (新規分)。HTML パース regex / String 操作は不正入力に対して safe (例外 throw でなく optional 返却)。
- [x] **テスト** — `MetadataParserTests` (固定 HTML フィクスチャで title / description / og:image 抽出・空 / 巨大 / 壊れ HTML)、`ArticleEnrichmentServiceTests` (Mock URLSession + Mock Store で retry / backoff / 成功 / 失敗 / 上限超え)、`SwiftDataArticleEnrichmentStoreTests` (in-memory ModelContainer)。UI test は SwiftUI Preview の状態網羅 + 既存 `SaveArticleUITests` への enriched 表示行 assertion 追加。
- [x] **アクセシビリティ・UX 一貫性** — 新規 accessibilityIdentifier: `articleEnrichmentStatusFetching`、`articleEnrichmentStatusUnfetched`、`articleEnrichmentStatusFailed`、`articleListThumbnail`。Dynamic Type / Dark Mode / VoiceOver: 既存パターンを継承。サムネイル `AsyncImage` は失敗時にプレースホルダ (透明 or グレー) を表示し layout shift を起こさない。
- [x] **パフォーマンス** — fetch ジョブは `Task` 非同期で main thread を 1 ms も占有しない。HTML パースも非同期 (`MetadataParser.parse(html:)` は detached task で実行)。`@Query<Article>` の view body は spec 001 から変えず、`ArticleEnrichment` は relationship 経由で取得 (Lazy load)。100 件超の enriched 表示は Instruments で別途検証 (tasks.md で task 化)。

**結論**: すべて check 通過。Complexity Tracking 不要。

## Project Structure

### Documentation (this feature)

```text
specs/002-fetch-content/
├── plan.md                                  # This file
├── research.md                              # Phase 0 出力
├── data-model.md                            # Phase 1 出力 (ArticleEnrichment + Article relationship)
├── quickstart.md                            # Phase 1 出力 (network 込み手動検証)
├── spec.md                                  # /speckit-specify 出力
├── checklists/
│   └── requirements.md                      # /speckit-specify 出力
├── contracts/                               # Phase 1 出力 (内部プロトコル境界)
│   ├── article-enrichment-service.md
│   ├── metadata-parser.md
│   └── article-enrichment-store.md
└── tasks.md                                 # Phase 2 出力 (/speckit-tasks で生成、本コマンドでは未作成)
```

### Source Code (repository root)

spec 001 の構造を **拡張する** (target 構成は不変、ファイルを追加のみ):

```text
KnowledgeTree/
├── Models/
│   ├── Article.swift                        # 既存 (spec 001)、要更新: enrichment への optional relationship を追加
│   └── ArticleEnrichment.swift              # 新規 (Phase 1 / data-model.md)
├── Services/
│   ├── ArticleStore.swift                   # 既存 (spec 001)、変更なし
│   ├── ArticleSavingService.swift           # 既存 (spec 001)、変更なし
│   ├── ArticleEnrichmentStore.swift         # 新規 (contracts/article-enrichment-store.md)
│   ├── ArticleEnrichmentService.swift       # 新規 (contracts/article-enrichment-service.md)
│   ├── MetadataParser.swift                 # 新規 (contracts/metadata-parser.md)
│   └── URLSessionProtocol.swift             # 新規 (テスト用 URLSession 抽象、軽い 1 メソッド protocol)
├── Views/
│   ├── ArticleListView.swift                # 既存、要更新: enriched カード表示 + status indicator (Phase 2 tasks)
│   ├── EmptyStateView.swift                 # 既存、変更なし
│   ├── SafariView.swift                     # 既存、変更なし
│   ├── ArticleRow.swift                     # 新規 (ArticleListView から行レンダリングを抽出 — Principle VI)
│   ├── EnrichmentStatusBadge.swift          # 新規 (取得中 / 未取得 / 失敗 のインジケータ)
│   └── ThumbnailView.swift                  # 新規 (AsyncImage ラッパ、失敗 / nil 時のプレースホルダ)
├── Localization/
│   └── Localizable.xcstrings                # 既存、要更新: enrichment.* キーを追加
├── KnowledgeTreeApp.swift                   # 既存、要更新: 起動時に enrichment ジョブを backfill キックオフ
├── AppGroup.swift                           # 既存、変更なし
└── KnowledgeTree.entitlements               # 既存、変更なし

KnowledgeTreeShareExtension/                 # 全ファイル変更なし (spec 002 はアプリ本体のみ)

KnowledgeTreeTests/
├── ArticleSavingServiceTests.swift          # 既存 (spec 001)
├── SwiftDataArticleStoreTests.swift         # 既存 (spec 001)
├── MetadataParserTests.swift                # 新規 (HTML フィクスチャから title/description/og:image 抽出)
├── ArticleEnrichmentServiceTests.swift      # 新規 (Mock URLSession + Mock Store で retry / backoff / 上限)
└── SwiftDataArticleEnrichmentStoreTests.swift # 新規 (in-memory ModelContainer)

KnowledgeTreeUITests/
├── SaveArticleUITests.swift                 # 既存、要更新: enriched 行表示 assertion を追加 (URLProtocol stub or fixture)
```

**Structure Decision**:
- spec 001 と同じ単一 Xcode project 構成。target 追加なし。
- 新規 Service 群 (`ArticleEnrichmentService` / `MetadataParser` / `ArticleEnrichmentStore`) は **app target のみ** (Share Extension は metadata fetch せず、保存だけ行う設計、Principle V — 共有が止まらない)。
- `URLSessionProtocol` は **app target のみ** (Share Extension は使わない)。
- 既存 `ArticleListView.swift` は `ArticleRow` / `ThumbnailView` / `EnrichmentStatusBadge` に分割 (単一巨大 View 回避、Principle VI)。
- App Group ID / entitlements は spec 001 のまま流用。

## Complexity Tracking

> **Constitution Check で violations が無いため未記入。**
>
> Network access は Principle I の例外要件 (spec.md の Network Access Justification) を満たすため violation ではない。

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (なし) | — | — |

## 設計上の意思決定 (Plan-level Decisions)

spec.md で定めず本 plan で決めた事項を明示:

1. **既存記事の backfill enrichment**: spec 002 リリース直後、起動時に `ArticleEnrichment` が紐づいていない既存 `Article` を全件スキャンしてキューイングする。スキャン件数が多い場合は順次処理 (rate limit はネットワーク 1 req/article で十分緩い)。
2. **First-run privacy disclosure (in-app prompt)**: 実装しない。理由: (a) ユーザーが explicit に保存した URL に対する 1 fetch のみ、(b) browser-equivalent 動作、(c) App Store privacy disclosure / Privacy Manifest で開示、(d) in-app プロンプトは Principle V (落ち着いた UX) と矛盾。将来 ON/OFF 設定 spec が来たときに改めて検討。
3. **並列度 (concurrent enrichment fetch)**: 当面 1 (順次処理)。理由: (a) 1 ユーザーの enrichment 件数は数十〜数百で並列の必要性が薄い、(b) 順次なら rate limit / fairness の心配なし。後続 spec で並列化が必要になったら拡張。
4. **rawHTML 保存判断**: 取得時のサイズ (Content-Length または読み取り後の bytes) が 2 MB 以下なら保存、超えたら捨ててメタデータだけ持つ。理由: spec 003 (本文抽出) で再 fetch せずに済むメリットと、SQLite の BLOB サイズの不利を天秤にかけ、典型的な記事ページ (200-800 KB) を救うラインを 2 MB に設定。
5. **schema migration**: spec 001 はまだ未リリース (本 PR で初めて出る)。spec 002 の新エンティティ追加は backward-compatible なため SwiftData 自動マイグレーションで吸収できる想定。production リリース後の真のマイグレーションは spec 002 リリース時に検証。
