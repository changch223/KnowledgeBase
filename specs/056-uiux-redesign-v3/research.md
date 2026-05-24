# Research: UIUX Redesign V3.0

**Branch**: `056-uiux-redesign-v3` | **Date**: 2026-05-24

12 個の技術判断 (R1-R12) を Decision / Rationale / Alternatives 形式で記録。

---

## R1: 3 タブ TabView 構造 + tab default migration 方式

**Decision**: `KnowledgeTreeApp.swift` の `enum AppTab` を 5 case → 3 case (.knowledgeClip / .library / .chat)。`selectedTab` の起動時初期値は無条件 `.knowledgeClip` (LastOpenedStore.lastTab は無視)。`UserDefaults` キー `spec056_v3_migrated` (Bool) で V2.5 → V3.0 初回起動を判定し、1 回だけ tooltip 表示。

**Rationale**:
- spec.md FR-001/002 で 3 タブ + 起動 default 知識 Clip を明示要求
- LastOpenedStore.lastTab は V2.5 時代の値 (.understanding 等が入っている可能性) で型 mismatch crash の元 → 無視が安全
- spec 044 で LastOpenedStore.lastTab migration を既に 1 回実施したパターンを踏襲 (`spec044_learningTabMigrated`)
- 「新習慣定着」のため毎回起動で知識 Clip 強制が UX 的にも適切

**Alternatives**:
- (rejected) LastOpenedStore.lastTab を新 enum に migration → 複雑、crash リスク
- (rejected) ユーザー設定で「起動 default タブを選ぶ」 → 1 文の本質「気になったものが勝手に整理される」と矛盾 (知識 Clip が主役)

---

## R2: KnowledgeClipView 8 → 3 セクション再構成戦略

**Decision**: 既存 `KnowledgeClipView.swift` (500+ 行) を全面書き換え (250 行程度に圧縮)。新規 3 section view (RecentArticlesSection / InterestingNextSection / FollowingPeopleSection) を `LazyVStack { ... }` 内に縦並び。toolbar 右上に AvatarMenu。各 section は 独立 `@MainActor View struct`、データ取得は section 内で完結 (@Query + service)。

**Rationale**:
- LazyVStack で onAppear 駆動 lazy 描画、起動時は最初の 1-2 section のみ render → SC-003 (1 秒以内) 達成
- 各 section が独立 View で責務分離、200 行以下を維持
- 既存 8 セクション (RecentDigest / FactConflicts / Stale / ConceptPage / DynamicTopics / KnowledgeDigest cards 等) は新 3 section 内に統合 or Layer 2 (もっと見る)

**Alternatives**:
- (rejected) 既存 KnowledgeClipView を漸進的に section 削除 → diff が複雑、退行リスク
- (rejected) NavigationStack 内に section を子 view 配置 → over-engineering

---

## R3: RecentArticlesService 差分判定 + cache 永続化方式

**Decision**: `@MainActor protocol RecentArticlesServiceProtocol` + `DefaultRecentArticlesService`。
- `fetchRecentArticles(since: Date, limit: Int = 3) async -> [Article]` — savedAt >= since を desc fetch、limit 件返却
- `cachedRecentArticleIDs: [UUID]` get/set — UserDefaults `spec056_recent_articles_cache` (JSON Array<UUID> 永続化)
- 上位 view (RecentArticlesSection) で:
  1. `fetchRecentArticles(since: lastOpenedStore.lastOpenedAt)` を呼ぶ
  2. count > 0 → 結果を表示 + cache 更新 (新 ID 配列で上書き)
  3. count == 0 → `cachedRecentArticleIDs` から ID で Article fetch (削除済 ID は skip、@Query で fallback)、表示は維持
- 初回起動 (cache empty + 差分 0) → empty state 表示 (US11)

**Rationale**:
- 差分ゼロ時に「画面が空になる」UX 問題を解消 (FR-009 / SC-004)
- UserDefaults で永続化、アプリ kill 後も維持
- 削除済 article の ID は in-memory filter で skip、安全

**Alternatives**:
- (rejected) SwiftData @Model で cache 永続化 → over-engineering、UserDefaults で十分軽量
- (rejected) cache を ConceptPage 連動で更新 → 複雑、目的 (差分維持) と無関係

---

## R4: InterestingNextSection 混在表示 (UnderstandingCard + KnowledgeDigest 統一)

**Decision**: 新 transient struct `MixedSurfaceCard`:

```swift
enum MixedSurfaceCard: Identifiable {
    case understanding(UnderstandingCard)
    case digest(KnowledgeDigest)
    
    var id: UUID { ... }
    var priorityScore: Int { ... }  // 共通スケール 0-100
    var displayTitle: String { ... }
    var displaySubtitle: String { ... }
}
```

