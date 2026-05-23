# Research: SavedAnswer 技術判断 (R1〜R10)

**Feature**: spec 043 SavedAnswer
**Phase**: 0 (Outline & Research)
**Date**: 2026-05-23

spec.md は技術中立、本 research で具体的な Swift/SwiftUI/SwiftData 実装方針を確定する。

---

## R1: SavedAnswer `@Model` 構造とフィールド設計

### Decision

新規 `@Model final class SavedAnswer` を 11 フィールドで定義 (data-model.md と一致)。`@Relationship(deleteRule: .nullify)` for `citedArticles` (片方向、Article 側 inverse なし)。`chatSessionID: UUID?` を nullable で持ち、ChatSession への直接 @Relationship は使わない (履歴保護 + 循環参照回避、spec 021 ChatMessage と同思想)。

### Rationale

- 片方向 @Relationship は spec 042 ConceptPage と同パターン、Article 既存スキーマ影響ゼロ
- chatSessionID を UUID 文字列ではなく `UUID?` 型で持つ理由: ChatMessage は `citedArticleIDs: [String]` だが、新規 entity ではより型安全な `UUID?` を採用 (spec 042 relatedConceptIDs と整合)
- `relatedConceptIDs: [UUID]` を @Relationship ではなく ID 配列にした理由: ConceptPage との関係は弱結合 (graph 経由 derived)、将来 spec 044+ で community-based 拡張時の migration 負担回避
- `savedAutomatically: Bool` を保持: 将来 metric / WikiLint 分析で「自動保存だったか手動だったか」を区別、現状は auto-save のみだが将来手動保存追加時 (Out of Scope) に活用

### Alternatives considered

- **Article 側に `var savedAnswers: [SavedAnswer]?` を追加**: 却下。Article 既存スキーマ影響、片方向で十分
- **ChatSession ↔ SavedAnswer 双方向 @Relationship**: 却下。ChatSession 削除で SavedAnswer も連動削除されると履歴保護失敗
- **question を Hash した key を持つ**: 却下。重複防止のためだけに複雑化、fetchで完全一致 check で十分 (Scale 30-100 件規模)

---

## R2: 自動保存トリガー (ChatService.ask hook)

### Decision

`ChatService.ask(question:in:)` の末尾、`assistantMessage` 永続化直後に fire-and-forget Task を追加:

```swift
// ChatService.ask 末尾、`try context.save()` 後
Task { [weak self] in
    await self?.savedAnswerService?.captureIfWorthy(
        question: trimmed,
        answer: cleanedAnswer,
        citedArticleIDs: filteredCited,
        sessionID: session.id
    )
}
return assistantMessage
```

`SavedAnswerService.captureIfWorthy(question:answer:citedArticleIDs:sessionID:)` パラメータ:
- `question: String` (trim 済の元 question)
- `answer: String` (cleanedAnswer、UUID strip 済)
- `citedArticleIDs: [String]` (filteredCited、availableIDs 通過済)
- `sessionID: UUID?` (ChatSession の id)

ChatService の dependency に `private weak var savedAnswerService: SavedAnswerServiceProtocol?` を追加 (optional、後方互換)、init parameter に追加 (`savedAnswerService: SavedAnswerServiceProtocol? = nil`)。

### Rationale

- spec 037 ConflictDetection / spec 040 GraphExtraction / spec 042 ConceptSynthesis 全部同パターンで実績あり
- 同期にしない理由: SavedAnswer 永続化は数百 ms かかる (Article fetch + ConceptPage fetch + insert + save)、ChatService.ask の latency に影響させない
- `[weak self]` capture で memory leak 防止
- Fire-and-forget なので失敗は silent (logger.error のみ)

### Alternatives considered

- **ChatService 内部で直接 SavedAnswer insert**: 却下。SoC 違反、SavedAnswer ロジック (重複判定 / ConceptPage 紐付け) を ChatService に詰め込む形になる
- **NotificationCenter で通知**: 却下。既存 pattern が Task + protocol DI で確立済、別 pattern 導入は維持コスト増

---

## R3: SavedAnswerService Protocol + 実装

