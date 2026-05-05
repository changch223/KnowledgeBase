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
    func classify(tagName: String) async -> String
}

/// production 用。Apple Foundation Models で 1 回推論。
@MainActor
final class FoundationModelsAutoCategoryClassifier: AutoCategoryClassifier {
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "auto-category")
    private let availabilityChecker: AvailabilityChecker

    init(availabilityChecker: AvailabilityChecker = SystemLanguageModelAvailabilityChecker()) {
        self.availabilityChecker = availabilityChecker
    }

    func classify(tagName: String) async -> String {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.debug("classify skipped: empty tagName")
            return CategorySeed.otherCategory.name
        }

        guard availabilityChecker.isAvailable else {
            logger.debug("classify fallback to other: language model unavailable")
            return CategorySeed.otherCategory.name
        }

        let prompt = """
            次のタグはどのカテゴリーに属しますか? 候補から 1 つだけ完全一致で返してください。
            候補: \(CategorySeed.promptCandidatesString)
            タグ: \(trimmed)
            """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                generating: CategoryClassificationOutput.self
            ) {
                prompt
            }
            let candidate = response.content.categoryName
            // 出力が CategorySeed に存在するか検証
            if CategorySeed.allSeeds.contains(where: { $0.name == candidate }) {
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

    func classify(tagName: String) async -> String {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return defaultCategory }
        return mapping[trimmed] ?? defaultCategory
    }
}
