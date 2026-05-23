# Research: ConceptPage 技術判断 (R1〜R10)

**Feature**: spec 042 ConceptPage (概念ページ)
**Phase**: 0 (Outline & Research)
**Date**: 2026-05-23

本ドキュメントは Technical Context の主要不確実性を 10 個の研究テーマに分解し、各 R で
**Decision / Rationale / Alternatives considered** を明示する。spec.md は技術中立で
書かれているため、本 research で初めて具体的な Swift / SwiftUI / SwiftData / Foundation
Models 実装方針を確定する。

---

## R1: ConceptPage `@Model` 構造とフィールド設計

### Decision

新規 `@Model final class ConceptPage` を 12 フィールドで定義。

```swift
@Model
final class ConceptPage {
    @Attribute(.unique) var id: UUID
    var name: String                                       // 表示用「主名」例: "Apple"
    var nameAliases: [String]                              // 同義語 ["アップル", "Apple Inc."]
    var categoryRaw: String                                // spec 015 と同 10 種固定 raw
    var summary: String                                    // AI 合成 200-400 字、初期 ""
    var crossSourceInsights: [String]                      // 0〜7 件
    @Relationship(deleteRule: .nullify) var relatedArticles: [Article] = []
    var relatedConceptIDs: [UUID]                          // 他 ConceptPage の id
    var userUnderstanding: Int                             // 0-5、初期 0 (内部、本 spec では未使用)
    var isFollowing: Bool                                  // ピン、初期 false
    var isStale: Bool                                      // BGTask 再合成フラグ、初期 true
    @Attribute(.externalStorage) var embedding: Data?      // [Float] L2-normalized
    var createdAt: Date
    var updatedAt: Date
}
```

`SharedSchema.all` に `ConceptPage.self` を追加。lightweight migration (SwiftData が
新規 @Model 追加を自動検知) で既存 store にゼロダウンタイム適用。

### Rationale

- `@Attribute(.unique) var id: UUID` は既存 @Model (Article / KnowledgeEntity /
  KnowledgeDigest / GraphNode) と統一。
- `@Relationship(deleteRule: .nullify)` で **Article 側は不変**、ConceptPage が消えても
  raw データ保護 (Constitution III + spec.md FR-016)。inverse 関係は SwiftData が
  自動推論 (`Article` 側に `var conceptPages: [ConceptPage]?` を **足さない** ことで
  片方向参照に留め、既存 Article への影響ゼロ)。
- `relatedConceptIDs: [UUID]` を **@Relationship ではなく ID 配列** にした理由:
  ConceptPage 同士の N:N は将来 spec 045 (Community) と spec 047 (WikiLint) で
  graph 拡張する可能性があり、`@Relationship` で固定するとマイグレーション負担。
  ID 配列なら lookup は ModelContext の fetch で足る。
- `embedding: Data?` `@Attribute(.externalStorage)` は spec 021
  `Article.essenceEmbedding` と同方式。L2 正規化済 `[Float]` を Data に zero-copy
  化、SwiftData blob 外部ファイル保存で row サイズを膨らませない。
- `categoryRaw: String` は spec 015 の 10 種固定 raw 値 (`Tag.categoryRaw` と同
  vocabulary) を使う。assumption「同 entity でも categoryRaw 別に ConceptPage」を
  ID + (name, categoryRaw) で実現 (Service 側で重複判定)。
- `isStale: Bool` 初期値 `true` で「未合成」状態を表現。BGTask が拾って初回合成。
- `userUnderstanding: Int` (0-5) は本 spec では永続化のみ実装、surface は spec 049
  (Understanding Chat / 学習タブ) で扱う。冗長と見えるが、後で migration せずに
  済むよう先行追加。

### Alternatives considered

- **Article ↔ ConceptPage 双方向 `@Relationship`**: 却下。Article へのスキーマ影響を
  避けたい (既存 spec 全体に regression リスク)。inverse 推論で十分。
- **`relatedConceptIDs` を `@Relationship var relatedConcepts: [ConceptPage]` に**:
  却下。SwiftData の self-referencing @Relationship は migration が複雑化、本 spec
  では fetch 経由で十分。