### Decision

AI 不使用なので Foundation/Fallback 二経路パターン不要、単一実装で十分:

```swift
@MainActor
protocol SavedAnswerServiceProtocol: AnyObject {
    func captureIfWorthy(
        question: String,
        answer: String,
        citedArticleIDs: [String],
        sessionID: UUID?
    ) async
    func setPinned(_ answer: SavedAnswer, isPinned: Bool) throws
    func delete(_ answer: SavedAnswer) throws
    func markStaleForArticle(_ article: Article) async
}

@MainActor
final class DefaultSavedAnswerService: SavedAnswerServiceProtocol {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "saved-answer")

    /// 答え本文の最小 char 数 (auto-save 判定の質的閾値)
    static let minAnswerChars = 50
    /// 引用件数の最小 (auto-save 判定の質的閾値)
    static let minCitedCount = 2
    /// relatedConceptIDs の最大件数
    static let maxRelatedConcepts = 5

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil)
}
```

`captureIfWorthy` 実装:
1. `citedArticleIDs.count >= 2` && `answer.count >= 50` 確認、未満なら early return
2. question trim 後、既存同 question SavedAnswer fetch (大文字小文字 sensitive、完全一致)、あれば early return
3. citedArticleIDs から UUID 配列に変換、Article fetch (`#Predicate { ids.contains($0.id) }`)
4. R5 ロジックで関連 ConceptPage を resolve (top 5)
5. SavedAnswer insert + context.save() + RefreshTrigger.bump()
6. logger.notice で success ログ

### Rationale

- spec 042 ConceptSynthesisService の Foundation+Fallback パターンは必要なし (AI 使わないため)
- 純粋ロジックなので Mock も不要、in-memory ModelContainer で全パス検証可能
- `@MainActor` 制約は SwiftData ModelContext との協調 (既存 service 全て同じ)

### Alternatives considered

- **`captureIfWorthy` に ChatAnswerOutput 全体を渡す**: 却下。spec 021 の Generable 型 (transient) を hook 層で渡すと test fixture が複雑化。素の `String` / `[String]` の方が単純
- **`throws` にする**: 却下。fire-and-forget hook なので catch されない、silent fail 推奨

---

## R4: isStale 連動 (KnowledgeExtractionService hook)

### Decision

spec 042 ConceptPage hook と並列、`KnowledgeExtractionService.extract` の末尾 (single + chunked 両経路) に追加:

```swift
// extract 末尾 hook 群に追加
Task { [weak self] in
    await self?.savedAnswerService?.markStaleForArticle(article)
}
```

KnowledgeExtractionService の init parameter に `savedAnswerService: SavedAnswerServiceProtocol? = nil` 追加 (後方互換)。

`markStaleForArticle` 実装:
1. article に関連する ConceptPage を fetch (`page.relatedArticles.contains article`)
2. それらの ConceptPage.id を集合化
3. `SavedAnswer` 全 fetch (in-memory filter で `relatedConceptIDs ∩ conceptPageIDs ≠ ∅`)
4. 該当 SavedAnswer.isStale = true + updatedAt = .now
5. context.save() + 影響件数を logger.notice
6. silent (UI 表示なし、本 spec では仕込みのみ)

### Rationale

- SavedAnswer.isStale は WikiLint (spec 044+) で「古い答え」検出に使う将来用フラグ
- @Query で予測 (SwiftData @Predicate で `[UUID].contains` をサポートしない場合) なため in-memory filter
- silent fire-and-forget で extract 本体に影響しない

### Alternatives considered

- **isStale を ConceptPage の @Relationship 経由で derive**: 却下。SwiftData @Relationship は逆引きで in-memory cost が大きい
- **Article 直接紐付け (SavedAnswer.isStale 判定を引用記事ベース)**: 却下。ConceptPage 経由のほうが「答えの根拠となった概念が更新された」semantics と整合

---

## R5: ConceptPage 紐付け解決ロジック

### Decision

`captureIfWorthy` 内で実行する純関数:

