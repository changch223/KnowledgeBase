# Phase 0 Research: spec 015 (AI ブレイン v2 + DesignSystem migration + Category)

**Created**: 2026-05-05
**Branch**: `015-ai-brain-v2-categories`

技術不確実性を 10 項目 (R1〜R10) で記録。

---

## R1: Tag.categoryRaw lightweight migration の安全性

### Decision

`Tag` モデルに `var categoryRaw: String?` を追加 (default nil)。SwiftData の lightweight migration で対応。`SharedSchema.all` のバージョンは bump せず、既存 SwiftData インスタンスは attribute を nil で初期化する。

```swift
@Model
final class Tag {
    @Attribute(.unique) var name: String
    @Relationship(inverse: \Article.tags) var articles: [Article] = []
    var categoryRaw: String?  // ← spec 015 追加 (nil = 未分類 / fallback「その他」)

    init(name: String, categoryRaw: String? = nil) {
        self.name = name
        self.categoryRaw = categoryRaw
    }
}
```

### Rationale

- SwiftData は属性追加のみの変更を「lightweight migration」として自動処理 (VersionedSchema 不要)
- default nil で既存データ無傷
- `categoryRaw` は単純 String (Category enum でなく) → 将来 Category seed が変わっても safe (= forward compatibility)
- 値は `CategorySeed.allSeeds.map(\.name)` のいずれか + nil

### Alternatives considered

- **A**: VersionedSchema + ModelContainer Migration ステージング → SwiftData 26 では一部 unstable、spec 010 までで採用していない、却下
- **B**: Tag に Category model relationship → 双方向 relationship + cascade delete 必要、複雑性増、却下
- **C**: categoryRaw を `Tag` 外に保持 (例: 別 @Model `TagCategoryAssignment`) → join 必要、UI 集計コスト増、却下

---

## R2: AutoCategoryClassifier の Apple Foundation Models 統合

### Decision

```swift
@Generable
struct CategoryClassificationOutput: Sendable {
    @Guide(description: "テクノロジー / 経済 / 健康 / デザイン / 学術 / アート / ニュース / スポーツ / エンタメ / その他 のいずれか 1 つ")
    let categoryName: String
}

@MainActor
protocol AutoCategoryClassifier {
    func classify(tagName: String) async -> String  // 戻り値は CategorySeed.name のいずれか or "その他"
}

@MainActor
final class FoundationModelsAutoCategoryClassifier: AutoCategoryClassifier {
    private let session: LanguageModelSessionProtocol
    init(session: LanguageModelSessionProtocol = FoundationModelLanguageModelSession())
    func classify(tagName: String) async -> String {
        // SystemLanguageModel.availability チェック
        // 利用不可なら "その他" return
        // session.respond(to: prompt, generating: CategoryClassificationOutput.self) で推論
        // 出力 categoryName が CategorySeed に存在しなければ "その他" fallback
    }
}

@MainActor
final class InMemoryAutoCategoryClassifier: AutoCategoryClassifier {
    private let mapping: [String: String]
    init(mapping: [String: String] = [:])
    func classify(tagName: String) async -> String {
        mapping[tagName.lowercased()] ?? "その他"
    }
}
```

### Rationale

- `@Generable` struct で構造化出力 (Apple Foundation Models 標準パターン、spec 004 / 006 / 010 と同様)
- protocol で test 隔離 (Foundation Models 不要な test 環境用)
- 推論失敗 → 即 "その他" return で graceful (calm UX 維持)
- prompt は短く: 「次のタグはどのカテゴリーに属しますか?」+ tag.name + 候補 10 個列挙
- 推論時間想定: 1 Tag あたり 3-5 秒 (Foundation Models on-device)

### Alternatives considered

- **A**: 自前 keyword matching (例: "swift" → "テクノロジー") → 拡張性低、ニッチタグで誤分類、却下
- **B**: enum で type-safe な return → CategorySeed の更新で compile breaking、文字列の方が forward compatible、却下
- **C**: 複数カテゴリー return → MVP 範囲外 (`Tag.categoryRaw` は単一値のみ)、将来 spec、却下

---

## R3: シードカテゴリー定義 (struct + static let)

### Decision

