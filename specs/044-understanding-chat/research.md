# Phase 0 Research: Understanding Chat (家庭教師ループ + 学習タブ)

**Feature**: spec 044 Understanding Chat
**Date**: 2026-05-23
**Status**: Complete (12 research items resolved)

spec 044 は新規 framework 不要、既存資産 (spec 021/042/043/040/035) を組み合わせる純粋ロジック層 + UI 層。NEEDS CLARIFICATION 項目はすべて事前 spec 対話で確定済。本 research.md は技術判断 R1-R12 の根拠を凍結する。

---

## R1: UnderstandingInteraction @Model 構造

**Decision**: 5 フィールドの SwiftData `@Model`、他 @Model との `@Relationship` ゼロ (孤立 ID 参照のみ)。

```swift
@Model
final class UnderstandingInteraction {
    @Attribute(.unique) var id: UUID
    var targetKind: String     // "conceptPage" / "savedAnswer" / "article"
    var targetID: UUID         // ConceptPage.id / SavedAnswer.id / Article.id
    var action: String         // "understood" / "needMore" / "openedChat" / "dismissed"
    var occurredAt: Date
}
```

**Rationale**:
- 履歴 (action log) は他 @Model 削除でも残るべき (集計 metric 用)、`@Relationship.nullify` で参照保持すると ConceptPage 削除時に nil 化されてしまう
- targetKind + targetID の string 参照は SwiftData の `#Predicate` で fetch 可能 (`#Predicate { $0.targetKind == "conceptPage" && $0.targetID == id }`)
- 軽量 (5 フィールド、各 row ~100 byte)、年間 2400 件想定でも 240KB 程度

**Alternatives considered**:
- Enum 直接 (`var action: ActionKind`): SwiftData は enum をサポートするが `rawValue: String` の方が migration 安全
- `@Relationship(deleteRule: .nullify)` を ConceptPage に張る: 上記理由で却下
- 1 @Model に 4 つの optional 関連 (`conceptPage: ConceptPage?` + `savedAnswer: SavedAnswer?` + ...): スキーマ複雑化 + cascade 不要

---

## R2: UnderstandingCard (transient struct)

**Decision**: SwiftUI 用 transient `struct UnderstandingCard: Identifiable, Hashable`、@Model ではない。Surface ロジックが ConceptPage / SavedAnswer を都度 wrap して返却。

```swift
struct UnderstandingCard: Identifiable, Hashable {
    let id: UUID                          // 元 entity.id
    let kind: UnderstandingCardKind       // .conceptPage(ConceptPage) or .savedAnswer(SavedAnswer)
    let priorityScore: Int                // 内部 surface 順位 (UI 非表示)
    let label: UnderstandingCardLabel     // .newKnowledge / .needsUpdate / .shallow / .deepDive / .review
    let lastInteractedAt: Date?           // 行動履歴最新 occurredAt、nil なら未操作
}

enum UnderstandingCardKind: Hashable {
    case conceptPage(ConceptPage)
    case savedAnswer(SavedAnswer)
}

enum UnderstandingCardLabel: String, Hashable {
    case newKnowledge   // 「新しい知識」
    case needsUpdate    // 「更新が必要」
    case shallow        // 「理解が浅い」
    case deepDive       // 「深掘り余地あり」
    case review         // 「復習」
}
```

**Rationale**:
- 永続化不要 (ConceptPage / SavedAnswer 自体が source of truth)、再構築コスト 0
- `Identifiable` + `Hashable` → SwiftUI `ForEach` + `navigationDestination(for:)` 互換
- `UnderstandingCardKind` が SwiftData @Model を保持するが、UI 表示時間のみ生存 (List scroll で fetch されたインスタンス) なので detach 心配なし

**Alternatives considered**:
- `@Model UnderstandingCard`: 不要な永続化、ConceptPage 更新時の同期が複雑化
- `enum UnderstandingCardData { case conceptPage(UUID) ... }` で ID のみ持つ: View 側で都度 fetch する必要、UI コード肥大
- Generic 化 (`UnderstandingCard<T>` where T: PersistentModel): Swift 6 actor isolation で扱い辛い

---