InterestingNextSection 内で:
1. `UnderstandingCardSurfaceService.surfaceTopCards(limit: 10)` 呼出 → UnderstandingCard 配列
2. `@Query(filter: createdAt >= 7days ago, sort: createdAt desc) var digests: [KnowledgeDigest]` から KnowledgeDigest 配列
3. 両方を MixedSurfaceCard でラップ、priorityScore でソート、上位 5 件混在表示
4. UnderstandingCard.priorityScore は既存 0-100、KnowledgeDigest は createdAt desc で 60 (新) → 30 (古) スケール

**Rationale**:
- spec.md FR-012 で混在表示明示要求
- UnderstandingCardSurfaceService (spec 044) は既存、流用可能
- transient struct で表示単位統一、UI 側は MixedSurfaceCard.kind で switch

**Alternatives**:
- (rejected) UnderstandingCard を拡張して KnowledgeDigest も含める → spec 044 schema 汚染
- (rejected) 2 つの section に分割 → 「続きが気になる」が 1 つで「整理された」表現になる原則と矛盾

---

## R5: FollowingPeopleSection + ⚠️ Action Items badge 統合

**Decision**:
- `@Query(filter: ConceptPage.isFollowing == true, sort: updatedAt desc, fetchLimit: 5) var followingPages` で上位 5 件
- 同 view 内で `@Query var conflicts: [ConflictProposal]` (undecided)、`@Query var staleAnswers: [SavedAnswer]` (isStale == true) を fetch
- subheader 位置に `if (conflicts.count + staleAnswers.count) > 0 { ⚠️ 更新が必要 (N) badge }` 条件表示
- badge tap → `NavigationLink` で新 `ActionItemsReviewView` push

新 `ActionItemsReviewView` は旧 `FactConflictsSection` + `StaleSavedAnswersSection` を 1 view に統合 (2 section + 共通 nav):

```swift
struct ActionItemsReviewView: View {
    var body: some View {
        List {
            Section("事実の更新提案") {
                ForEach(conflicts) { ConflictProposalRow(...) }
            }
            Section("確認が必要な答え") {
                ForEach(staleAnswers) { SavedAnswerRow(...) }
            }
        }
        .navigationTitle("更新が必要")
    }
}
```

**Rationale**:
- spec.md FR-017/018/019/020 で明示要求
- 既存 `ConflictProposalRow` / `SavedAnswerRow` を流用、新規 row 不要
- badge 非表示判定 (count == 0) は SwiftUI conditional view で簡単

**Alternatives**:
- (rejected) ⚠️ badge を toolbar 配置 → 視認性低い、知識 Clip section と分離
- (rejected) 旧 FactConflictsSection / StaleSavedAnswersSection を残して section 数を増やす → 「3 section ルール」と矛盾

---

## R6: SuggestedPromptGenerator 動的生成 + fallback + cache

**Decision**: `@MainActor protocol SuggestedPromptGeneratorProtocol` + `DefaultSuggestedPromptGenerator`。
- `generateSuggestedPrompts(in: ModelContext) async -> [SuggestedPrompt]` (3 件返却)
- 生成ロジック:
  1. 最新 ConceptPage (updatedAt desc, fetchLimit: 1) があれば: 「{name} について教えて」
  2. 最新 Category (Article.categoryRaw 集計、updatedAt desc) があれば: 「{categoryName} 分野で何があった?」
  3. 常に 1 つ: 「最近保存した記事の要点は?」
  4. 3 件未満なら generic fallback で埋める (「iKnow について教えて」「使い方を教えて」「最近何が新しい?」)
- 各 prompt は最大 30 字 (SC-011)、超過時 truncate
- キャッシュ: UserDefaults `spec056_suggested_prompts_cache` に JSON ({date: String, prompts: [SuggestedPrompt]})、起動時に date と今日比較、同じなら cache 返却、違うなら再生成

**Rationale**:
- 動的生成で「自分のデータに関連する」prompt が出る → AI チャットの「何聞いていいか分からない」問題解決
- cache で起動毎の生成負荷 (SwiftData fetch) を回避
- 30 字制約は Apple Intelligence Writing Tools の suggested action 長さに倣う

**Alternatives**:
- (rejected) Foundation Models で prompt 自体を生成 → 起動時 5-10 秒待ち、ライトユーザー UX 悪化
- (rejected) 完全固定 prompt → 「自分のデータ反映」感薄れる、redesign のメッセージと矛盾

---

## R7: KnowledgeGraphFullScreenView 全 Category subgraph 表示

**Decision**: AI チャットタブ toolbar 📊 icon tap → `NavigationLink(destination: KnowledgeGraphFullScreenView())` push。