- **`embedding` を `[Float]` 直接**: SwiftData は `[Float]` を直接サポートするが、
  `.externalStorage` 指定が困難で row サイズが膨らむ。`Data?` + ext で zero-copy
  変換が確立済 (spec 021)。

---

## R2: 自動生成トリガー (extract hook)

### Decision

`KnowledgeExtractionService.extract(article:)` の末尾に fire-and-forget Task で
`conceptSynthesisService?.processNewArticle(article:)` を呼ぶ。spec 037
ConflictDetection / spec 040 GraphExtraction と完全同パターン:

```swift
// KnowledgeExtractionService.swift extract 末尾 (single + chunked パス両方)
Task { [weak self] in
    await self?.conceptSynthesisService?.processNewArticle(article: article)
}
```

`processNewArticle` の中で:
1. article から KnowledgeEntity 一覧を取得
2. 各 entity (name, categoryRaw) について同名 ConceptPage を fetch (大文字小文字無視 + aliases 考慮)
3. **既存あり** → `isStale = true` + `updatedAt = .now` でマーク (再合成は BGTask)
4. **既存なし & 他 Article に 1+ 件登場 (= 今回で 2+ 件目)** → 新規 ConceptPage 生成 + isStale = true
5. **既存なし & 他 Article にゼロ** → 何もしない (graph ノードのみ)

### Rationale

- 既存 spec 037/040 の fire-and-forget hook パターンは本番安定動作実績あり。エラー時も
  silent 失敗で extract 本体に影響しない (Constitution V calm UX + SC-008)。
- 同期にしない理由: ConceptSynthesis は Foundation Models 呼び出しを含むため数秒〜
  数十秒かかる、extract の per-article latency に影響させない。
- 2+ 件目で自動生成する判定は「過去全 Article から同 entity を持つ件数」を `FetchDescriptor`
  で count する純粋関数で実装 (テスト容易)。
- `chunked` パスでも同 hook を呼ぶ (spec 010 hierarchical 経路) — 末尾 1 箇所に集約。

### Alternatives considered

- **extract 内で同期実行**: 却下。latency 悪化 + UI thread blocking リスク。
- **BGTask だけで遅延処理**: 却下。SC-001「2 件目記事保存から 30 秒以内に ConceptPage 確認」
  を満たすには新記事 ingest 時点で即時 `isStale = true` セットが必要。
- **NotificationCenter で通知**: 却下。既存パターンが Task + protocol 注入で確立済、
  別パターン導入は維持コスト増。

---

## R3: ConceptSynthesisService の Foundation + Fallback 2 経路

### Decision

spec 018 KnowledgeDigestService と同パターン:

```swift
@MainActor
protocol ConceptSynthesisServiceProtocol: AnyObject {
    func processNewArticle(article: Article) async
    func resynthesize(_ conceptPage: ConceptPage) async
    func resynthesizeAllStale() async
    func backfillFromExistingArticles() async
}

@MainActor
final class FoundationModelsConceptSynthesisService: ConceptSynthesisServiceProtocol {
    private let session: LanguageModelSessionProtocol
    private let availability: AvailabilityChecker
    private let fallback: ConceptSynthesisServiceProtocol
    private let embeddingService: EmbeddingServiceProtocol
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger

    // availability OK → session、NG → fallback に委譲
}

@MainActor
final class FallbackConceptSynthesisService: ConceptSynthesisServiceProtocol {
    // essence + KeyFact を機械的に並べた簡易 summary 生成
    // crossSourceInsights は最初の 3 件の essence をそのまま採用
}
```

`availability.isAvailable` チェックは各 public method 冒頭で 1 回、`false` なら
fallback に委譲。Foundation 経路で例外発生時も同様。

### Rationale

- spec 018 で確立した 2 経路パターンは Mock テスト容易 (`isAvailable` を切り替えるだけ
  で両経路をカバー)。
- Fallback service は AI を呼ばないので決定論的、unit test の expected value 検証が容易。
- `@MainActor` 制約は SwiftData ModelContext の thread affinity 要件のため (既存 service
  全て同じ)。
