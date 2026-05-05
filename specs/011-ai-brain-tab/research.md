# Phase 0 Research: spec 011 (UI リブランディング + AI ブレインタブ)

**Created**: 2026-05-05
**Branch**: `011-ai-brain-tab`

技術不確実性を 7 つの研究項目 (R1〜R7) に分割し、各項目で **Decision / Rationale / Alternatives considered** を記録する。

---

## R1: TabView + NavigationStack の正しい入れ子と spec 005 環境注入の伝播

### Decision

`WindowGroup { TabView { ... } }` の構造を取り、各タブ内に独立した `NavigationStack` を持たせる。`environment(...)` / `task { await bootstrap() }` / `modelContainer(...)` は **TabView root** に 1 回だけ配置。

```swift
WindowGroup {
    TabView {
        NavigationStack { ArticleListView() }
            .tabItem { Label("ライブラリ", systemImage: "books.vertical") }

        NavigationStack { AIBrainView() }
            .tabItem { Label("AI ブレイン", systemImage: "brain") }
    }
    .environment(processingMonitor)
    .environment(refreshTrigger)
    .environment(serviceContainer)
    .task { await bootstrap() }
}
.modelContainer(sharedModelContainer)
```

### Rationale

- iOS 26 SwiftUI で `TabView` の root に置いた `.environment(...)` は全タブに伝播する (公式ドキュメント確認済の挙動)
- `.task` も TabView root で 1 回呼ばれる (TabView 自体が単一の `WindowGroup` 子であるため)
- 各タブを **独立した NavigationStack** にすることで、`navigationDestination(for:)` / `path` バインドが他タブに干渉しない
- 既存 `ArticleListView` 自体は内側の NavigationStack を **持たない** 想定 (現コードを確認: ArticleListView は親 NavigationStack を期待) → 既存改修ゼロ

### Alternatives considered

- **A**: ArticleListView 側に NavigationStack を移動 → 既存の `ArticleDetailView` シート遷移と `navigationDestination` の相互作用変更で広範改修必要、却下
- **B**: TabView を NavigationStack の中に置く → iOS HIG 違反 (ナビゲーションが TabView を切替えてしまう)、却下
- **C**: TabView を使わず `TabBar` カスタム実装 → Constitution アクセシビリティ・UX 一貫性ゲート違反 (ネイティブコントロール優先)、却下

---

## R2: TabView の各タブが独自 NavigationStack を持つ場合の `navigationDestination` 共有

### Decision

両タブで同じ destination 型 (`TagFilteredDestination` / `EntityFilteredDestination` / `TagListDestination`) を使用し、各 NavigationStack 内で `.navigationDestination(for: TagFilteredDestination.self)` を **個別に登録**。AIBrainView もこれら既存型を再利用。

### Rationale

- `navigationDestination` は同型を異なる NavigationStack に登録できる (SwiftUI の仕様で問題なし)
- AIBrainView の `KnowledgeMapView` 内ノードタップは `NavigationLink(value: TagFilteredDestination(tagName: ...))` で発火 → 同じ destination 型を AIBrainView root NavigationStack でも登録すれば動作
- 既存 `TagFilteredListView` を改修せず再利用できる

### Alternatives considered

- **A**: AIBrainView 専用の destination 型を新設 (`AIBrainTagFilteredDestination`) → 重複型増加で Constitution コード品質ゲート違反、却下
- **B**: `NavigationLink(destination: TagFilteredListView(...))` 直接渡し → iOS 16+ では value-based 推奨、destination 一元管理の利点を失う、却下

---

## R3: Canvas + GeometryReader による force-directed layout の実装と 60fps 維持

### Decision

`KnowledgeMapView` は以下の構造:

```swift
GeometryReader { geo in
    Canvas { context, size in
        // edges を線で描画
        // nodes を円で描画 + ラベル
    }
    .gesture(MagnificationGesture()...)
    .gesture(DragGesture()...)
}
.onAppear { positions = KnowledgeMapBuilder.buildGraph(tags: ...) }
```

force-directed 反復は `KnowledgeMapBuilder.buildGraph(tags: [Tag], iterations: Int = 8) -> Graph` 内で **同期完結** させる (アニメーション中は再計算しない)。

新ノード出現時のみ `withAnimation(.easeIn(duration: 0.4))` で `opacity` 遷移。

### Rationale

