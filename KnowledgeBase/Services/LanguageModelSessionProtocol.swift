//
//  LanguageModelSessionProtocol.swift
//  KnowledgeTree
//
//  spec 004 — Apple Foundation Models 抽象境界 + Generable 型定義
//
//  Generable 型 (transient、生成出力スキーマ) は本ファイルで集中定義。
//  @Model 型 (persistent、SwiftData 永続化) は Models/ExtractedKnowledge.swift。
//  Store 層で Generable→@Model のマッピング (Plan 設計判断 #1)。
//

import Foundation
import FoundationModels
import Translation
import os

// MARK: - Generable Output Types (transient、生成スキーマ)

@Generable
struct ExtractedKnowledgeOutput: Codable {
    @Guide(description: "1-2 文 / 200 字以内 / 元記事の主題と核心 / 元記事に明示されている内容のみ")
    let essence: String

    @Guide(description: "2-4 文 / 400 字以内 / 元記事の構造を維持した説明的要約 / 推測禁止")
    let summary: String

    @Guide(description: "最大 10 件、重要度が高い順、元記事に明示されている事実のみ。コード断片や関数呼び出しは含めない。")
    let keyFacts: [KeyFactOutput]

    @Guide(description: "5-10 件、記事の主題に関わる重要な固有名詞 (人物・組織・製品・サービス・具体的な技術/概念) に限る。一般名詞・代名詞・地名・日付・数値 (例: 男性, ユーザー, 企業, 彼, 東京駅) は含めない。")
    let entities: [KnowledgeEntityOutput]
}

@Generable
struct KeyFactOutput: Codable {
    @Guide(description: "事実の 1 文 (200 字以内)、元記事に明示されている内容のみ")
    let statement: String

    @Guide(description: "事実の種別")
    let type: FactType
}

@Generable
enum FactType: String, Codable {
    case event       // 出来事
    case claim       // 主張・意見
    case statistic   // 数値・統計
    case definition  // 定義・説明
    case quote       // 引用
}

@Generable
struct KnowledgeEntityOutput: Codable {
    @Guide(description: "記事の主題に関わる固有名詞 (人物・組織・製品・具体的な技術/概念)、30 字以内。一般名詞・代名詞・地名は不可。")
    let name: String

    @Guide(description: "種別")
    let type: EntityType

    @Guide(description: "重要度 1〜5 (5 が最重要)")
    let salience: Int
}

@Generable
enum EntityType: String, Codable {
    case person        // 人物
    case organization  // 組織・企業
    case location      // 場所
    case concept       // 概念・用語
    case product       // 製品・サービス
    case work          // 作品 (本・記事・動画等)
}

/// spec (案A, 2026-06-12): chunked 抽出専用の小型出力スキーマ。
/// 各 chunk は小さい (600-900字) ので事実 10 件も entity 10 件も出ない。出力上限を ≤4 に絞り、
/// per-chunk では使われない summary を持たないことで「出力予約」を削減 → 同じ窓で chunk を大きくできる。
/// essence + keyFacts + entities のみ (ChunkedKnowledgeAggregator が使うのはこの 3 つ。summary は meta 段で生成)。
/// 最終的な記事全体の知識は meta-summary が full schema (ExtractedKnowledgeOutput) で作るため品質は不変。
@Generable
struct ChunkKnowledgeOutput: Codable {
    @Guide(description: "1 文 / 120 字以内 / このチャンクの主題と核心 / 明示されている内容のみ")
    let essence: String

    @Guide(description: "最大 4 件、このチャンクで重要な事実のみ、明示されている内容のみ。コード断片は含めない。")
    let keyFacts: [KeyFactOutput]

    @Guide(description: "最大 4 件、主題に関わる固有名詞 (人物・組織・製品・具体的な技術/概念)。一般語・代名詞・地名は不可。")
    let entities: [KnowledgeEntityOutput]
}

// MARK: - spec 018: 知識 Clip タブ用 Generable Output

@Generable
struct DigestOutput: Codable {
    @Guide(description: "Category 内の記事を統合した 1〜3 個のカード。1 つにまとまるなら 1 個、トピックが散らばるなら最大 3 個に分割。")
    let cards: [DigestCardOutput]
}

@Generable
struct DigestCardOutput: Codable {
    @Guide(description: "このカードの要点を 150 字以内で要約")
    let summary: String