- `EmbeddingServiceProtocol` 経由で spec 021 と疎結合 (NLEmbedding 不可端末でも nil
  返却で degrade)。

### Alternatives considered

- **availability チェックを Service 外部に出す**: 却下。spec 018 同パターンで内部チェック
  に統一済、bootstrap で 1 経路に固定すると非対応端末で fall-through できない。
- **Fallback を Service ではなく inline if-let**: 却下。テスト時に Foundation 経路と
  Fallback 経路を別々に検証したい、Service 分離が clean。

---

## R4: `@Generable ConceptSynthesisOutput` と prompt 設計

### Decision

`LanguageModelSessionProtocol.swift` に新 @Generable struct を追加:

```swift
@Generable
struct ConceptSynthesisOutput: Codable {
    @Guide(description: """
    概念について複数の保存記事から統合した「今わかっていること」。
    200〜400 字の日本語。
    重要: 推測や一般知識から補強した内容は含めない。原文に明示された内容のみを統合すること。
    主語は省略可、です・ます調ではなく断定調 (「である / する / だ」) で書く。
    """)
    let summary: String

    @Guide(description: """
    複数記事を横断して見える知見の bullet 配列。最大 7 件、各 50〜150 字の日本語。
    「単一記事だけでは見えない発見」を含める。例:
    - 「A 社と B 社が異なる時期に同じ戦略を取った」
    - 「2024 年から 2026 年にかけて方針が変化している」
    記事に書かれていない推測は含めないこと。
    """)
    let crossSourceInsights: [String]
}
```

`LanguageModelSessionProtocol` に
`func generateConceptSynthesis(prompt: String) async throws -> ConceptSynthesisOutput`
を追加、`FoundationModelLanguageModelSession` 実装、`MockLanguageModelSession`
拡張 (deterministic な fixture 返却 + scenario 切替)。

Prompt は以下のテンプレ:
```
あなたは複数の保存記事から「{name}」について「今わかっていること」を統合する役割です。

## 概念
名前: {name}
別名: {aliases}
カテゴリー: {categoryDisplay}

## 元記事 (essence + KeyFact)
{記事ごとに}
- [{index}] {title} / {savedAt}
  essence: {essence}
  KeyFact: {keyFacts joined}

## 出力要件
- summary: 200-400 字、原文に明示された内容のみ統合
- crossSourceInsights: 最大 7 件、各 50-150 字、複数記事を並べて初めて見える発見
- 推測・一般知識からの補強禁止
```

### Rationale

- spec 040 GraphTripleOutput / spec 018 DigestOutput と同 @Generable パターン、Foundation
  Models が Codable struct を直接返してくれるので JSON parse 不要。
- `@Guide` description は spec 018 の知見「推測禁止を明示すると幻覚率が下がる」を踏襲、
  Constitution III ハルシネーション抑止 + FR-031 を実現する prompt 制約として機能。
- 200-400 字制約は spec.md SC-002 を直接反映。Foundation Models は @Guide 制約に
  概ね従うが、ConceptSynthesisService 側で文字数超過時の trim (suffix 切り捨て + "…")
  を 1 段噛ます (post-process)。
- crossSourceInsights は配列なので空配列 (1 記事しか合成材料がない場合) も valid。

### Alternatives considered

- **summary + crossSourceInsights を別 prompt で 2 回呼ぶ**: 却下。トークン 2 倍 + 一貫性
  低下。1 prompt 1 struct で十分。
- **fact list を構造化フィールドで持つ**: 却下。spec 037 ConflictProposal とスコープ重複、
  本 spec は「概念を読める文章で提示」が目的。
- **prompt 内で「英語で書け」**: 却下。Constitution VII 日本語ファースト、固有名詞は
  原文維持 (英語 entity 名は英語のまま) で十分。

---

## R5: hierarchical + meta-summary パターン (5+ 関連記事対応)

### Decision

ConceptPage.relatedArticles が `count >= 5` の場合、spec 010 と同パターンで chunked:

```
1. relatedArticles を [essence + KeyFact joined] のテキスト配列に変換
2. テキスト配列を chunk_size = 4 で分割 (5-8 件 → 2 chunk, 9-12 → 3 chunk, ...)
3. 各 chunk について Foundation Models で「この 4 記事の要点をまとめろ」prompt 実行
   → ConceptSummaryChunk struct (`@Generable` 簡易 1 フィールド)
4. 全 chunk 要約を結合した meta-text を作り、最終 prompt (R4 同形式) に渡す
5. 結果の summary + crossSourceInsights を ConceptPage に保存
```

実装は `FoundationModelsConceptSynthesisService.synthesizeWithHierarchy(_:)`
private method として隔離 (4 件以下は直接 R4 prompt)。

### Rationale

- Foundation Models の context window は約 4K-8K token と狭く、5+ 記事の essence
  (各 300-500 字) + KeyFact (各 200-300 字) を 1 prompt に詰め込むと overflow リスク。
- spec 010 で確立済の hierarchical パターンは既に hot-fix 含めて安定動作中、本 spec で
  別実装する必要なし。
- chunk_size = 4 は spec 010 の経験値 (3 だと chunk 多すぎ、5 だと per-chunk overflow)。
- meta-summary 段階で crossSourceInsights を抽出するので、横断知見の検出は失われない。

### Alternatives considered

- **常に chunked パス**: 却下。1-4 記事なら 1 prompt で十分 + latency 良い。
- **chunk_size を動的決定**: 却下。複雑化、固定 4 で十分。
- **Embedding 類似度で重要記事だけ選別**: 将来検討 (V2 candidate)。本 spec では全件取り込み。

---

## R6: ConceptPageStore (rename / merge / delete / setFollowing)

### Decision

spec 024 TagStore + spec 041 GraphNodeStore と完全同パターン:

```swift
@MainActor
final class ConceptPageStore {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger

    enum ConceptPageStoreError: Error {
        case emptyName, nameTooLong, duplicateInCategory, sameSourceTarget
    }

    @discardableResult
    func rename(_ conceptPage: ConceptPage, to newName: String) throws -> ConceptPage {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .emptyName }
        guard trimmed.count <= 30 else { throw .nameTooLong }
        // 同 category 内重複チェック (大文字小文字無視)
        // ...
        conceptPage.name = trimmed
        conceptPage.updatedAt = .now
        conceptPage.isStale = true  // 名前変更で再合成
        try context.save()
        refreshTrigger.bump()
        return conceptPage
    }

    func merge(source: ConceptPage, into target: ConceptPage) throws {
        guard source.id != target.id else { throw .sameSourceTarget }
        // relatedArticles を union (重複除外、SwiftData @Relationship)
        for article in source.relatedArticles where !target.relatedArticles.contains(where: { $0.id == article.id }) {
            target.relatedArticles.append(article)
        }
        // relatedConceptIDs を union
        target.relatedConceptIDs = Array(Set(target.relatedConceptIDs + source.relatedConceptIDs)).filter { $0 != target.id }
        // nameAliases に source.name と source.aliases を追加
        target.nameAliases = Array(Set(target.nameAliases + [source.name] + source.nameAliases))
        // userUnderstanding は max
        target.userUnderstanding = max(target.userUnderstanding, source.userUnderstanding)
        // isFollowing は or
        target.isFollowing = target.isFollowing || source.isFollowing
        target.isStale = true
        target.updatedAt = .now
        context.delete(source)
        try context.save()
        refreshTrigger.bump()
    }

    func delete(_ conceptPage: ConceptPage) throws {
        // 他 ConceptPage の relatedConceptIDs から削除
        let descriptor = FetchDescriptor<ConceptPage>()
        let all = try context.fetch(descriptor)
        for other in all where other.id != conceptPage.id {
            other.relatedConceptIDs.removeAll { $0 == conceptPage.id }
        }
        context.delete(conceptPage)
        try context.save()
        refreshTrigger.bump()
    }

    func setFollowing(_ conceptPage: ConceptPage, isFollowing: Bool) throws {
        conceptPage.isFollowing = isFollowing
        conceptPage.updatedAt = .now
        try context.save()
        refreshTrigger.bump()
    }
}
```

### Rationale

- TagStore / GraphNodeStore と同 API 表面 + 同 error enum パターン → 学習コスト低、
  テストも横展開しやすい。