```swift
struct Category: Hashable, Sendable {
    let name: String          // 日本語名 (Tag.categoryRaw に保存される値)
    let englishName: String   // 将来 i18n 用 (現状未使用)
    let order: Int            // 表示順 (0 = 上位)
    let symbolName: String    // 将来 UI で SF Symbol 表示する用 (現状未使用)
}

enum CategorySeed {
    static let allSeeds: [Category] = [
        Category(name: "テクノロジー",     englishName: "Technology",     order: 0, symbolName: "cpu"),
        Category(name: "経済",             englishName: "Economy",        order: 1, symbolName: "chart.line.uptrend.xyaxis"),
        Category(name: "健康",             englishName: "Health",         order: 2, symbolName: "heart"),
        Category(name: "デザイン",         englishName: "Design",         order: 3, symbolName: "paintbrush"),
        Category(name: "学術",             englishName: "Academic",       order: 4, symbolName: "book"),
        Category(name: "アート",           englishName: "Art",            order: 5, symbolName: "paintpalette"),
        Category(name: "ニュース",         englishName: "News",           order: 6, symbolName: "newspaper"),
        Category(name: "スポーツ",         englishName: "Sports",         order: 7, symbolName: "figure.run"),
        Category(name: "エンタメ",         englishName: "Entertainment",  order: 8, symbolName: "tv"),
        Category(name: "その他",           englishName: "Other",          order: 9, symbolName: "ellipsis.circle"),
    ]

    /// 指定 name でカテゴリー検索。見つからなければ「その他」を返す (= fallback)
    static func category(for name: String?) -> Category {
        guard let name else { return allSeeds.last! /* その他 */ }
        return allSeeds.first { $0.name == name } ?? allSeeds.last!
    }
}
```

### Rationale

- `static let allSeeds: [Category]` で order を Array 順序で保証
- struct は Sendable + Hashable で SwiftUI ForEach / dict key に使える
- `category(for:)` で nil / unknown を「その他」に正規化、UI 側の defensive コード不要
- englishName / symbolName は将来用、未使用でも保持 (forward compatibility)

### Alternatives considered

- **A**: `enum CategorySeed { case technology, economy, ... }` → display name の取得が switch case 必要、UI で扱いにくい、却下
- **B**: SwiftData @Model で Category 永続化 → Tag との relationship 必要、migration 複雑化、MVP 範囲外、却下
- **C**: JSON / plist 外部ファイル → 編集容易だが MVP では不要、コードに hardcode が単純、却下

---

## R4: BottomStatusBar phase tint 統一

### Decision

`BottomStatusBar.phaseTintColor(_ phase:)` 関数を全 case で `DS.Color.actionBlue` を返すように簡略化。phase 識別は `phaseLabel(_)` のテキストのみで担保。

```swift
private func phaseTintColor(_ phase: ProcessingMonitor.Phase) -> Color {
    DS.Color.actionBlue   // 全 phase で統一
}

private func phaseLabel(_ phase: ProcessingMonitor.Phase) -> LocalizedStringKey {
    switch phase {
    case .enrichment:        return "status.phase.enrichment"
    case .body:              return "status.phase.body"
    case .knowledge:         return "status.phase.knowledge"
    case .tagBackfilling:    return "status.phase.tagBackfilling"
    case .categoryClassifying: return "status.phase.categoryClassifying"  // spec 015 追加
    }
}
```

### Rationale

- DESIGN.md 「Don't introduce a second accent color」遵守
- phase は label text で十分区別可能、色で区別すると user に過剰な情報を与える (calm UX)
- 関数本体が「全 case 同じ return」なので拡張時の case 追加コスト最小

### Alternatives considered

- **A**: `phase.tintColor: Color` を enum extension に → 全 case 同じ値なら関数で十分、enum 拡張は冗長、却下
- **B**: phaseTintColor() を完全削除して view 側で `.tint(DS.Color.actionBlue)` 直書き → DesignSystem 経由が一貫性、却下

---

## R5: 廃止 view (PowerGauge / KnowledgeMap / RecentActivityCards) の token 残存処理

### Decision

`DesignSystem.swift` の旧 token (aiBrandStart 等) を **削除しない**。代わりに新 token への alias として残し、`@available(*, deprecated)` 等のマーカーは付けない (compile warning を増やさないため)。

