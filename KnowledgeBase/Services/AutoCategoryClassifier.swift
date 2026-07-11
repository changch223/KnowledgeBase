//
//  AutoCategoryClassifier.swift
//  KnowledgeTree
//
//  spec 015 — Tag.name → Category.name (CategorySeed.allSeeds のいずれか) を 1 回推論。
//  protocol で Foundation Models 実装と test mock を切り替える。
//
//  contracts/auto-category-classifier.md 準拠。
//
//  失敗 / 不明 / 利用不可 → "その他" を return (graceful)。
//

import Foundation
import FoundationModels
import os

@Generable
struct CategoryClassificationOutput: Sendable {
    // i18n Phase B: 候補名は言語別 (CategorySeed / CategoryRegistry) に追従するため、
    // ここでは特定言語のカテゴリー名を列挙しない。prompt 側の「# カテゴリー候補」で列挙する。
    @Guide(description: "prompt の候補リストにあるカテゴリー名のいずれか 1 つ。完全一致")
    let categoryName: String
    @Guide(description: "確信度: High / Medium / Low のいずれか 1 つ")
    let confidence: String
}

/// spec 097: 分類の確信度。Low → その他 (保守) / Medium・Low → lint で優先再分類。
enum ClassificationConfidence: String, Sendable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    /// LM 出力文字列を寛容にパース (不明は安全側で medium)。
    static func parse(_ raw: String) -> ClassificationConfidence {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "high": return .high
        case "low": return .low
        default: return .medium
        }
    }
}

/// spec 097: 分類結果 (カテゴリ + 確信度)。
struct CategoryClassification: Sendable {
    let category: String
    let confidence: ClassificationConfidence
}

/// spec 097 Phase 2: 学習用の few-shot 例 (ユーザー修正の正解)。@Model を classifier に持ち込まない値型。
struct CategoryFewShot: Sendable {
    let tagName: String
    let correctCategory: String
    let wrongCategory: String?
}

@MainActor
protocol AutoCategoryClassifier {
    /// spec 097: Tag の name を入力に、カテゴリ + 確信度を返す。
    /// 失敗 / 不明 / Low → "その他" (= CategorySeed.otherCategory.name)。
    /// context (記事タイトル/essence 等) を渡すと文脈込みで精度が上がる。nil でタグ名のみ。
    /// spec 097 Phase 2: examples (過去のユーザー修正) を渡すと few-shot として注入し精度が上がる。
    func classifyDetailed(tagName: String, context: String?, examples: [CategoryFewShot]) async -> CategoryClassification
}

extension AutoCategoryClassifier {
    /// 例なし版 (Phase 1 経路、初回分類)。
    func classifyDetailed(tagName: String, context: String?) async -> CategoryClassification {
        await classifyDetailed(tagName: tagName, context: context, examples: [])
    }
    /// 後方互換: カテゴリ名のみ返す。
    func classify(tagName: String, context: String?) async -> String {
        await classifyDetailed(tagName: tagName, context: context, examples: []).category
    }
    func classify(tagName: String) async -> String {
        await classify(tagName: tagName, context: nil)
    }
}

