# Phase 0 Research: iCloud sync — Technical Spike

**Spec**: spec 051 CloudKit sync
**Date**: 2026-05-24
**Spike scope**: Schema audit + CloudKit constraint check (静的分析、実機 spike は user に委ねる)
**Outcome**: 🟡 **Phase A 着手可能だが大規模 refactor 確定** — schema 改修 ~19 model、~250 行、+ ~80 行の app-level dedup

## R1: @Attribute(.unique) 全件 (19 箇所)

| Model | フィールド | 用途 | dedup 戦略 (CloudKit 後) |
|---|---|---|---|
| Article.id | UUID | 主キー | UUID 生成時に既存チェック (ArticleStore) |
| ArticleEnrichment.id | UUID | 主キー | EnrichmentStore で既存チェック |
| ArticleBody.id | UUID | 主キー | BodyStore で |
| ExtractedKnowledge.id | UUID | 主キー | KnowledgeStore で |
| KeyFact.id | UUID | 主キー | cascade で問題なし |
| KnowledgeEntity.id | UUID | 主キー | cascade で問題なし |
| Tag.name | **String** | semantic 一意性 (タグ名重複防止) | TagStore で normalize + 既存検索 (既実装、現状の `cleanupOrphans` の隣に dedup) |
| KnowledgeChunkProgress.id | UUID | 主キー | ChunkProgressStore で |
| BackgroundExtractionQueueEntry.id | UUID | 主キー | BackgroundExtractionQueue で |
| KnowledgeDigest.id | UUID | 主キー | DigestService で |
| ChatSession.id | UUID | 主キー | ChatService で |
| ChatMessage.id | UUID | 主キー | ChatService で |
| ConflictProposal.id | UUID | 主キー | ConflictDetectionService で |
| UserTopic.id | UUID | 主キー | TopicClusteringService で |
| GraphNode.id | UUID | 主キー | GraphNodeStore で |
| GraphEdge.id | UUID | 主キー | GraphNodeStore で |
| ConceptPage.id | UUID | 主キー | ConceptPageStore で |
| SavedAnswer.id | UUID | 主キー | SavedAnswerService で |
| UnderstandingInteraction.id | UUID | 主キー | TrackerService で |

**Tag.name は特別**: id ではなく **意味的に一意な name** (タグ重複防止)。CloudKit 同期下では同名 Tag が 2 端末で同時作成されると衝突する。対策: TagStore で merge ロジック (既存実装にあるか確認、なければ追加)。

## R2: 非 optional / 非 Array attribute without default value 全件

CloudKit は新 record 作成時に default value が必要。現状は init() でしか設定できない。

| Model | 改修必要 field 数 | 例 |
|---|---|---|
| Article | 3 | url / title / savedAt |
| ArticleBody | 3 | article / statusRaw / extractionVersion |
| ArticleEnrichment | 5 | article / statusRaw / retryCount / pageCountFetched / pageCountSkipped |
| BackgroundExtractionQueueEntry | 2 | articleID / queuedAt |
| ChatMessage | 3 | role / text / timestamp |
| ChatSession | 3 | createdAt / lastMessageAt / title |
| ConceptPage | 8 | name / categoryRaw / summary / userUnderstanding / isFollowing / 等 |
| ConflictProposal | 6 | entityName / conflictDescription / newFact / oldFact / status / 等 |
| ExtractedKnowledge | 15 | article / statusRaw / extractionVersion / chunkProcessedCount / 等 |
| GraphEdge | 6 | confidence / isUncertain / weight / categoryRaw / createdAt / 等 |
| GraphNode | 8 | (未集計、grep limit) |
| ... | ... | ... |

**全 model 合計**: 推定 80-100 fields に `= 空文字列 / 0 / .now / .nullify default` を追加必要。

**改修例**:
```swift
// 改修前
var url: String

// 改修後
var url: String = ""
```

これは init() があれば「init で実際の値が入る」ので default はあくまで CloudKit が新規 record 受信時の placeholder。

## R3: @Relationship 全件 — CloudKit 互換性チェック

| 種別 | 用例 | CloudKit 互換? |
|---|---|---|
| Optional (`var foo: Bar?`) | ConflictProposal.newArticle | ✅ OK |
| Array empty default (`var foo: [Bar] = []`) | Article.tags / SavedAnswer.citedArticles | ✅ OK |
| Cascade delete rule | Article.enrichment / ChatSession.messages | ✅ OK (CloudKit cascade 動作確認必要、おそらく OK) |
| Nullify delete rule | ConflictProposal.newArticle / SavedAnswer.citedArticles | ✅ OK |
| Inverse 指定 | ExtractedKnowledge.keyFacts (inverse: \KeyFact.knowledge) | ✅ OK (双方向 OK) |
| Non-optional, non-Array | ❌ 該当なし (audit 結果ゼロ) | — |

**結論**: relationship 側は問題なし。

## R4: @Attribute(.externalStorage) Data?

| Model | フィールド | サイズ |
|---|---|---|
| Article | essenceEmbedding | ~1.2KB (300-dim Float) |
| ConceptPage | embedding | ~1.2KB |

**CloudKit 互換**: ✅ externalStorage は CloudKit asset として sync 可。1 ユーザー 100 記事で ~120KB 程度、quota 圧迫なし。

## R5: 推定 CloudKit storage 使用量

