//
//  AutoCategoryClassifierTests.swift
//  KnowledgeTreeTests
//
//  spec 015 — contracts/auto-category-classifier.md 5 ケース。
//  InMemoryAutoCategoryClassifier 中心の挙動検証。
//

import Testing
import Foundation
@testable import KnowledgeTree

@MainActor
struct AutoCategoryClassifierTests {

    @Test func testInMemoryReturnsMappedCategory() async {
        let mapping: [String: String] = ["swift": "テクノロジー"]
        let classifier = InMemoryAutoCategoryClassifier(mapping: mapping)
        let result = await classifier.classify(tagName: "Swift")
        #expect(result == "テクノロジー")
    }

    @Test func testInMemoryReturnsDefaultForUnknown() async {
        let classifier = InMemoryAutoCategoryClassifier(mapping: [:])
        let result = await classifier.classify(tagName: "xyz")
        #expect(result == "その他")
    }

    @Test func testInMemoryReturnsDefaultForEmpty() async {
        let classifier = InMemoryAutoCategoryClassifier(mapping: ["swift": "テクノロジー"])
        let result = await classifier.classify(tagName: "")
        #expect(result == "その他")
    }

    @Test func testInMemoryRespectsCustomDefault() async {
        let classifier = InMemoryAutoCategoryClassifier(
            mapping: [:],
            defaultCategory: "学術"
        )
        let result = await classifier.classify(tagName: "xyz")
        #expect(result == "学術")
    }

    @Test func testFallbackContainsAllSeedNames() async {
        // CategorySeed.allSeeds の name 全 10 個を mapping して、
        // それぞれ正しく返ることを確認 (CategorySeed 整合性 + InMemory 動作の両確認)
        let allSeedNames = CategorySeed.allSeeds.map(\.name)
        var mapping: [String: String] = [:]
        for name in allSeedNames {
            mapping[name.lowercased()] = name
        }
        let classifier = InMemoryAutoCategoryClassifier(mapping: mapping)
        for name in allSeedNames {
            let result = await classifier.classify(tagName: name)
            #expect(result == name, "\(name) should map to itself")
        }
    }
}
