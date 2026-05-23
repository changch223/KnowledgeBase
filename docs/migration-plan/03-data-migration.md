# 03 — Data Migration 戦略

## Status: Skeleton (Phase 3 で詳細化予定)

## このファイルの目的

現知積の SwiftData store にある既存ユーザーデータを、**1 件も失わずに iKnow に移行する** 戦略を定義。

---

## 大原則

- **既存データ絶対保持** = Constitution
- **lightweight migration のみ** = custom migration plan は避ける
- **段階的 backfill** = 新 @Model (ConceptPage 等) は既存記事から後追い生成

---

## 既存 @Model 16 個の Migration 戦略

| @Model | 変更 | Migration 種別 |
|---|---|---|
| Article | `sourceType: String?` 追加 (default "web") | Lightweight |
| ArticleEnrichment | 変更なし | なし |
| ArticleBody | 変更なし | なし |
| ExtractedKnowledge | 変更なし | なし |
| KeyFact | 変更なし | なし |
| KnowledgeEntity | 変更なし | なし |
| Tag | 変更なし (or 廃止検討) | なし |
| KnowledgeChunkProgress | 変更なし | なし |
| BackgroundExtractionQueueEntry | 変更なし | なし |
| KnowledgeDigest | 変更なし | なし |
| ChatSession | 変更なし | なし |
| ChatMessage | `savedAnswerID: UUID?` 追加 | Lightweight |
| ConflictProposal | 変更なし | なし |
| UserTopic | (検討) EntityCommunity と統合 → 削除 or 並立 | Lightweight or なし |
| GraphNode | 変更なし | なし |
| GraphEdge | 変更なし | なし |

---

## 新 @Model 4 個の追加戦略

| 新 @Model | 追加方法 | backfill 必要? |
|---|---|---|
| ConceptPage | SwiftData lightweight (新 entity 追加) | ✅ 既存 KnowledgeEntity から後追い生成 |
| SavedAnswer | 同上 | ❌ (V1 リリース後の chat から蓄積) |
| EntityCommunity | 同上 | ✅ 既存 GraphNode から検出 |
| ActivityLog | 同上 | ❌ (V1 リリース後の event から記録) |

### ConceptPage backfill 戦略

```
起動時 (or 設定で手動 trigger):
  for each Article:
    for each KnowledgeEntity in Article.extractedKnowledge.entities:
      同名 entity を他 Article から探す
      2+ Article に登場 → ConceptPage 自動生成
      
1 段階目: 軽量 (既存 entity のみ統合、AI 呼ばない)
2 段階目: 各 ConceptPage を isStale = true でマーク
3 段階目: BGTask で順次 AI 合成 (Foundation Models、空き時間に少しずつ)
```

→ ユーザーは触らずに、数日かけて完全な ConceptPage 群が育つ。

### EntityCommunity backfill 戦略

```
起動時 (or 週 1 BGTask):
  既存 GraphNode を K-means or Louvain でクラスタリング
  クラスター ごとに EntityCommunity 生成
  AI で命名 (Foundation Models)
  
1 回完了で current state が反映、以降は週 1 で更新
```

---

## Migration 実行手順

### Step 1: アプリ起動時の Schema 確認

```swift
// SharedSchema.all に新 @Model を追加
static var all: Schema {
    Schema([
        // 既存 16 個
        Article.self, ArticleEnrichment.self, ArticleBody.self,
        ExtractedKnowledge.self, KeyFact.self, KnowledgeEntity.self,
        Tag.self, KnowledgeChunkProgress.self, BackgroundExtractionQueueEntry.self,
        KnowledgeDigest.self, ChatSession.self, ChatMessage.self,
        ConflictProposal.self, UserTopic.self,
        GraphNode.self, GraphEdge.self,
        // 新規 4 個
        ConceptPage.self,         // spec 045
        SavedAnswer.self,         // spec 046
        EntityCommunity.self,     // spec 048
        ActivityLog.self,         // spec 047
    ])
}
```

SwiftData が自動で lightweight migration 実行。

### Step 2: backfill 起動

```swift
// 初回起動 (iKnow v2.0 アップデート後 1 回)
if isFirstLaunchAsIKnow {
    Task.detached(priority: .background) {
        await conceptSynthesisService.backfillFromExistingArticles()
        await communityDetectionService.detectAll()
    }
}
```

### Step 3: ユーザー体験

- 起動: 即座にアプリ動く (既存データ全部見える)
- 数分後: 概念ページが続々生成され始める
- 数日後: フル backfill 完了、すべてリッチに

---

## 失敗時の fallback

| 失敗パターン | fallback |
|---|---|
| lightweight migration 失敗 | 起動阻害、エラー表示 (発生確率極低、テスト必須) |
| ConceptPage backfill 失敗 | 該当 entity スキップ、log 記録 (他の処理は継続) |
| EntityCommunity 検出失敗 | 1 cluster (= 全 entity) として fallback、後で再試行 |
| Foundation Models 不可 | backfill 保留、ユーザーが Apple Intelligence 有効化したら自動再開 |

---

## 次のステップ

Phase 3 で詳細化:
- 各 backfill のタイミング詳細
- 進捗 UI (任意、Calm UX で表示しない方針)
- 失敗時のリトライ戦略
- backfill 中の Foundation Models 負荷管理 (重い処理が並列で走らない)