    @Guide(description: "重要なキーファクト 3 個 (各 30 字程度)")
    let topKeyFacts: [String]

    @Guide(description: "関連する重要エンティティ名 3 個 (人物 / 概念 / 製品名)")
    let topEntityNames: [String]

    @Guide(description: "このカードに対応する元記事の ID list (UUID 文字列)")
    let sourceArticleIDs: [String]
}

// MARK: - spec 035: 「最近のあなた」差分ダイジェスト用 Generable Output

@Generable
struct RecentDigestOutput: Codable {
    /// V3.0 polish: 「3 段落 80-150 字」→「ヘッドライン 1 文 + テーマ 3 個」に変更。
    /// paragraphs[0] = 60-100 字のヘッドライン、paragraphs[1..3] = 各 10-20 字のテーマ名詞句。
    @Guide(description: "4 件の文字列を順に入れる。[0]=60-100 字の見出し (テーマを統合した 1 文、断定調)、[1][2][3]=各 10-20 字の主要テーマ名詞句。読み手は『最近何を学んだか』を一目で把握できるように。")
    let paragraphs: [String]
}

// MARK: - spec 040: Knowledge Graph triple 抽出用 Generable Output

@Generable
struct GraphTripleOutput: Codable {
    @Guide(description: "記事から抽出した事実関係の triple リスト。最大 10 件、確信度 0.5 未満は除外。同じ subject-predicate-object の組合せは 1 つにまとめる。")
    let triples: [GraphTripleItem]
}

@Generable
struct GraphTripleItem: Codable {
    @Guide(description: "主語となる entity (人物・場所・モノ・概念)。記事に明示されているものに限る、30 字以内。例: 『Apple』『Tim Cook』『Swift 6』")
    let subject: String

    @Guide(description: "関係性を表す短い動詞句 (release / lead / succeed / criticize / create / belong to 等)、30 字以内。記事の文脈から確実に読み取れるものに限る。")
    let predicate: String

    @Guide(description: "目的語となる entity (人物・場所・モノ・概念)、30 字以内。記事に明示されているもの。")
    let object: String

    @Guide(description: "この triple の確信度 0.0-1.0。記事に明確に書かれていれば 0.8 以上、推測が必要なら 0.5-0.7、推測の域を出ないなら 0.0-0.5。0.5 未満は出力しない。")
    let confidence: Double
}

// MARK: - spec 036: 動的トピック命名用 Generable Output

@Generable
struct TopicNameOutput: Codable {
    @Guide(description: "クラスタの記事群の共通テーマを 5-20 字の短い自然な語で命名。技術用語を避け、ユーザーが直感的に理解できる名前。例: 『AI と Product Management』『SwiftUI 状態管理』『日本企業 DX 動向』。")
    let name: String
}

// MARK: - spec 037: 時系列事実上書き用 Generable Output

@Generable
struct ConflictDetectionOutput: Codable {
    @Guide(description: "2 つの記事の間で同じ entity (人物・場所・モノ等) について書かれた事実が矛盾しているか。例: 『開店』vs『閉店』、『就任』vs『退任』、『リリース』vs『廃止』など、明らかに片方が古い情報になっている場合のみ true。"  )
    let hasConflict: Bool

    @Guide(description: "矛盾の内容説明。20-50 字の自然な文。例: 『前回は開店、今回は閉店』。hasConflict=false なら空文字。")
    let conflictDescription: String

    @Guide(description: "新しい記事側の事実 (1 文、50 字以内)。hasConflict=false なら空文字。")
    let newFact: String

    @Guide(description: "古い記事側の事実 (1 文、50 字以内)。hasConflict=false なら空文字。")
    let oldFact: String
}

// MARK: - spec 042: ConceptPage 自動合成用 Generable Output

@Generable
struct ConceptSynthesisOutput: Codable {
    // 注 (token fix 2026-06-07 / spec 077): @Generable は宣言した最大サイズ分だけ出力 token を予約する。
    // 旧 summary 400 字 + insights 7×150 字 = 出力予約だけで窓の半分超 → exceededContextWindowSize 多発。
    // spec 077: broad/specific 両経路の境界 overflow (4089-4091) 余裕確保のため summary 280→180・insights 4→2 に縮小。
    // 控えめ (240/3) でも境界ケースが残ったため もっと短く (180/2) に再調整 (Apple 固定オーバーヘッドが支配的)。
    @Guide(description: "120〜180 字、断定調、原文にあることのみ。")
    let summary: String