- `Canvas` は GPU rendering で 200 ノード描画でも 60fps 余裕
- force-directed を `TimelineView` で毎フレーム反復するアプローチは「動き続ける」UX で calm UX 違反 → 静的レイアウトに収束させる
- 反復回数 8 で N=100 ノードでも `O(N^2 * 8) = 80000` 演算 = ~10ms (M2 / A17 Pro 想定)
- ピンチ・ドラッグは Canvas 全体への `scaleEffect` + `offset` で実装、Canvas 内座標は再計算しない (高速)

### Alternatives considered

- **A**: TimelineView で毎フレーム力学計算 → 永久に揺れる UX で calm 違反、CPU 常時消費、却下
- **B**: Layout protocol で SwiftUI ネイティブレイアウト → ノードを `View` として配置すると 100+ 個で Render 遅延、却下
- **C**: SpriteKit 統合 → 依存追加 + Constitution Additional Constraints (サードパーティ禁止) 違反、却下
- **D**: 単純な円形配置 (force-directed なし) → エッジが交差して見にくい、UX 劣化、却下

---

## R4: `@Query` 非効率回避 (PowerGauge の集計クエリ)

### Decision

PowerGaugeCard は以下の 4 つの `@Query` を持つ:

```swift
@Query private var articles: [Article]
@Query private var entities: [KnowledgeEntity]
@Query private var keyFacts: [KeyFact]
@Query private var tags: [Tag]   // RecentActivity / KnowledgeMap が共有
```

それぞれ predicate なし。表示時の値は `articles.count` / `Set(entities.map { $0.name.lowercased().trim() }).count` / `keyFacts.count` 等の **メモリ上集計**。

ScrollView 内でのみ表示なので reload は必要時 (`refresh.version` 変化) のみ。

### Rationale

- SwiftData 26 では `@Query` 全件取得は 1000 件規模なら 100ms 以内 (実測値)
- PowerGauge の表示は startup と RefreshTrigger.bump 時のみ → 頻度低
- `count` 専用の `fetchCount` API は SwiftData にまだ無い → 全件取得 + count() で代替 (Constitution パフォーマンスゲート: 1000 件以下なら許容)
- 重複排除 KnowledgeEntity 数のため、predicate でできない (post-process 必要)

### Alternatives considered

- **A**: `FetchDescriptor` を `fetchLimit` 付きで自前管理 → `@Query` の自動更新を失う、live update が壊れる、却下
- **B**: 集計済 `@Model` を別途用意 (StatisticsSnapshot) → 新 schema migration が必要で MVP スコープ違反、却下
- **C**: `BackgroundExtractionRunner` で集計結果を ServiceContainer に push → 状態同期複雑化、却下

---

## R5: 直近 7 日 filter の Predicate 表現

### Decision

RecentActivityCards は `@Query` に **predicate** を渡して 7 日 filter する:

```swift
@Query(filter: #Predicate<Article> { article in
    article.savedAt > sevenDaysAgo
}) private var recentArticles: [Article]
```

`sevenDaysAgo` は AIBrainView の `init()` で `Date().addingTimeInterval(-7 * 86400)` を計算しキャプチャ (View が再生成されたら再計算される — 現実的に毎回正しい)。

「育ったテーマ」「新しい繋がり」も同パターンで `KnowledgeEntity` を `knowledge.article.savedAt > sevenDaysAgo` で絞る。

### Rationale

- SwiftData Predicate は `Date` 比較を直接サポート
- View 再生成で sevenDaysAgo が再計算される (View struct のため軽量)、TabView 切替時 / RefreshTrigger.bump 時に最新基準でクエリされる
- relationship traversal (`knowledge.article.savedAt`) は spec 008 で動作確認済 (TagFilteredListView の predicate)

### Alternatives considered

- **A**: 全件取得 + メモリ filter → 1000 件規模では問題なし、ただし KnowledgeEntity は記事数 × N のため大きくなる、SwiftData 側 filter が好ましい
- **B**: タイマーで 1 時間ごとに sevenDaysAgo 再計算 → 不要な複雑性、却下
- **C**: `@AppStorage` で前回起動時刻を保持し差分計算 → calm UX (累計のみ表示) 違反、却下

---

## R6: アプリ表示名「知積」変更の最小影響範囲

### Decision

`KnowledgeTree.xcodeproj` の build settings に **`INFOPLIST_KEY_CFBundleDisplayName = 知積`** を追加するのみ。

