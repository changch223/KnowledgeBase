//
//  ScreenshotDemo.swift
//  KnowledgeBase
//
//  App Store スクリーンショット用の DEBUG 限定デモデータ投入モード。
//  起動引数: `-screenshotDemo YES -screenshotScreen <home|topic|chat|article|library>`
//  (端末言語は `-AppleLanguages (en)` `-AppleLocale en_US` で切り替える)。
//  - in-memory ModelContainer に決定的なデモデータを seed (CloudKit・既存ストアには触れない)
//  - 起動時 bootstrap (backfill / 整理ループ / AI) は走らせない
//  - Release ビルドには一切含まれない (ファイル全体が #if DEBUG)
//  撮影は ScreenShot/capture.sh から行う。
//

#if DEBUG
import Foundation
import SwiftData

enum ScreenshotDemo {
    enum Screen: String {
        case home, topic, chat, article, library
    }

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: "screenshotDemo") }

    static var screen: Screen {
        Screen(rawValue: UserDefaults.standard.string(forKey: "screenshotScreen") ?? "home") ?? .home
    }

    /// 撮影対象画面に対応する初期タブ。
    static var initialTab: AppTab {
        switch screen {
        case .home, .topic, .article: return .knowledgeClip
        case .library: return .library
        case .chat: return .search
        }
    }

    /// 起動引数の端末言語から生成言語を解決 (シミュレータに残った保存値で上書きされないよう同期する)。
    static func prepareLanguage() {
        let lang = PipelineLanguage.fromPreferredLanguages(Locale.preferredLanguages)
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        defaults.set(lang.rawValue, forKey: PipelineLanguage.userDefaultsKey)
        PipelineLanguage._resetForTesting()
    }

    // 決定的 ID (画面遷移で lookup せずに参照するため)
    static let topicID = UUID(uuidString: "D0000000-0000-4000-8000-000000000001")!
    static let sessionID = UUID(uuidString: "D0000000-0000-4000-8000-0000000000C1")!
    static func articleID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "D0000000-0000-4000-8000-0000000000A%X", index))!
    }

    // MARK: - Container

    @MainActor
    static func makeSeededContainer() -> ModelContainer {
        prepareLanguage()
        do {
            let container = try ModelContainer(
                for: SharedSchema.all,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
            seed(into: container.mainContext)
            return container
        } catch {
            fatalError("ScreenshotDemo: in-memory ModelContainer failed: \(error)")
        }
    }

    // MARK: - Seed

    private struct Spec {
        let host: String
        let tagIndex: Int
        let topicIndex: Int
        /// 保存からの経過 (分)
        let minutesAgo: Double
    }

    /// 記事 10 件の言語非依存部分。topicIndex: 1 = プロンプト / 2 = AI×仕事 / 3 = 睡眠 / 4 = 家計 / 5 = 家ごはん
    private static let specs: [Spec] = [
        Spec(host: "ai-notes.example.com", tagIndex: 0, topicIndex: 1, minutesAgo: 25),
        Spec(host: "tech-column.example.com", tagIndex: 0, topicIndex: 1, minutesAgo: 190),
        Spec(host: "workstyle.example.org", tagIndex: 1, topicIndex: 2, minutesAgo: 60 * 27),
        Spec(host: "dev-journal.example.com", tagIndex: 1, topicIndex: 2, minutesAgo: 60 * 52),
        Spec(host: "sleep-lab.example.org", tagIndex: 2, topicIndex: 3, minutesAgo: 60 * 24 * 3),
        Spec(host: "health-daily.example.com", tagIndex: 2, topicIndex: 3, minutesAgo: 60 * 24 * 4),
        Spec(host: "money-note.example.org", tagIndex: 3, topicIndex: 4, minutesAgo: 60 * 24 * 6),
        Spec(host: "household.example.com", tagIndex: 3, topicIndex: 4, minutesAgo: 60 * 24 * 9),
        Spec(host: "kitchen-diary.example.com", tagIndex: 4, topicIndex: 5, minutesAgo: 60 * 24 * 12),
        Spec(host: "recipe-box.example.org", tagIndex: 4, topicIndex: 5, minutesAgo: 60 * 24 * 20),
    ]

    @MainActor
    private static func seed(into context: ModelContext) {
        let text = DemoTexts.text(for: PipelineLanguage.current)
        // ステータスバーは 9:41 固定で撮るので、保存時刻も「今日 9:41」を基準にする (表示の食い違い防止)。
        // 9:41 より前に撮る場合は実時刻を使い、未来の時刻にならないようにする。
        let real = Date()
        let nineFortyOne = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: real) ?? real
        let now = min(real, nineFortyOne)
        let seeds = CategorySeed.allSeeds(for: PipelineLanguage.current)
        func category(_ i: Int) -> String { seeds[i].name }

        CategoryRegistry(context: context).seedIfNeeded()

        // タグ (0 AI / 1 仕事術 / 2 睡眠 / 3 家計 / 4 料理)
        let tagCategories = [0, 0, 2, 1, 2]
        let tags: [Tag] = text.tags.enumerated().map { i, name in
            let tag = Tag(name: name, categoryRaw: category(tagCategories[i]))
            context.insert(tag)
            return tag
        }

        // 記事
        var articles: [Article] = []
        for (i, spec) in specs.enumerated() {
            let saved = now.addingTimeInterval(-spec.minutesAgo * 60)
            let article = Article(
                id: articleID(i),
                url: "https://\(spec.host)/articles/\(i + 1)",
                title: text.titles[i],
                savedAt: saved
            )
            context.insert(article)
            article.tags = [tags[spec.tagIndex]]
            // 古い記事は開封済み、直近 2 件は未開封のまま
            if i >= 2 { article.lastOpenedAt = saved.addingTimeInterval(600) }

            let enrichment = ArticleEnrichment(article: article, status: .succeeded, lastFetchedAt: saved)
            context.insert(enrichment)
            article.enrichment = enrichment

            let bodyText = i == 0
                ? text.a0Body.joined(separator: "\n\n")
                : text.essences[i] + "\n\n" + text.essences[(i + 1) % text.essences.count]
            let body = ArticleBody(article: article, status: .succeeded, extractedText: bodyText, lastExtractedAt: saved)
            context.insert(body)
            article.body = body

            let knowledge = ExtractedKnowledge(
                article: article,
                status: .succeeded,
                essence: text.essences[i],
                summary: nil,
                generatedAt: saved
            )
            context.insert(knowledge)
            article.extractedKnowledge = knowledge
            if i == 0 {
                for (order, fact) in text.a0Facts.enumerated() {
                    let kf = KeyFact(knowledge: knowledge, statement: fact, typeRaw: "claim", order: order)
                    context.insert(kf)
                }
            }
            articles.append(article)
        }

        // トピック: 0 親(生成AI) / 1,2 子 / 3 睡眠 / 4 家計 / 5 家ごはん
        let topicCategories = [0, 0, 0, 2, 1, 2]
        let topicArticles: [[Int]] = [[0, 1, 2, 3], [0, 1], [2, 3], [4, 5], [6, 7], [8, 9]]
        let topicUpdatedMinutesAgo: [Double] = [60, 90, 200, 60 * 24 * 2, 60 * 24 * 5, 60 * 24 * 9]
        let topicIDs: [UUID] = [topicID] + (1...5).map { _ in UUID() }
        for t in 0..<6 {
            let sourceIDs = topicArticles[t].map { articles[$0].id.uuidString }
            let page = ConceptPage(
                id: topicIDs[t],
                name: text.topicNames[t],
                categoryRaw: category(topicCategories[t]),
                summary: text.topicSummaries[t],
                crossSourceInsights: text.topicInsights[t],
                // 要点ごとの出典 (記事を順に割り当て)
                insightSourceArticleIDs: text.topicInsights[t].indices.map { sourceIDs[$0 % sourceIDs.count] },
                isStale: false,
                parentConceptID: (t == 1 || t == 2) ? topicID : nil,
                conceptLevelRaw: t == 0 ? ConceptLevel.broad.rawValue : ConceptLevel.specific.rawValue,
                createdAt: now.addingTimeInterval(-3 * 86400),
                updatedAt: now.addingTimeInterval(-topicUpdatedMinutesAgo[t] * 60),
                // 生成AI だけ未読扱い → フィード先頭に来る (他は既読)
                lastSeenAt: t == 0 ? nil : now
            )
            context.insert(page)
            page.relatedArticles = topicArticles[t].map { articles[$0] }
        }

        // チャット 1 セッション (質問 1 + 番号引用付き回答 1)
        let session = ChatSession(
            id: sessionID,
            createdAt: now.addingTimeInterval(-600),
            lastMessageAt: now.addingTimeInterval(-540),
            title: text.question
        )
        context.insert(session)
        let user = ChatMessage(
            session: session, role: ChatMessageRole.user.rawValue,
            text: text.question, timestamp: now.addingTimeInterval(-600)
        )
        let answer = text.answer
            .replacingOccurrences(of: "{A}", with: "(article-id://\(articles[0].id.uuidString))")
            .replacingOccurrences(of: "{B}", with: "(article-id://\(articles[1].id.uuidString))")
        let assistant = ChatMessage(
            session: session, role: ChatMessageRole.assistant.rawValue,
            text: answer,
            citedArticleIDs: [articles[0].id.uuidString, articles[1].id.uuidString],
            timestamp: now.addingTimeInterval(-540)
        )
        context.insert(user)
        context.insert(assistant)

        try? context.save()
    }
}
#endif