    // spec 080: 「答え先出し」の要点レイヤー。最大 2→5 に拡張、各 90→60 字に短縮 (token 予約は微増)。
    // iKnow カードの主役 + 概念詳細の最上段に表示。結論・要点を重要度順で。
    @Guide(description: "最大 5 件、各 60 字以内、この概念で最も大事な要点・結論を重要度順に。断定調、原文にあることのみ。")
    let crossSourceInsights: [String]
}

/// spec 080拡張: overflow 時の adaptive retry 用、出力予約を絞った小型版。
/// 記事の多い大概念 (生成AI 19 記事等) で ConceptSynthesisOutput (要点5×60字) の出力予約が
/// 窓を超える場合の 1 回再試行に使う。summary 短め + 要点 2 件で予約を縮め窓内に収める。
@Generable
struct ConceptSynthesisCompactOutput: Codable {
    @Guide(description: "100 字以内、断定調、原文にあることのみ。")
    let summary: String

    @Guide(description: "最大 2 件、各 40 字以内、この概念で最も大事な要点を重要度順に。")
    let crossSourceInsights: [String]
}

/// hierarchical chunked パスで使う中間 chunk 要約 (3+ 関連記事時)。
@Generable
struct ConceptSummaryChunk: Codable {
    @Guide(description: "80-140 字、断定調、原文のみ。")
    let chunkSummary: String
}

/// spec 074: 記事の概念階層 (広い概念 1 + 具体概念 2-4)。
/// 出力を小さく保つ (broad 1 + specific ≤4、各短い) = token 安全 (docs/ARCHITECTURE.md §12)。
@Generable
struct ConceptHierarchyOutput: Codable {
    @Guide(description: "この記事の最も広い概念 1 つ。短い名詞・専門用語のみ (16 字以内、体言)。例: 生成AI、データエンジニアリング、マクロ経済。文・説明句 (『〜するエンジニア』等) は不可。一般語・地名・代名詞も不可。")
    let broadConcept: String

    @Guide(description: "記事が論じる具体トピックを 2-4 個。各『短い名詞・専門用語』のみ (体言止め、18 字以内)。例: Text-to-SQL、RAG、ワイドテーブル、コンテキストエンジニアリング。『顧客企業に入り込むエンジニア』『新会社設立』のような説明文・動詞句は禁止。記事に明示されたもののみ、一般語・地名・代名詞は不可。")
    let specificConcepts: [String]
}

// MARK: - spec 021: AI Chat (RAG) 用 Generable Output

@Generable
struct ChatAnswerOutput: Codable {
    @Guide(description: "ユーザーの質問への回答。3 段落以内。根拠にした記事は、その根拠となる文の直後に `(article-id://UUID)` というマーカーだけを置く (記事タイトルや番号は本文に書かない)。参考記事に答えがない場合は空文字を返す。")
    let answer: String

    @Guide(description: "回答の根拠に使った記事の ID 配列 (Article.id の UUID 文字列)。参考記事に答えがない場合は空配列。一般知識から推測した内容には ID を載せてはいけない。")
    let citedArticleIDs: [String]
}

// MARK: - Generable → Stored 変換ヘルパ

extension FactType {
    /// SwiftData への永続化文字列。`String(describing:)` で得られる case 名。
    var storedRawValue: String { String(describing: self) }
}

extension EntityType {
    var storedRawValue: String { String(describing: self) }
}

// MARK: - LanguageModelSession 抽象

protocol LanguageModelSessionProtocol: Sendable {
    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput

    /// 案A: chunked 抽出用、小型スキーマ (出力予約を削って chunk を大きくできる)。
    func generateChunkKnowledge(prompt: String) async throws -> ChunkKnowledgeOutput

    /// spec 018: Category 統合ダイジェスト生成
    func generateDigest(prompt: String) async throws -> DigestOutput

    /// spec 021: AI Chat (RAG) 回答生成
    func generateChatAnswer(prompt: String) async throws -> ChatAnswerOutput

