//
//  UnderstandingCardSurfaceService.swift
//  KnowledgeTree
//
//  spec 044 — 学習タブの surface 候補生成 (5-tier scoring)。
//
//  - newKnowledge (100): ConceptPage created 24h 以内 + userUnderstanding=0
//  - needsUpdate  (90):  SavedAnswer isStale=true
//  - shallow      (80):  ConceptPage userUnderstanding <= 1 + 関連記事 7d 以内
//  - deepDive     (60):  ConceptPage userUnderstanding 2-3 + isFollowing=true
//  - review       (40):  ConceptPage lastInteractedAt nil or > 30d 前
//  - 補正:        -10    dismissed 既往 (UnderstandingInteraction)
//

import Foundation
import SwiftData
import os

@MainActor
protocol UnderstandingCardSurfaceServiceProtocol: AnyObject {
    /// 上位 N 件の card を返す (default 5)。
    func surfaceTopCards(limit: Int) async -> [UnderstandingCard]
    /// 全 surface 候補を返す (paginated UI 側で表示)。
    func surfaceAllCards() async -> [UnderstandingCard]
}

@MainActor
final class DefaultUnderstandingCardSurfaceService: UnderstandingCardSurfaceServiceProtocol {

    private let context: ModelContext
    private let now: () -> Date
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "surface")

    /// 過去 N 日の interaction を fetch (lastInteractedMap / dismissedIDs 計算)。
    private let interactionLookbackDays: TimeInterval = 60 * 86_400

    /// shallow 判定の関連記事 lookback (秒)。
    private let recentArticleWindow: TimeInterval = 7 * 86_400

    /// review 判定の lastInteractedAt cutoff (秒)。
    private let reviewCutoff: TimeInterval = 30 * 86_400

    /// newKnowledge 判定の createdAt 24h 以内。
    private let newKnowledgeWindow: TimeInterval = 86_400

    /// dismissed 既往の priority penalty。
    private let dismissPenalty: Int = -10

    init(context: ModelContext, now: @escaping () -> Date = { .now }) {
        self.context = context
        self.now = now
    }

    func surfaceTopCards(limit: Int) async -> [UnderstandingCard] {
        let all = await surfaceAllCards()
        return Array(all.prefix(limit))
    }

    func surfaceAllCards() async -> [UnderstandingCard] {
        let currentNow = now()

        // === Fetch interaction history ===
        let lookbackCutoff = currentNow.addingTimeInterval(-interactionLookbackDays)
        var dismissedIDs: Set<UUID> = []
        var lastInteractedMap: [UUID: Date] = [:]

        let interactionDescriptor = FetchDescriptor<UnderstandingInteraction>(
            predicate: #Predicate { $0.occurredAt >= lookbackCutoff },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        let interactions = (try? context.fetch(interactionDescriptor)) ?? []
        for ix in interactions {
            // lastInteractedAt: 各 targetID の最新 occurredAt (interactions は desc sort 済 → 初回 hit が最新)
            if lastInteractedMap[ix.targetID] == nil {
                lastInteractedMap[ix.targetID] = ix.occurredAt
            }
            if ix.actionEnum == .dismissed {
                dismissedIDs.insert(ix.targetID)
            }
        }

        // === Fetch ConceptPage ===
        let allPages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []

        // === Fetch SavedAnswer ===
        let allAnswers = (try? context.fetch(FetchDescriptor<SavedAnswer>())) ?? []

        // === Score ConceptPage ===
        var cards: [UnderstandingCard] = []
        let newKnowledgeCutoff = currentNow.addingTimeInterval(-newKnowledgeWindow)
        let recentArticleCutoff = currentNow.addingTimeInterval(-recentArticleWindow)
        let reviewCutoffDate = currentNow.addingTimeInterval(-reviewCutoff)

        for page in allPages {
            let last = lastInteractedMap[page.id]

            // label 判定 (上から順、最初に match した label を採用)
            let label: UnderstandingCardLabel
            let baseScore: Int

            if page.createdAt >= newKnowledgeCutoff && page.userUnderstanding == 0 {
                label = .newKnowledge
                baseScore = 100
            } else if page.userUnderstanding <= 1 && hasRecentArticle(page: page, cutoff: recentArticleCutoff) {
                label = .shallow
                baseScore = 80
            } else if page.userUnderstanding >= 2 && page.userUnderstanding <= 3 && page.isFollowing {
                label = .deepDive
                baseScore = 60
            } else if last == nil || (last ?? .distantPast) < reviewCutoffDate {
                label = .review
                baseScore = 40
            } else {
                continue  // surface 候補外
            }

            var score = baseScore
            if dismissedIDs.contains(page.id) {
                score += dismissPenalty
            }
            cards.append(UnderstandingCard(
                id: page.id,
                kind: .conceptPage(page),
                priorityScore: score,
                label: label,
                lastInteractedAt: last
            ))
        }

        // === Score SavedAnswer ===
        let savedAnswerNewKnowledgeCutoff = newKnowledgeCutoff
        for answer in allAnswers {
            let last = lastInteractedMap[answer.id]
            let label: UnderstandingCardLabel
            let baseScore: Int

            if answer.isStale {
                label = .needsUpdate
                baseScore = 90
            } else if answer.savedAt >= savedAnswerNewKnowledgeCutoff && !answer.relatedConceptIDs.isEmpty {
                label = .newKnowledge
                baseScore = 70
            } else {
                continue
            }

            var score = baseScore
            if dismissedIDs.contains(answer.id) {
                score += dismissPenalty
            }
            cards.append(UnderstandingCard(
                id: answer.id,
                kind: .savedAnswer(answer),
                priorityScore: score,
                label: label,
                lastInteractedAt: last
            ))
        }

        // === Sort: priorityScore desc, then savedAt/createdAt desc ===
        cards.sort { lhs, rhs in
            if lhs.priorityScore != rhs.priorityScore {
                return lhs.priorityScore > rhs.priorityScore
            }
            return sortDate(of: lhs) > sortDate(of: rhs)
        }

        return cards
    }

    // MARK: - Helpers

    /// shallow 判定: 関連記事に savedAt >= cutoff の Article が 1 件以上あるか。
    private func hasRecentArticle(page: ConceptPage, cutoff: Date) -> Bool {
        for article in (page.relatedArticles ?? []) {
            if article.savedAt >= cutoff { return true }
        }
        return false
    }

    /// tiebreak 用の日付 (ConceptPage は createdAt、SavedAnswer は savedAt)。
    private func sortDate(of card: UnderstandingCard) -> Date {
        switch card.kind {
        case .conceptPage(let page): return page.createdAt
        case .savedAnswer(let answer): return answer.savedAt
        }
    }
}
