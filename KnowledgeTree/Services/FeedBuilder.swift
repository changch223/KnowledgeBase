//
//  FeedBuilder.swift
//  KnowledgeTree
//
//  spec 066 (LLM Wiki) — News+ 風フィードを組み立てる純粋ロジック service。
//  記事 (savedAt 降順) と Wiki 更新 (ConceptPage、最近更新 + 本文あり) を sortDate で
//  時系列 merge する。AI 呼び出しゼロ (SwiftData fetch + merge のみ = VISION 軽さ優先)。
//

import Foundation
import SwiftData

@MainActor
protocol FeedBuilding {
    /// フィード 1 画面分のカード列を時系列降順で返す。
    func build() -> [FeedItem]
}

@MainActor
final class FeedBuilder: FeedBuilding {

    /// Wiki 更新カードを出す直近日数 (過去すぎる更新は出さない = 情報過多防止)。
    static let wikiUpdateWindowDays = 14
    /// 記事 fetch 上限。
    static let maxArticles = 60
    /// Wiki 更新カード上限。
    static let maxWikiUpdates = 20
    /// 周期ダイジェストを差し込む間隔 (この件数ごとに 1 枚、P2)。0 で無効。
    static let periodicDigestEvery = 12
    /// 周期ダイジェストに束ねる Wiki 上限。
    static let periodicDigestSize = 5

    // spec 068: おすすめ carousel
    /// おすすめ carousel の件数。
    static let recommendLimit = 5
    /// Wiki おすすめスコアの「関連記事数」重み。
    static let wikiArticleWeight = 2.0
    /// おすすめ更新ボーナスの減衰窓 (日)。これを超えると更新ボーナス 0。
    static let recommendRecencyWindowDays = 14.0
    /// carousel を表示する最小候補数 (これ未満なら非表示)。
    static let carouselMinItems = 3
    /// 縦フィードの何件目の後に carousel を挿入するか。
    static let carouselInsertIndex = 3

    private let context: ModelContext
    private let now: () -> Date

    init(context: ModelContext, now: @escaping () -> Date = { Date() }) {
        self.context = context
        self.now = now
    }

    func build() -> [FeedItem] {
        let articles = fetchArticles()
        let pages = fetchWikiCandidates()
        return Self.assemble(articles: articles, wikiPages: pages, now: now())
    }

    /// 純粋 merge ロジック (テスト容易 + View が @Query 結果で直接呼べる = reactive)。
    /// articles は savedAt 降順、wikiPages は isHidden==false の全候補を渡す前提。
    /// spec 068: AI 処理が完了した記事のみ表示 (処理中は出さない = calm UX)。
    static func assemble(articles: [Article], wikiPages: [ConceptPage], now: Date) -> [FeedItem] {
        let cutoff = now.addingTimeInterval(-Double(wikiUpdateWindowDays) * 86_400)
        let wikiUpdates = wikiPages
            .filter { !$0.isHidden }
            .filter { $0.updatedAt >= cutoff }
            .filter { !$0.bodyMarkdown.isEmpty || !$0.summary.isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(maxWikiUpdates)
            .map { $0 }

        var items: [FeedItem] = articles
            .filter { isProcessingComplete($0) }
            .prefix(maxArticles)
            .map { .article($0) }
        items.append(contentsOf: wikiUpdates.map { .wikiUpdate($0) })
        items.sort { $0.sortDate > $1.sortDate }

        return insertPeriodicDigests(into: items, wikiCandidates: wikiUpdates)
    }

    /// spec 068: 記事の AI 知識抽出が完了しているか (succeeded / partiallySucceeded のみ表示対象)。
    /// pending / processing / failed / 未生成 (nil) はフィードに出さない。
    static func isProcessingComplete(_ article: Article) -> Bool {
        switch article.extractedKnowledge?.status {
        case .succeeded, .partiallySucceeded: return true
        default: return false
        }
    }

    // MARK: - spec 068: おすすめ carousel (recommend)

    /// 記事と Wiki を同一スコア軸でソートし、上位 limit 件を carousel 用に返す (AI 呼び出しゼロ)。
    /// - Wiki スコア = 関連記事数 × wikiArticleWeight + 更新 recency ボーナス
    /// - 記事スコア = 保存 recency ボーナス (AI 処理完了済のみ)
    /// limit は省略時 recommendLimit(5)。デフォルト引数は nonisolated context で評価されるため
    /// @MainActor static プロパティを直接書けない (Swift 6) → -1 sentinel で本体解決。
    static func recommend(
        articles: [Article],
        wikiPages: [ConceptPage],
        now: Date,
        limit: Int = -1
    ) -> [FeedItem] {
        let limit = limit < 0 ? recommendLimit : limit
        var scored: [(item: FeedItem, score: Double)] = []

        for page in wikiPages where !page.isHidden {
            guard !page.bodyMarkdown.isEmpty || !page.summary.isEmpty else { continue }
            let articleCount = Double((page.relatedArticles ?? []).count)
            let score = articleCount * wikiArticleWeight + recencyBonus(page.updatedAt, now: now)
            scored.append((.wikiUpdate(page), score))
        }

        for article in articles where isProcessingComplete(article) {
            scored.append((.article(article), recencyBonus(article.savedAt, now: now)))
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.item)
    }

    /// 0〜1 の線形減衰 recency ボーナス。recommendRecencyWindowDays を超えると 0。
    private static func recencyBonus(_ date: Date, now: Date) -> Double {
        let days = now.timeIntervalSince(date) / 86_400
        guard days >= 0 else { return 1 }
        return max(0, 1 - days / recommendRecencyWindowDays)
    }

    // MARK: - Fetch

    private func fetchArticles() -> [Article] {
        var descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.maxArticles
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 非表示でない ConceptPage 全件 (更新ガードは assemble 側で適用)。
    private func fetchWikiCandidates() -> [ConceptPage] {
        let descriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate<ConceptPage> { !$0.isHidden },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 周期ダイジェスト (P2)

    /// periodicDigestEvery 件ごとに、最近更新 Wiki を束ねた振り返りカードを差し込む。
    /// 候補が足りない / 無効設定なら何もしない (calm UX、過多防止)。
    private static func insertPeriodicDigests(into items: [FeedItem], wikiCandidates: [ConceptPage]) -> [FeedItem] {
        guard Self.periodicDigestEvery > 0,
              wikiCandidates.count >= 2,
              items.count > Self.periodicDigestEvery else {
            return items
        }
        let digestPages = Array(wikiCandidates.prefix(Self.periodicDigestSize))
        var result = items
        let insertAt = min(Self.periodicDigestEvery, result.count)
        result.insert(.periodicDigest(digestPages), at: insertAt)
        return result
    }
}