```swift
enum Color {
    // === spec 015 新規 ===
    static let actionBlue       = SwiftUI.Color(red: 10/255, green: 77/255, blue: 140/255)
    static let actionBlueFocus  = SwiftUI.Color(red: 21/255, green: 101/255, blue: 184/255)
    static let parchment        = SwiftUI.Color(red: 250/255, green: 248/255, blue: 243/255)
    static let knowledgeTile    = SwiftUI.Color(red: 245/255, green: 245/255, blue: 247/255)
    static let tagFill          = SwiftUI.Color(red: 234/255, green: 234/255, blue: 239/255)

    // === spec 014 既存 (残す) ===
    static let surfacePrimary   = SwiftUI.Color(.systemBackground)
    static let surfaceSecondary = SwiftUI.Color(.secondarySystemBackground)
    // ... overlaySubtle / Light / Medium / textEmphasis ===

    // === spec 014 → 015 で「廃止予定」だが廃止 view が参照中なので alias 残し ===
    // 将来 spec で廃止 view (PowerGaugeCard / KnowledgeMapView / RecentActivityCards) 自体を削除する時、
    // 一緒に削除する。
    static let aiBrandStart      = actionBlue.opacity(0.10)   // 元: accentColor.opacity(0.15)
    static let aiBrandEnd        = actionBlue.opacity(0.20)   // 元: purple.opacity(0.15)
    static let aiBrandEdge       = SwiftUI.Color.secondary.opacity(0.25)
    static let aiBrandNodeFill   = actionBlue.opacity(0.10)
    static let aiBrandNodeStroke = actionBlue.opacity(0.55)
    static let phaseEnrichment   = actionBlue   // 全 phase 統一
    static let phaseBody         = actionBlue
    static let phaseKnowledge    = actionBlue
    static let phaseTagging      = actionBlue
}
```

### Rationale

- 廃止 view を本 spec で touch しない方針 (FR-039)
- 旧 token を新 token への alias 化で compile 維持
- 視覚的に actionBlue の単一トーンに変わる (= Apple-quiet 路線にも整合)
- 将来 spec で廃止 view 自体を削除する時、token も一緒に削除可能

### Alternatives considered

- **A**: 旧 token 参照を廃止 view 内で local Color literal に置換 → 廃止 view を触る必要、コミット重く、本 spec のスコープが膨らむ、却下
- **B**: 廃止 view 自体を削除 → 将来 spec で復活余地を残したい、却下
- **C**: `@available(*, deprecated)` マーカー → compile warning 大量、ノイズ、却下

---

## R6: AutoCategoryBackfillRunner の進捗表示

### Decision

`spec 013 AutoTagBackfillRunner` と完全同パターン:

```swift
@MainActor
final class AutoCategoryBackfillRunner {
    private let context: ModelContext
    private let classifier: AutoCategoryClassifier
    private let processingMonitor: ProcessingMonitor?
    private let flagStore: BackfillFlagStore
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "auto-category-backfill")

    static let backfillProcessingID = UUID(uuidString: "00000000-0000-0000-0000-CA7E0CEAA70F")!

    init(
        context: ModelContext,
        classifier: AutoCategoryClassifier,
        processingMonitor: ProcessingMonitor? = nil,
        flagStore: BackfillFlagStore = UserDefaultsBackfillFlagStore(key: "auto_category_backfill_v1_done")
    )

    func run() async {
        guard !flagStore.isCompleted() else { return }

        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.categoryRaw == nil }
        )
        let candidates = (try? context.fetch(descriptor)) ?? []

        guard !candidates.isEmpty else {
            flagStore.markCompleted()
            return
        }

        processingMonitor?.start(
            .categoryClassifying,
            articleID: Self.backfillProcessingID,
            title: "全タグのカテゴリー分類中",
            progressIndex: 0,
            progressTotal: candidates.count
        )

        for (i, tag) in candidates.enumerated() {
            let categoryName = await classifier.classify(tagName: tag.name)
            tag.categoryRaw = categoryName
            try? context.save()
            processingMonitor?.updateProgress(
                articleID: Self.backfillProcessingID,
                index: i + 1
            )
        }

        processingMonitor?.finish(articleID: Self.backfillProcessingID)
        flagStore.markCompleted()
    }
}
```

### Rationale

- spec 013 の AutoTagBackfillRunner と同じ構造で保守容易
- `BackfillFlagStore` を再利用 (key だけ変える)
- ProcessingMonitor 新 phase `.categoryClassifying = 4` で BottomStatusBar 連携
- 1 件ずつ classify して直ちに save → 中断時も部分結果が残る
- `predicate: $0.categoryRaw == nil` で対象を絞る → 既存 categorized Tag は触らない

### Alternatives considered

- **A**: 全 Tag 一括 classify → 推論遅延中の中断リスク、却下
- **B**: 1 度のみ classify (再 backfill 不可) → 失敗 Tag のリトライ余地ない、却下
- **C**: spec 013 を generic backfill runner にリファクタ → スコープ膨らむ、却下

