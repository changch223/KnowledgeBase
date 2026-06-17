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

    // spec 068: カテゴリー / タグ ハイライトカード (縦フィードのバリエーション)
    /// 「最近」= 直近何日に追加された記事を「今週 +N」としてカウントするか。
    static let highlightRecentWindowDays = 7.0
    /// カテゴリーカードを出す最小記事数 (これ未満の小さいカテゴリは出さない)。
    static let categoryHighlightMinArticles = 3
    /// タグカードを出す最小「最近の増加数」(直近 N 日でこれ以上増えたタグのみ)。
    static let tagHighlightMinRecent = 2
    /// 縦フィードに挿入するハイライトカードの間隔 (この件数ごとに 1 枚)。
    static let highlightEvery = 6
    /// 縦フィードに挿入するハイライトカードの総数上限。
    static let maxHighlights = 3

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

    // MARK: - spec 075: 概念中心フィード (AI 呼び出しゼロ、純 fetch + in-memory merge)

    /// 上部「新着」棚の件数上限。
    static let newShelfLimit = 10
    /// 新着棚に出す記事の鮮度上限 (日)。これを超えた未概念化記事は出さない (失敗記事の永久居座り防止)。
    static let newShelfRecencyDays = 30.0

    /// まだ概念に束ねられていない新着記事 (上部「新着」棚用)。
    /// 条件: AI 処理完了済 + `relatedConcepts` が空 (= まだどの概念ページにも紐づいていない)
    /// + 直近 newShelfRecencyDays 以内。savedAt 降順で limit 件。
    /// 概念化される (relatedConcepts に概念が付く) と自動的に棚から消える。
    static func newArticleShelf(
        articles: [Article],
        now: Date,
        limit: Int = -1,
        recencyDays: Double = -1
    ) -> [Article] {
        let limit = limit < 0 ? newShelfLimit : limit
        let recencyDays = recencyDays < 0 ? newShelfRecencyDays : recencyDays
        let cutoff = now.addingTimeInterval(-recencyDays * 86_400)
        return articles
            .filter { isProcessingComplete($0) }
            .filter { ($0.relatedConcepts ?? []).isEmpty }
            .filter { $0.savedAt >= cutoff }
            .sorted { $0.savedAt > $1.savedAt }
            .prefix(limit)
            .map { $0 }
    }

    /// 縦フィードの主役 = トップレベル概念 (広い概念 + 孤立 specific = `parentConceptID == nil`)。
    /// 子 specific を親に畳み込み、記事数を解決した ConceptFeedEntry を updatedAt 降順で返す。
    /// pre-spec-074 のフラットページ (level=specific, parent=nil) も孤立として拾うので消えない。
    /// 中身が空のページ (summary/body/子/記事 すべて無し) はノイズなので除外。
    static func topLevelConcepts(pages: [ConceptPage], now: Date) -> [ConceptFeedEntry] {
        let visible = pages.filter { !$0.isHidden }

        // 親ID → 子ページ群
        var childrenByParent: [UUID: [ConceptPage]] = [:]
        for page in visible {
            if let pid = page.parentConceptID {
                childrenByParent[pid, default: []].append(page)
            }
        }

        return visible
            .filter { $0.parentConceptID == nil }
            .map { page -> ConceptFeedEntry in
                let children = (childrenByParent[page.id] ?? [])
                    .sorted { $0.updatedAt > $1.updatedAt }
                return ConceptFeedEntry(
                    page: page,
                    children: children,
                    articleCount: (page.relatedArticles ?? []).count
                )
            }
            .filter { entry in
                !entry.page.summary.isEmpty
                    || !entry.page.bodyMarkdown.isEmpty
                    || !entry.children.isEmpty
                    || entry.articleCount > 0
            }
            // spec 080拡張: 「未読/更新あり」を先に、各グループ内は「重要(記事数)×最新」。
            // fresh = updatedAt > lastSeenAt (未読 or 最終閲覧後に更新)。既読で未更新は下げる。
            .sorted { a, b in
                let aFresh = isFresh(a.page), bFresh = isFresh(b.page)
                if aFresh != bFresh { return aFresh }            // 未読/更新を上に
                if a.articleCount != b.articleCount {
                    return a.articleCount > b.articleCount         // 重要 = 記事が溜まっている
                }
                return a.page.updatedAt > b.page.updatedAt         // 最新 tiebreak
            }
    }

    /// spec 080拡張: 未読 or 最終閲覧後に更新された概念か (フィード上位判定)。
    static func isFresh(_ page: ConceptPage) -> Bool {
        page.updatedAt > (page.lastSeenAt ?? .distantPast)
    }

    /// 上部カルーセル用おすすめ = トップレベル概念を活動量 (関連記事数) + 更新 recency で採点し上位 limit。
    static func recommendConcepts(
        pages: [ConceptPage],
        now: Date,
        limit: Int = -1
    ) -> [ConceptPage] {
        let limit = limit < 0 ? recommendLimit : limit
        return pages
            .filter { !$0.isHidden && $0.parentConceptID == nil }
            .filter { !$0.summary.isEmpty || !$0.bodyMarkdown.isEmpty }
            .map { page -> (page: ConceptPage, score: Double) in
                let articleCount = Double((page.relatedArticles ?? []).count)
                return (page, articleCount * wikiArticleWeight + recencyBonus(page.updatedAt, now: now))
            }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.page)
    }

    // MARK: - spec 068: カテゴリー / タグ ハイライト

    /// 縦フィードのバリエーション用に、カテゴリーカード・タグカードを生成する (AI 呼び出しゼロ)。
    /// 「最近伸びている」= 直近 highlightRecentWindowDays 日に追加された記事数でランク付け。
    /// - articles: 表示対象 (AI 処理完了済を渡す前提だが内部でも filter)
    /// - tags: 全 Tag
    /// - wikiCountByCategory: カテゴリ名 → Wiki(ConceptPage) 件数
    static func highlights(
        articles: [Article],
        tags: [Tag],
        wikiCountByCategory: [String: Int],
        now: Date
    ) -> [FeedItem] {
        let recentCutoff = now.addingTimeInterval(-highlightRecentWindowDays * 86_400)
        let shown = articles.filter { isProcessingComplete($0) }

        // --- カテゴリーカード: 記事の Tag.categoryRaw を集計 ---
        var catTotal: [String: Int] = [:]
        var catRecent: [String: Int] = [:]
        for article in shown {
            // 記事のカテゴリ = tags の categoryRaw 最頻 (なければ「その他」)
            let cat = resolveArticleCategory(article)
            catTotal[cat, default: 0] += 1
            if article.savedAt >= recentCutoff { catRecent[cat, default: 0] += 1 }
        }
        let categoryNames: [String] = catTotal.keys
            .filter { (catTotal[$0] ?? 0) >= categoryHighlightMinArticles }
            .sorted { lhs, rhs in
                let lr = catRecent[lhs] ?? 0, rr = catRecent[rhs] ?? 0
                if lr != rr { return lr > rr }
                return (catTotal[lhs] ?? 0) > (catTotal[rhs] ?? 0)
            }
        let categoryCards: [FeedItem] = categoryNames.map { name in
            .categoryHighlight(
                category: CategorySeed.category(for: name),
                articleCount: catTotal[name] ?? 0,
                wikiCount: wikiCountByCategory[name] ?? 0,
                recentCount: catRecent[name] ?? 0
            )
        }

        // --- タグカード: 直近 N 日に増えたタグ ---
        let tagCards: [FeedItem] = tags
            .compactMap { tag -> (Tag, Int, Int)? in
                let arts = tag.articles ?? []
                let recent = arts.filter { $0.savedAt >= recentCutoff && isProcessingComplete($0) }.count
                guard recent >= tagHighlightMinRecent else { return nil }
                return (tag, arts.count, recent)
            }
            .sorted { $0.2 > $1.2 }
            .map { .tagHighlight(tag: $0.0, totalCount: $0.1, recentCount: $0.2) }

        // カテゴリ → タグ の順で交互に、maxHighlights まで
        var result: [FeedItem] = []
        var ci = categoryCards.makeIterator()
        var ti = tagCards.makeIterator()
        while result.count < maxHighlights {
            var added = false
            if let c = ci.next() { result.append(c); added = true }
            if result.count >= maxHighlights { break }
            if let t = ti.next() { result.append(t); added = true }
            if !added { break }
        }
        return result
    }

    /// 記事のカテゴリを解決 (tags の categoryRaw のうち最頻、無ければ「その他」)。
    private static func resolveArticleCategory(_ article: Article) -> String {
        let cats = (article.tags ?? []).compactMap { $0.categoryRaw }.filter { !$0.isEmpty }
        guard !cats.isEmpty else { return CategorySeed.otherCategory.name }
        let counts = Dictionary(cats.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { $0.value < $1.value }?.key ?? CategorySeed.otherCategory.name
    }

    /// 時系列 feed にハイライトカードを highlightEvery 件ごとに差し込む (純関数)。
    static func interleaveHighlights(into feed: [FeedItem], highlights: [FeedItem]) -> [FeedItem] {
        guard !highlights.isEmpty, !feed.isEmpty else { return feed }
        var result: [FeedItem] = []
        var hi = highlights.makeIterator()
        for (idx, item) in feed.enumerated() {
            result.append(item)
            if (idx + 1) % highlightEvery == 0, let h = hi.next() {
                result.append(h)
            }
        }
        return result
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
