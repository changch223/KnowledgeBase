//
//  RawArticleIntakeTests.swift
//  KnowledgeTreeTests
//
//  spec 091 — 非 URL コンテンツの取り込み土台。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

// .serialized + 単一共有 in-memory コンテナ: 1 プロセスで SharedSchema の in-memory
// ModelContainer を複数生成すると落ちるため (テスト専用 artifact、アプリは 1 コンテナ)、
// 全テストで 1 つを共有。各テストは異なる本文を使うので干渉しない。
@Suite(.serialized)
@MainActor
struct RawArticleIntakeTests {

    @MainActor
    private static let sharedContainer: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: SharedSchema.all, configurations: config)
    }()

    private func makeContext() throws -> ModelContext {
        let ctx = Self.sharedContainer.mainContext
        // 共有コンテナ + リピート実行対策: 各テスト開始時にクリーンにする。
        try ctx.delete(model: Article.self)
        try ctx.delete(model: ArticleBody.self)
        try ctx.delete(model: ArticleEnrichment.self)
        try ctx.save()
        return ctx
    }

    // (1) メモ保存: 合成 URL + 本文事前投入 + enrichment terminal
    @Test func savesRawTextAsArticleWithBody() throws {
        let context = try makeContext()
        let result = RawArticleIntake.save(into: context, title: "メモ見出し", bodyText: "これはテストのメモ本文です。", source: .note)

        guard case let .saved(article) = result else {
            Issue.record("expected .saved, got \(result)"); return
        }
        #expect(article.url.hasPrefix("knowledgebase://note/"))
        #expect(article.title == "メモ見出し")
        #expect(article.body?.extractedText == "これはテストのメモ本文です。")
        #expect(article.body?.status == .succeeded)
        #expect(article.enrichment?.status == .permanentlyFailed)
    }

    // (2) 同一本文 + 同一 source は重複
    @Test func sameBodyIsDuplicate() throws {
        let context = try makeContext()
        let body = "重複検知のテスト本文"
        _ = RawArticleIntake.save(into: context, title: nil, bodyText: body, source: .note)
        let second = RawArticleIntake.save(into: context, title: nil, bodyText: body, source: .note)
        #expect(second == .duplicate)
    }

    // (3) 空本文は missingURL 扱い
    @Test func emptyBodyRejected() throws {
        let context = try makeContext()
        #expect(RawArticleIntake.save(into: context, title: nil, bodyText: "   \n ", source: .note) == .missingURL)
    }

    // (4) タイトル導出: 明示なしは本文先頭行
    @Test func derivedTitleFromFirstLine() {
        #expect(RawArticleIntake.derivedTitle(rawTitle: nil, body: "最初の行\n2行目") == "最初の行")
        #expect(RawArticleIntake.derivedTitle(rawTitle: "明示タイトル", body: "本文") == "明示タイトル")
    }

    // (5) ハッシュは決定的
    @Test func stableHashIsDeterministic() {
        #expect(RawArticleIntake.stableHash("abc") == RawArticleIntake.stableHash("abc"))
        #expect(RawArticleIntake.stableHash("abc") != RawArticleIntake.stableHash("abd"))
    }

    // (6) テキストファイル取り込み: 本文読み出し + filename からタイトル導出
    @Test func extractsPlainTextFile() throws {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("memo-from-drive.txt")
        let body = "ファイル取り込みのテスト本文です。\n2 行目もあります。"
        try body.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let extracted = RawArticleIntake.extractFile(at: url)
        #expect(extracted?.body == body)
        #expect(extracted?.title == "memo from drive")
    }
}