---

## R7: TagStore.addTag からの classify 呼び出し

### Decision

`TagStore.addTag(rawName:to:)` 内で新規 Tag 作成後、fire-and-forget Task で classifier を呼び出し:

```swift
@discardableResult
func addTag(rawName: String, to article: Article) throws -> String? {
    // ... 既存ロジック (TagNormalizer / 重複チェック / context.insert) ...

    if isNewTag, let classifier {
        // fire-and-forget で分類 (Tag 作成自体は同期で成功)
        Task { [weak self] in
            guard let self else { return }
            let categoryName = await classifier.classify(tagName: tag.name)
            await MainActor.run {
                tag.categoryRaw = categoryName
                try? self.context.save()
                self.refreshTrigger?.bump()
            }
        }
    }

    try context.save()
    refreshTrigger?.bump()
    return normalized
}
```

`AutoCategoryClassifier` を `TagStore` のイニシャライザに optional inject。default nil で classify 走らず、後方互換。

### Rationale

- Tag 作成は同期成功、classify は非同期で後追い
- 失敗しても Tag は残る (graceful)
- 既存 spec 008 / 012 の挙動変更ゼロ (classifier nil で動作不変)
- `refreshTrigger?.bump()` で UI 更新 (Category List に新 Tag 反映)

### Alternatives considered

- **A**: addTag を async にして classify を待つ → 既存呼び出し側 (spec 012 AutoTagApplier ループ) が遅延、却下
- **B**: classify を別 service (TagClassifierObserver) で trigger → 複雑性増、却下
- **C**: classifier 呼び出しを bootstrap backfill のみに限定 → 新 Tag が分類されないまま、却下

---

## R8: AIBrainView v2 構造

### Decision

```swift
struct AIBrainView: View {
    @Environment(ProcessingMonitor.self) private var monitor
    @Query private var allTags: [Tag]

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: DS.Spacing.section) {
                        AIBrainStatsRow()
                            .padding(.horizontal, DS.Spacing.xxl)

                        AIInsightCard(tags: allTags)
                            .padding(.horizontal, DS.Spacing.xxl)

                        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                            Text("aibrain.categories.heading")
                                .font(DS.Typography.sectionTitle)
                                .padding(.horizontal, DS.Spacing.xxl)

                            CategoryListSection(tags: allTags)
                        }
                    }
                    .padding(.vertical, DS.Spacing.xxl)
                }
                .scrollIndicators(.hidden)
                .navigationTitle("aibrain.tab.title")
                .navigationDestination(for: TagFilteredDestination.self) { dest in
                    TagFilteredListView(tagName: dest.tagName)
                }

                BottomStatusBar(monitor: monitor)
            }
        }
        .accessibilityIdentifier("aibrain.root")
    }
}

private struct CategoryListSection: View {
    let tags: [Tag]

    var groupedByCategory: [(Category, Int)] {
        // categoryRaw でグループ化、各グループの記事数集計、降順 sort
        Dictionary(grouping: tags) { CategorySeed.category(for: $0.categoryRaw) }
            .map { (category, tags) in
                let articleCount = Set(tags.flatMap { $0.articles.map(\.id) }).count
                return (category, articleCount)
            }
            .filter { $0.1 > 0 }
            .sorted { ($0.1, -$0.0.order) > ($1.1, -$1.0.order) }
    }

    var maxCount: Int {
        groupedByCategory.first?.1 ?? 1
    }

    var body: some View {
        if groupedByCategory.isEmpty {
            ContentUnavailableView { ... }
        } else {
            LazyVStack(spacing: 0) {
                ForEach(groupedByCategory, id: \.0) { (category, count) in
                    KnowledgeCategoryRow(
                        category: category,
                        articleCount: count,
                        maxCount: maxCount,
                        topTagName: ... // for navigation
                    )
                    Divider()
                }
            }
        }
    }
}
```

### Rationale

- ScrollView 1 本、3 セクション縦並び (DS.Spacing.section = 24pt)
- 各セクションは独立 view ファイルで分離 (test 容易)
- Category 集計は CategoryListSection 内で computed property、`@Query<Tag>` 1 回で取得
- LazyVStack で 100+ Category の効率的レンダリング

### Alternatives considered

- **A**: List に切り替え → セパレータ制御が制限的、却下
- **B**: ForEach 直 (LazyVStack なし) → 100+ Tag で遅延、却下
- **C**: 各セクションを 1 view に集約 → 巨大 view、test 困難、却下

---

