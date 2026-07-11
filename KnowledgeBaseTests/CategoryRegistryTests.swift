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

    @Test func testEnSeedsReturnEnglishNames() {
        let names = CategorySeed.allSeeds(for: .en).map(\.name)
        #expect(names.count == 10)
        #expect(names.contains("Technology"))
        #expect(names.contains("Other"))
        #expect(CategorySeed.otherCategory(for: .en).name == "Other")
        // 定義も英語で用意されている
        let definitions = CategorySeed.seedDefinitions(for: .en)
        #expect(definitions.count == 10)
        #expect(definitions.allSatisfy { !$0.definition.isEmpty })
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

    // MARK: - i18n Phase B (言語混在バグ修正): CategorySeed.foreignSeedNames

    @Test func testAllLanguageSeedsHaveSameCountAndOrder() {
        // index 対応の heal (CategoryLanguageHealMapping) の前提: 全言語で同数 (10)・同順 (order == index)。
        for language in PipelineLanguage.allCases {
            let seeds = CategorySeed.allSeeds(for: language)
            #expect(seeds.count == 10)
            #expect(seeds.enumerated().allSatisfy { $0.offset == $0.element.order })
        }
    }

    @Test func testAllLanguageSeedsShareSameEnglishNameAtEachIndex() {
        // heal (categoryLanguageHealMapping) は index 対応で言語間を張り替える。
        // 将来シード順がズレると誤マッピング (例: 「テクノロジー」が「經濟」に化ける) が起きるので、
        // 同 index の englishName が全言語で一致することを固定する (意味的な順序保証)。
        let baseline = CategorySeed.allSeeds(for: .ja).map(\.englishName)
        for language in PipelineLanguage.allCases {
            let englishNames = CategorySeed.allSeeds(for: language).map(\.englishName)
            #expect(englishNames == baseline)
        }
    }

    @Test func testForeignSeedNamesExcludingZhHansContainsJaAndZhHantOnlyNames() {
        let foreign = CategorySeed.foreignSeedNames(excluding: .zhHans)
        // ja のシード名は zh-Hans から見て foreign
        #expect(foreign.contains("テクノロジー"))
        #expect(foreign.contains("その他"))
        // zh-Hant だけの表記 (zh-Hans と異なる繁体字) も foreign
        #expect(foreign.contains("經濟"))
        // zh-Hans 自身のシード名は foreign に含まれない
        #expect(!foreign.contains("科技"))
        #expect(!foreign.contains("其他"))
        // 複数言語で共有される名前 (健康) は foreign から除外される
        #expect(!foreign.contains("健康"))
    }

    @Test func testForeignSeedNamesExcludingJaContainsZhNames() {
        let foreign = CategorySeed.foreignSeedNames(excluding: .ja)
        #expect(foreign.contains("科技"))
        #expect(foreign.contains("經濟"))
        #expect(!foreign.contains("テクノロジー"))
        #expect(!foreign.contains("健康"))  // 共有名は除外されない
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

    @Test func testSeedIfNeededSeedsEnglishNamesForEnPipeline() async throws {
        try await withPipelineLanguage(.en) {
            let container = try makeContainer()
            let registry = CategoryRegistry(context: container.mainContext)
            registry.seedIfNeeded()

            let defs = (try? container.mainContext.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
            #expect(defs.count == 10)
            #expect(defs.contains { $0.name == "Technology" })
            #expect(defs.contains { $0.name == "Other" })
            #expect(!defs.contains { $0.name == "テクノロジー" })

            // promptCandidatesWithDefinitions / validNames もレジストリ経由で英語名を返す
            #expect(registry.validNames().contains("Technology"))
            #expect(registry.promptCandidatesWithDefinitions().contains("Technology"))
        }
    }

    // MARK: - i18n Phase B (言語混在バグ修正): 候補フィルタ

    @Test func testCandidatesExcludeForeignSeedNamesWhenMixedRegistry() async throws {
        let container = try makeContainer()
        let registry = CategoryRegistry(context: container.mainContext)
        // ja 端末として起動 → ja の 10 シードを seed (実運用の「元は ja パイプラインだった」状態を再現)。
        registry.seedIfNeeded()

        try await withPipelineLanguage(.zhHans) {
            // 端末の言語を zh-Hans に切替 → 次回起動で zh の 10 シードが追加 seed される
            // (「健康」は ja と表記が同じなので idempotent skip、9 件だけ新規追加)。
            registry.seedIfNeeded()

            let defs = (try? container.mainContext.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
            #expect(defs.count == 19)  // ja 10 + zh 10 - 共有 "健康" の重複 skip 1 件

            // ja のシード名は候補から除外される
            // ※ "- テクノロジー:" 行の有無で判定する (raw contains だと「健康」の ja 定義文中に
            //   例文として「テクノロジー」という語が出現するため false positive になる)。
            #expect(!registry.validNames().contains("テクノロジー"))
            #expect(!registry.promptCandidatesWithDefinitions().contains("- テクノロジー:"))
            // zh-Hans 自身のシード名は候補に残る
            #expect(registry.validNames().contains("科技"))
            #expect(registry.promptCandidatesWithDefinitions().contains("- 科技:"))
            // 共有名 (健康) は現在言語にも属するので候補に残る
            #expect(registry.validNames().contains("健康"))
        }
    }

    @Test func testDynamicCategorySurvivesEvenIfNameMatchesForeignSeed() async throws {
        try await withPipelineLanguage(.zhHans) {
            let container = try makeContainer()
            let registry = CategoryRegistry(context: container.mainContext)
            registry.seedIfNeeded()  // zh-Hans の 10 シードのみ (ja シードは registry に存在しない)

            // 動的カテゴリ (isSeed=false) が、たまたま ja のシード名と同じ名前で追加されたケース。
            #expect(registry.insertCategory(name: "テクノロジー", definition: "d") == true)

            // 言語情報を持たない動的カテゴリは、名前が foreign シード名と一致していても除外されない。
            #expect(registry.validNames().contains("テクノロジー"))
            #expect(registry.promptCandidatesWithDefinitions().contains("テクノロジー"))
        }
    }

    @Test func testCandidatesUnaffectedOnJaOnlyDevice() throws {
        // zh シードが存在しない通常の ja インストールでは、フィルタは無挙動変化。
        let container = try makeContainer()
        let registry = CategoryRegistry(context: container.mainContext)
        registry.seedIfNeeded()

        #expect(registry.validNames().count == 10)
        #expect(registry.validNames().contains("テクノロジー"))
        #expect(registry.promptCandidatesWithDefinitions().contains("テクノロジー"))
    }
}
