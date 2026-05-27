# Research: Agentic Chat

**Branch**: `056-uiux-redesign-v3` | **Date**: 2026-05-24

10 個の技術判断 (R1-R10) を Decision / Rationale / Alternatives 形式で記録。

---

## R1: AgentAction `@Generable` enum design

**Decision**: 4 case の単一 enum、各 case に最小限の payload:

```swift
@Generable
enum AgentAction {
    @Guide(description: "即答可能な質問への直接回答")
    case immediate(answer: String)
    
    @Guide(description: "intent 曖昧、聞き返しと 3 候補で確認")
    case askClarification(question: String, suggestions: [String])
    
    @Guide(description: "保存記事から検索する必要あり")
    case searchArticles(query: String, threshold: Double)
    
    @Guide(description: "search 結果統合後の最終答え")
    case finalAnswer(text: String, citedArticleIDs: [UUID])
}
```

**Rationale**:
- 4 case で agent loop の全 path を表現 (intent 確認 → 検索 → 答え)
- payload を最小に保ち、Generable schema が 4096 token に収まる
- Foundation Models の Generable enum は単純な case + 基本型でないと unstable

**Alternatives**:
- (rejected) `case useToolByName(toolName: String, args: [String: Any])` → Any 型は Generable 不可
- (rejected) 多段 enum (Action → SubAction) → 構造複雑、Generable 解析弱い
- (rejected) plain String + parser → format 違反で死ぬ

---

## R2: ChatService 内部 refactor vs 新 AgenticChatService protocol

**Decision**: **内部 refactor** (新 protocol 作らない)。

既存 `ChatServiceProtocol.send(question:in:contextMessages:)` の signature を維持し、内部実装を agent loop に全面書き換え。新 `AgenticChatService` protocol は作らず、ChatService 単一に統合。

**Rationale**:
- spec.md FR-022 で「public API 維持」を要件
- 二重 protocol は混乱の元 + DI の冗長化
- UI (ChatTabView) を無改修にする目標と整合
- 既存 spec 021/033/047 の test が PASS し続ける regression 保証

**Alternatives**:
- (rejected) 並行運用 (旧 ChatService + 新 AgenticChatService) → code 重複 + routing logic 必要
- (rejected) 新 protocol で完全置換 → UI 全 view 改修が必要、影響大

---

## R3: max 3 round clarification の terminate 条件 + state machine

**Decision**: agent loop の state machine:

```
[Initial] → LLM.generateAgentAction(question)
  ↓
case .immediate(answer)          → [Final: answer]
case .askClarification(q, chips) → [Round N (max 3)]
  ↓ user responds (chip tap or free text)
case .askClarification → loop until Round 3
  ↓ Round 3 reached
forceForceFinalAnswer (LLM に「もう情報集まった、最善努力で答えて」prompt)
  ↓
case .finalAnswer(text, cites) → [Final: answer + cites]
case .searchArticles(query, threshold) → embedding 検索 → 結果を context 追加 → LLM 再呼出
  ↓
最終的に .finalAnswer or .immediate で terminate
```

```swift
enum AgentState {
    var clarificationRound: Int = 0     // max 3
    var searchPerformed: Bool = false   // max 1 search per loop (effectively)
    var conversationContext: [ChatMessage]  // user + assistant pairs
}
```

**Rationale**:
- max 3 round 後は **forceFinalAnswer** prompt で必ず answer 生成 (FR-010)
- search は max 1 回 / loop (token efficiency)
- state machine が確定的、debug 容易

**Alternatives**:
- (rejected) unlimited clarification → ユーザー疲弊
- (rejected) max 1 round で即 final → 体験が「ChatGPT 風」にならない、聞き出せない
- (rejected) search 複数回許可 → token 爆発リスク

---

## R4: HedgePhraseFilter のキーワード set + 置換ロジック

**Decision**: 純粋関数 `HedgePhraseFilter.replace(_:)`、出力 string を post-process:

