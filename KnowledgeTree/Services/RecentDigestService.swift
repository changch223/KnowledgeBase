//
//  RecentDigestService.swift
//  KnowledgeTree
//
//  spec 035 — 「最近のあなた」差分 3 段落 AI 統合要約。
//  前回開いた時刻 〜 now の Article を Foundation Models で 3 段落統合、
//  Apple Intelligence 不可端末では Fallback (各記事 essence を順序通り並べる擬似 3 段落)。
//

import Foundation
import SwiftData
import os

@MainActor
protocol RecentDigestServiceProtocol: AnyObject {
    /// 期間内の Article から 3 段落要約を生成。期間 0 件なら空配列を返す。
    func generate(since: Date, in context: ModelContext) async throws -> RecentDigestResult
}

struct RecentDigestResult: Equatable {
    let paragraphs: [String]
    let articleCount: Int
    let earliestSavedAt: Date?
    let latestSavedAt: Date?

    static let empty = RecentDigestResult(paragraphs: [], articleCount: 0, earliestSavedAt: nil, latestSavedAt: nil)
    var isEmpty: Bool { articleCount == 0 || paragraphs.isEmpty }
}

@MainActor
final class RecentDigestService: RecentDigestServiceProtocol {

    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "recent-digest")
    private let session: LanguageModelSessionProtocol
    private let availability: AvailabilityChecker

    /// 上限件数 (これを超えたら最新優先で truncate)
    private let maxArticles = 30

    init(
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker = SystemLanguageModelAvailabilityChecker()
    ) {
        self.session = session
        self.availability = availability
    }

    func generate(since: Date, in context: ModelContext) async throws -> RecentDigestResult {
        // since 以降の Article を fetch
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.savedAt > since },
            sortBy: [SortDescriptor(\Article.savedAt, order: .reverse)]
        )
        let candidates = (try? context.fetch(descriptor)) ?? []
        let articles = Array(candidates.prefix(maxArticles))

        guard !articles.isEmpty else { return .empty }

        let earliest = articles.last?.savedAt
        let latest = articles.first?.savedAt

        // Foundation Models 経路 / Fallback 経路 分岐
        if availability.isAvailable {
            do {
                let prompt = Self.buildPrompt(articles: articles)
                let output = try await session.generateRecentDigest(prompt: prompt)
                let cleaned = output.paragraphs
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !cleaned.isEmpty {
                    return RecentDigestResult(
                        paragraphs: cleaned,
                        articleCount: articles.count,
                        earliestSavedAt: earliest,
                        latestSavedAt: latest
                    )
                }
                logger.notice("recent digest LM returned empty paragraphs, falling back")
            } catch {
                logger.error("recent digest LM failed: \(String(describing: error), privacy: .public), falling back")
            }
        }

        // Fallback: 各記事の essence (or title) を順序通り並べた擬似 3 段落
        let fallbackParagraphs = Self.fallbackParagraphs(articles: articles)
        return RecentDigestResult(
            paragraphs: fallbackParagraphs,
            articleCount: articles.count,
            earliestSavedAt: earliest,
            latestSavedAt: latest
        )
    }

    // MARK: - Prompt

    static func buildPrompt(articles: [Article]) -> String {
        var prompt = """
        あなたは知積 (KnowledgeTree) の AI アシスタントです。ユーザーが最近保存した以下の記事の要点を、自然な日本語の 3 段落に統合してください。

        ## ルール
        1. 各段落は 80-150 字程度。
        2. 記事を機械的に並べるのではなく、テーマごとに統合する。
        3. ID や URL を本文に書かないでください。
        4. 「私が読んだのは」のような視点ではなく、要点だけ書く。
        5. 記事に答えがない / 内容が薄い場合は、無理に書かず短くまとめる。

        ## 最近保存した記事 (件数 \(articles.count))
        """

        for (i, article) in articles.enumerated() {
            let essence = article.extractedKnowledge?.essence ?? ""
            let keyFacts = article.extractedKnowledge?.keyFacts.prefix(3).map { $0.statement }.joined(separator: " / ") ?? ""
            prompt += """

            [\(i + 1)] タイトル: \(article.title)
            要点: \(essence)
            主な事実: \(keyFacts)
            """
        }

        prompt += """

        ## 出力形式
        paragraphs フィールドに 3 つの段落 (String 3 件) を入れてください。
        """
        return prompt
    }

    // MARK: - Fallback (擬似 3 段落生成)

    static func fallbackParagraphs(articles: [Article]) -> [String] {
        // 記事を 3 グループに分けて、各グループ essence を結合
        let total = articles.count
        guard total > 0 else { return [] }

        let groupSize = max(1, Int(ceil(Double(total) / 3.0)))
        var paragraphs: [String] = []

        for groupIndex in 0..<3 {
            let start = groupIndex * groupSize
            guard start < total else { break }
            let end = min(start + groupSize, total)
            let group = articles[start..<end]
            let essences = group.map { article -> String in
                if let e = article.extractedKnowledge?.essence, !e.isEmpty {
                    return e
                }
                return article.title
            }
            // 記事間は「。」or「 / 」で結合
            let combined = essences.joined(separator: " / ")
            // 200 字に truncate
            let truncated = combined.count > 250 ? String(combined.prefix(250)) + "…" : combined
            paragraphs.append(truncated)
        }
        return paragraphs
    }
}