/// production 用。Apple Foundation Models で 1 回推論。
@MainActor
final class FoundationModelsAutoCategoryClassifier: AutoCategoryClassifier {
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "auto-category")
    private let availabilityChecker: AvailabilityChecker
    /// spec 074: 動的カテゴリのレジストリ。nil なら CategorySeed (固定 10) に fallback。
    private let categoryRegistry: CategoryRegistry?

    init(
        availabilityChecker: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        categoryRegistry: CategoryRegistry? = nil
    ) {
        self.availabilityChecker = availabilityChecker
        self.categoryRegistry = categoryRegistry
    }

    func classifyDetailed(tagName: String, context: String? = nil, examples: [CategoryFewShot] = []) async -> CategoryClassification {
        let other = CategorySeed.otherCategory.name
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.debug("classify skipped: empty tagName")
            return CategoryClassification(category: other, confidence: .low)
        }

        guard availabilityChecker.isAvailable else {
            logger.debug("classify fallback to other: language model unavailable")
            return CategoryClassification(category: other, confidence: .low)
        }

        // spec 072: context (記事タイトル/essence) があれば文脈ブロックを足す。
        let contextBlock: String
        if let context, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextBlock = "\n\nこのタグが登場した文脈:\n\(String(context.prefix(200)))"
        } else {
            contextBlock = ""
        }

        // spec 074: 候補はレジストリ駆動 (動的カテゴリ対応)。nil なら CategorySeed に fallback。
        let candidatesText = categoryRegistry?.promptCandidatesWithDefinitions()
            ?? CategorySeed.promptCandidatesWithDefinitions
        let validNames = categoryRegistry?.validNames()
            ?? Set(CategorySeed.allSeeds.map { $0.name })

        // spec 097 Phase 2: 過去のユーザー修正を few-shot で注入 (最大 8 件)。
        let exampleBlock = Self.buildExampleBlock(examples)

        let prompt = """
            次のタグを、下記カテゴリーのいずれか 1 つに分類してください。
            必ず候補リストにあるカテゴリー名だけを完全一致で 1 つ返すこと。リストにない新しい名前 (技術/数学/政治/男性 等) を作ってはいけません。
            判断に迷う人名・組織名・一般語は「\(other)」にしてください。
            ただし下記の特例に当てはまる場合は、迷わずその分野に分類すること:
            \(CategorySeed.firstPassTieBreakers)
            \(exampleBlock)
            # カテゴリー候補 (定義と例)
            \(candidatesText)

            # 分類するタグ
            \(trimmed)\(contextBlock)

            # 確信度
            回答の最後に確信度を [High / Medium / Low] のいずれかで出力してください。
            High=文脈や一般的事実から直接の根拠がある / Medium=情報が一部不足だが推論で妥当 / Low=情報が足りず推測の域を出ない。
            """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                generating: CategoryClassificationOutput.self
            ) {
                prompt
            }
            let candidate = response.content.categoryName
            let confidence = ClassificationConfidence.parse(response.content.confidence)
            // 出力が有効カテゴリ (レジストリ or CategorySeed) に存在するか検証
            guard validNames.contains(candidate) else {
                logger.notice("classify '\(trimmed, privacy: .public)' returned unknown category '\(candidate, privacy: .public)', fallback")
                return CategoryClassification(category: other, confidence: .low)
            }
            // spec 097: Low は確信が低いので保守的に「その他」へ (lint 第2段で再分類される)。
            if confidence == .low {
                logger.notice("classify '\(trimmed, privacy: .public)' -> '\(candidate, privacy: .public)' but Low → その他")
                return CategoryClassification(category: other, confidence: .low)
            }
            logger.notice("classify '\(trimmed, privacy: .public)' -> '\(candidate, privacy: .public)' [\(confidence.rawValue, privacy: .public)]")
            return CategoryClassification(category: candidate, confidence: confidence)
        } catch {
            logger.error("classify failed for '\(trimmed, privacy: .public)': \(String(describing: error), privacy: .public)")
            return CategoryClassification(category: other, confidence: .low)
        }
    }

    /// spec 097 Phase 2: ユーザー修正の few-shot ブロックを組み立てる (最大 8 件、空なら空文字)。
    static func buildExampleBlock(_ examples: [CategoryFewShot]) -> String {
        guard !examples.isEmpty else { return "" }
        let lines = examples.prefix(8).map { ex -> String in
            if let wrong = ex.wrongCategory, !wrong.isEmpty, wrong != ex.correctCategory {
                return "- 「\(ex.tagName)」→「\(ex.correctCategory)」(「\(wrong)」ではない)"
            }
            return "- 「\(ex.tagName)」→「\(ex.correctCategory)」"
        }
        return """

            # 過去のユーザー修正 (同じ間違いを避ける)
            \(lines.joined(separator: "\n"))

            """
    }
}

/// test 用。hardcoded mapping または default を返す。Foundation Models 不要。
@MainActor
final class InMemoryAutoCategoryClassifier: AutoCategoryClassifier {
    private let mapping: [String: String]
    private let defaultCategory: String
    /// spec 097: テストで返す確信度 (default High)。tagName(lowercased)→confidence を上書き可。
    private let confidenceMapping: [String: ClassificationConfidence]
    private let defaultConfidence: ClassificationConfidence

    init(
        mapping: [String: String] = [:],
        defaultCategory: String = "その他",
        confidenceMapping: [String: ClassificationConfidence] = [:],
        defaultConfidence: ClassificationConfidence = .high
    ) {
        self.mapping = mapping
        self.defaultCategory = defaultCategory
        self.confidenceMapping = confidenceMapping
        self.defaultConfidence = defaultConfidence
    }

    func classifyDetailed(tagName: String, context: String? = nil, examples: [CategoryFewShot] = []) async -> CategoryClassification {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return CategoryClassification(category: defaultCategory, confidence: .low) }
        let category = mapping[trimmed] ?? defaultCategory
        let confidence = confidenceMapping[trimmed] ?? defaultConfidence
        return CategoryClassification(category: category, confidence: confidence)
    }
}