```swift
enum HedgePhraseFilter {
    static let bannedPhrases = [
        "分かりません",
        "分かりかねます",
        "答えられません",
        "回答できません",
        "情報がありません",
        "情報を持っていません",
        "知りません",
        "不明です"
    ]
    
    static let hedgeReplacements = [
        "私の理解では",
        "一般的には",
        "あくまで概要として",
        "確実ではありませんが"
    ]
    
    static func replace(_ text: String) -> String {
        var result = text
        for banned in bannedPhrases {
            if result.contains(banned) {
                let hedge = hedgeReplacements.randomElement() ?? "私の理解では"
                result = result.replacingOccurrences(of: banned, with: hedge)
            }
        }
        return result
    }
}
```

**Rationale**:
- 純粋関数 = test 容易、deterministic
- 「分かりません」絶対排除 (FR-008/009)
- 自然な hedge phrase でユーザーに「これは確実ではない」と伝わる
- LLM prompt 制約 + post-process filter の二段構え

**Alternatives**:
- (rejected) prompt 制約のみ → LLM の挙動ブレで「分かりません」漏れる
- (rejected) LLM に hedge 出力させる (二度の LM 呼び) → 遅い
- (rejected) regex 複雑置換 → 過剰、誤検知リスク

---

## R5: ClarificationChipsView の UI レイアウト + auto-fill 連動

**Decision**: assistant message bubble の下に horizontal `FlowLayout` で 3 chip:

```swift
struct ClarificationChipsView: View {
    let suggestions: [String]
    let onTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onTap(suggestion)
                } label: {
                    Text(suggestion)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().stroke(.tint, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("clarification.chip.\(suggestion)")
            }
        }
    }
}
```

ChatTabView 側で chip tap → input field に auto-fill + 自動送信:

```swift
.onChange(of: tappedChip) { _, chip in
    guard let chip else { return }
    inputText = chip
    Task { await sendQuestion() }
    tappedChip = nil
}
```

**Rationale**:
- shipping pattern (Apple Mail / Notes の suggested actions に近い)
- auto-fill + 自動送信で「即決感」を出す (体験速い)
- 自由入力 (chip 無視) も可能、柔軟

**Alternatives**:
- (rejected) horizontal scroll → chip 多いと迷う、3 件固定で OK
- (rejected) chip tap で input fill のみ (自動送信なし) → 1 tap 余分

---

## R6: AnswerActionsMenu の long press 実装

**Decision**: SwiftUI 標準 `.contextMenu` を ChatMessageRow の assistant bubble に追加:

```swift
.contextMenu {
    Button {
        savedAnswerService?.saveExplicit(question: question, answer: message.text)
    } label: {
        Label("answer.actions.save", systemImage: "star")
    }
    Button {
        UIPasteboard.general.string = message.text
    } label: {
        Label("answer.actions.copy", systemImage: "doc.on.doc")
    }
    ShareLink(item: message.text) {
        Label("answer.actions.share", systemImage: "square.and.arrow.up")
    }
}
```

**Rationale**:
- iOS 標準 long press パターン、user familiar
- ShareLink で iOS native ShareSheet
- 実装シンプル、custom view 不要

**Alternatives**:
- (rejected) swipe actions → List 内じゃないと不適切
- (rejected) custom long press gesture + sheet → 過剰実装、Apple pattern 違反
- (rejected) bubble 下に常時 toolbar → UI 圧迫

---

## R7: SavedAnswer auto-save 廃止の hook 削除戦略

**Decision**:
- `SavedAnswerService.captureIfWorthy / captureIfWorthyOrReplaceStale` メソッドを **no-op に変更** (中身を return; に置換)
- public API は維持 (既存 ChatService の hook 呼び出しを壊さない)
- 新規 `saveExplicit(question: String, answer: String, citedArticleIDs: [UUID] = [])` を追加