## R3: 5-tier Surface Priority Scoring (UnderstandingCardSurfaceService)

**Decision**: priorityScore Int を計算後、desc + tiebreak (savedAt/createdAt desc) で sort、`prefix(limit)`。

| label         | base score | 条件 |
|---------------|-----------|-----|
| newKnowledge  | 100       | ConceptPage で `createdAt >= now - 24h` かつ `userUnderstanding == 0` |
| needsUpdate   | 90        | SavedAnswer で `isStale == true` |
| shallow       | 80        | ConceptPage で `userUnderstanding in [0,1]` かつ関連記事の最新 savedAt >= now - 7d |
| deepDive      | 60        | ConceptPage で `userUnderstanding in [2,3]` かつ `isFollowing == true` |
| review        | 40        | ConceptPage で `lastInteractedAt == nil` or `lastInteractedAt < now - 30d` |

**Modifier**:
- `UnderstandingInteraction` で `action == "dismissed"` 既往あり → priority -10 (重ね掛けせず flat -10)
- tiebreak: ConceptPage `savedAt` / SavedAnswer `savedAt` desc

**Edge cases**:
- 全 ConceptPage の userUnderstanding == 5: review 候補のみ残る → さらに 0 件なら空状態 placeholder (US1 Edge Case)
- 同 entity が複数 label 該当: 最高 score の label 1 つ採用 (例: 新規 ConceptPage で isStale も該当した SavedAnswer は別 entity なので競合しない)

**Rationale**:
- 5-tier は spec input で確定、UX として「新しい・更新必要・理解浅い・深掘り・復習」5 種は人間が認知しやすい
- score は 100 / 90 / 80 / 60 / 40 で 10 単位、dismissed -10 と干渉せず明確に序列保持

**Alternatives considered**:
- ML scoring: 過剰、Phase A scope 外
- ユーザー手動順位: VISION「AI が選ぶ」原則と衝突
- 7-tier 細分化: UX 認知負荷増、5 tier で十分

---

## R4: 1-hop Graph 波及 (UnderstandingTrackerService)

**Decision**: `recordUnderstood(card:)` で本体 ConceptPage を +1 (clamp 0-5) した後、`GraphTraversalService.neighbors(of:hops:1)` で取得した neighbor ConceptPage に +0.5 (累積で +1 化)。

実装:
```swift
func recordUnderstood(card: UnderstandingCard) async throws {
    // 1. 履歴 insert
    try insertInteraction(card: card, action: .understood)
    // 2. 対象 ConceptPage 解決
    let conceptIDs = resolveConceptIDs(card: card)  // SavedAnswer なら relatedConceptIDs
    // 3. 本体 +1
    for id in conceptIDs {
        try await incrementUnderstanding(conceptID: id, by: 1)
    }
    // 4. 1-hop 波及 +0.5
    if let graph = graphService {
        for id in conceptIDs {
            let neighbors = try await graph.neighborConceptIDs(for: id, hops: 1)
            for neighborID in neighbors {
                try await incrementUnderstanding(conceptID: neighborID, by: 0.5)
            }
        }
    }
    refreshTrigger?.bump()
}
```

`userUnderstanding` は `Int` なので +0.5 は **履歴累積** で表現:
- `UnderstandingInteraction` で当該 ConceptPage に対する `understood` action の **波及分** を別 action `"propagated"` で記録
- 計算時: ConceptPage.userUnderstanding = baseUnderstanding (直接 +1 回数) + floor(propagatedCount × 0.5) を都度算出 → 永続化された ConceptPage.userUnderstanding は直接 +1 回数の累積 (整数)

**簡略化**: 1-hop 波及は累積で +1 と扱う (Float キャッシュなし)。すなわち propagation が 2 回累積 = +1 増加。

実装ルール:
- ConceptPage.userUnderstanding +1 = 直接 understood イベント 1 回
- ConceptPage.userUnderstanding +1 (propagation) = neighbor として propagated 2 回 (round-half-up)
- すべて clamp [0, 5]

**Rationale**:
- Float キャッシュを ConceptPage に持つと spec 042 schema を改修必要 (避けたい)、UnderstandingInteraction 履歴のみで完結
- 1-hop limit (depth=1) は graph 大規模化での O(N^2) 回避、SC-004「2 秒以内」維持

