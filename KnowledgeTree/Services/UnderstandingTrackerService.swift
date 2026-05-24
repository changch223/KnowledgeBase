//
//  UnderstandingTrackerService.swift
//  KnowledgeTree
//
//  spec 044 — 学習行動の記録 + ConceptPage.userUnderstanding 更新 + 1-hop graph 波及。
//
//  ✓ わかった (recordUnderstood):
//    1. UnderstandingInteraction insert (action="understood")
//    2. 対象 ConceptPage を解決 (SavedAnswer card 経路は relatedConceptIDs 全て)
//    3. ConceptPage.userUnderstanding += 1 (clamp [0, 5])
//    4. 1-hop 波及: ConceptPage.relatedConceptIDs (spec 042 で graph 経由 populate 済) を辿り
//       neighbor ConceptPage に "propagated" interaction insert、累積 2 件 = +1 (round-half-up) で
//       neighbor.userUnderstanding に反映
//    5. refreshTrigger.bump()
//
//  🤔 もっと (recordNeedMore) / ✗ 違う (recordDismissed) / カード起動 (recordOpenedChat):
//    interaction insert のみ、userUnderstanding 不変
//

import Foundation
import SwiftData
import os

@MainActor
protocol UnderstandingTrackerServiceProtocol: AnyObject {
    func recordUnderstood(card: UnderstandingCard) async throws
    func recordNeedMore(card: UnderstandingCard) async throws
    func recordDismissed(card: UnderstandingCard) async throws
    func recordOpenedChat(card: UnderstandingCard) async throws
}

@MainActor
final class DefaultUnderstandingTrackerService: UnderstandingTrackerServiceProtocol {

    private let context: ModelContext
    private weak var refreshTrigger: RefreshTrigger?
    private let now: () -> Date
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "tracker")

    /// `userUnderstanding` の clamp 上限。
    static let maxUnderstanding: Int = 5

    /// 1-hop 波及 1 件ごとに加算される propagation 効果 (累積 `propagationStep` 件 = +1)。
    private let propagationStep: Int = 2

    init(
        context: ModelContext,
        refreshTrigger: RefreshTrigger? = nil,
        now: @escaping () -> Date = { .now }
    ) {
        self.context = context
        self.refreshTrigger = refreshTrigger
        self.now = now
    }

    // MARK: - recordUnderstood

    func recordUnderstood(card: UnderstandingCard) async throws {
        let nowDate = now()

        // 1. 履歴 insert
        insertInteraction(card: card, action: .understood, at: nowDate)

        // 2. 対象 ConceptPage 解決
        let conceptIDs = resolveConceptIDs(for: card)

        // 3. 各 ConceptPage に +1 clamp
        for pageID in conceptIDs {
            guard let page = fetchConceptPage(id: pageID) else { continue }
            page.userUnderstanding = min(Self.maxUnderstanding, max(0, page.userUnderstanding + 1))
            page.updatedAt = nowDate
        }

        // 4. 1-hop 波及: relatedConceptIDs (spec 042 で graph 経由 populate 済) を辿る
        var processedNeighbors: Set<UUID> = Set(conceptIDs)
        for pageID in conceptIDs {
            guard let page = fetchConceptPage(id: pageID) else { continue }
            for neighborID in page.relatedConceptIDs {
                guard !processedNeighbors.contains(neighborID) else { continue }
                processedNeighbors.insert(neighborID)
                propagateUnderstanding(neighborID: neighborID, at: nowDate)
            }
        }

        // 5. save + refresh
        try context.save()
        refreshTrigger?.bump()
        logger.notice("recordUnderstood: card=\(card.id.uuidString, privacy: .public) concepts=\(conceptIDs.count) propagated=\(processedNeighbors.count - conceptIDs.count)")
    }

    // MARK: - recordNeedMore

    func recordNeedMore(card: UnderstandingCard) async throws {
        let nowDate = now()
        insertInteraction(card: card, action: .needMore, at: nowDate)
        try context.save()
        refreshTrigger?.bump()
    }

    // MARK: - recordDismissed

    func recordDismissed(card: UnderstandingCard) async throws {
        let nowDate = now()
        insertInteraction(card: card, action: .dismissed, at: nowDate)
        try context.save()
        refreshTrigger?.bump()
    }

    // MARK: - recordOpenedChat

    func recordOpenedChat(card: UnderstandingCard) async throws {
        let nowDate = now()
        insertInteraction(card: card, action: .openedChat, at: nowDate)
        try context.save()
        // refreshTrigger.bump() は意図的に呼ばない (頻繁、UI 振動回避)
    }

    // MARK: - Private helpers

    private func insertInteraction(card: UnderstandingCard, action: UnderstandingInteraction.Action, at date: Date) {
        let kind: UnderstandingInteraction.Kind
        switch card.kind {
        case .conceptPage: kind = .conceptPage
        case .savedAnswer: kind = .savedAnswer
        }
        let interaction = UnderstandingInteraction(
            kind: kind,
            targetID: card.id,
            action: action,
            occurredAt: date
        )
        context.insert(interaction)
    }

    /// card から「+1 対象となる ConceptPage の id」を返す。
    /// - ConceptPage card → [page.id]
    /// - SavedAnswer card → answer.relatedConceptIDs (max 5)
    private func resolveConceptIDs(for card: UnderstandingCard) -> [UUID] {
        switch card.kind {
        case .conceptPage(let page):
            return [page.id]
        case .savedAnswer(let answer):
            return answer.relatedConceptIDs
        }
    }

    private func fetchConceptPage(id: UUID) -> ConceptPage? {
        let descriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// neighbor ConceptPage に "propagated" interaction を insert し、累積件数 / propagationStep の差分だけ
    /// userUnderstanding を +1 (round-half-up = floor((existing + 1) / step) - floor(existing / step))。
    private func propagateUnderstanding(neighborID: UUID, at date: Date) {
        // 1. 既存 propagated 件数を fetch
        let propagatedRaw = UnderstandingInteraction.Action.propagated.rawValue
        let descriptor = FetchDescriptor<UnderstandingInteraction>(
            predicate: #Predicate { $0.targetID == neighborID && $0.action == propagatedRaw }
        )
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        // 2. propagated interaction insert
        let interaction = UnderstandingInteraction(
            kind: .conceptPage,
            targetID: neighborID,
            action: .propagated,
            occurredAt: date
        )
        context.insert(interaction)

        // 3. propagation step 境界跨ぎなら neighbor の userUnderstanding を +1
        let prevFloor = existingCount / propagationStep
        let newFloor = (existingCount + 1) / propagationStep
        let delta = newFloor - prevFloor

        if delta > 0, let neighbor = fetchConceptPage(id: neighborID) {
            neighbor.userUnderstanding = min(Self.maxUnderstanding, max(0, neighbor.userUnderstanding + delta))
            neighbor.updatedAt = date
        }
    }
}