```swift
struct KnowledgeGraphFullScreenView: View {
    @Query private var allCategories: [String]  // Article.categoryRaw distinct
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(allCategories, id: \.self) { category in
                    Section(category) {
                        CategoryGraphView(categoryRaw: category)  // 既存 spec 041 流用
                            .frame(height: 300)
                    }
                }
            }
        }
        .navigationTitle("Knowledge Graph")
    }
}
```

- 各 Category = 1 subgraph (height 300、別 LazyVStack item)
- 既存 `CategoryGraphView` (spec 041、SwiftUI Canvas + force-directed) を Category 配列で iterate
- node tap → `GraphNodeDetailView` (既存) push、既存遷移経路維持

**Rationale**:
- spec.md FR-039/040/041 で明示要求
- 既存 CategoryGraphView 流用、新規描画コードゼロ
- LazyVStack で大量 Category も lazy 描画、60fps 維持
- GraphNode 200+ 件は Category 分割で各 subgraph 30-50 node 程度に収まる

**Alternatives**:
- (rejected) 全 GraphNode を 1 Canvas に集約描画 → 重い、Canvas force-directed が 200+ node で固まる可能性
- (rejected) UICollectionView で flow layout → SwiftUI 標準で十分

---

## R8: LibraryGroupedView 日付別 grouping アルゴリズム

**Decision**: `LibraryDateGrouper` は純粋関数 + transient struct:

```swift
enum LibraryDateGroup: String, CaseIterable {
    case today      // 今日 (今日 0 時 00 分以降)
    case yesterday  // 昨日 (昨日 0 時 00 分 - 今日 0 時 00 分)
    case thisWeek   // 今週 (今週月曜 0 時 00 分 - 昨日 0 時 00 分)
    case thisMonth  // 今月 (今月 1 日 0 時 00 分 - 今週月曜 0 時 00 分)
    case earlier    // それ以前 (今月 1 日 0 時 00 分より前)
    
    var localizedTitle: LocalizedStringKey { ... }
}

struct LibraryDateGrouper {
    static func group(_ articles: [Article], now: Date = .now) -> [(LibraryDateGroup, [Article])] {
        let calendar = Calendar.current
        var groups: [LibraryDateGroup: [Article]] = [:]
        for article in articles {
            let group = LibraryDateGrouper.classify(article.savedAt, now: now, calendar: calendar)
            groups[group, default: []].append(article)
        }
        // 各 group 内 savedAt desc ソート
        return LibraryDateGroup.allCases.compactMap { group in
            guard let articles = groups[group], !articles.isEmpty else { return nil }
            return (group, articles.sorted { $0.savedAt > $1.savedAt })
        }
    }
    
    static func classify(_ date: Date, now: Date, calendar: Calendar) -> LibraryDateGroup { ... }
}
```

LibraryGroupedView で:
- `@Query(sort: \Article.savedAt, order: .reverse) var allArticles`
- `let grouped = LibraryDateGrouper.group(allArticles)` で grouping
- `ForEach(grouped, id: \.0)` で Section 表示
- 各 Section 内に DisclosureGroup (折りたたみ可能、default expanded)

**Rationale**:
- 純粋関数で test 容易 (LibraryDateGrouperTests 5 ケース)
- Date 注入 (`now: Date = .now`) で deterministic test
- 既存 ArticleRow を流用、UI コード新規不要
- DisclosureGroup で大量 group も折りたたみ可能

**Alternatives**:
- (rejected) Apple Photos の月単位 grouping (12 月、11 月…) → 「最近のもの」優先で today / yesterday / thisWeek を強調する方針 (Apple News パターン)
- (rejected) SwiftData の @Query group 機能 → iOS 17 で導入されたが、純粋関数の方が test 容易

---

## R9: AddArticleSheet URL validation + 重複検知

**Decision**: modal sheet (`.sheet(isPresented: $showAddSheet) { AddArticleSheet() }`)。

```swift
struct AddArticleSheet: View {
    @State private var urlText = ""
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @Environment(ServiceContainer.self) var services
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("URL を入力", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("記事を追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(urlText.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        guard let url = URL(string: urlText),
              url.scheme == "http" || url.scheme == "https" else {
            errorMessage = "有効な URL を入力してください"
            return
        }
        // 重複検知
        let urlStr = url.absoluteString
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.url == urlStr }
        )
        if let existing = try? context.fetch(descriptor).first {
            // 既存記事へジャンプ (alert 経由)
            ...
            return
        }
        // 保存 (既存 ArticleSavingService 経由)
        Task {
            try? await services.articleSavingService.save(url: url)
            dismiss()
        }
    }
}
```

**Rationale**:
- spec.md FR-029〜FR-033 で明示要求
- 既存 ArticleSavingService 流用、新規 logic ゼロ
- modal sheet で「集中して入力」UX (Apple HIG 推奨)