**Alternatives considered**:
- 2-hop / 3-hop: 関連性希薄化 + 計算コスト 増 → 却下
- Float キャッシュ: spec 042 ConceptPage schema 変更必要 → 却下
- 単純な +1 のみ (波及なし): VISION「腹落ちは概念ネットワークで起こる」を表現できず → 却下

---

## R5: Deep Dive Chat Starter (DeepDiveChatStarter)

**Decision**: 既存 `ChatService.createSession()` + `ChatService.ask()` 流用、Service の薄い wrapper のみ新規。

```swift
@MainActor
protocol DeepDiveChatStarterProtocol: AnyObject {
    func startChat(for card: UnderstandingCard) async throws -> ChatSession
}

@MainActor
final class DefaultDeepDiveChatStarter: DeepDiveChatStarterProtocol {
    private let chatService: ChatServiceProtocol
    private let tracker: UnderstandingTrackerServiceProtocol

    func startChat(for card: UnderstandingCard) async throws -> ChatSession {
        let session = try chatService.createSession()
        session.title = makeTitle(for: card)
        let context = buildTutorContext(for: card)
        _ = try await chatService.ask(message: context, in: session)  // 初期発話 AI 自動生成
        try await tracker.recordOpenedChat(card: card)
        return session
    }
}
```

`buildTutorContext` プロンプト template:
```
あなたは家庭教師として、ユーザーが「{conceptName}」を腹落ちするまで助けてください。
質問に答えるだけでなく、ユーザーの理解度を確認する逆質問や、関連する保存記事への参照を促してください。
今、ユーザーは{kind == .conceptPage ? "この概念" : "この質問の答え"}について深く理解したいと考えています。
まず最初の質問: ユーザーがこの概念について現時点で気になっていることは何かを 1 つ問いかけてください。
```

ConceptPage 用は `essence` + 上位 KeyFact 2 つを追加 context、SavedAnswer 用は question + answer 冒頭 100 字を追加。

**Rationale**:
- ChatService 改修ゼロ (既存 API のみ利用)
- prompt 注入で「家庭教師調」を実現、新 LM API 不要
- Apple Intelligence 不可時は ChatService 既存 fallback (essence 並べ) に乗る → silent degrade

**Alternatives considered**:
- ChatService に `createTutorSession()` 追加: ChatService に concept 知識を漏らす、層分離違反
- 新規 LM session: Foundation Models 重複インスタンス、メモリ無駄
- AI 初期発話を手動入力 (ユーザーが最初の質問書く): UX 劣化 (US2 シナリオ違反)

---

## R6: 起動時 default Tab 切替 (LastOpenedStore migration)

**Decision**: `KnowledgeTreeApp.init()` で `LastOpenedStore` の default を `.learning` 新 case に切替、既存ユーザーは UserDefaults キー存在チェックで 1 回限り強制リセット。

```swift
// LastOpenedStore.swift (改修)
enum AppTab: String, Hashable {
    case learning      // ★ 新規、4 タブ目だが UI 順序は 1 番目
    case aiChat
    case knowledgeClip
    case library
}

// KnowledgeTreeApp.swift (改修)
init() {
    let store = LastOpenedStore()
    // spec 044 migration: 初回起動 or .knowledgeClip default ユーザーは .learning に強制
    if !UserDefaults.standard.bool(forKey: "spec044_learningTabMigrated") {
        store.lastTab = .learning
        UserDefaults.standard.set(true, forKey: "spec044_learningTabMigrated")
    }
    self.lastOpenedStore = store
}
```

**Rationale**:
- 既存 spec 035 で `.knowledgeClip` を default にした migration と同パターン
- UserDefaults キー 1 つで idempotent、再起動で意図せず戻らない
- session 内では `store.lastTab = .aiChat` 等で自由に変更可 (FR-002 シナリオ 2 で「前回選択タブ維持」)

