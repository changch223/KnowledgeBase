---

description: "Task list for spec 007 - マルチページ記事の自動追跡 + 本文統合"
---

# Tasks: マルチページ記事の自動追跡 + 本文統合

**Input**: Design documents from `/specs/007-multipage-fetch/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: 含む。Mock URLSessionProtocol で各ページの応答を制御。

## Path Conventions

- iOS app: `KnowledgeTree/{Models,Services,Views,Localization}/` + `KnowledgeTreeTests/`

---

## Phase 1: Setup

- [ ] T001 git ブランチ確認 (`007-multipage-fetch` 上で作業)。spec 006 が完了していることを `git log` で確認 (spec 006 の Foundational 列追加と独立)
- [ ] T002 [P] 既存 spec 002 関連テスト全 pass を確認 (`xcodebuild test -only-testing:KnowledgeTreeTests/ArticleEnrichmentServiceTests`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**目的**: ArticleEnrichment 列追加 + URL 正規化 utility + Mock URLSessionProtocol 拡張

- [ ] T003 `KnowledgeTree/Models/ArticleEnrichment.swift` に新規列 2 つを追加: `pageCountFetched: Int = 1`, `pageCountSkipped: Int = 0` (init にも引数追加、default 値で既存呼び出し互換)
- [ ] T004 [P] `KnowledgeTree/Services/URLNormalization.swift` を新規作成。`URL.normalized() -> String` 拡張 (research.md R2: scheme lowercase + host www 除去 + fragment 削除 + tracking params 削除 + trailing slash 統一)
- [ ] T005 [P] `KnowledgeTree/Services/ArticleEnrichmentStore.swift` の `upsert` に新引数 `pageCountFetched: Int = 1, pageCountSkipped: Int = 0` を追加。既存呼び出しは無修正可能
- [ ] T006 [P] `KnowledgeTreeTests/Fixtures/PaginationHTML.swift` を新規作成 (data-model.md セクション 6 の 8 fixture: linkRelNextHTML / anchorRelNextHTML / anchorClassNextHTML / urlPatternHTML / noPaginationHTML / crossDomainHTML / selfLoopHTML / relativeURLHTML)
- [ ] T007 schema migration テスト: in-memory ModelContainer で既存 ArticleEnrichment レコードを新 schema で読んで pageCountFetched=1, pageCountSkipped=0 のデフォルトが入ることを `SwiftDataArticleEnrichmentStoreTests.swift` の新ケースで確認
- [ ] T008 [P] `KnowledgeTreeTests/MockURLSessionProtocol.swift` を新規 (or 既存拡張): URL ごとに異なる response を返せるようにする (現状 1 レスポンスのみなら拡張)

**Checkpoint**: Foundation ready - US1 / US2 / US3 着手可能

---

## Phase 3: User Story 1 - 連載記事を 1 件としてフルキャプチャ (P1) 🎯 MVP

**Goal**: rel=next / class=next / URL パターンを検出して最大 5 ページを自動追跡、連結 HTML を保存。

**Independent Test**: Mock URLSession で 3 ページ HTML (rel=next 連鎖) を用意し、`MultiPageCrawler.crawl(initialURL:)` が `pageCountFetched=3, stopReason=.completed` を返すことを確認。

### Tests for User Story 1 ⚠️

- [ ] T009 [P] [US1] `KnowledgeTreeTests/PaginationDetectorTests.swift` を新規作成。contracts/pagination-detector.md の 16 ケースを実装 (rule 1-4 / クロスドメイン / http 拒否 / 自己ループ / 相対 URL / www 違い / class word boundary 等)
- [ ] T010 [P] [US1] `KnowledgeTreeTests/MultiPageCrawlerTests.swift` を新規作成。contracts/multipage-crawler.md の 12 ケース (1 ページ / 3 ページ / 5 ページ上限 / 循環 / クロスドメイン / 中間失敗 / 1 ページ目失敗 / retry 成功 / progress / delay / boundary comment / 大きすぎ)
- [ ] T011 [P] [US1] `KnowledgeTreeTests/ArticleEnrichmentServiceTests.swift` に 7 multi-page ケース追加 (3 ページ / 5 ページ上限 / 循環 / クロスドメイン拒否 / 巨大 rawHTML / progress 更新 / 1 ページ目 retry 成功)

### Implementation for User Story 1

- [ ] T012 [P] [US1] `KnowledgeTree/Services/PaginationDetector.swift` を新規作成。contracts/pagination-detector.md の API + 4 ルール優先順位検出 + クロスドメイン拒否 + 自己ループ拒否 + 相対 URL 解決を実装。`PaginationLink` / `DetectionRule` も同ファイル
- [ ] T013 [US1] `KnowledgeTree/Services/MultiPageCrawler.swift` を新規作成 (T004 + T012 完了後)。contracts/multipage-crawler.md の actor + crawl メソッド実装。1 ページ目 retry / 2 ページ目以降 1 回 / URL set / sameHost / boundary comment / progressCallback / 5MB / 2MB rawHTMLLimitWillExceed
- [ ] T014 [US1] `KnowledgeTree/Services/ArticleEnrichmentService.swift` の `performEnrichment` を `MultiPageCrawler` 経由に変更 (T013 完了後)。store.upsert の新引数 (pageCountFetched, pageCountSkipped) に CrawlResult 値を渡す
- [ ] T015 [US1] `MultiPageCrawler` の Task.isCancelled チェックを各ページ fetch 前に追加 (cancelAll() 互換)

**Checkpoint**: US1 単独で動作確認可能。3 ページ記事の rawHTML に全 HTML が含まれ、後続 body / knowledge 抽出に渡される。

---

## Phase 4: User Story 2 - 単一ページ記事の挙動を維持 (P1)

**Goal**: pagination が無いまたは検出失敗時は spec 002 既存挙動。pageCountFetched=1, +0.5 秒以内オーバーヘッド。

**Independent Test**: Mock URLSession で rel=next / class=next / URL パターンが一切検出されない HTML を返し、`pageCountFetched=1, stopReason=.completed` で終わることを確認。

### Tests for User Story 2 ⚠️

- [ ] T016 [P] [US2] `MultiPageCrawlerTests` の `singlePageArticle` ケース (T010 に含む)。期待 stopReason=.completed
- [ ] T017 [P] [US2] `ArticleEnrichmentServiceTests` の既存 4 ケース (`enrichWithSuccessfulFetchUpdatesStoreToSucceeded` 等) が **無修正で pass** することを確認 (後方互換 sanity check)

### Implementation for User Story 2

- [ ] T018 [US2] T012 / T013 の実装が pagination 検出失敗時に nil 返却 + stopReason=.completed で 1 ページのみ取得することを T010 の T013 含むテストでカバー (新規実装不要、既存テスト pass で担保)

**Checkpoint**: US1 + US2 動作。連載記事も単一記事も同じ Service で処理される。

---

## Phase 5: User Story 3 - 取得進捗の可視化 (P2)

**Goal**: BottomStatusBar に enrichment フェーズの (N/M) 進捗表示。

**Independent Test**: 5 ページ記事の enrichment 中に ProcessingMonitor.current.progressIndex が 1 → 2 → 3 → 4 → 5 と更新されることを確認。

### Tests for User Story 3 ⚠️

- [ ] T019 [P] [US3] `ArticleEnrichmentServiceTests` に「enrichUpdatesProgressPerPage」ケース追加 (Mock monitor の updateProgress 呼び出し回数と引数 verify)

### Implementation for User Story 3

- [ ] T020 [US3] `ArticleEnrichmentService.performEnrichment` で `monitor.start(.enrichment, articleID, title, progressIndex: 0, progressTotal: 5)` で初期 progress 設定 (spec 006 で追加した API、T013 で MultiPageCrawler から呼ぶ progressCallback と連携)
- [ ] T021 [US3] `MultiPageCrawler.crawl` の progressCallback を `ArticleEnrichmentService` で受け取り `monitor.updateProgress(articleID:index:)` を MainActor 内で呼ぶ (T013 で T020 と統合)
- [ ] T022 [P] [US3] `KnowledgeTree/Views/BottomStatusBar.swift` の表示分岐は spec 006 で追加済 (N/M 表示) → spec 007 では enrichment phase で同表示が出るだけ、変更不要
- [ ] T023 [P] [US3] `KnowledgeTree/Localization/Localizable.xcstrings` の `status.phase.knowledgeProgress` (spec 006 で追加) を `status.phase.progress` のような phase-agnostic キーに rename or `status.phase.enrichmentProgress` を新規追加。BottomStatusBar の表示ロジックは phase + progress の組み合わせで適切なキーを選ぶ

**Checkpoint**: US1 + US2 + US3 動作。連載記事処理中に N/M 進捗表示。

---

## Phase 6: Edge Cases

**目的**: research.md / spec.md で定義した境界条件の網羅。

- [ ] T024 [P] 循環 pagination (A → B → A) の Mock URLSession テスト (T010 の `loopDetected` ケース)
- [ ] T025 [P] クロスドメイン拒否のテスト (T010 の `crossDomainBlocked`)
- [ ] T026 [P] 中間ページ HTTP 404 の挙動テスト (T010 の `midFetchFailed`、stopReason=.fetchFailed)
- [ ] T027 [P] 連結 HTML 2MB 超過時 rawHTML nil 保存 (T011 の `enrichRawHTMLLimitExceeded`)
- [ ] T028 [P] 1 ページ目 retry 後 multi-page 成功 (T011 の `enrichFirstPageRetrySucceeds`)

---

## Phase 7: UI 注記 (skipped pages)

- [ ] T029 [P] `KnowledgeTree/Localization/Localizable.xcstrings` に `detail.pages.skippedNotice` を追加 (例: "本文が長いため最初の 5 ページのみ取得しました")
- [ ] T030 [P] `KnowledgeTree/Views/ArticleDetailView.swift` で `article.enrichment?.pageCountSkipped ?? 0 > 0` なら注記表示する分岐を追加 (knowledge 注記と並列、spec 006 の skippedTailChars 注記と統合可)

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T031 [P] 全 spec 001-007 テスト pass 確認 (`xcodebuild test`)
- [ ] T032 [P] specs/007-multipage-fetch/quickstart.md の S1〜S7 を実機で実行
- [ ] T033 [P] Console ログでマルチページ追跡の挙動確認 (各ページ fetch / pagination 検出 / 停止理由)
- [ ] T034 spec 006 + 007 の組合せ動作確認: 5 ページ × 2000 文字 = 10000 文字記事を保存して chunked summarization が 10 chunk + meta-summary で全文要約することを実機で検証 (quickstart S7)
- [ ] T035 git commit + push + PR description 更新

---

## Dependencies & Execution Order

### Phase 依存

- **Phase 1 (Setup)**: 即着手
- **Phase 2 (Foundational)**: T003 → T004, T005, T006, T008 (並列可) → T007 は T003 後
- **Phase 3 (US1)**: Phase 2 完了後。T009-T011 (並列テスト) → T012 → T013 → T014, T015
- **Phase 4 (US2)**: Phase 3 のテスト群で担保 (新規実装不要)
- **Phase 5 (US3)**: Phase 3 完了後。T019 → T020, T021 → T022, T023 (並列)
- **Phase 6 (Edge)**: Phase 3 完了後 (テスト整備)
- **Phase 7 (UI 注記)**: Phase 5 完了後 (UI 文言整備)
- **Phase 8 (Polish)**: 全完了後

### User Story 並列性

- US1 (P1) と US2 (P1) は同じ Service 経路で実装される (条件分岐) ので並列困難
- US3 (P2) は US1 の Service 拡張に依存
- US1 → US2 → US3 の順で逐次が現実的

---

## Implementation Strategy

### MVP 路線 (US1 + US2)

1. Phase 1 → Phase 2
2. Phase 3 (US1) — テスト先 → 実装
3. Phase 4 (US2) は Phase 3 のテストで担保される
4. **STOP & VALIDATE**: 連載記事 (3 ページ) と単一ページ記事を実機保存して挙動確認
5. Demo 可能

### Incremental Delivery

1. MVP (US1 + US2) merge
2. US3 (進捗表示) merge
3. Phase 6 (Edge case 網羅) と Phase 7 (UI 注記) と Phase 8 (Polish) を最後に

---

## Parallel Example: User Story 1 テスト群

```bash
# Phase 3 テスト並列:
Task: "PaginationDetectorTests.swift 新規"      # T009
Task: "MultiPageCrawlerTests.swift 新規"         # T010
Task: "ArticleEnrichmentServiceTests 拡張"      # T011
```

```bash
# 実装並列 (Phase 2 完了後):
Task: "URLNormalization.swift 新規"             # T004
Task: "PaginationDetector.swift 新規"           # T012
```

---

## Notes

- spec 002 の既存 ArticleEnrichmentService は API 後方互換 (Service の public method は変更なし、内部で Crawler 経由)
- spec 005 の重複抑止ガード / charset 検出 / HTTPS 強制 はそのまま継承
- spec 006 の ProcessingMonitor の N/M API を流用 (新規 API 追加なし)
- 1 秒遅延は実機で 5 ページ ≤ 15 秒の体感を確認 (quickstart S2)
- rate limit エラー時の挙動は MVP 範囲外、retry-after ヘッダ対応は将来 spec