```swift
private func resolveTopConceptIDs(
    citedArticles: [Article],
    in context: ModelContext
) -> [UUID] {
    let citedIDs = Set(citedArticles.map(\.id))
    let allPages: [ConceptPage] = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
    let scored: [(UUID, Int)] = allPages.compactMap { page in
        let overlap = page.relatedArticles.filter { citedIDs.contains($0.id) }.count
        return overlap > 0 ? (page.id, overlap) : nil
    }
    return scored
        .sorted { $0.1 > $1.1 }  // overlap 数 desc
        .prefix(Self.maxRelatedConcepts)
        .map(\.0)
}
```

スコア = 引用記事と ConceptPage.relatedArticles の overlap 数 (多いほど関連性高い)、上位 5 件。

### Rationale

- 単純な overlap count で十分、AI / embedding 不要
- 30-200 件 ConceptPage 規模で全件 fetch + filter は < 100ms (data scope assumption)
- 引用記事 0 件 / ConceptPage 0 件 / overlap 0 件 のいずれも空配列を返す (graceful)

### Alternatives considered

- **mentionCount や salience も加味した重み付けスコア**: 却下。複雑化に対するゲインが低い、overlap だけで MVP 十分
- **embedding 類似度ベース**: 却下。AI 不要原則違反、コスト高

---

## R6: ConceptPage merge 連動 (data integrity)

### Decision

`ConceptPageStore.merge(source:into:)` の末尾、context.save() の前に SavedAnswer の relatedConceptIDs 置換を追加:

```swift
// ConceptPageStore.merge 末尾、context.save() 前
let allAnswers: [SavedAnswer] = (try? context.fetch(FetchDescriptor<SavedAnswer>())) ?? []
for answer in allAnswers where answer.relatedConceptIDs.contains(source.id) {
    var ids = answer.relatedConceptIDs.filter { $0 != source.id }
    if !ids.contains(target.id) {
        ids.append(target.id)
    }
    answer.relatedConceptIDs = Array(ids.prefix(DefaultSavedAnswerService.maxRelatedConcepts))
    answer.updatedAt = .now
}
```

`DefaultSavedAnswerService.maxRelatedConcepts` (= 5) を参照、ConceptPageStore は SavedAnswerService 全体ではなく定数だけ知る (疎結合)。

### Rationale

- spec 042 で実装した ConceptPage merge ロジックの自然な拡張
- 全 SavedAnswer fetch → in-memory filter は 30-100 件規模で問題なし
- target.id が既に含まれる場合は重複避ける

### Alternatives considered

- **ConceptPageStore に SavedAnswerService を inject**: 却下。循環依存リスク (SavedAnswerService も ConceptPage を参照) + 過剰結合
- **ConflictProposal と同様 NotificationCenter で通知**: 却下。spec 037 ConflictProposal の同等処理が直接 context fetch + update でやっているので同パターン

---

## R7: ConceptPage 詳細画面の SavedAnswer セクション

### Decision

新規 `SavedAnswerSection` view を ConceptPageDetailView の 5 番目セクションに追加:

```swift
// ConceptPageDetailView.aliveBody 内、relatedConceptsSection の前
SavedAnswerSection(conceptPageID: conceptPage.id)
```

`SavedAnswerSection` 実装:
```swift
struct SavedAnswerSection: View {
    let conceptPageID: UUID
    @Query private var allAnswers: [SavedAnswer]

    init(conceptPageID: UUID) {
        self.conceptPageID = conceptPageID
        _allAnswers = Query(
            sort: [SortDescriptor(\SavedAnswer.savedAt, order: .reverse)]
        )
    }

    /// in-memory filter (SwiftData @Predicate は [UUID].contains を直接サポートしないため)
    private var relatedAnswers: [SavedAnswer] {
        allAnswers
            .filter { $0.relatedConceptIDs.contains(conceptPageID) }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.savedAt > rhs.savedAt
            }
    }

    var body: some View {
        if relatedAnswers.isEmpty {
            EmptyView()  // 0 件なら非表示
        } else {
            VStack(alignment: .leading) {
                Text("この概念についての質問と答え (\(relatedAnswers.count))")
                    .font(.title3.bold())
                ForEach(relatedAnswers.prefix(5)) { answer in
                    NavigationLink(value: SavedAnswerDetailDestination(id: answer.id)) {
                        SavedAnswerRow(answer: answer)
                    }
                }
                if relatedAnswers.count > 5 {
                    NavigationLink(value: SavedAnswerListByConceptDestination(conceptPageID: conceptPageID)) {
                        Text("+\(relatedAnswers.count - 5) すべて見る")
                    }
                }
            }
        }
    }
}
```

