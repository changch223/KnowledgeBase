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
    @Guide(description: "テクノロジー / 経済 / 健康 / デザイン / 学術 / アート / ニュース / スポーツ / エンタメ / その他 のいずれか 1 つ。完全一致")
    let categoryName: String
}

@MainActor
protocol AutoCategoryClassifier {
    /// Tag の name を入力に、CategorySeed の category 名を返す。
    /// 失敗 / 不明 → "その他" (= CategorySeed.otherCategory.name)。
    /// spec 072: context (記事タイトル/essence 等) を渡すと文脈込みで分類精度が上がる。nil でタグ名のみ。
    func classify(tagName: String, context: String?) async -> String
}

extension AutoCategoryClassifier {
    /// 後方互換: context なし呼び出し。
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

    func classify(tagName: String, context: String? = nil) async -> String {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.debug("classify skipped: empty tagName")
            return CategorySeed.otherCategory.name
        }

        guard availabilityChecker.isAvailable else {
            logger.debug("classify fallback to other: language model unavailable")
            return CategorySeed.otherCategory.name
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

        let prompt = """
            次のタグを、下記カテゴリーのいずれか 1 つに分類してください。
            必ず候補リストにあるカテゴリー名だけを完全一致で 1 つ返すこと。リストにない新しい名前 (技術/数学/政治/男性 等) を作ってはいけません。
            判断に迷う人名・組織名・一般語は「その他」にしてください。
            ただし明確な技術用語 (AI / 人工知能 / 機械学習 / LLM / 生成AI / プログラミング言語 / フレームワーク / クラウド等) は迷わず「テクノロジー」に分類すること。

            # カテゴリー候補 (定義と例)
            \(candidatesText)

            # 分類するタグ
            \(trimmed)\(contextBlock)
            """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                generating: CategoryClassificationOutput.self
            ) {
                prompt
            }
            let candidate = response.content.categoryName
            // 出力が有効カテゴリ (レジストリ or CategorySeed) に存在するか検証
            if validNames.contains(candidate) {
                logger.notice("classify '\(trimmed, privacy: .public)' -> '\(candidate, privacy: .public)'")
                return candidate
            } else {
                logger.notice("classify '\(trimmed, privacy: .public)' returned unknown category '\(candidate, privacy: .public)', fallback")
                return CategorySeed.otherCategory.name
            }
        } catch {
            logger.error("classify failed for '\(trimmed, privacy: .public)': \(String(describing: error), privacy: .public)")
            return CategorySeed.otherCategory.name
        }
    }
}

/// test 用。hardcoded mapping または default を返す。Foundation Models 不要。
@MainActor
final class InMemoryAutoCategoryClassifier: AutoCategoryClassifier {
    private let mapping: [String: String]
    private let defaultCategory: String

    init(mapping: [String: String] = [:], defaultCategory: String = "その他") {
        self.mapping = mapping
        self.defaultCategory = defaultCategory
    }

    func classify(tagName: String, context: String? = nil) async -> String {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return defaultCategory }
        return mapping[trimmed] ?? defaultCategory
    }
}
