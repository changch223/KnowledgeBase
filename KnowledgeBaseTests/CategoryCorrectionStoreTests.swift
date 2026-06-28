//
//  CategoryCorrectionStoreTests.swift
//  KnowledgeTreeTests
//
//  spec 097 Phase 2 — 学習ストア (記録 + few-shot 選定) のテスト。
//  ※ 複数 in-memory ModelContainer 生成はプロセスを落とす artifact があるため、
//    単一共有コンテナ + .serialized + 各テスト冒頭で全削除して clean にする。
//

import Testing
import SwiftData
@testable import KnowledgeBase

@Suite(.serialized)
@MainActor
struct CategoryCorrectionStoreTests {

    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: CategoryCorrectionExample.self, configurations: config)
    }()

    private func freshStore() -> CategoryCorrectionStore {
        let ctx = Self.container.mainContext
        let all = (try? ctx.fetch(FetchDescriptor<CategoryCorrectionExample>())) ?? []
        for e in all { ctx.delete(e) }
        try? ctx.save()
        return CategoryCorrectionStore(context: ctx, container: Self.container)
    }

    // 記録 + 同一 (tagName, correctCategory) は重複させない。
    @Test func recordsAndDedupes() {
        let store = freshStore()
        store.record(tagName: "腸内細菌", correctCategory: "健康")
        store.record(tagName: "腸内細菌", correctCategory: "健康")  // dedupe
        #expect(store.count == 1)
        store.record(tagName: "AI", wrongCategory: "健康", correctCategory: "テクノロジー")
        #expect(store.count == 2)
    }

    // few-shot は同名タグの修正を最優先で返す。
    @Test func fewShotPrioritizesSameTag() {
        let store = freshStore()
        store.record(tagName: "X", correctCategory: "経済")
        store.record(tagName: "腸内細菌", wrongCategory: "テクノロジー", correctCategory: "健康")
        let shots = store.fewShot(for: "腸内細菌", limit: 8)
        #expect(shots.first?.tagName == "腸内細菌")
        #expect(shots.first?.correctCategory == "健康")
        #expect(shots.first?.wrongCategory == "テクノロジー")
        #expect(shots.count == 2)
    }

    // 例が無ければ空。
    @Test func emptyWhenNoExamples() {
        let store = freshStore()
        #expect(store.fewShot(for: "なんでも").isEmpty)
    }

    // 空のタグ名 / 空のカテゴリは記録しない。
    @Test func ignoresEmptyInput() {
        let store = freshStore()
        store.record(tagName: "  ", correctCategory: "健康")
        store.record(tagName: "AI", correctCategory: "  ")
        #expect(store.count == 0)
    }
}