### Rationale

- @Query で全件 fetch + in-memory filter は 30-100 件規模で問題なし
- isPinned 優先 + savedAt desc の sort も in-memory (@Query sort は単一 KeyPath なので分割)
- 0 件で EmptyView (Constitution V calm UX)

### Alternatives considered

- **@Query の filter で `relatedConceptIDs.contains(id)`**: SwiftData @Predicate macro が `[UUID].contains(_:)` 未サポート (バージョン依存)、in-memory filter で確実性優先
- **SavedAnswerService にメソッド追加して fetch を service に押し付け**: 却下。View 直接 fetch (@Query) のほうが Observation で自動更新

---

## R8: SavedAnswer 詳細画面 (Live check pattern 適用)

### Decision

新規 `SavedAnswerDetailView`、spec 042 ConceptPageDetailView と同 `@Query live check` パターンを必須適用:

```swift
struct SavedAnswerDetailView: View {
    @Bindable var answer: SavedAnswer
    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceContainer.self) private var services
    @State private var showDeleteConfirm: Bool = false
    /// 削除時に空になる reactive guard (spec 042 と同パターン)
    @Query private var liveMatches: [SavedAnswer]

    init(answer: SavedAnswer) {
        self.answer = answer
        let id = answer.id
        _liveMatches = Query(filter: #Predicate<SavedAnswer> { $0.id == id })
    }

    private var isAlive: Bool { !liveMatches.isEmpty }

    var body: some View {
        if !isAlive {
            Color.clear.onAppear { dismiss() }
        } else {
            aliveBody
        }
    }

    @ViewBuilder
    private var aliveBody: some View {
        ScrollView {
            VStack {
                headerSection            // 保存日時 / 自動 or 手動 / pin badge
                questionSection
                answerSection
                citedArticlesSection     // Article jump
                relatedConceptsSection   // ConceptPage chip jump
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: pinBinding) { Image(systemName: answer.isPinned ? "pin.fill" : "pin") }
                    .toggleStyle(.button)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .alert("この答えを削除", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) {
                try? services.savedAnswerService?.delete(answer)
                // dismiss は live check が自動でやる
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("引用された記事は残ります。")
        }
    }
}
```

### Rationale

- 削除 → SwiftData 観測通知 → `liveMatches` 空に → body 再評価 → `Color.clear.onAppear { dismiss() }` 短絡 → @Bindable answer プロパティ参照ゼロ → crash 回避
- spec 042 で確立済パターン、信頼性高い

### Alternatives considered

- **EditSheet 経由 (spec 042 と同形式)**: 却下。SavedAnswer 編集は pin + delete の 2 操作のみで sheet ほど複雑でない、toolbar 直接で十分。シンプルさ優先
- **`@Environment(\.modelContext)` で fetch ベース**: spec 042 で @Query live check のほうが Observation framework との整合が良いと検証済

---

## R9: SavedAnswer 履歴画面 (P2 + P3 検索)

### Decision

新規 `SavedAnswerHistoryView` (独立画面):

```swift
struct SavedAnswerHistoryView: View {
    @Query(sort: [SortDescriptor(\SavedAnswer.savedAt, order: .reverse)])
    private var allAnswers: [SavedAnswer]
    @State private var searchText: String = ""

    private var displayedAnswers: [SavedAnswer] {
        let baseSort = allAnswers.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.savedAt > rhs.savedAt
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return baseSort }
        return SearchService.searchSavedAnswers(query: trimmed, in: baseSort)
            .map(\.savedAnswer)
    }

    var body: some View {
        ScrollView {
            LazyVStack { /* ForEach displayedAnswers, SavedAnswerRow */ }
        }
        .searchable(text: $searchText)
        .navigationTitle("保存された答え")
    }
}
```

