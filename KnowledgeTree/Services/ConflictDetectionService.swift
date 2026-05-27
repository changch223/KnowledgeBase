//
//  ConflictDetectionService.swift
//  KnowledgeTree
//
//  spec 037 — 時系列事実上書き検出。
//  新記事の knowledge 抽出完了後に呼ばれる fire-and-forget。
//  新記事の top entities ごとに同 entity を持つ過去記事 (上限 5 件) と比較、
//  Foundation Models で矛盾検出 → ConflictProposal 作成。
//

import Foundation
import SwiftData
import os

@MainActor
protocol ConflictDetectionServiceProtocol: AnyObject {
    func detect(article: Article) async
    /// spec 041: graph triple 衝突検出 (AI 不要、SwiftData fetch のみ)。
    /// graph extraction 完了後に呼ばれる前提。同 (source, label) で複数 target があれば
    /// ConflictProposal を作成 (graphEdgeID 付き)。
    func detectGraphConflicts(article: Article)
}

@MainActor
final class ConflictDetectionService: ConflictDetectionServiceProtocol {

    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "conflict")
    private let context: ModelContext
    private let session: LanguageModelSessionProtocol
    private let availability: AvailabilityChecker

    /// 検出に使う entity 上位件数 (salience 高い順)
    private let topEntityCount: Int = 2

    /// 比較対象の過去記事上限 (entity ごと)
    private let comparisonLimit: Int = 5

    /// dismissed 状態を「再検出を許可しない」期間
    private let dismissCooldownDays: Int = 30

    init(
        context: ModelContext,
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker = SystemLanguageModelAvailabilityChecker()
    ) {
        self.context = context
        self.session = session
        self.availability = availability
    }

    func detect(article: Article) async {
        guard availability.isAvailable else { return }
        guard let knowledge = article.extractedKnowledge,
              !(knowledge.entities ?? []).isEmpty else { return }

        // top N entities (salience 高い順)
        let topEntities = (knowledge.entities ?? [])
            .sorted { $0.salience > $1.salience }
            .prefix(topEntityCount)

        for entity in topEntities {
            await detectForEntity(article: article, entityName: entity.name)
        }
    }

    private func detectForEntity(article: Article, entityName: String) async {
        let normalized = entityName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }

        // 同 entity を持つ過去記事 fetch (自分自身は除外、savedAt 降順、上限 N)
        let allArticles = (try? context.fetch(FetchDescriptor<Article>())) ?? []
        let articleID = article.id
        let pastCandidates = allArticles
            .filter { other in
                guard other.id != articleID else { return false }
                guard let otherEntities = other.extractedKnowledge?.entities else { return false }
                return otherEntities.contains { e in
                    e.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
                }
            }
            .sorted { $0.savedAt > $1.savedAt }
            .prefix(comparisonLimit)

        for past in pastCandidates {
            await compareAndStoreIfConflict(
                newArticle: article,
                oldArticle: past,
                entityName: entityName
            )
        }
    }

    private func compareAndStoreIfConflict(
        newArticle: Article,
        oldArticle: Article,
        entityName: String
    ) async {
        // 既に同ペアの ConflictProposal があれば skip (dismiss cooldown も考慮)
        if hasRecentProposal(newID: newArticle.id, oldID: oldArticle.id) { return }

        let prompt = Self.buildPrompt(
            newArticle: newArticle,
            oldArticle: oldArticle,
            entityName: entityName
        )

        do {
            let output = try await session.generateConflictDetection(prompt: prompt)
            guard output.hasConflict,
                  !output.conflictDescription.isEmpty else { return }

            // spec 058: AI 自動採用 (autoResolved status)、両方残す、ユーザー confirm なし
            let proposal = ConflictProposal(
                newArticle: newArticle,
                oldArticle: oldArticle,
                entityName: entityName,
                conflictDescription: output.conflictDescription,
                newFact: output.newFact,
                oldFact: output.oldFact,
                status: ConflictStatus.autoResolved.rawValue
            )
            proposal.resolvedAt = .now
            context.insert(proposal)
            try? context.save()
            logger.notice("conflict auto-resolved (両方残す): \(entityName, privacy: .public) for new=\(newArticle.url, privacy: .public) vs old=\(oldArticle.url, privacy: .public)")
        } catch {
            // silent fail (calm UX)
            logger.error("conflict detection failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// 同ペア (newID, oldID) で pending or dismissed (cooldown 内) の ConflictProposal が
    /// 既に存在するか check。
    private func hasRecentProposal(newID: UUID, oldID: UUID) -> Bool {
        let descriptor = FetchDescriptor<ConflictProposal>()
        let all = (try? context.fetch(descriptor)) ?? []
        let cooldownDate = Date.now.addingTimeInterval(-Double(dismissCooldownDays) * 86400)
        return all.contains { p in
            guard p.newArticle?.id == newID, p.oldArticle?.id == oldID else { return false }
            // pending は再作成しない
            if p.status == ConflictStatus.pending.rawValue { return true }
            // dismissed は cooldown 内なら再作成しない
            if p.status == ConflictStatus.dismissed.rawValue,
               let resolved = p.resolvedAt,
               resolved > cooldownDate { return true }
            // overwrite / keepBoth は同ペアで再作成しない
            return p.status == ConflictStatus.overwrite.rawValue
                || p.status == ConflictStatus.keepBoth.rawValue
        }
    }

    // MARK: - spec 041: graph triple 衝突検出

    func detectGraphConflicts(article: Article) {
        // article が紐づく Category を解決 (categoryRaw は Tag で optional)
        let resolvedCategory: String? = (article.tags ?? []).lazy
            .compactMap { $0.categoryRaw }
            .first(where: { !$0.isEmpty })
        guard let categoryRaw = resolvedCategory else { return }

        // article の entities → GraphNode 解決
        let entityNames: [String] = article.extractedKnowledge?.entities?.map { $0.name } ?? []
        guard !entityNames.isEmpty else { return }
        let normalized = Set(entityNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty })
        guard !normalized.isEmpty else { return }

        let descriptor = FetchDescriptor<GraphNode>(
            predicate: #Predicate<GraphNode> { node in
                node.isActive == true && node.categoryRaw == categoryRaw
            }
        )
        let candidates: [GraphNode] = (try? context.fetch(descriptor)) ?? []
        let articleNodes = candidates.filter { normalized.contains($0.name.lowercased()) }

        for node in articleNodes {
            // ラベル付き outgoing edges を label でグループ化、target が複数あれば衝突候補
            let labeledEdges = (node.outgoingEdges ?? []).filter { $0.label != nil && $0.target?.isActive == true }
            let groupedByLabel = Dictionary(grouping: labeledEdges, by: { $0.label ?? "" })
            for (label, edges) in groupedByLabel where edges.count >= 2 {
                // updatedAt 降順で sort、最新 / 1 つ前を比較
                let sorted = edges.sorted { $0.updatedAt > $1.updatedAt }
                let newest = sorted[0]
                let older = sorted[1]
                guard let newestTarget = newest.target,
                      let olderTarget = older.target,
                      newestTarget.id != olderTarget.id else { continue }

                // 既存 ConflictProposal (同 graphEdgeID) は skip
                if hasGraphProposalForEdge(edgeID: newest.id) { continue }

                // spec 058: AI 自動採用 (autoResolved status)、両方残す、ユーザー confirm なし
                let description = "「\(node.name)」の「\(label)」が更新されています"
                let proposal = ConflictProposal(
                    newArticle: article,
                    oldArticle: nil,
                    entityName: node.name,
                    conflictDescription: description,
                    newFact: "\(node.name) は \(label): \(newestTarget.name)",
                    oldFact: "\(node.name) は \(label): \(olderTarget.name)",
                    status: ConflictStatus.autoResolved.rawValue,
                    graphEdgeID: newest.id
                )
                proposal.resolvedAt = .now
                context.insert(proposal)
            }
        }
        try? context.save()
    }

    private func hasGraphProposalForEdge(edgeID: UUID) -> Bool {
        let descriptor = FetchDescriptor<ConflictProposal>(
            predicate: #Predicate<ConflictProposal> { $0.graphEdgeID == edgeID }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        // pending or 直近の resolved があれば skip
        let cooldownDate = Date.now.addingTimeInterval(-Double(dismissCooldownDays) * 86400)
        return existing.contains { p in
            if p.status == ConflictStatus.pending.rawValue { return true }
            if let resolved = p.resolvedAt, resolved > cooldownDate { return true }
            return false
        }
    }

    // MARK: - Prompt

    static func buildPrompt(newArticle: Article, oldArticle: Article, entityName: String) -> String {
        let newEssence = newArticle.extractedKnowledge?.essence ?? ""
        let oldEssence = oldArticle.extractedKnowledge?.essence ?? ""
        let newKeyFacts = newArticle.extractedKnowledge?.keyFacts?.prefix(3).map { $0.statement }.joined(separator: " / ") ?? ""
        let oldKeyFacts = oldArticle.extractedKnowledge?.keyFacts?.prefix(3).map { $0.statement }.joined(separator: " / ") ?? ""

        return """
        以下の 2 記事は同じ entity「\(entityName)」について書かれています。
        新記事と旧記事の事実 (open/閉店、就任/退任、リリース/廃止 等) に矛盾があるか判定してください。

        ## ルール
        1. 矛盾とは「明らかに片方の事実が古い情報になっている」状態 (例: 開店 → 閉店)。
        2. 単に新しい情報を補足しているだけの場合は矛盾なし (false)。
        3. トピックが微妙に違う場合 (例: 経営方針の話 vs 商品紹介) も矛盾なし。
        4. 矛盾がある場合のみ hasConflict=true、説明文を出力。

        ## 新記事 (保存日: \(newArticle.savedAt.iso8601))
        タイトル: \(newArticle.title)
        要点: \(newEssence)
        主な事実: \(newKeyFacts)

        ## 旧記事 (保存日: \(oldArticle.savedAt.iso8601))
        タイトル: \(oldArticle.title)
        要点: \(oldEssence)
        主な事実: \(oldKeyFacts)
        """
    }
}

private extension Date {
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }
}