    /// spec 035: 「最近のあなた」差分 3 段落要約生成
    func generateRecentDigest(prompt: String) async throws -> RecentDigestOutput

    /// spec 037: 2 記事間の事実矛盾検出
    func generateConflictDetection(prompt: String) async throws -> ConflictDetectionOutput

    /// spec 036: 動的トピック命名
    func generateTopicName(prompt: String) async throws -> TopicNameOutput

    /// spec 040: Knowledge Graph triple 抽出
    func generateGraphTriples(prompt: String) async throws -> GraphTripleOutput

    /// spec 042: ConceptPage の AI 合成 (summary + crossSourceInsights を 1 prompt で生成)
    func generateConceptSynthesis(prompt: String) async throws -> ConceptSynthesisOutput

    /// spec 080拡張: overflow 時の小型再試行 (出力予約を絞る)。
    func generateConceptSynthesisCompact(prompt: String) async throws -> ConceptSynthesisCompactOutput

    /// spec 042: hierarchical chunked パス用、中間 chunk 要約 (5+ 関連記事時)
    func generateConceptSummaryChunk(prompt: String) async throws -> ConceptSummaryChunk

    /// spec 074: 記事の概念階層 (広い概念 + 具体概念) を抽出。
    func generateConceptHierarchy(prompt: String) async throws -> ConceptHierarchyOutput

    /// spec 042: 英語等の本文を日本語に翻訳する。
    /// 実装は Apple Translation framework (iOS 18+ offline)。
    /// Foundation Models は非日本語入力を `unsupportedLanguageOrLocale` で拒否するため、
    /// 入口で別エンジンで翻訳してから既存 generateKnowledge に流す。
    /// 翻訳エラー / 未インストール言語ペアは throws (caller で raw fallback)。
    func translate(text: String) async throws -> String

    /// spec 093: 任意の source 言語 (BCP-47) から日本語へ翻訳 (多言語対応)。
    /// 既存 conformer は default 実装 (source 無視 → translate(text:)) で後方互換。
    func translate(text: String, source: String) async throws -> String

    /// spec 044: 学習タブ用「家庭教師」自由形 chat 応答。
    /// Generable 制約なし、plain string 返却。prompt 内に instructions + concept context + 会話履歴 + user 入力を全て展開する。
    /// retrieval なし (ChatService の RAG 経路を経由しない、low-similarity 早期 return を避けるため)。
    func generateTutorReply(prompt: String) async throws -> String

    /// spec 063 (LLM Wiki): Wiki ページ本文を Markdown で生成 (plain string、@Generable 不使用)。
    /// 出力 schema コストがゼロなので token を入力に回せ、長い本文でも 4096 上限内に収まる。
    func generateWikiBody(prompt: String) async throws -> String

    /// spec 057: Agentic Chat 用、AgentAction Generable enum を生成。
    /// LLM が agent loop の毎 turn で「immediate / askClarification / searchArticles / finalAnswer」のいずれかを返す。
    /// Swift 側で switch 分岐して状態遷移する (Tool Use 不在の代替パターン)。
    func generateAgentAction(prompt: String) async throws -> AgentAction

    /// spec 094: 音声文字起こしの用語補正 (plain string、Generable 不使用)。
    /// 既知の正しい用語集をヒントに、誤認識された固有名詞・専門用語だけを直す。
    func generateTranscriptCorrection(prompt: String) async throws -> String
}

extension LanguageModelSessionProtocol {
    /// spec 093: `translate(text:source:)` の既定実装。
    /// 既存 conformer (Mock 等) が未実装でも source を無視して `translate(text:)` に委譲し後方互換。
    func translate(text: String, source: String) async throws -> String {
        try await translate(text: text)
    }

    /// spec 094: `generateTranscriptCorrection` の既定実装。
    /// 既存 conformer は plain 生成の `generateWikiBody` に委譲し後方互換。
    func generateTranscriptCorrection(prompt: String) async throws -> String {
        try await generateWikiBody(prompt: prompt)
    }
}

// MARK: - Foundation Models 直列化ゲート

/// async セマフォ (permit 数だけ同時通過を許可、超過は FIFO で待機)。
actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(_ permits: Int) { self.permits = permits }

    func acquire() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            permits += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}

