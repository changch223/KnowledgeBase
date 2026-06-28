//
//  TranslationCacheTests.swift
//  KnowledgeTreeTests
//
//  spec 096 (perf) — 翻訳キャッシュの hit/miss/上限テスト。
//

import Testing
@testable import KnowledgeBase

@MainActor
struct TranslationCacheTests {

    // 未登録は nil、登録後は hit。
    @Test func storesAndRetrieves() {
        let cache = TranslationCache()
        #expect(cache.cached(source: "zh-Hant", text: "你好") == nil)
        cache.put(source: "zh-Hant", text: "你好", translated: "こんにちは")
        #expect(cache.cached(source: "zh-Hant", text: "你好") == "こんにちは")
    }

    // source が違えば別キー。
    @Test func sourceIsPartOfKey() {
        let cache = TranslationCache()
        cache.put(source: "en", text: "hello", translated: "やあ")
        #expect(cache.cached(source: "zh-Hant", text: "hello") == nil)
        #expect(cache.cached(source: "en", text: "hello") == "やあ")
    }

    // spec 101: notInstalled で失敗した言語を記録し、以後スキップ判定できる。
    @Test func tracksUnavailableLanguages() {
        let cache = TranslationCache()
        #expect(cache.isUnavailable(source: "id") == false)
        cache.markUnavailable(source: "id")
        #expect(cache.isUnavailable(source: "id"))
        #expect(cache.isUnavailable(source: "en") == false)  // 別言語は影響なし
    }

    // 上限を超えると最古から破棄。
    @Test func evictsOldestOverCapacity() {
        let cache = TranslationCache(capacity: 2)
        cache.put(source: "en", text: "a", translated: "A")
        cache.put(source: "en", text: "b", translated: "B")
        cache.put(source: "en", text: "c", translated: "C")  // a を破棄
        #expect(cache.cached(source: "en", text: "a") == nil)
        #expect(cache.cached(source: "en", text: "b") == "B")
        #expect(cache.cached(source: "en", text: "c") == "C")
        #expect(cache.count == 2)
    }
}
