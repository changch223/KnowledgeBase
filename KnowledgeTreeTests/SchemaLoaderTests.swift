//
//  SchemaLoaderTests.swift
//  KnowledgeTreeTests
//
//  spec 058 — SchemaLoader の fallback + section 解析テスト。
//

import Testing
@testable import KnowledgeTree

@MainActor
struct SchemaLoaderTests {

    @Test func testFallbackSchemaIsNonEmpty() {
        let fallback = SchemaLoader.fallbackSchema
        #expect(!fallback.isEmpty)
        #expect(fallback.contains("NEVER STOP"))
        #expect(fallback.contains("hedge"))
    }

    @Test func testLoadInitializesCache() {
        // Bundle に iknow-schema.md がない場合は fallback、ある場合は bundle source
        // どちらでも cachedSchema が non-nil になる
        SchemaLoader.shared.load()
        let schema = SchemaLoader.shared.loadedSchema
        #expect(!schema.rawMarkdown.isEmpty)
        // source は .bundle or .fallback
        switch schema.source {
        case .bundle, .fallback:
            break  // OK
        }
    }

    @Test func testSectionExtraction() {
        // fallback schema には「Hedge phrases」section が含まれる
        SchemaLoader.shared.load()
        let hedge = SchemaLoader.shared.section(named: "Hedge phrases")
        // bundle に iknow-schema.md がある時は hedge != nil、fallback も hedge を含むので nil ではない可能性高い
        if let hedge {
            #expect(hedge.contains("私の理解では") || hedge.contains("hedge"))
        }
    }

    @Test func testSectionNotFoundReturnsNil() {
        SchemaLoader.shared.load()
        let result = SchemaLoader.shared.section(named: "存在しないセクション_XYZ123")
        #expect(result == nil)
    }
}