/// 全 Foundation Models `respond` 呼び出しの同時実行を制限するゲート。
/// 実機ログで「多数の LanguageModelSession を同時実行 → ANE 競合 → 偽の
/// exceededContextWindowSize (4091 tokens) / inference 失敗 / translationd crash」が判明したため、
/// AI 推論を直列化 (maxConcurrent=1) して競合を排除する。ANE は元々単一なので直列化は実質ノーロス。
enum FoundationModelGate {
    /// 同時実行上限。1 = 完全直列。競合が消えたら 2 等に緩めてもよい。
    static let semaphore = AsyncSemaphore(1)
    /// spurious overflow / inference 失敗の再試行回数 (実機高負荷で一時的に出るため)。
    static let maxAttempts = 3

    @MainActor
    static func run<T>(_ operation: () async throws -> T) async throws -> T {
        await semaphore.acquire()
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                let result = try await operation()
                await semaphore.release()
                return result
            } catch {
                lastError = error
                // 一時エラー (exceededContextWindowSize / inference 失敗) は待って再試行。
                // セマフォは保持したまま sleep → 直列性を保ちつつランタイムの回復を待つ。
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000) // 0.5s, 1.0s
                }
            }
        }
        await semaphore.release()
        throw lastError ?? CancellationError()
    }
}

// MARK: - 送信前 preflight (LLM Best Practices P2-1)

/// respond を呼ぶ前に token 見積もりで窓超過が確実と判明したときに throw するエラー。
/// 呼び出し側 (概念合成の adaptive retry) はこれを overflow と同一視して compact に切替え、
/// 無駄な full respond を 1 回省く。`String(describing:)` に "wouldExceedContextWindowSize"
/// を含めることで、既存の文字列ベース overflow 検出器が追加変更なしで認識できる。
enum FoundationModelPreflightError: Error, CustomStringConvertible {
    case wouldExceedContextWindowSize(promptTokens: Int, schemaTokens: Int, contextSize: Int)

    var description: String {
        switch self {
        case let .wouldExceedContextWindowSize(p, s, c):
            return "wouldExceedContextWindowSize(prompt: \(p), schema: \(s), context: \(c))"
        }
    }
}

// MARK: - Apple Foundation Models 本番実装