| データ | 1 ユーザー 6 ヶ月想定 | サイズ目安 |
|---|---|---|
| Article (200 件 × 各 ~5KB SQLite) | 1MB | small |
| ArticleBody (200 件 × 平均 ~30KB 本文) | 6MB | medium |
| ExtractedKnowledge + KeyFact + Entity | 1MB | small |
| Embedding (Article + ConceptPage、各 1.2KB) | 200 + 50 件 × 1.2KB = ~300KB | small |
| ConceptPage / SavedAnswer / Chat / Graph etc | 1MB | small |
| **合計** | **~10MB** | iCloud 5GB free tier の 0.2% |

quota 余裕、ユーザー心配ゼロ。

## R6: App Group + CloudKit 共存 (🚨 実機検証必須)

**現状**:
```swift
ModelConfiguration(
    schema: SharedSchema.all,
    groupContainer: .identifier(AppGroup.identifier)
)
```

**CloudKit 追加案**:
```swift
ModelConfiguration(
    schema: SharedSchema.all,
    isStoredInMemoryOnly: false,
    groupContainer: .identifier(AppGroup.identifier),
    cloudKitDatabase: .private("iCloud.app.KnowledgeTree")
)
```

**Apple docs 明確記載なし** — App Group container + CloudKit private DB の同時指定は未保証。実機検証必須。

**3 想定シナリオ**:
1. **正常動作** (best case): App Group + CloudKit が共存、Share Extension も sync 後の data 共有 ✅
2. **CloudKit のみ** (silent fail): groupContainer が無視され、Share Extension が CloudKit に直接書く必要 → 改修可能
3. **エラー** (worst case): `ModelContainer` init で例外 → CloudKit + App Group は不可、Share Extension を XPC ベース等で別 IPC 設計必要 (大規模 refactor、~2 週間追加)

**Mitigation**: Phase 0 spike 完了後、上記 3 シナリオのどれかが判明 → 必要なら spec scope 縮小 or V2.5 へ繰り延べ。

## R7: 既存ユーザー migration 戦略

Toggle ON 時の挙動:

**Option A: アプリ再起動が必要**
- ModelConfiguration を `cloudKitDatabase: .private` 付きに切替
- アプリ全 ModelContainer 再構築 → SwiftData が既存 local data を CloudKit に push (Apple のドキュメント上、これは自動)
- 再起動中は使えない、UX 劣化

**Option B: hot-swap (実装複雑)**
- 既存 ModelContainer を維持 + 別 ModelContainer (CloudKit) を作る + 全データを copy → swap
- 時間かかる、メモリ大、エラーハンドル困難

**Option C: 翌起動から sync (cleanest)**
- Toggle ON で flag を立てる + 「次回起動から有効」case
- 次回起動時に CloudKit configuration で起動 → Apple が migration 自動
- アプリ再起動 banner 表示

**採用候補**: **C** が cleanest、user 1 度の手動再起動だけで済む。Phase A で実装。

## R8: Apple Developer / App Store Connect 作業

- Apple Developer Account で **CloudKit Container** `iCloud.app.KnowledgeTree` 作成
- App ID に CloudKit + iCloud capabilities 追加
- Xcode で `Signing & Capabilities` → `+ Capability` → `iCloud` → CloudKit + container ID
- `.entitlements` に追加 (自動)
- App Store 提出時に CloudKit Container を **production schema deploy** 必要

## 推奨判断

### Phase A 着手 GO / NO-GO

**GO**: 以下を user が承諾できる場合:
- 19 unique constraint 削除 + 80-100 field default 追加 = 大規模 schema 変更
- Phase 0 実機 spike で App Group + CloudKit 共存が動作する確認 (1-2 日、user 実機で xcode 検証)
- スケジュール 2-3 週間 (本 spike + Phase A 実装)
- 失敗時 (R6 worst case) は scope 縮小 / V2.5 繰り延べ受容

**NO-GO** で別案検討:
- V2.0 は spec 052 Widget のみで release (~1 週間で完成)
- iCloud sync は V2.5 で R6 の不確実性を別途検証してから着手
- spec 051 はこの paper を残し、実装はしない

### 私の推奨

**Phase 0 実機 spike を user が短時間で実施 → 結果見て GO/NO-GO 判断** を強く推奨。

具体的に user が実機で確認すべき手順:
1. Xcode で minimal demo project 作成 (5 分)
2. ModelConfiguration に App Group + CloudKit private 両方指定 (5 分)
3. iPhone 実機で起動、エラーなく ModelContainer 構築されるか確認 (5 分)
4. iCloud Settings 確認、record 同期されるか別端末で見る (15 分)
5. Share Extension 風の subprocess (今回は不要、別 Target で代替可) からも書けるか (10 分)

合計 1 時間以下の検証で R6 不確実性を解消できる。

## 規模再見積もり (audit 後)

- @Attribute(.unique) 削除: 19 行
- default value 追加: 80-100 行
- App-level dedup logic 追加: 8 store × 10 行 = ~80 行
- Settings toggle 改修: 30 行
- ModelContainer 動的構築 (re-init logic): 50 行
- Migration UI: 100 行 (Phase B 行き OK)
- Tests: 200 行 (新 schema 動作確認)

**Phase A 合計**: ~580 行 (spec で見積もり ~1100 行は overestimate、実際は ~580 行)
**期間**: spike 1 日 + Phase A 実装 1.5 週間 = **2 週間**