- rename / merge 時 `isStale = true` 設定で BGTask 再合成 → 「edit したら summary も
  更新される」が自然に成立。
- delete 時の relatedConceptIDs 掃除は SwiftData が自動でやらないので明示。
- `refreshTrigger.bump()` で全 @Query が再評価 (既存パターン)。

### Alternatives considered

- **`actor`** にする: 却下。SwiftData ModelContext は `@MainActor` 前提、既存パターン
  と整合。
- **delete cascade で関連 Article も消す**: 却下。spec.md FR-016 + Constitution III、
  Article は raw データなので保護。
- **merge を「source.relatedArticles 全部移して source は残す」(空殻化)**: 却下。
  ユーザーは「2 つを 1 つにした」mental model で operation するはず、source は消す。

---

## R7: 知識 Clip タブ新セクション + Card UI

### Decision

`KnowledgeClipView` に新セクション追加。既存セクション群 (RecentDigestSection /
FactConflictsSection / DynamicTopicsSection / KnowledgeDigest 群) の **間に挿入**
する位置は **FactConflictsSection の下、DynamicTopicsSection の上** とする。

セクション実装:
```swift
@Query(
    filter: #Predicate<ConceptPage> { $0.relatedArticles.count >= 2 },
    sort: [SortDescriptor(\.isFollowing, order: .reverse),
           SortDescriptor(\.updatedAt, order: .reverse)],
    animation: .default
) private var conceptPages: [ConceptPage]

// body:
if !conceptPages.isEmpty {
    VStack(alignment: .leading) {
        Text("あなたが追っている人物・モノ")
            .font(.dsSectionTitle)
        ForEach(conceptPages.prefix(5)) { conceptPage in
            NavigationLink(value: ConceptPageDetailDestination(id: conceptPage.id)) {
                ConceptPageCard(conceptPage: conceptPage)
            }
        }
        if conceptPages.count > 5 {
            NavigationLink("+\(conceptPages.count - 5) すべて見る", value: ConceptPageListDestination())
                .font(.dsCaption)
        }
    }
}
```

`ConceptPageCard` view (~80 行):
- 行 1: SF Symbol (categoryRaw 別アイコン) + name (font .dsBodyEmphasized) + 関連記事数 badge
- 行 2: summary preview 1 行 (lineLimit(1), truncationMode: .tail)
- 行 3: 「最終更新: 3 日前」(SavedAtFormatter 流用)

タップ → NavigationDestination 経由で `ConceptPageDetailView` 表示。

### Rationale

- `@Query` の `#Predicate { $0.relatedArticles.count >= 2 }` で「2+ 件持つ」だけ表示
  (FR-001 と整合)。
- `SortDescriptor(\.isFollowing, order: .reverse)` で pin が上に固定 (FR-020)。
- `prefix(5)` + 「+N すべて見る」link で 60fps 維持 (SC-007、上位 5 のみ render)。
- セクション挿入位置は既存 spec 018 (Digest) / 037 (Conflict) / 036 (DynamicTopics) と
  視覚 hierarchy 整合性確認、Conflict と DynamicTopics の間が「読むべきもの」と
  「探索できるもの」の境界として自然。

### Alternatives considered

- **「+N すべて見る」を別 view**: 既存パターン (spec 016 CategoryFilteredListView と
  同) で別 view (`ConceptPageListView`) を実装、`@Query` 全件 + `LazyVStack`。
- **NavigationLink の value 型を `ConceptPage` 直接**: 却下。SwiftData @Model は
  Hashable だが NavigationStack で渡すには ID transient wrapper が安全 (spec 016 パターン)。
- **空状態でもセクションヘッダー表示**: 却下。Constitution V calm UX、空なら見せない。

---

## R8: ConceptPageDetailView (4 セクション)

### Decision

ScrollView + 4 セクション + toolbar:

```swift
struct ConceptPageDetailView: View {
    @Bindable var conceptPage: ConceptPage
    @Environment(\.modelContext) private var context
    @State private var showEditSheet = false
    @State private var conceptPageStore: ConceptPageStore?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection          // 名前 + categoryRaw chip + 関連記事数 + 最終更新
                summarySection         // 「今わかっていること」 (summary 本文 or 「整理中…」)
                crossSourceInsightsSection  // 「横断的知見」(bullet list)
                relatedArticlesSection      // 「関連記事」(NavigationLink to ArticleDetailView)
                relatedConceptsSection      // 「つながる人物・モノ」(他 ConceptPage への NavigationLink)
            }
            .padding(.dsContentPadding)
        }
        .navigationTitle(conceptPage.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditSheet = true } label: { Image(systemName: "ellipsis.circle") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: bindingForFollowing) { Image(systemName: "pin") }
                    .toggleStyle(.button)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ConceptPageEditSheet(conceptPage: conceptPage, store: conceptPageStore!)
        }
    }
}
```

各セクションの「整理中…」placeholder:
- `summary.isEmpty || isStale` → 「整理中… AI が複数記事を統合しています」テキスト
- crossSourceInsights が空 → セクション自体非表示 (空 bullet を出さない)

`relatedConceptsSection` の表示:
- `relatedConceptIDs` から該当 ConceptPage を fetch (in-memory cache、最初 8 件)
- 各 ConceptPage を `NavigationLink(value: ConceptPageDetailDestination(id:))` で再帰遷移可能

### Rationale

- ScrollView + VStack の 4 セクション固定順は spec.md US3 + FR-022 を直接反映。
- `@Bindable` で ConceptPage 変更 (rename / pin) が即座に view 反映 (spec 015/016 同パターン)。
- toolbar の「ピン」を独立 Toggle にすることで edit sheet を開かずに 1 タップで pin
  on/off (UX 改善、calm UX)。
- relatedConceptsSection で再帰遷移可能なので、ユーザーは概念から概念へ「ウィキ的に
  探索」できる (Karpathy LLM Wiki 思想の探索動線)。

### Alternatives considered

- **TabView で 4 セクション切替**: 却下。短時間確認用途には scroll が速い。
- **summary を Markdown rendering**: 却下。本 spec の summary は plain text、Markdown
  rendering は spec 049 (Understanding Chat) で別途。
- **「関連記事」を grid 表示**: 却下。Article は list が既存パターン (ArticleListView)、
  整合性優先。

---

## R9: BGTask での stale 再合成

### Decision

新 BGTaskIdentifier `app.KnowledgeTree.conceptResynthesis` を Info.plist の
`BGTaskSchedulerPermittedIdentifiers` に追加。`KnowledgeTreeApp.init` で register、
spec 009 `BackgroundExtractionScheduler` と並列で動作する
`ConceptResynthesisScheduler` (新規ファイル不要、`BackgroundExtractionScheduler.swift`
内に追加 or 既存 service に static method 追加) で実装:

```swift
// BackgroundExtractionScheduler 末尾に追加
static func registerConceptResynthesisTask(synthesisService: ConceptSynthesisServiceProtocol?) {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "app.KnowledgeTree.conceptResynthesis", using: nil) { task in
        Task { @MainActor in
            await synthesisService?.resynthesizeAllStale()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { task.setTaskCompleted(success: false) }
    }
}
```

`resynthesizeAllStale` の内部実装:
- `FetchDescriptor<ConceptPage>(predicate: #Predicate { $0.isStale })` + `fetchLimit = 5`
- 取得した 0-5 件を順次 `resynthesize(_:)` (Foundation 経路、~5-15 秒 per page)
- 終わったら `BGAppRefreshTaskRequest` で次回 (1 時間後) スケジュール

bootstrap で `scheduleNextRun()` を起動時に 1 度呼ぶ (既存 spec 009 と同パターン)。

### Rationale

- BGAppRefreshTask は通常 30 秒以内で完了する必要、5 件 × 平均 10 秒 = 50 秒は overrun
  リスク → 3 件まで、または timeout 切り上げ。spec 009 で同じ調整経験あり。
- expirationHandler で task.setTaskCompleted(success: false) を返すと OS が次回再試行を
  スケジュール、安全。
- Stale 連鎖更新 (Article 大量保存後) でも徐々に消化される設計。
- Foundation Models 不可端末では Fallback service 経路が走るので silent degrade、
  ユーザーには Stale のままに見える (acceptable for V1)。

