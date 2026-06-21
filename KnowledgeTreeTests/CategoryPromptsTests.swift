//
//  CategoryPromptsTests.swift
//  KnowledgeTreeTests
//
//  spec 097 Phase 3 — カテゴリ別合成プロンプトの分野ブロック。
//

import Testing
@testable import KnowledgeTree

struct CategoryPromptsTests {

    // 分野ありは重視点 + 表記統一ヒントが入る。
    @Test func techBlockHasEmphasisAndGlossary() {
        let block = CategoryPrompts.block(forCategoryRaw: "テクノロジー")
        #expect(block.contains("この分野での重視点"))
        #expect(block.contains("固有名詞の表記統一"))
        #expect(block.contains("Claude"))
    }

    @Test func healthBlockIsDomainSpecific() {
        let block = CategoryPrompts.block(forCategoryRaw: "健康")
        #expect(block.contains("症状"))
    }

    // その他 / 未知 / nil は空 = 汎用生成。
    @Test func otherAndUnknownAndNilAreEmpty() {
        #expect(CategoryPrompts.block(forCategoryRaw: "その他").isEmpty)
        #expect(CategoryPrompts.block(forCategoryRaw: "存在しない分野").isEmpty)
        #expect(CategoryPrompts.block(forCategoryRaw: nil).isEmpty)
    }

    // 9 分野 (その他 除く) すべてにプロファイルがある。
    @Test func coversNineCategories() {
        let names = ["テクノロジー", "経済", "健康", "デザイン", "学術", "アート", "ニュース", "スポーツ", "エンタメ"]
        for n in names {
            #expect(!CategoryPrompts.block(forCategoryRaw: n).isEmpty, "missing profile: \(n)")
        }
    }
}