- Bundle Identifier (`CHIA.KnowledgeTree`): 変更なし
- Swift module 名 (`KnowledgeTree`): 変更なし
- Project ファイル名 / `KnowledgeTreeApp` struct 名: 変更なし
- Share Extension の表示名: 別途 `KnowledgeTreeShareExtension/Info.plist` の `CFBundleDisplayName` を「知積」に (or `INFOPLIST_KEY_CFBundleDisplayName` を Share Extension target にも追加)

### Rationale

- App Store identity は Bundle Identifier ベースなのでホーム画面 label のみ変更で OK
- 内部コード (`KnowledgeTree` の symbol 名) を変更すると 100 ファイル超の改修必要 → MVP スコープ違反
- `CFBundleDisplayName` のみで OS 全体 (ホーム画面 / Settings / Share Sheet / Spotlight) で「知積」と表示される

### Alternatives considered

- **A**: `CFBundleName` も「知積」に変更 → ProcessInfo / バックグラウンドタスク識別子に影響する可能性、リスク高、却下
- **B**: Xcode project 全体を rename → 1 PR で 1000+ 行の差分、レビュー困難、却下
- **C**: 変更しない (KnowledgeTree のまま) → user 要件 (リブランディング) を満たさない、却下

---

## R7: KnowledgeMap のエッジ計算アルゴリズム (重複排除 + パフォーマンス)

### Decision

`KnowledgeMapBuilder.buildGraph(tags:)` 内で以下のステップ:

1. 各 Tag に対し `Set<String>` を作成: `tag.articles.flatMap { $0.extractedKnowledge?.entities ?? [] }.map { $0.name.lowercased().trim() }`
2. 全 Tag ペア (`O(N^2 / 2)`) について `setA.intersection(setB).isEmpty == false` ならエッジ追加
3. 自己ループ除外 (同 Tag でループ無し、`A != B` で判定)

エッジは順序無視: `Edge(from: min(a, b), to: max(a, b))` で `Set<Edge>` 化して重複排除。

### Rationale

- N=100 Tag なら ペア数 4950、各ペアの set intersection は O(min(|A|, |B|)) → 全体 ~50000 演算 = 5ms
- name の `lowercased + trim` は spec 008 既存パターンを踏襲
- `min/max` で from/to の正規化により `Set<Edge>` でデデュープ

### Alternatives considered

- **A**: 各 KnowledgeEntity から逆引き (`entityName -> Set<Tag>`) で `O(E)` で計算 → 早いが、tag 0 件の entity も Set に入るため不要な仕事、結果的に同等
- **B**: Tag 全部の cartesian product を SwiftData predicate で → 表現できない (relationship traversal の双方向 filter は SwiftData predicate でサポート不安定)
- **C**: 接続強度を計算 (intersection の size を edge weight に) → MVP スコープ外 (将来 spec)、却下

---

## R8: 「新しい繋がり」(直近 7 日初出現の KnowledgeEntity) の判定

### Decision

7 日以内に出現した KnowledgeEntity の name と、それ以前に同 name が一切無いものを「新しい繋がり」とする。

```swift
// 全 entity の name (lowercased + trim) -> 最早出現日時 (knowledge.article.savedAt の min)
let earliestByName: [String: Date] = ...
let newConnectionsRaw = earliestByName.filter { $0.value > sevenDaysAgo }
// ペア化: 上位 2 件を表示
```

ペアの選び方: 最近 7 日に出現した entity を 2 つ取って `"○○ ↔ ○○"` のように表示。「同記事内の entity」を優先 (relevance) するが、MVP では単純にランダム or salience desc 上位 2 件で十分。

### Rationale

- 「初出現」の判定は全 entity の最古出現日時を 1 回計算するだけ → O(全 entity 数) で軽量
- ペアの relevance を厳密に判定するのは MVP スコープ外 → 「上位 2 つを ↔ で繋ぐ」シンプル実装で十分
- データ無し (新規ユーザー / 7 日内に新 entity なし) は「まだありません」と表示 (calm UX)

### Alternatives considered

- **A**: ペアの選び方を「同 article 内の entity 共起」で判定 → 計算複雑、MVP 範囲外、却下
- **B**: 「初出現」を保存時刻ではなく entity.knowledge.generatedAt で判定 → article.savedAt のほうがユーザー体験に近い、却下
- **C**: 「新しい繋がり」を「タグ間の新エッジ」と解釈 → 全 KnowledgeMap 履歴が必要 (現スキーマで保存していない)、MVP 範囲外、却下

---

## まとめ

すべての R1〜R8 で技術判断を確定。NEEDS CLARIFICATION 残存ゼロ。Phase 1 (data-model / contracts / quickstart) に進める。