配置: `SettingsView` 内に新規 NavigationLink「保存された答えの履歴」追加。`Settings → 保存された答えの履歴` で開く。

### Rationale

- 知識 Clip タブだと多機能化で「タブの目的」がぼやける、Settings からの NavigationLink で「ユーザーが意識的に履歴を見に行く」UX
- @Query sort は SwiftData level (savedAt desc) + 二次 sort (isPinned 優先) は in-memory
- 検索は SearchService.searchSavedAnswers (R10) 経由、score 不要なので flat list 返す

### Alternatives considered

- **ChatTabView の sub-tab / sub-section**: 却下。ChatTabView は会話 UI に集中、履歴は別画面が適切
- **知識 Clip タブの section として常時表示**: 却下。SavedAnswer は ConceptPage 経由で発見するのが主、独立履歴はあくまで補助
- **新 tab item「履歴」**: 却下。tab 増えると視覚的にうるさい、Settings 配下で十分

---

## R10: SearchService.searchSavedAnswers + テスト戦略

### Decision

`SearchService` に新関数追加 (既存 searchConceptPages と同パターン):

```swift
struct ScoredSavedAnswer: Identifiable {
    var id: UUID { savedAnswer.id }
    let savedAnswer: SavedAnswer
    let score: Int
}

static func searchSavedAnswers(query: String, in answers: [SavedAnswer]) -> [ScoredSavedAnswer] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return [] }
    var results: [ScoredSavedAnswer] = []
    for a in answers {
        var score = 0
        if a.question.localizedStandardContains(q) { score += 50 }
        if a.answer.localizedStandardContains(q) { score += 20 }
        if a.citedArticles.contains(where: { $0.title.localizedStandardContains(q) }) { score += 10 }
        if score > 0 {
            results.append(ScoredSavedAnswer(savedAnswer: a, score: score))
        }
    }
    return results.sorted { lhs, rhs in
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        return lhs.savedAnswer.savedAt > rhs.savedAnswer.savedAt
    }
}
```

### テスト戦略 (8-10 ケース + hook 検証 2-3 ケース)

`SavedAnswerServiceTests`:
1. captureIfWorthy で 2+ 引用 + 50 字+ answer → SavedAnswer 生成、savedAutomatically=true
2. captureIfWorthy で 1 引用 → 生成しない
3. captureIfWorthy で 49 字 answer → 生成しない
4. captureIfWorthy で 同 question 既存 → 2 件目作成しない (重複防止)
5. captureIfWorthy で 同 question (前後空白だけ違う) → 重複扱い (trim 比較)
6. relatedConceptIDs 解決: 引用記事 3 件 → 重複の多い ConceptPage 上位 5 件
7. relatedConceptIDs 解決: ConceptPage 0 件 → relatedConceptIDs 空配列
8. setPinned: false → true → 永続化
9. delete: SavedAnswer 削除、Article は残る、ChatSession 影響なし
10. markStaleForArticle: 引用記事 → 関連 ConceptPage → SavedAnswer.isStale 連鎖

`ChatServiceTests` 拡張 (`MockSavedAnswerService`):
- A. `ask()` で answer 返却後、savedAnswerService.captureIfWorthyCallCount == 1
- B. SavedAnswerService 未注入 (nil) でも ask() 正常完了

`ConceptPageStoreTests` 拡張:
- C. ConceptPageStore.merge で SavedAnswer.relatedConceptIDs の source.id → target.id 置換

### Rationale

- spec 044 SearchService の searchConceptPages と同パターンなので学習コスト低
- 重み: question 50 > answer 20 > cited title 10 (検索意図と直結する順)
- score 同点なら savedAt desc

### Alternatives considered

- **UI テスト追加**: 既存 spec 011-042 同方針で実機検証 (quickstart.md) に委ねる
- **検索 を P2 に格上げ**: 現状 P3 で十分、100 件規模では substring match で実用十分
