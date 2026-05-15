# Plan: 動的トピック自動発見

**Spec**: [spec.md](./spec.md)

## Technical Context

- Swift 6 / SwiftUI / SwiftData / Foundation Models / NaturalLanguage / Accelerate
- iOS 26+
- spec 021 の Article.essenceEmbedding を再利用
- 規模: 大 (~810 行、~15-20 タスク)

## Architecture

```
[KnowledgeTreeApp]
  └── 起動時 batch: TopicClusteringService.runIfDue()

[Services]
  ├── TopicClusteringService (新)
  │    ├── K-means (Accelerate)
  │    ├── AI 命名 (LanguageModelSession.generateTopicName)
  │    └── UserTopicStore.upsertCandidate()
  ├── UserTopicStore (新、CRUD + 重複 check)
  └── LanguageModelSessionProtocol (拡張)
       └── generateTopicName(prompt: String) -> TopicNameOutput

[Models]
  └── UserTopic @Model (新)
       ├── id, name, createdAt
       ├── acceptedAt?, dismissedAt?
       ├── clusterCentroid: Data?
       └── articles: [Article]

[Views]
  └── KnowledgeClipView
       └── DynamicTopicsSection (新)
            ├── 候補リスト (採用/却下/後で)
            └── 採用済リスト (重要度順、タップで詳細)
                 └── UserTopicDetailView (新)
                      └── 3 段落要約 + KeyFact + Entity
```

## Implementation Outline

### Phase 1: Foundation
- T001 [P] UserTopic @Model 新規 + SharedSchema 追加
- T002 [P] TopicNameOutput @Generable + LanguageModelSession 拡張
- T003 [P] UserTopicStore (CRUD + 重複 centroid check)
- T004 UserTopicStoreTests 5 ケース

### Phase 2: Clustering
- T005 K-means 実装 (Accelerate vDSP_dotpr / vDSP_vadd 使用)
  - cosine similarity ベース、L2 正規化済 embedding 前提
  - K = max(2, count/10)、上限 20
  - 収束: 100 iter or center 変化 < 0.01
- T006 TopicClusteringService.runIfDue() (起動時 + 7 日 batch、UserDefaults flag)
- T007 TopicClusteringServiceTests 7 ケース

### Phase 3: AI 命名 + UI 候補
- T008 LanguageModelSession.generateTopicName + Mock 拡張
- T009 DynamicTopicsSection 候補リスト UI (採用/却下/後で)
- T010 UserTopicCandidateRow

### Phase 4: 採用済 UI + 詳細画面
- T011 DynamicTopicsSection 採用済リスト (重要度順)
- T012 UserTopicDetailView (3 段落要約 + KeyFact + Entity + 元記事)
- T013 KnowledgeClipView 改修 (section 追加)

### Phase 5: Bootstrap + Polish
- T014 ServiceContainer に TopicClusteringService / UserTopicStore 追加
- T015 KnowledgeTreeApp で起動時 batch run
- T016 build 警告ゼロ + 既存テスト全回帰
- T017 CLAUDE.md / ROADMAP 更新
- T018 実機検証 (ユーザー)

## 主要研究項目

1. **K の最適化**: 記事数 / 10 で十分か、シルエット係数で動的決定すべきか
2. **clustering 速度**: 1000 articles × 512 dim で K-means 100 iter < 2 秒可能か (Accelerate ベンチ)
3. **重複 cluster 検出**: centroid 間 cosine similarity threshold (0.7?)、Spec 021 と同手法
4. **30 日 dismiss 期間**: 適切か (短すぎ / 長すぎ)、UserDefaults / @Model どちらで管理
5. **AI 命名 prompt 安定化**: 短い名前 (5-10 字)、技術用語回避
6. **batch 処理タイミング**: Cold start でユーザーが待たされない設計 (background Task で fire-and-forget)
7. **Empty state**: 記事 30 件未満時の guidance 文言

## MVP 範囲外

- ユーザー手動トピック名編集 / 削除 / 統合
- トピック間の関連グラフ可視化
- リアルタイム再 clustering (記事追加毎)
- 多階層 clustering (トピックの中のサブトピック)
- 共有 / エクスポート

## 依存関係

- **spec 021 の essence embedding 必須** — 未生成 Article は clustering に含まれない
- 新規インストール直後は記事少なくて clustering 不可 → Empty state guidance