```swift
final class DefaultSavedAnswerService: SavedAnswerServiceProtocol {
    // spec 057: auto-save 廃止、no-op 化
    func captureIfWorthy(question: String, answer: String, citedArticleIDs: [UUID], sessionID: UUID?) throws {
        // no-op (spec 057 で auto-save 廃止)
    }
    
    func captureIfWorthyOrReplaceStale(question: String, answer: String, citedArticleIDs: [UUID], sessionID: UUID?) throws {
        // no-op
    }
    
    // spec 057 新規: 明示的に保存
    func saveExplicit(question: String, answer: String, citedArticleIDs: [UUID] = []) throws -> SavedAnswer {
        let saved = SavedAnswer(question: question, answer: answer, ...)
        // 関連 ConceptPage 解決 (spec 043 ロジック流用)
        ...
        context.insert(saved)
        try context.save()
        return saved
    }
}
```

**Rationale**:
- 既存 hook 呼び出し箇所 (ChatService.send / extract hook) を改修不要
- 過去データロスゼロ (FR-026)
- 新規明示保存 API でも spec 043 の関連 ConceptPage 解決ロジックは流用

**Alternatives**:
- (rejected) hook 呼出箇所を全て削除 → diff 大、regression risk
- (rejected) hook を残し、auto-save 条件を緩和 → spec 意図と矛盾 (Q3 = C → A 微調整)

---

## R8: token efficiency for Generable enum

**Decision**:
- AgentAction enum の case name を短く (case `.immediate` ではなく case `.imm` も検討、ただし可読性のため `.immediate` 維持)
- payload string は max 200 char (clarification question + suggestions[0..3])
- context (multi-turn) は直前 4 message に限定 (既存 spec 033 同様)
- search results を context に追加する時、各 article の essence は 100 char に truncate

**token budget** (4096 上限):
- AgentAction Generable schema: ~800 token
- prompt (system + context 4 message): ~1500 token
- search results (3 articles × 100 char): ~300 token
- 余裕: ~1500 token (response 用)

**Rationale**:
- 既存 spec 010/044 の token 縮小ノウハウを継承
- 4096 上限超過時は graceful degrade (context 4 → 2 reduce)

**Alternatives**:
- (rejected) max token 8192 端末専用機能 → 互換性問題
- (rejected) chunked agent loop → 複雑

---

## R9: agent loop debug logging

**Decision**: NSLog で agent state 遷移を出力:

```swift
NSLog("agent loop: round=\(state.clarificationRound) action=\(action) elapsed=\(elapsed)ms")
```

production では `#if DEBUG` で除外、Console.app で開発時のみ可視。

**Rationale**:
- agent loop の debug が容易 (state 遷移 visible)
- production には影響なし

**Alternatives**:
- (rejected) print() → release build に残る
- (rejected) os_log → 形式厳密、debug にはオーバースペック

---

## R10: テスト戦略

**Decision**: 既存 `MockLanguageModelSession` を拡張、AgentAction 返却 sequence を制御可能に:

```swift
// MockLanguageModelSession 拡張
var nextAgentActions: [AgentAction] = []  // FIFO
func generateAgentAction(prompt: String, context: [ChatMessage]) async throws -> AgentAction {
    guard !nextAgentActions.isEmpty else {
        return .immediate(answer: "default answer")
    }
    return nextAgentActions.removeFirst()
}
```

テスト構成:
- **AgentActionTests** (10 ケース): Generable Codable round-trip + enum 分岐
- **AgenticChatServiceTests** (10+ ケース): 各 agent loop path (immediate / clarification 1-3 round / search / forceFinalAnswer / hedge filter)
- in-memory ModelContainer + Mock LM + Date 注入

**Rationale**:
- deterministic test (FIFO sequence で各 path テスト可能)
- 既存 MockLanguageModelSession パターン踏襲
- Generable round-trip で format 違反検出

**Alternatives**:
- (rejected) live Foundation Models で test → flaky、CI 不可
- (rejected) UI test 中心 → unit test 容易性失う
