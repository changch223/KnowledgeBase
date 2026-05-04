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
struct ExtractedKnowledgeOutput {
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
struct KeyFactOutput {
    @Guide(description: "事実の 1 文 (200 字以内)、元記事に明示されている内容のみ")
    let statement: String

    @Guide(description: "事実の種別")
    let type: FactType
}

@Generable
enum FactType {
    case event       // 出来事
    case claim       // 主張・意見
    case statistic   // 数値・統計
    case definition  // 定義・説明
    case quote       // 引用
}

@Generable
struct KnowledgeEntityOutput {
    @Guide(description: "固有名詞 (30 字以内)")
    let name: String

    @Guide(description: "種別")
    let type: EntityType

    @Guide(description: "重要度 1〜5 (5 が最重要)")
    let salience: Int
}

@Generable
enum EntityType {
    case person        // 人物
    case organization  // 組織・企業
    case location      // 場所
    case concept       // 概念・用語
    case product       // 製品・サービス
    case work          // 作品 (本・記事・動画等)
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