**Alternatives considered**:
- 強制せず default のみ変更: 既存ユーザーは前回の .knowledgeClip を維持してしまい SC-005 違反
- 毎起動強制: ユーザーが選択した別タブを記憶しない、不便
- spec 035 LastOpenedStore 削除: 機能後退、spec 035 設計を壊す

---

## R7: UnderstandingTabView レイアウト (4 タブ構成)

**Decision**: `TabView` の 1 番目 (index 0) に「学習」(SF Symbol `book.fill`)、order: 学習 / AI チャット / 知識 Clip / ライブラリ。

```swift
TabView(selection: $lastOpenedStore.lastTab) {
    UnderstandingTabView()
        .tabItem { Label("学習", systemImage: "book.fill") }
        .tag(AppTab.learning)
    ChatTabView()
        .tabItem { Label("AI チャット", systemImage: "bubble.left.and.bubble.right.fill") }
        .tag(AppTab.aiChat)
    KnowledgeClipView()
        .tabItem { Label("知識 Clip", systemImage: "lightbulb.fill") }
        .tag(AppTab.knowledgeClip)
    ArticleListView()
        .tabItem { Label("ライブラリ", systemImage: "books.vertical.fill") }
        .tag(AppTab.library)
}
```

UnderstandingTabView body:
- ScrollView + LazyVStack + 上位 5 件 ForEach + 「+N すべて見る」NavigationLink + 空状態 placeholder
- `.task { await refresh() }` で `surfaceService.surfaceTopCards(limit: 5)` + `surfaceAllCards().count` を読み込み
- `navigationDestination(for: UnderstandingCard.self) { card in DeepDiveChatView(card: card) }`
- `navigationDestination(for: UnderstandingCardListDestination.self) { _ in UnderstandingCardListView() }`

**Rationale**:
- 4 タブ目に追加すると右端 (ライブラリの隣) になり既存ユーザーが見落とす → 左端 (index 0) で起動 default と一致
- `book.fill` は SF Symbols で「学習」の概念に合致

**Alternatives considered**:
- 3 タブのまま「AI チャット」に統合: surface UX が deep dive と混ざり認知負荷増
- 5 タブ (Settings 含む): iOS HIG で「タブは 5 個以内が望ましい」、本 spec で限界
- 右端配置: 起動 default にすると違和感、index 0 が自然

---

## R8: UnderstandingCardRow (統一 UI for ConceptPage / SavedAnswer)

**Decision**: 1 つの `UnderstandingCardRow` で両 kind を表示、kind switch で icon + 主タイトル差別化。

```swift
struct UnderstandingCardRow: View {
    let card: UnderstandingCard

    var body: some View {
        HStack(spacing: 12) {
            iconView                                  // 概念 or 質問 icon (SF Symbol)
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)                       // ConceptPage.name or SavedAnswer.question preview
                    .font(.body)
                    .foregroundStyle(DesignSystem.dsPrimaryText)
                HStack(spacing: 8) {
                    LabelBadge(label: card.label)     // 「新しい知識」等
                    if let lastInteracted = card.lastInteractedAt {
                        Text(SavedAtFormatter.relative(from: lastInteracted))
                            .font(.caption)
                            .foregroundStyle(DesignSystem.dsSecondaryText)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
        }
        .padding(12)
        .background(DesignSystem.dsCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("card.understanding.\(card.kindString).\(card.id.uuidString)")
    }
}
```

iconView: `.conceptPage` → `lightbulb.fill` (DesignSystem.actionBlue) / `.savedAnswer` → `quote.bubble.fill` (DesignSystem.dsAccent)
LabelBadge: SwiftUI capsule + 5 色 (newKnowledge=green, needsUpdate=orange, shallow=yellow, deepDive=blue, review=gray)

**Rationale**:
- 2 種別の Row を別 View にすると重複コード、統一 Row でロジック集約
- DesignSystem (spec 014/017) 流用、Dark Mode 自動対応

**Alternatives considered**:
- ConceptPageRow / SavedAnswerRow 別: 重複コード ~60 行、保守負荷増
- カード形 (画像つき): MVP 過剰、Phase A scope 外

---

## R9: DeepDiveChatView (既存 chat UI + sticky 3 button)

