//
//  TitleCleanerTests.swift
//  KnowledgeTreeTests
//
//  spec 103 — TitleCleaner 純関数。
//

import Testing
import Foundation
@testable import KnowledgeBase

struct TitleCleanerTests {
    @Test func japaneseSiteNameIsKept() {
        #expect(TitleCleaner.clean("生成AIの現在地 | 日経電子版", host: "nikkei.com") == "生成AIの現在地 | 日経電子版")
    }

    @Test func removesMatchingSiteName() {
        #expect(TitleCleaner.clean("Swift 6 の新機能 - Zenn", host: "zenn.dev") == "Swift 6 の新機能")
    }

    @Test func unrelatedTailIsKept() {
        #expect(TitleCleaner.clean("What's new - Swift 6", host: "example.com") == "What's new - Swift 6")
    }

    @Test func shortCoreNameIsKept() {
        #expect(TitleCleaner.clean("Tesla - next year", host: "x.com") == "Tesla - next year")
    }

    @Test func tailContainingHostButNotCoreIsKept() {
        #expect(TitleCleaner.clean("記事 - AI", host: "mainichi.jp") == "記事 - AI")
    }

    @Test func syntheticUrlHasNoWebHost() {
        #expect(TitleCleaner.webHost(of: "knowledgebase://text/abc") == nil)
        #expect(TitleCleaner.webHost(of: "https://zenn.dev/a") == "zenn.dev")
        #expect(TitleCleaner.clean("Meeting - notes", host: TitleCleaner.webHost(of: "knowledgebase://text/abc")) == "Meeting - notes")
    }

    @Test func emptyAfterRemovalIsKept() {
        #expect(TitleCleaner.clean("Zenn", host: "zenn.dev") == "Zenn")
    }
}