**Alternatives**:
- (rejected) Inline 入力 field を tab top に常駐 → tab UI 圧迫
- (rejected) Push 画面で URL 入力 → modal の方が「一時的タスク」感に合う

---

## R10: AvatarMenu iPhone push vs iPad sheet 分岐

**Decision**: `UIDevice.current.userInterfaceIdiom` で分岐:

```swift
struct AvatarMenu: View {
    @State private var showSettings = false
    var body: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.title2)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}
```

iPhone / iPad どちらも sheet 統一 (NavigationStack 内で nested push 可能、sheet dismiss で root 復帰)。

**Rationale**:
- sheet 統一の方がコード simple、UIDevice 分岐は不要
- SettingsView (既存) は NavigationStack 内で nested push に対応済
- iPad では sheet が画面中央に表示 (iOS 26 standard、modally adapted)

**Alternatives**:
- (rejected) iPhone push / iPad sheet 分岐 → NavigationPath の管理が複雑化
- (rejected) Popover (iPad) → アバター icon サイズが小さく popover anchor として弱い

---

## R11: FABButton scroll 同期 + 共通 component 化

**Decision**: 共通 `FABButton` component を `Views/FABButton.swift` に切り出し:

```swift
struct FABButton: View {
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: .circle)
                .shadow(radius: 4)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }
}
```

使用側 (知識 Clip / ライブラリ):
```swift
ZStack(alignment: .bottomTrailing) {
    ScrollView { ... }
    FABButton(icon: "plus") { showAddSheet = true }
}
```

scroll 同期 (down で隠す Apple News パターン) は **MVP 範囲外** (将来 polish)、初版は常時表示。

**Rationale**:
- 共通 component 化で 知識 Clip / ライブラリ で再利用
- MVP では常時表示で十分、scroll 同期は将来 polish
- 56x56 + circle は Material Design Floating Action Button 標準サイズに準拠

**Alternatives**:
- (rejected) ToolbarItem に + を配置 → Apple News や Mail では FAB ではないが、追加 UX 強調のため FAB 選択
- (rejected) scroll 同期を MVP に含める → over-engineering、Phase D 以降

---

## R12: テスト戦略 (新規 19 + UI 3 + 既存全 regression)

**Decision**:

新規 unit test (19 ケース):
- **RecentArticlesServiceTests** (8 ケース):
  1. 空状態 (fetch 0 件、cache empty) → empty array
  2. 差分あり (3 件新規) → 3 件返却 + cache 更新
  3. 差分ゼロ (0 件 + cache 3 件) → cache から 3 件返却
  4. cache 永続化 (set → get で同 ID 配列)
  5. max 3 件制限 (5 件 fetch しても 3 件のみ cache)
  6. LastOpenedAt 連動 (since= now → 全部新規扱い)
  7. 削除済 article ID skip (cache に 3 件、DB に 1 件 → 1 件のみ返却)
  8. new install state (cache empty + DB empty) → empty array (US11)

- **SuggestedPromptGeneratorTests** (6 ケース):
  1. 最新 ConceptPage 1 + Category 1 + 汎用 1 (正常時)
  2. ConceptPage 0 / Category 0 → fallback 3 件
  3. ConceptPage 5 / Category 3 → 最新 1 + 最新 1 + 汎用 1 (3 件のみ)
  4. 30 字超過 prompt は truncate (… 付き)
  5. 1 日 cache (同 date 内で再呼出 → cache 返却、call count 増えない)
  6. cache miss (date 違う → 再生成、call count 増える)

- **LibraryDateGrouperTests** (5 ケース):
  1. 5 group 分類 (今日 1 / 昨日 1 / 今週 1 / 今月 1 / それ以前 1)
  2. 空配列 → 空 result
  3. 各 group 内 savedAt desc ソート確認
  4. 境界 (今日 23:59 / 明日 00:00 → 別 group)
  5. large data 1000 件 → 性能 100ms 以内 (deterministic Date 注入)

新規 UI test (3 ケース):
- **V3RedesignUITests**:
  1. アプリ起動 → tab bar 3 つのみ表示 + selected = 知識 Clip
  2. 知識 Clip → FAB tap → URL 入力 sheet 表示
  3. AI チャット → suggested prompt tap → user message として送信される

既存 unit test 全 regression PASS 必須 (xcodebuild test -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO)。

**Rationale**:
- 新規 service 3 つは全 protocol + Default、Mock 不要、in-memory ModelContainer + Date 注入で deterministic
- UI test は核心 user journey のみ (3 ケース)、残りは spec 044/043 等の既存 UI test で cover
- Date 注入は spec 044 同パターン (`now: () -> Date = { .now }`)

**Alternatives**:
- (rejected) snapshot test 導入 → 環境依存高、CI で flaky になりがち
- (rejected) UI test を 10+ ケースに拡大 → maintenance cost 高、簡素化原則と矛盾
