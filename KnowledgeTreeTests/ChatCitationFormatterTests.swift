//
//  ChatCitationFormatterTests.swift
//  KnowledgeTreeTests
//
//  spec 081 — 番号引用 formatter の純粋関数テスト。
//

import Testing
import Foundation
@testable import KnowledgeTree

struct ChatCitationFormatterTests {

    private let idA = "11111111-1111-1111-1111-111111111111"
    private let idB = "22222222-2222-2222-2222-222222222222"

    // (1) 裸マーカーを初出順に採番、出典も同順
    @Test func bareMarkerNumberingInOrder() {
        let body = "A について述べます (article-id://\(idA))。次に B です (article-id://\(idB))。"
        let result = ChatCitationFormatter.format(body: body, citedArticleIDs: [idA, idB])

        let citations = result.segments.compactMap { seg -> (Int, UUID)? in
            if case let .citation(n, id) = seg { return (n, id) }
            return nil
        }
        #expect(citations.map { $0.0 } == [1, 2])
        #expect(citations.map { $0.1.uuidString.lowercased() } == [idA, idB])
        #expect(result.sources.map { $0.number } == [1, 2])
        #expect(result.sources.map { $0.articleID.uuidString.lowercased() } == [idA, idB])
    }

    // (2) 旧形式 [タイトル](article-id://UUID) もタイトルを残しつつ採番
    @Test func legacyTitleLinkIsNumbered() {
        let body = "詳しくは [リリース記事](article-id://\(idA)) を参照。"
        let result = ChatCitationFormatter.format(body: body, citedArticleIDs: [idA])

        let texts = result.segments.compactMap { seg -> String? in
            if case let .text(t) = seg { return t }
            return nil
        }
        #expect(texts.contains { $0.contains("リリース記事") })
        #expect(result.sources.count == 1)
        #expect(result.sources.first?.number == 1)
        #expect(result.sources.first?.articleID.uuidString.lowercased() == idA)
    }

    // (3) 同一 UUID 再出は同番号、出典は 1 件
    @Test func repeatedSameIDReusesNumber() {
        let body = "X (article-id://\(idA)) と Y (article-id://\(idA)) は同じ出典。"
        let result = ChatCitationFormatter.format(body: body, citedArticleIDs: [idA])

        let numbers = result.segments.compactMap { seg -> Int? in
            if case let .citation(n, _) = seg { return n }
            return nil
        }
        #expect(numbers == [1, 1])
        #expect(result.sources.count == 1)
    }

    // (4) 本文に出ない citedArticleID は出典末尾に追加
    @Test func citedNotInBodyAppendedToSources() {
        let body = "本文では A だけ言及 (article-id://\(idA))。"
        let result = ChatCitationFormatter.format(body: body, citedArticleIDs: [idA, idB])

        #expect(result.sources.map { $0.number } == [1, 2])
        #expect(result.sources.map { $0.articleID.uuidString.lowercased() } == [idA, idB])
        let bodyCitations = result.segments.compactMap { seg -> UUID? in
            if case let .citation(_, id) = seg { return id }
            return nil
        }
        #expect(bodyCitations.map { $0.uuidString.lowercased() } == [idA])
    }

    // (5) マーカー無し本文は素通り、出典空
    @Test func plainBodyHasNoCitations() {
        let body = "これは引用マーカーの無い普通の回答です。"
        let result = ChatCitationFormatter.format(body: body, citedArticleIDs: [])
        #expect(result.sources.isEmpty)
        #expect(result.segments == [.text(body)])
    }
}
