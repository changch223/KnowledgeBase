# Contract: 起動 backfill 並列化 (P1-7)

## 対象
- `KnowledgeTree/KnowledgeTreeApp.swift:388-427` (bootstrap 末尾)

## 変更
- 直列維持: `enrichmentService.backfillAll()` → `bodyService.backfillAll()` → `knowledgeService.backfillAll()`
- 並列化 (async let で同時進行 → 全完了 await):
  - `tagStore.cleanupOrphans()` (try?)
  - `AutoTagBackfillRunner.run()`
  - `AutoCategoryBackfillRunner.run()`
  - `digestService.regenerateAllStale()` (try? await)
  - `chatService.backfillEmbeddings()`
  - `topicClusteringService.runIfDue(force: false)`
  - `conceptSynthesisService.backfillFromExistingArticles()` → `resynthesizeAllStale()` (連鎖、1 つの async let 内)
- BGTask 予約 (`scheduleNextConceptResynthesis` / `scheduleNextWeeklyLint`) は全 backfill 後

## 契約条件
| 条件 | 期待 |
|---|---|
| 起動 backfill | 独立処理が同時進行し全完了 (FR-009 / SC-004) |
| enrichment→body→knowledge | 順序保持 (FR-010) |
| いずれか失敗 | 他処理・起動完了をブロックしない |
| @MainActor service | 構造化並行で交互実行、データ競合なし |

## テスト
- 起動完了の regression (既存 suite)。TTI 計測はユーザー後追い (Instruments)。