### Alternatives considered

- **既存 BackgroundExtractionScheduler に統合 (同 BGTask で extract + synthesize)**:
  却下。priority / cadence が異なる、別 task identifier の方が OS schedule 制御が
  細かい。
- **app foreground でも resynthesize**: 却下。foreground 中の Foundation Models 呼び出しは
  UI 競合リスク、background 専用に。
- **BGProcessingTask** (長時間 task): 却下。BGAppRefreshTask で十分、過剰指定すると
  実行頻度低下。

---

## R10: テスト戦略

### Decision

#### ConceptSynthesisServiceTests (~250 行、8-10 ケース)

In-memory ModelContainer + SharedSchema.all + MockLanguageModelSession で構築。

| # | Scenario | Expected |
|---|----------|----------|
| 1 | `processNewArticle` で同 entity 1 件のみ → ConceptPage 未生成 | fetch count 0 |
| 2 | 2+ 件 → ConceptPage 新規生成 + isStale = true | 1 件生成、name/categoryRaw 一致 |
| 3 | 既存 ConceptPage あり + 新記事 → isStale = true | 既存数据保持、isStale true |
| 4 | `resynthesize` (Foundation 経路、Mock summary 返却) → summary 更新 + isStale = false | summary == mock、isStale false |
| 5 | `resynthesize` (4 記事、1 chunk) → summary 更新 | hierarchy 経由せず |
| 6 | `resynthesize` (5+ 記事、chunked パス) → summary 更新 + chunk 数検証 | session call count 一致 |
| 7 | Fallback 経路 (`isAvailable = false`) → essence 並べた summary 生成 | 元 essence 文字列 join 形式 |
| 8 | Foundation 経路でエラー → silent fail、isStale 維持 | 例外 throw 無し、isStale true |
| 9 | `backfillFromExistingArticles` (50 件 article、10 entity) → 10 ConceptPage 生成 | count 10 |
| 10 | 大文字小文字違い ("Apple" vs "apple") → 同 ConceptPage に統合 | count 1 |

#### ConceptPageStoreTests (~200 行、7-8 ケース)

| # | Scenario | Expected |
|---|----------|----------|
| 1 | `rename` 正常 → name 更新 + isStale true + updatedAt 更新 | 全 PASS |
| 2 | `rename` 空文字 → emptyName error | throw |
| 3 | `rename` 31 字 → nameTooLong error | throw |
| 4 | `rename` 同 category 内重複 → duplicateInCategory error | throw |
| 5 | `merge` 2 ConceptPage → 1 つに統合、relatedArticles union、source 削除 | target.relatedArticles.count == 合算 |
| 6 | `merge` source == target → sameSourceTarget error | throw |
| 7 | `delete` → ConceptPage 削除、他 ConceptPage の relatedConceptIDs から除去、Article 残る | count 0, Article count 不変 |
| 8 | `setFollowing` toggle → isFollowing 永続化 | DB 反映 |

#### KnowledgeExtractionServiceTests 改修 (~30 行追加、1-2 ケース)

- extract 末尾の hook 呼び出し検証 (`MockConceptSynthesisService` を inject、call count 検証)
- chunked パスでも 1 回だけ hook 呼ばれることを検証

#### UI テスト

本 spec では実機検証 (quickstart.md SC-001〜SC-010) で代替、UI テスト自動化は V1 全体
方針が固まってから (現状の spec 011-018 と同方針)。

### Rationale

- 既存 spec 011-018 と同じ fixture (in-memory ModelContainer + Mock LM session) で
  追加コストゼロ、テスト suite 実行時間も短い。
- 10 + 8 = 18 ケースで主要分岐 (Foundation/Fallback/chunked/error/edge case) を網羅。
- `MockConceptSynthesisService` を Test target に追加することで KnowledgeExtractionService
  改修も regression テストできる。

### Alternatives considered

- **snapshot test for UI**: 却下。Xcode snapshot は CI 不安定、優先度低い。
- **integration test (実 Foundation Models)**: 却下。CI 環境では Apple Intelligence
  使用不可、Mock で十分。
