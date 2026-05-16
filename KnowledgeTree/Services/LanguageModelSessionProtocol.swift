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

// MARK: - Generable Output Types (transient、生成スキーマ)

@Generable
struct ExtractedKnowledgeOutput: Codable {
    @Guide(description: "1 文 / 150 字以内 / 元記事の主題と核心 / 元記事に明示されている内容のみ")
    let essence: String

    @Guide(description: "2-3 文 / 300 字以内 / 元記事の構造を維持した説明的要約 / 推測禁止")
    let summary: String

    @Guide(description: "3-5 件、元記事に明示されている事実のみ")
    let keyFacts: [KeyFactOutput]

    @Guide(description: "5-10 件、重要な固有名詞")
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
    @Guide(description: "固有名詞 (30 字以内)")
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

// MARK: - spec 018: 知識 Clip タブ用 Generable Output

@Generable
struct DigestOutput: Codable {
    @Guide(description: "Category 内の記事を統合した 1〜3 個のカード。1 つにまとまるなら 1 個、トピックが散らばるなら最大 3 個に分割。")
    let cards: [DigestCardOutput]
}

@Generable
struct DigestCardOutput: Codable {
    @Guide(description: "このカードの要点を 150 字以内で日本語で要約")
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
    @Guide(description: "最近の記事を統合した自然な日本語の 3 段落要約。各段落 80-150 字。読み手は『最近の自分が学んだこと』を一目で把握できるように。")
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

    @Guide(description: "関係性を表す短い動詞句 (release / lead / succeed / criticize / create / belong to 等)、30 字以内。日本語可。記事の文脈から確実に読み取れるものに限る。")
    let predicate: String

    @Guide(description: "目的語となる entity (人物・場所・モノ・概念)、30 字以内。記事に明示されているもの。")
    let object: String

    @Guide(description: "この triple の確信度 0.0-1.0。記事に明確に書かれていれば 0.8 以上、推測が必要なら 0.5-0.7、推測の域を出ないなら 0.0-0.5。0.5 未満は出力しない。")
    let confidence: Double
}

// MARK: - spec 036: 動的トピック命名用 Generable Output

@Generable
struct TopicNameOutput: Codable {
    @Guide(description: "クラスタの記事群の共通テーマを 5-20 字の自然な日本語で命名。技術用語を避け、ユーザーが直感的に理解できる名前。例: 『AI と Product Management』『SwiftUI 状態管理』『日本企業 DX 動向』。")
    let name: String
}

// MARK: - spec 037: 時系列事実上書き用 Generable Output

@Generable
struct ConflictDetectionOutput: Codable {
    @Guide(description: "2 つの記事の間で同じ entity (人物・場所・モノ等) について書かれた事実が矛盾しているか。例: 『開店』vs『閉店』、『就任』vs『退任』、『リリース』vs『廃止』など、明らかに片方が古い情報になっている場合のみ true。"  )
    let hasConflict: Bool

    @Guide(description: "矛盾の内容説明。20-50 字の自然な日本語。例: 『前回は開店、今回は閉店』。hasConflict=false なら空文字。")
    let conflictDescription: String

    @Guide(description: "新しい記事側の事実 (1 文、50 字以内)。hasConflict=false なら空文字。")
    let newFact: String

    @Guide(description: "古い記事側の事実 (1 文、50 字以内)。hasConflict=false なら空文字。")
    let oldFact: String
}

// MARK: - spec 021: AI Chat (RAG) 用 Generable Output

@Generable
struct ChatAnswerOutput: Codable {
    @Guide(description: "ユーザーの質問への回答。日本語で 3 段落以内。参考記事に答えがない場合は『分かりません。保存された記事の中に該当する情報が見つかりませんでした。』と回答する。")
    let answer: String

    @Guide(description: "回答に使った記事の ID 配列 (Article.id の UUID 文字列)。参考記事に答えがない場合は空配列を返す。一般知識から推測した内容には ID を載せてはいけない。")
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

    /// spec 042: 任意言語 → 日本語の翻訳 (KnowledgeExtractor 前処理)
    /// 固有名詞は原文表記維持、訳文のみを返す。
    func generateTranslation(prompt: String) async throws -> String
}

// MARK: - Apple Foundation Models 本番実装

@MainActor
final class FoundationModelLanguageModelSession: LanguageModelSessionProtocol {
    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput {
        let session = LanguageModelSession()
        let response = try await session.respond(
            generating: ExtractedKnowledgeOutput.self
        ) {
            prompt
        }
        return response.content
    }

    /// spec 018: Category 統合ダイジェスト生成
    func generateDigest(prompt: String) async throws -> DigestOutput {
        let session = LanguageModelSession()
        let response = try await session.respond(
            generating: DigestOutput.self
        ) {
            prompt
        }
        return response.content
    }

    /// spec 021: AI Chat (RAG) 回答生成
    func generateChatAnswer(prompt: String) async throws -> ChatAnswerOutput {
        let session = LanguageModelSession()
        let response = try await session.respond(
            generating: ChatAnswerOutput.self
        ) {
            prompt
        }
        return response.content
    }

    /// spec 035: 「最近のあなた」差分 3 段落要約生成
    func generateRecentDigest(prompt: String) async throws -> RecentDigestOutput {
        let session = LanguageModelSession()
        let response = try await session.respond(
            generating: RecentDigestOutput.self
        ) {
            prompt
        }
        return response.content
    }

    /// spec 037: 2 記事間の事実矛盾検出
    func generateConflictDetection(prompt: String) async throws -> ConflictDetectionOutput {
        let session = LanguageModelSession()
        let response = try await session.respond(
            generating: ConflictDetectionOutput.self
        ) {
            prompt
        }
        return response.content
    }

    /// spec 036: 動的トピック命名
    func generateTopicName(prompt: String) async throws -> TopicNameOutput {
        let session = LanguageModelSession()
        let response = try await session.respond(
            generating: TopicNameOutput.self
        ) {
            prompt
        }
        return response.content
    }

    /// spec 040: Knowledge Graph triple 抽出
    func generateGraphTriples(prompt: String) async throws -> GraphTripleOutput {
        let session = LanguageModelSession()
        let response = try await session.respond(
            generating: GraphTripleOutput.self
        ) {
            prompt
        }
        return response.content
    }

    /// spec 042: 翻訳 (plain String 返却、Generable なし)
    func generateTranslation(prompt: String) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond {
            prompt
        }
        return response.content
    }
}

// MARK: - Apple Intelligence Availability

protocol AvailabilityChecker: Sendable {
    var isAvailable: Bool { get }
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
}