**Decision**: 既存 `ChatTabView` の messages 表示部 + `ChatInputField` を再利用 (component 抽出)、下部に 3 ボタン bar sticky 追加。

```swift
struct DeepDiveChatView: View {
    let card: UnderstandingCard
    @State private var session: ChatSession?
    @State private var isInitializing = true

    var body: some View {
        VStack(spacing: 0) {
            if isInitializing {
                ProgressView("家庭教師を起動中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let session {
                // 既存 ChatTabView の messages + input 部分を抽出した ChatBodyView
                ChatBodyView(session: session)
            }
            UnderstandingActionBar(card: card, session: session)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.regularMaterial)
        }
        .navigationTitle(card.deepDiveTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                session = try await deepDiveStarter.startChat(for: card)
                isInitializing = false
            } catch {
                isInitializing = false
                logger.error("deep dive chat start failed: \(error)")
            }
        }
    }
}
```

`UnderstandingActionBar`: HStack with 3 buttons (✓ わかった / 🤔 もっと / ✗ 違う)、各 tap で tracker call + 視覚 fb (haptic light、Constitution V 合致、効果音なし)

**Rationale**:
- 既存 ChatTabView を component 化することで AI チャットタブと UI 統一性維持
- sticky bar は `.regularMaterial` で背景透けつつ可読性確保

**Alternatives considered**:
- ChatTabView 内に学習モード trigger: 状態管理複雑化、独立 view が clean
- sheet 表示: full screen が深掘り体験に合う、sheet は半端
- 3 ボタンを toolbar 配置: 親指届きにくい (片手操作 Constitution V 違反)

---

## R10: ConceptPage 詳細「学習する」Button (P2 US9)

