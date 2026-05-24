//
//  SuggestedPromptGenerator.swift
//  KnowledgeTree
//
//  spec 056 — AI チャットタブ 空状態 (ChatSession 履歴ゼロ) で表示する
//  3 つの suggested prompts を動的生成。
//
//  生成ロジック:
//   (a) 最新 ConceptPage 1 件 → 「{name} について教えて」
//   (b) 最新 Category 1 件 → 「{categoryName} 分野で何があった?」
//   (c) 固定: 「最近保存した記事の要点は?」
//   (d) 3 件未満なら generic fallback で埋める
//
//  各 prompt は最大 30 字、超過時 truncate (... 付き)。
//  UserDefaults `spec056_suggested_prompts_cache` に 1 日 1 回 cache。
//

import Foundation
import SwiftData

struct SuggestedPrompt: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let text: String
    let sourceType: SourceType

    enum SourceType: String, Codable {
        case latestConceptPage
        case latestCategory
        case fixedSummaryPrompt
        case genericFallback
    }
}

@MainActor
protocol SuggestedPromptGeneratorProtocol: AnyObject {
    func generateSuggestedPrompts(in context: ModelContext) async -> [SuggestedPrompt]
    func clearCache()
}

@MainActor
final class DefaultSuggestedPromptGenerator: SuggestedPromptGeneratorProtocol {
    static let cacheKey = "spec056_suggested_prompts_cache"
    static let maxChars = 30

    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.defaults = defaults
        self.now = now
    }

    private struct CacheEntry: Codable {
        let date: String  // "yyyy-MM-dd"
        let prompts: [SuggestedPrompt]
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }

    func generateSuggestedPrompts(in context: ModelContext) async -> [SuggestedPrompt] {
        let today = dateFormatter.string(from: now())

        // 1. cache check
        if let data = defaults.data(forKey: Self.cacheKey),
           let cache = try? JSONDecoder().decode(CacheEntry.self, from: data),
           cache.date == today {
            return cache.prompts
        }

        // 2. 再生成
        var prompts: [SuggestedPrompt] = []

        // (a) 最新 ConceptPage
        if let cp = await fetchLatestConceptPage(in: context) {
            let text = truncate("\(cp.name) について教えて", maxChars: Self.maxChars)
            prompts.append(.init(id: UUID(), text: text, sourceType: .latestConceptPage))
        }

        // (b) 最新 Category (Article.categoryRaw distinct、最新 savedAt の Article から)
        if let cat = await fetchLatestCategory(in: context) {
            let text = truncate("\(cat) 分野で何があった?", maxChars: Self.maxChars)
            prompts.append(.init(id: UUID(), text: text, sourceType: .latestCategory))
        }

        // (c) 固定
        let fixedText = String(localized: "chat.suggested.recentSummary")
        prompts.append(.init(id: UUID(), text: fixedText, sourceType: .fixedSummaryPrompt))

        // (d) 3 件未満なら generic fallback で埋める
        let fallbacks: [String] = [
            String(localized: "chat.suggested.fallback.aboutApp"),
            String(localized: "chat.suggested.fallback.howToUse"),
            String(localized: "chat.suggested.fallback.whatsNew")
        ]
        for fb in fallbacks where prompts.count < 3 {
            prompts.append(.init(id: UUID(), text: fb, sourceType: .genericFallback))
        }

        // 上位 3 件のみ
        let result = Array(prompts.prefix(3))

        // 3. cache save
        let entry = CacheEntry(date: today, prompts: result)
        if let data = try? JSONEncoder().encode(entry) {
            defaults.set(data, forKey: Self.cacheKey)
        }

        return result
    }

    func clearCache() {
        defaults.removeObject(forKey: Self.cacheKey)
    }

    // MARK: - Helpers

    private func fetchLatestConceptPage(in context: ModelContext) async -> ConceptPage? {
        var descriptor = FetchDescriptor<ConceptPage>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchLatestCategory(in context: ModelContext) async -> String? {
        // 最新 Article → その関連 Tag → categoryRaw を取得 (Category は Tag に存在)。
        // Article 直接の category は持っていないため、最新 Article 上位 20 件の
        // tags を順に走査して、最初に categoryRaw が non-nil の Tag を採用する。
        var descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let recent = (try? context.fetch(descriptor)) ?? []
        for article in recent {
            let tags = article.tags ?? []
            for tag in tags {
                if let cat = tag.categoryRaw, !cat.isEmpty {
                    return cat
                }
            }
        }
        return nil
    }

    private func truncate(_ s: String, maxChars: Int) -> String {
        guard s.count > maxChars else { return s }
        return String(s.prefix(maxChars - 1)) + "…"
    }
}
