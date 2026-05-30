//
//  RecentDigestService.swift
//  KnowledgeTree
//
//  spec 035 — 「最近のあなた」差分 3 段落 AI 統合要約。
//  V3.0 polish (2026-05-27):
//    - 出力を「3 段落 80-150 字」→「ヘッドライン 1 文 + テーマ 3 個」に変更
//    - 4 tier fallback 階層を導入:
//      Tier 1: since 以降の Article + AI 生成成功 → 表示 + UserDefaults cache 保存
//      Tier 2: since 以降 0 件 → 前回 cache から復元 (古くても表示、calm UX)
//      Tier 3: cache も無い (初回起動) → 全 Article 最新 1 件の essence を headline 化
//      Tier 4: 記事ゼロ → empty
//

import Foundation
import SwiftData
import os

@MainActor
protocol RecentDigestServiceProtocol: AnyObject {
    /// 期間内の Article から 1 文ヘッドライン + テーマ 3 個 を生成。
    /// 4 tier fallback (Service ヘッダコメント参照) で常に「何かしらを表示する」設計。
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
    private let userDefaults: UserDefaults

    /// 上限件数 (これを超えたら最新優先で truncate)
    private let maxArticles = 30

    /// V3.0 polish: 前回 AI 生成結果の cache キー (UserDefaults JSON encode)
    private static let cacheKey = "spec056_recentDigest_cache_v3"

    init(
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        userDefaults: UserDefaults = .standard
    ) {
        self.session = session
        self.availability = availability
        self.userDefaults = userDefaults
    }

