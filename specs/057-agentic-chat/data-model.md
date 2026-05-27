# Data Model: Agentic Chat

**Branch**: `056-uiux-redesign-v3` | **Date**: 2026-05-24

## Summary

**新規 SwiftData @Model: なし** (UI / Service layer のみの spec)。
Apple Foundation Models との agent loop で扱う型 + transient struct のみ。

---

## 新規 Generable enum (1)

### `AgentAction`

LLM が agent loop の毎 turn で返す Generable enum、Swift 側で switch 分岐。

**定義場所**: `KnowledgeTree/Models/AgentAction.swift`

```swift
import Foundation
import FoundationModels

@Generable
enum AgentAction: Sendable, Codable, Equatable {
    @Guide(description: "明確な質問への即答 (一般知識で答え、検索なし)")
    case immediate(answer: String)

    @Guide(description: "intent 曖昧、聞き返し質問 + 3 候補")
    case askClarification(question: String, suggestions: [String])

    @Guide(description: "保存記事を検索する必要あり")
    case searchArticles(query: String)

    @Guide(description: "検索結果を統合した最終答え (引用 article IDs 付き)")
    case finalAnswer(text: String, citedArticleIDs: [UUID])
}
```

**ライフサイクル**: 永続化なし、agent loop 内で transient に流れる。

---

## 新規 Transient Struct (4)

### 1. `AgentState`

agent loop の状態管理 (round count + 蓄積 context)。

**定義場所**: `KnowledgeTree/Services/ChatService.swift` (private struct or extension)

```swift
struct AgentState {
    var clarificationRound: Int = 0      // 0..3 (max 3 で forceFinalAnswer)
    var searchPerformed: Bool = false    // search は 1 loop につき 1 回まで
    var conversationContext: [ChatMessage]  // 直前 4 message + clarification 中の history
    var clarificationHistory: [(question: String, response: String)] = []
}

extension AgentState {
    var isMaxRoundReached: Bool { clarificationRound >= 3 }
    mutating func incrementRound() { clarificationRound += 1 }
}
```

**ライフサイクル**: ChatService.send(...) の関数内 local var、return で破棄。

---

### 2. `SuggestedChip`

clarification 時に表示する 1 つの suggestion。

**定義場所**: `KnowledgeTree/Views/ClarificationChipsView.swift` (private)

```swift
struct SuggestedChip: Identifiable, Hashable {
    let id: UUID = UUID()
    let text: String  // tap で auto-fill されるテキスト
}
```

**ライフサイクル**: 各 clarification turn で生成、tap or 自由入力で消失。

---

### 3. `HedgePhrase` (constants)

「分かりません」置換用 hedge phrase 集。

**定義場所**: `KnowledgeTree/Services/HedgePhraseFilter.swift`

```swift
enum HedgePhraseFilter {
    /// 排除対象キーワード (これらが含まれていたら hedge に置換)
    static let bannedPhrases: [String] = [
        "分かりません",
        "分かりかねます",
        "答えられません",
        "回答できません",
        "情報がありません",
        "情報を持っていません",
        "知りません",
        "不明です"
    ]

    /// 置換用 hedge phrase (ランダム選択)
    static let hedgeReplacements: [String] = [
        "私の理解では",
        "一般的には",
        "あくまで概要として",
        "確実ではありませんが"
    ]

    static func replace(_ text: String) -> String { ... }
}
```

**ライフサイクル**: 静的定数、library-wide reuse。

---

### 4. `AgentLoopResult`

agent loop の最終結果 (ChatService.send の return 型に統合 or 内部使用)。

```swift
struct AgentLoopResult {
    let finalMessage: ChatMessage      // assistant message (永続化済 or 未永続化)
    let citedArticleIDs: [UUID]
    let clarificationRoundsUsed: Int
    let usedSearch: Bool
    let elapsedMilliseconds: Int
}
```

**ライフサイクル**: ChatService 内部の return 型、UI には ChatMessage のみ渡す。

---

## UserDefaults キー (1)

### 1. `spec057_longPressHintShown` (Bool)

長押し menu の初回 hint tooltip 表示済フラグ。

- **型**: `Bool`
- **read/write**: ChatTabView (.onAppear or first answer rendered) で参照、初回表示後 true 永続化
- **初期値**: `false`
- **更新タイミング**: 初回 hint 表示 + dismiss 完了で true に

---

## 既存 @Model / Service の利用箇所

| 既存 @Model | 利用箇所 |
|---|---|
| `Article` | AgentAction.searchArticles → embedding 検索 → 引用 article IDs |
| `ChatMessage` | agent loop の context、最終 assistant message として永続化 |
| `ChatSession` | session 単位の context、sidebar 表示 (spec 033 維持) |
| `SavedAnswer` | 長押し menu「保存」で明示作成 (auto-save 廃止) |
| `ConceptPage` | spec 047 関連 chip 表示 (引用 articles から overlap top 3) |

| 既存 Service | 利用箇所 |
|---|---|
| `EmbeddingService` (spec 021) | AgentAction.searchArticles の embedding cosine similarity |
| `SavedAnswerService` (spec 043) | captureIfWorthy = no-op 化 + saveExplicit 新規 |
| `LanguageModelSessionProtocol` | `generateAgentAction(prompt:context:)` 新規メソッド |
| `MockLanguageModelSession` | テスト用、AgentAction sequence FIFO 制御 |
| `RefreshTrigger` | UI 反映 (clarification 表示時 / 答え表示時) |
| `ServiceContainer` | ChatService inject 経路維持 |

---

## Schema 変更ゼロ確認

```
新規 @Model: 0
既存 @Model 変更: 0
@Attribute 変更: 0
@Relationship 変更: 0
SharedSchema 変更: 0
lightweight migration 不要
CloudKit schema 影響なし
```

SwiftData / CloudKit の観点では完全に純 Service/UI refactor。spec 056 と一括 V3.0 release しても schema 衝突なし。