## R9: テスト戦略

### Decision

| ファイル | ケース数 | 内容 |
|---|---:|---|
| `AutoCategoryClassifierTests.swift` | 5 | mock classify / fallback / unknown name / lowercased / async cancellation |
| `AutoCategoryBackfillRunnerTests.swift` | 7 | flag false 実行 / flag true skip / categoryRaw nil only / 既に classified skip / 全 nil → 全分類 / classify 失敗 → "その他" / empty database |
| 既存 `KnowledgeMapBuilderTests` | 11 | 無傷 (KnowledgeMapView は廃止だが builder service は残す、後方互換) |
| 既存 `RecentActivitySnapshotBuilderTests` | 7 | 同上 |
| 既存 `AutoTagApplierTests` / `AutoTagBackfillRunnerTests` | 14 | 無傷 |
| `AIBrainTabUITests.swift` | 改修 6 → 4 | 旧 6 ケースのうち PowerGauge / KnowledgeMap / RecentActivity 系 5 ケースを廃止、新 4 ケース (Stats Row / Insight Card / Category List 表示 + ライブラリタブ回帰) に書き換え |

`private typealias Tag = KnowledgeTree.Tag` で SwiftUI Tag 衝突解消 (spec 011/012/013 同パターン)。

### Rationale

- 新規テスト 12 ケース、既存無傷 49 ケース、UI test 4 ケースで合計 65 ケース
- spec 014 までの 66 unit テストとほぼ同規模
- AutoCategoryClassifier の Foundation Models 統合 test は実機/Simulator で要確認 (mock 中心)

### Alternatives considered

- **A**: snapshot test 追加 → swift-snapshot-testing 等の依存追加が必要、Constitution Additional Constraints 違反、却下
- **B**: AIBrainTabUITests 既存 6 ケースを保持 → 廃止 view の identifier 参照で fail、却下

---

## R10: 古い AIBrainTabUITests との互換性

### Decision

spec 011 で書いた 6 UI test のうち、PowerGauge / KnowledgeMap / RecentActivity 関連の 4-5 ケースは **delete + 4 新ケースに置き換え**:

| 旧 (spec 011) | 新 (spec 015) |
|---|---|
| `testLibraryTabRetainsExistingBehavior` | ✅ 保持 |
| `testAIBrainTabShowsPowerGauge` | ❌ 削除 → `testAIBrainTabShowsStatsRow` |
| `testAIBrainRootAccessibilityIdentifier` | ✅ 保持 |
| `testKnowledgeMapPresent` | ❌ 削除 → `testCategoryListPresent` |
| `testKnowledgeMapEmptyStateOnFreshInstall` | ❌ 削除 → `testCategoryListEmptyStateOnFreshInstall` |
| `testRecentActivityCardsPresent` | ❌ 削除 → `testInsightCardPresent` |

新 identifier:
- `aibrain.stats_row` (StatsRow)
- `aibrain.insight_card` (InsightCard)
- `aibrain.category_list` (CategoryList container)
- `aibrain.category_list.empty` (empty state)
- `aibrain.category_row.{name}` (各 Category 行)

### Rationale

- 廃止 view 自体は残るが AIBrainView から外れる → identifier も AIBrainView 経由では到達不可能
- 新 identifier で v2 layout を検証
- `testLibraryTabRetainsExistingBehavior` と `testAIBrainRootAccessibilityIdentifier` は v2 でも有効 → 保持

### Alternatives considered

- **A**: 旧 UI test 全削除 + 新 7 ケース → 既存 fixture 構築コスト + ライブラリタブ回帰 test 重要なので、旧 2 件保持が現実的
- **B**: 旧テストに skip マーカー → 後で消し忘れリスク、却下

---

## まとめ

R1〜R10 で全技術判断確定。NEEDS CLARIFICATION 残存ゼロ。

**コア発見**:
- Tag.categoryRaw は lightweight migration、既存データ無傷
- AutoCategoryClassifier protocol で Foundation Models / mock 差し替え可能
- 廃止 view の token alias 残しで本 spec のスコープを最小化
- BottomStatusBar phase tint 統一は phaseTintColor() 全 case actionBlue で達成
- 新 phase `.categoryClassifying = 4` を ProcessingMonitor に追加
- AIBrainView v2 は ScrollView 1 本 + 3 セクション独立 view 構成
- spec 011 UI test は 4-5 ケース置き換え、ライブラリ回帰 test は保持

**Phase 1 (data-model / contracts / quickstart) に進める準備完了。**