    func generate(since: Date, in context: ModelContext) async throws -> RecentDigestResult {
        // Tier 1: since 以降の Article を fetch
        let recentDescriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.savedAt > since },
            sortBy: [SortDescriptor(\Article.savedAt, order: .reverse)]
        )
        let recentCandidates = (try? context.fetch(recentDescriptor)) ?? []
        let recentArticles = Array(recentCandidates.prefix(maxArticles))

        if !recentArticles.isEmpty {
            // since 以降の記事がある → AI 生成 (or fallback paragraphs)
            let result = await tryGenerate(articles: recentArticles)
            // 成功時のみ cache 保存 (失敗時の fallback は保存しない、次回は新規生成を試す)
            if availability.isAvailable && !result.paragraphs.isEmpty {
                saveCache(result)
            }
            return result
        }

        // Tier 2: since 以降 0 件 → 前回 cache から復元 (古くても OK)
        if let cached = loadCache() {
            logger.notice("recent digest: tier 2 cache restored, cachedAt=\(cached.cachedAt, privacy: .public)")
            return RecentDigestResult(
                paragraphs: cached.paragraphs,
                articleCount: cached.articleCount,
                earliestSavedAt: cached.earliestSavedAt,
                latestSavedAt: cached.latestSavedAt
            )
        }

        // Tier 3: cache も無い → 全 Article から最新 1 件で headline 抽出
        let allDescriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\Article.savedAt, order: .reverse)]
        )
        var allBounded = allDescriptor
        allBounded.fetchLimit = 1
        let allArticles = (try? context.fetch(allBounded)) ?? []

        if let latest = allArticles.first {
            logger.notice("recent digest: tier 3 latest-article fallback, title=\(latest.title, privacy: .public)")
            let headline = Self.headlineFromSingleArticle(latest)
            let theme = Self.themeFromArticle(latest)
            let result = RecentDigestResult(
                paragraphs: [headline, theme],
                articleCount: 1,
                earliestSavedAt: latest.savedAt,
                latestSavedAt: latest.savedAt
            )
            // V3.0 polish (2026-05-28): Tier 3 結果も cache 保存 → 連発の log 抑制 + 画面再表示で安定。
            // Tier 1 AI 成功時に上書きされるので、後で AI 結果に置き換わる。
            saveCache(result)
            return result
        }

        // Tier 4: 記事ゼロ
        return .empty
    }

    // MARK: - Private: AI 生成 + fallback paragraphs

    private func tryGenerate(articles: [Article]) async -> RecentDigestResult {
        let earliest = articles.last?.savedAt
        let latest = articles.first?.savedAt

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
                logger.notice("recent digest LM returned empty paragraphs, falling back to essence-based")
            } catch {
                logger.error("recent digest LM failed: \(String(describing: error), privacy: .public), falling back to essence-based")
            }
        }

        // Fallback: essence ベースで 1 文ヘッドライン + テーマ 3 個 を擬似生成
        return RecentDigestResult(
            paragraphs: Self.fallbackParagraphs(articles: articles),
            articleCount: articles.count,
            earliestSavedAt: earliest,
            latestSavedAt: latest
        )
    }

    // MARK: - Private: UserDefaults cache

    private struct CachedDigest: Codable {
        var paragraphs: [String]
        var articleCount: Int
        var earliestSavedAt: Date?
        var latestSavedAt: Date?
        var cachedAt: Date
    }

    private func saveCache(_ result: RecentDigestResult) {
        let cached = CachedDigest(
            paragraphs: result.paragraphs,
            articleCount: result.articleCount,
            earliestSavedAt: result.earliestSavedAt,
            latestSavedAt: result.latestSavedAt,
            cachedAt: Date.now
        )
        if let data = try? JSONEncoder().encode(cached) {
            userDefaults.set(data, forKey: Self.cacheKey)
        }
    }

    private func loadCache() -> CachedDigest? {
        guard let data = userDefaults.data(forKey: Self.cacheKey),
              let cached = try? JSONDecoder().decode(CachedDigest.self, from: data) else {
            return nil
        }
        return cached
    }

    // MARK: - Prompt

    /// V3.0 polish: 「3 段落 80-150 字」→「1 文 60-100 字 ヘッドライン + テーマ 3 件」に変更。
    /// 知識 Clip 最上部「最近の学び」セクションで、長い段落ではなく一目で読める 1 文要約 +
    /// 主要テーマ 3 個を chips で並べる UI に統合。token も大幅削減。
    /// 出力 (RecentDigestOutput.paragraphs) の構造:
    ///   - [0] ヘッドライン本文 (60-100 字、テーマ統合の 1 文)
    ///   - [1] テーマ 1 (10-20 字)
    ///   - [2] テーマ 2 (10-20 字)
    ///   - [3] テーマ 3 (10-20 字)
    /// spec 060 (P1-10): buildPrompt に列挙する記事の上限。
    /// maxArticles=30 (差分判定 / articleCount 表示用) とは別に、prompt 構築だけ絞る。
    /// ヘッドライン + テーマ 3 個の生成には最新 8 件で代表性十分。
    static let promptArticleLimit = 8
    /// spec 060 (P1-10): prompt 累積文字数の安全上限。日本語 char≈token 近似で
    /// Foundation Models の 4096 token 上限を確実に下回るマージン。
    static let promptCharBudget = 3000

    static func buildPrompt(articles: [Article]) -> String {
        var prompt = """
        あなたは iKnow の AI アシスタントです。ユーザーが最近保存した記事から、何を学んだかを「1 文の見出し + 主要テーマ 3 個」で伝えてください。

        ## ルール
        1. ヘッドラインは 60〜100 字、自然な日本語、テーマを統合した断定調。
           例: 「最近は AI エージェント設計と Claude Skills について 4 件読みました。」
        2. テーマは各 10〜20 字の短い名詞句。記事横断で見える共通テーマを 3 個まで。
           例: 「AI エージェント」「Claude Skills」「PM 効率化」。
        3. ID や URL を本文に書かない、「私が読んだのは」のような視点も使わない。

        ## 最近保存した記事 (件数 \(articles.count))
        """

        // spec 060 (P1-10): 全 30 件列挙だと ~4089 token で 4096 超過するため、
        // 上限 promptArticleLimit 件 + 累積文字数ガードで token 超過を防ぐ。
        let promptArticles = Array(articles.prefix(promptArticleLimit))
        for (i, article) in promptArticles.enumerated() {
            let essence = (article.extractedKnowledge?.essence ?? "").prefix(50)
            let firstFact = article.extractedKnowledge?.keyFacts?.first?.statement.prefix(20) ?? ""
            let entry = """

            [\(i + 1)] \(article.title.prefix(50))
            要点: \(essence)
            事実: \(firstFact)
            """
            // 累積が安全上限を超えるならそれ以上記事を足さない (1 記事が異常に長いケースも吸収)
            if prompt.count + entry.count > promptCharBudget { break }
            prompt += entry
        }

        prompt += """

        ## 出力形式
        paragraphs フィールドに 4 件の文字列を順に入れてください:
          [0] = ヘッドライン (60〜100 字)
          [1] = テーマ 1 (10〜20 字)
          [2] = テーマ 2 (10〜20 字)
          [3] = テーマ 3 (10〜20 字)
        """
        return prompt
    }

    // MARK: - Fallback (Apple Intelligence 不可時の擬似生成)

    /// V3.0 polish: 4 件 (ヘッドライン + テーマ 3) の擬似出力を生成。
    /// ヘッドライン = 最初の記事 essence (or title) を抜粋、テーマ = 最新 3 件の title を圧縮。
    static func fallbackParagraphs(articles: [Article]) -> [String] {
        guard !articles.isEmpty else { return [] }

        let headlineSource = articles.first?.extractedKnowledge?.essence
            ?? articles.first?.title
            ?? ""
        let headlineBase = headlineSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let headline = articles.count > 1
            ? "最近 \(articles.count) 件保存しました。" + (headlineBase.count > 50 ? String(headlineBase.prefix(50)) + "…" : headlineBase)
            : headlineBase

        let themes = articles.prefix(3).map { article -> String in
            let title = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.count > 18 ? String(title.prefix(18)) + "…" : title
        }

        return [headline] + themes
    }

    // MARK: - Tier 3: 単一記事 headline 抽出

    /// 全 Article fallback も cache も無い時、最新 1 件の essence を headline 化。
    /// 「保存したばかり / 抽出中」記事でも何か出すよう、essence → title の順に fallback。
    /// V3.0 polish (2026-05-28): essence が長い場合は最初の文で切る (「途中で切れる」見た目をなくす)。
    static func headlineFromSingleArticle(_ article: Article) -> String {
        if let essence = article.extractedKnowledge?.essence,
           !essence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return firstCompleteSentence(essence)
        }
        return article.title
    }

    /// テキストの最初の完結文を返す (「。」「.」「\n」終端で切る)。
    /// 1 文も無いなら 100 字以下なら全文、超えれば prefix 100 で末尾「…」付ける。
    static func firstCompleteSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let terminators: Set<Character> = ["。", "．", ".", "\n"]
        if let endIndex = trimmed.firstIndex(where: { terminators.contains($0) }) {
            // 終端文字含めて返す (.「。」が自然)
            let next = trimmed.index(after: endIndex)
            return String(trimmed[..<next])
        }
        // 終端なし → 100 字以下なら全文、超えれば truncate
        if trimmed.count <= 100 { return trimmed }
        return String(trimmed.prefix(100)) + "…"
    }

    /// 単一記事からテーマ chip 用の短い名詞句を抽出。
    /// KnowledgeEntity > KeyFact > title prefix の優先順位。
    static func themeFromArticle(_ article: Article) -> String {
        // 上位 entity (salience desc) があれば使う
        if let entity = (article.extractedKnowledge?.entities ?? [])
            .sorted(by: { $0.salience > $1.salience })
            .first {
            return entity.name
        }
        if let fact = article.extractedKnowledge?.keyFacts?.first?.statement {
            return String(fact.prefix(18))
        }
        return String(article.title.prefix(18))
    }
}