@MainActor
final class FoundationModelLanguageModelSession: LanguageModelSessionProtocol {
    // MARK: - DEBUG token 計測 (全 respond を中枢 1 箇所で計測)
    #if DEBUG
    private static let probeLogger = Logger(subsystem: "app.KnowledgeTree", category: "token-probe")
    /// prompt と (あれば) schema の実トークンをログ。respond の隠れコストは別途 overflow ログで確認。
    private static func probe(_ label: String, prompt: String, schema: GenerationSchema?) async {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return }
        let pTok = (try? await model.tokenCount(for: prompt)) ?? -1
        if let schema {
            let sTok = (try? await model.tokenCount(for: schema)) ?? -1
            probeLogger.notice("[TokenProbe] \(label, privacy: .public): prompt \(prompt.count, privacy: .public)字=\(pTok, privacy: .public)tok + schema(compact)=\(sTok, privacy: .public)tok | 窓\(model.contextSize, privacy: .public)")
        } else {
            probeLogger.notice("[TokenProbe] \(label, privacy: .public): prompt \(prompt.count, privacy: .public)字=\(pTok, privacy: .public)tok | schema=none(plain) | 窓\(model.contextSize, privacy: .public)")
        }
    }
    #endif

    // MARK: - 本番 overflow 計測 (LLM Best Practices P1-1)

    /// 本番でも記録する overflow 専用 logger。happy path はゼロコスト、窓超過時のみ計測する。
    private static let overflowLogger = Logger(subsystem: "app.KnowledgeTree", category: "token-overflow")

    /// エラーが窓超過 (実 overflow or preflight overflow) か。文字列判定で頑健 (型 import 不要)。
    static func isOverflowError(_ error: Error) -> Bool {
        let s = String(describing: error)
        return s.contains("exceededContextWindowSize") || s.contains("wouldExceedContextWindowSize")
    }

    /// overflow 発生時に prompt / schema の実トークンを本番ログに残す (発生条件を可視化)。
    private static func logOverflow(_ label: String, prompt: String, schema: GenerationSchema?) async {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            overflowLogger.error("[overflow] \(label, privacy: .public): FM unavailable で計測不可")
            return
        }
        let pTok = (try? await model.tokenCount(for: prompt)) ?? -1
        var sTok = -1
        if let schema { sTok = (try? await model.tokenCount(for: schema)) ?? -1 }
        overflowLogger.error("[overflow] \(label, privacy: .public): prompt \(prompt.count, privacy: .public)字=\(pTok, privacy: .public)tok + schema=\(sTok, privacy: .public)tok | 窓\(model.contextSize, privacy: .public) — 窓超過")
    }

    /// 全 @Generable 生成の共通経路。DEBUG で token を計測してから respond。
    /// - Parameter preflightOutputReserve: LLM Best Practices P2-1。非 nil なら respond の前に
    ///   `tokenCount(for:)` で prompt + schema を実測し、`prompt + schema + reserve > contextSize`
    ///   なら早期に `FoundationModelPreflightError` を throw する (無駄な full respond を省き compact へ)。
    ///   nil = preflight なし (既定、チャット等の低レイテンシ経路)。
    private func generateStructured<T: Generable>(
        _ label: String,
        _ type: T.Type,
        prompt: String,
        maxResponseTokens: Int? = nil,
        preflightOutputReserve: Int? = nil
    ) async throws -> T {
        #if DEBUG
        await Self.probe(label, prompt: prompt, schema: T.generationSchema)
        #endif

        // LLM Best Practices P2-1: 送信前スキーマ選択。
        // 大きな概念合成では prompt + schema が窓を超え得る。respond を呼ぶ前に見積もり、
        // 超過が確実なら早期 throw → 呼び出し側 (adaptive retry) が compact に即切替 (1 呼び出し節約)。
        if let reserve = preflightOutputReserve {
            let model = SystemLanguageModel.default
            if model.isAvailable,
               let pTok = try? await model.tokenCount(for: prompt),
               let sTok = try? await model.tokenCount(for: T.generationSchema) {
                let ctx = model.contextSize
                if pTok + sTok + reserve > ctx {
                    Self.overflowLogger.notice("[preflight] \(label, privacy: .public): prompt=\(pTok, privacy: .public)tok + schema=\(sTok, privacy: .public)tok + reserve=\(reserve, privacy: .public) > 窓\(ctx, privacy: .public) → compact へ")
                    throw FoundationModelPreflightError.wouldExceedContextWindowSize(
                        promptTokens: pTok, schemaTokens: sTok, contextSize: ctx
                    )
                }
            }
        }

        // spec 096 (perf): 出力トークンの上限。@Guide で短く指定していても LM が暴走出力すると
        // prompt + 生成中トークンが窓 4096 を超えて overflow する。ハード上限で生成を止める。
        // nil = 既定 (上限なし)。
        let options = GenerationOptions(maximumResponseTokens: maxResponseTokens)
        do {
            return try await FoundationModelGate.run {
                let session = LanguageModelSession()
                let response = try await session.respond(generating: type, options: options) { prompt }
                return response.content
            }
        } catch {
            // LLM Best Practices P1-1: 本番でも overflow の実態を可視化 (窓超過時のみ計測)。
            if Self.isOverflowError(error) {
                await Self.logOverflow(label, prompt: prompt, schema: T.generationSchema)
            }
            throw error
        }
    }

    /// plain string 生成の共通経路 (Generable schema なし)。
    private func generatePlain(_ label: String, prompt: String) async throws -> String {
        #if DEBUG
        await Self.probe(label, prompt: prompt, schema: nil)
        #endif
        return try await FoundationModelGate.run {
            let session = LanguageModelSession()
            let response = try await session.respond { prompt }
            return response.content
        }
    }

    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput {
        // spec 099: 出力ハード上限で overflow を防御。legit 出力 (~700tok) には十分余裕、
        // 暴走時のみ作動 (入力~1100 + 1200 + FM overhead < 4096)。品質は落とさない。
        try await generateStructured("generateKnowledge (知識抽出)", ExtractedKnowledgeOutput.self,
                                     prompt: prompt, maxResponseTokens: 1200)
    }

    func generateChunkKnowledge(prompt: String) async throws -> ChunkKnowledgeOutput {
        // spec 099: 小型スキーマ。legit ~300tok、暴走時のみ作動。
        try await generateStructured("generateChunkKnowledge (chunk知識/小型)", ChunkKnowledgeOutput.self,
                                     prompt: prompt, maxResponseTokens: 600)
    }

    /// spec 018: Category 統合ダイジェスト生成
    func generateDigest(prompt: String) async throws -> DigestOutput {
        try await generateStructured("generateDigest (Categoryダイジェスト)", DigestOutput.self, prompt: prompt)
    }

    /// spec 021: AI Chat (RAG) 回答生成
    func generateChatAnswer(prompt: String) async throws -> ChatAnswerOutput {
        try await generateStructured("generateChatAnswer (AIチャット)", ChatAnswerOutput.self, prompt: prompt)
    }

    /// spec 035: 「最近のあなた」差分 3 段落要約生成
    func generateRecentDigest(prompt: String) async throws -> RecentDigestOutput {
        try await generateStructured("generateRecentDigest (最近のあなた)", RecentDigestOutput.self, prompt: prompt)
    }

    /// spec 037: 2 記事間の事実矛盾検出
    func generateConflictDetection(prompt: String) async throws -> ConflictDetectionOutput {
        try await generateStructured("generateConflictDetection (矛盾検出)", ConflictDetectionOutput.self, prompt: prompt)
    }

    /// spec 036: 動的トピック命名
    func generateTopicName(prompt: String) async throws -> TopicNameOutput {
        try await generateStructured("generateTopicName (トピック命名)", TopicNameOutput.self, prompt: prompt)
    }

    /// spec 040: Knowledge Graph triple 抽出
    func generateGraphTriples(prompt: String) async throws -> GraphTripleOutput {
        try await generateStructured("generateGraphTriples (グラフ抽出)", GraphTripleOutput.self, prompt: prompt)
    }

    /// spec 042: ConceptPage の AI 合成 (summary + crossSourceInsights を 1 prompt で生成)
    /// spec 096: 出力上限で overflow を抑える (summary≤280 + 要点5×60 ≈ 500tok 程度 → 余裕込み 800)。
    func generateConceptSynthesis(prompt: String) async throws -> ConceptSynthesisOutput {
        // P2-1: preflight で窓超過が確実なら respond せず compact に回す (reserve は maxResponseTokens と揃える)。
        try await generateStructured("generateConceptSynthesis (概念合成)", ConceptSynthesisOutput.self,
                                     prompt: prompt, maxResponseTokens: 800, preflightOutputReserve: 800)
    }

    /// spec 080拡張: overflow 時の小型再試行 (出力予約を絞る)。
    func generateConceptSynthesisCompact(prompt: String) async throws -> ConceptSynthesisCompactOutput {
        try await generateStructured("generateConceptSynthesisCompact (概念合成/小型)", ConceptSynthesisCompactOutput.self,
                                     prompt: prompt, maxResponseTokens: 400)
    }

    /// spec 042: hierarchical chunked パス用、中間 chunk 要約 (5+ 関連記事時)
    func generateConceptSummaryChunk(prompt: String) async throws -> ConceptSummaryChunk {
        try await generateStructured("generateConceptSummaryChunk (概念chunk)", ConceptSummaryChunk.self,
                                     prompt: prompt, maxResponseTokens: 300)
    }

    /// spec 074: 記事の概念階層 (広い概念 + 具体概念) を抽出 (小出力 = token 安全)。
    func generateConceptHierarchy(prompt: String) async throws -> ConceptHierarchyOutput {
        try await generateStructured("generateConceptHierarchy (概念階層)", ConceptHierarchyOutput.self, prompt: prompt)
    }

    /// spec 042: 英語 → 日本語の翻訳 (Apple Translation framework、iOS 26+ offline)。
    /// `installedSource:` は事前に Settings > General > Language で日本語/英語ペアが
    /// ダウンロードされている前提。未インストール / 失敗時は throws → caller が raw fallback。
    /// Foundation Models は非日本語入力を unsupportedLanguageOrLocale で拒否するため、
    /// 翻訳経路だけは別エンジンを使う。
    func translate(text: String) async throws -> String {
        try await translate(text: text, source: "en")
    }

    /// spec 093: 任意の source 言語 → 日本語。Apple Translation framework (offline)。
    /// `installedSource:` の言語ペアが未インストールなら throws → caller が raw fallback。
    /// i18n Phase B: 翻訳先は固定の日本語ではなく `PipelineLanguage.current` (パイプライン言語) に追従する。
    func translate(text: String, source: String) async throws -> String {
        let sourceLang = Locale.Language(identifier: source)
        let target = Locale.Language(identifier: PipelineLanguage.current.translationTargetBCP47)
        let session = TranslationSession(installedSource: sourceLang, target: target)
        let response = try await session.translate(text)
        return response.targetText
    }

    /// spec 044: 学習タブ用「家庭教師」自由形 chat 応答 (plain string、Generable 制約なし)。
    /// LanguageModelSession の `respond { prompt }` を直接呼び、`.content` (String) を返却。
    func generateTutorReply(prompt: String) async throws -> String {
        try await generatePlain("generateTutorReply (家庭教師)", prompt: prompt)
    }

    /// spec 063 (LLM Wiki): Wiki 本文 plain string 生成 (Generable schema を渡さず token 節約)。
    func generateWikiBody(prompt: String) async throws -> String {
        try await generatePlain("generateWikiBody (Wiki本文)", prompt: prompt)
    }

    /// spec 094: 音声文字起こしの用語補正 (plain string)。専用ラベルでログ追跡。
    func generateTranscriptCorrection(prompt: String) async throws -> String {
        try await generatePlain("generateTranscriptCorrection (文字起こし校正)", prompt: prompt)
    }

    /// spec 057: Agentic Chat 用 AgentActionOutput Generable struct 生成 → AgentAction enum に変換。
    func generateAgentAction(prompt: String) async throws -> AgentAction {
        let output = try await generateStructured("generateAgentAction (Agent)", AgentActionOutput.self, prompt: prompt)
        return AgentAction(from: output)
    }
}