**Decision**: `ConceptPageDetailView` の toolbar に `Button("学習する", systemImage: "book.fill")` 追加、tap で `DeepDiveChatStarter.startChat()` 経由で `DeepDiveChatView` push。

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            // ConceptPage を transient UnderstandingCard に wrap
            let card = UnderstandingCard.fromConceptPage(conceptPage)
            // navigationDestination 経由で push
            navigationPath.append(card)
        } label: {
            Label("学習する", systemImage: "book.fill")
        }
        .accessibilityIdentifier("button.learn")
    }
}
```

ConceptPageDetailView 親側 (KnowledgeClipView) で `navigationDestination(for: UnderstandingCard.self) { DeepDiveChatView(card: $0) }` 配線必要。

**Rationale**:
- 学習タブを経由せず、ConceptPage 詳細から最短導線 (US9 シナリオ 1)
- toolbar 右上は ConceptPage 詳細既存 toolbar (ピン / 編集 / 削除) と整合

**Alternatives considered**:
- 詳細画面下部に大きな CTA Button: 既存 layout 圧迫
- floating action button: iOS HIG 非推奨

---

## R11: SavedAnswer Surface 戦略 (P2 US8)

**Decision**: `UnderstandingCardSurfaceService` の 5-tier に SavedAnswer 候補を統合。優先順は label = .needsUpdate (isStale) が priority 90 で 2 位、関連 ConceptPage が無くても savedAt 新しい順で surface。

実装:
```swift
// SurfaceService 内
let staleSavedAnswers = try context.fetch(FetchDescriptor<SavedAnswer>(
    predicate: #Predicate { $0.isStale == true },
    sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
))
let recentSavedAnswers = try context.fetch(FetchDescriptor<SavedAnswer>(
    predicate: #Predicate { $0.isStale == false && $0.savedAt >= cutoffDate },
    sortBy: [SortDescriptor(\.savedAt, order: .reverse)],
    fetchLimit: 20
))
// score 化: stale = 90、recent (24h以内 + relatedConceptIDs.isEmpty == false) = 70 (newKnowledge と shallow の間)
```

**Rationale**:
- SavedAnswer は spec 043 で auto-save された Compound Moment、surface して家庭教師化することで「答え取って終わり」を防ぐ
- isStale (spec 043 既存) は WikiLint 仕込み、本 spec で初活用

**Alternatives considered**:
- SavedAnswer は surface しない (ConceptPage のみ): VISION「秘書 → 家庭教師の自然な接続」(US8) 違反
- 全 SavedAnswer surface: ノイズ多すぎ、stale + 24h 以内 + relatedConceptIDs 非空 に限定

---

## R12: テスト戦略 (in-memory ModelContainer + Mock service)

**Decision**: 3 新 service 各テストファイル + 既存 ChatServiceTests に追加なし (本 spec で ChatService 無改修)。Mock は `MockChatService` (新規) + `MockUnderstandingTrackerService` (DeepDiveChatStarterTests 用)。

| Test File | ケース数 | 主検証ポイント |
|-----------|---------|--------------|
| UnderstandingCardSurfaceServiceTests | 10 | 空状態 / 新規優先 / isStale 優先 / shallow / dismissed -10 / 上限 5 / ブレンド / 全 max → review fallback / label 付与 / tiebreak savedAt desc |
| UnderstandingTrackerServiceTests | 8 | recordUnderstood +1 / max clamp / 1-hop 波及 / needMore 不変 + 履歴 / dismissed surface 下位 / SavedAnswer 経由波及 / graph 不存在 silent / 連打 max 停止 |
| DeepDiveChatStarterTests | 5 | ChatSession 作成 + title / tutor prompt 注入 / openedChat 履歴 / Foundation 不可 fallback (Mock LM) / SavedAnswer 経路 |
| UnderstandingTabUITests (UI) | 3 | 学習タブ起動 / カードタップ / 「✓ わかった」 |

全テスト共通:
- in-memory `ModelContainer(SharedSchema.all, configurations: ModelConfiguration(isStoredInMemoryOnly: true))`
- `Date.now` 注入 (テスト用 `now: () -> Date` parameter で固定可能、spec 037 / 042 / 043 同パターン)
- 既存 `MockLanguageModelSession` (spec 021 で導入) 流用、DeepDiveChatStarterTests 用に答え template 1 つ追加

**Rationale**:
- 23 ケース (10+8+5) = spec 042 (10+8+10 = 28) と同規模、Phase A 最大 spec の品質担保
- UI テスト 3 件は pre-existing flaky 8 件と分離 (新規 file)、CI 安定性確保

**Alternatives considered**:
- Integration テスト (実 ChatService + 実 LM): Foundation Models simulator 不安定、CI 不向き
- Mock 全置換 (Mock GraphTraversalService 等): graph service は in-memory ModelContainer で実体動作可、Mock 不要
- Snapshot テスト: Phase A scope 外、Phase B 候補

---

## Resolved Dependencies

| Dep | Spec | Usage in 044 |
|-----|------|-------------|
| ConceptPage `@Model` + userUnderstanding | spec 042 | Surface 主対象、+1 直接記録先 |
| SavedAnswer `@Model` + isStale | spec 043 | Surface 副対象、needsUpdate label |
| ChatService createSession + ask | spec 021 | DeepDiveChatStarter wrapper 経由 |
| GraphTraversalService neighbors | spec 040 | 1-hop 波及 (optional、無ければ skip) |
| LastOpenedStore + AppTab enum | spec 035 | .learning 新 case + default 切替 |
| SavedAtFormatter relative | spec 016 | Row 内 lastInteractedAt 表示 |
| DesignSystem.adaptive + dsCardBackground 等 | spec 017 | Card UI Dark Mode 自動対応 |
| RefreshTrigger.bump() | 既存 | Tracker 更新後 UI 反映 |
| ServiceContainer DI | 既存 | 3 新 service + ChatService 配線 |

---

## Unresolved / Deferred (将来 spec)

- 1-hop 波及の AI 質問生成 (波及した関連 ConceptPage に「これも理解した?」AI 質問追加): Phase B 候補
- 同 ConceptPage への複数 ChatSession 集約 (現状: 都度新規 ChatSession、過去 deep dive は AI チャットタブの履歴に残る): Phase B
- Streak / 通知 / バッジ (VISION + Constitution V で永久 non-goal): 実装しない
- 「正解 / 不正解」テスト UI (VISION 非ゴール): 実装しない
- Widget 学習カード表示: spec 048

全 12 research 項目 resolved、NEEDS CLARIFICATION ゼロ。Phase 1 design に進む準備完了。
