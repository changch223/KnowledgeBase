//
//  CategoryRegistryTests.swift
//  KnowledgeTreeTests
//
//  i18n Phase B — CategorySeed / CategoryRegistry の言語別シードのテスト。
//  `.ja` (既定) では従来と完全一致する値を返し、`.zhHans` / `.zhHant` では中文シードを返すことを検証する。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

// i18n Phase B: withPipelineLanguage は PipelineLanguage.current の実プロセス状態
// (UserDefaults + static cache) を書き換える。他 suite との並列実行で読み書きが競合しないよう直列化する。
@Suite(.serialized)
@MainActor
struct CategoryRegistryTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    // MARK: - CategorySeed: 言語別 API

    @Test func testJaSeedsMatchLegacyValues() {
        let names = CategorySeed.allSeeds(for: .ja).map(\.name)
        #expect(names == [
            "テクノロジー", "経済", "健康", "デザイン", "学術",
            "アート", "ニュース", "スポーツ", "エンタメ", "その他",
        ])
        #expect(CategorySeed.otherCategory(for: .ja).name == "その他")
    }

    @Test func testZhHansSeedsReturnChineseNames() {
        let names = CategorySeed.allSeeds(for: .zhHans).map(\.name)
        #expect(names.count == 10)
        #expect(names.contains("科技"))
        #expect(names.contains("其他"))
        #expect(!names.contains("テクノロジー"))
        #expect(CategorySeed.otherCategory(for: .zhHans).name == "其他")
        // 定義も中文で用意されている
        let definitions = CategorySeed.seedDefinitions(for: .zhHans)
        #expect(definitions.count == 10)
        #expect(definitions.allSatisfy { !$0.definition.isEmpty })
    }

    @Test func testZhHantSeedsReturnTraditionalChineseNames() {
        let names = CategorySeed.allSeeds(for: .zhHant).map(\.name)
        #expect(names.count == 10)
        #expect(names.contains("經濟"))
        #expect(names.contains("其他"))
        #expect(CategorySeed.otherCategory(for: .zhHant).name == "其他")
    }

    @Test func testDefaultAPIFollowsCurrentPipelineLanguage() async throws {
        // 既定 (テスト環境 = .ja) では `.current` 経由の computed property が ja の値と完全一致する。
        #expect(CategorySeed.allSeeds.map(\.name) == CategorySeed.allSeeds(for: .ja).map(\.name))
        #expect(CategorySeed.otherCategory.name == "その他")

        try await withPipelineLanguage(.zhHans) {
            #expect(CategorySeed.allSeeds.map(\.name) == CategorySeed.allSeeds(for: .zhHans).map(\.name))
            #expect(CategorySeed.otherCategory.name == "其他")
        }

        // 復元後は ja に戻る
        #expect(CategorySeed.otherCategory.name == "その他")
    }

    // MARK: - CategoryRegistry: seedIfNeeded が言語別に seed する

    @Test func testSeedIfNeededSeedsJapaneseNamesByDefault() throws {
        let container = try makeContainer()
        let registry = CategoryRegistry(context: container.mainContext)
        registry.seedIfNeeded()

        let defs = (try? container.mainContext.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
        #expect(defs.count == 10)
        #expect(defs.contains { $0.name == "テクノロジー" })
        #expect(defs.contains { $0.name == "その他" })
    }

    @Test func testSeedIfNeededSeedsChineseNamesForZhPipeline() async throws {
        try await withPipelineLanguage(.zhHans) {
            let container = try makeContainer()
            let registry = CategoryRegistry(context: container.mainContext)
            registry.seedIfNeeded()

            let defs = (try? container.mainContext.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
            #expect(defs.count == 10)
            #expect(defs.contains { $0.name == "科技" })
            #expect(defs.contains { $0.name == "其他" })
            #expect(!defs.contains { $0.name == "テクノロジー" })

            // promptCandidatesWithDefinitions / validNames もレジストリ経由で中文名を返す
            #expect(registry.validNames().contains("科技"))
            #expect(registry.promptCandidatesWithDefinitions().contains("科技"))
        }
    }
}