// MARK: - Apple Intelligence Availability

protocol AvailabilityChecker: Sendable {
    var isAvailable: Bool { get }
    /// spec 048: ユーザー向けに「なぜ使えないか」を構造化して返す。available なら nil。
    var unavailabilityReason: AppleIntelligenceUnavailabilityReason? { get }
}

extension AvailabilityChecker {
    /// 後方互換 default 実装 (既存 mock が default だけ実装すれば nil 返却で動く)。
    var unavailabilityReason: AppleIntelligenceUnavailabilityReason? {
        isAvailable ? nil : .unknown
    }
}

/// spec 048: Apple Intelligence が使えない理由 (UI banner 表示用)。
enum AppleIntelligenceUnavailabilityReason: Equatable {
    /// 端末非対応 (iPhone 15 Pro 未満、A17 Pro / M1 以降の iPad 以外)。
    case deviceNotEligible
    /// 設定で Apple Intelligence が OFF。
    case appleIntelligenceNotEnabled
    /// モデル DL 中 / 待機中。
    case modelNotReady
    /// その他 (region 不対応 / 不明)。
    case unknown

    var titleKey: String {
        switch self {
        case .deviceNotEligible:           return "AI 機能はこの端末では使えません"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence が OFF です"
        case .modelNotReady:               return "AI モデルを準備中です"
        case .unknown:                     return "AI 機能を利用できません"
        }
    }

    var bodyKey: String {
        switch self {
        case .deviceNotEligible:
            return "iPhone 15 Pro 以降、または M1 以降の iPad で AI 要約・AI チャット・家庭教師機能が使えます。記事の保存と閲覧は引き続きこの端末で行えます。"
        case .appleIntelligenceNotEnabled:
            return "設定 App → Apple Intelligence と Siri から ON にしてください。"
        case .modelNotReady:
            return "Apple Intelligence のモデルが端末にダウンロード中です。完了まで AI 機能は使えません (通常 数分〜数時間)。"
        case .unknown:
            return "iOS 設定や端末状態を確認してください。記事保存・閲覧は引き続き使えます。"
        }
    }
}

struct SystemLanguageModelAvailabilityChecker: AvailabilityChecker {
    var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        default:
            return false
        }
    }

    var unavailabilityReason: AppleIntelligenceUnavailabilityReason? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .deviceNotEligible
            case .appleIntelligenceNotEnabled:
                return .appleIntelligenceNotEnabled
            case .modelNotReady:
                return .modelNotReady
            @unknown default:
                return .unknown
            }
        @unknown default:
            return .unknown
        }
    }
}
