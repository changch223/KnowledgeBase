//
//  GraphProposalReviewService.swift
//  KnowledgeTree
//
//  spec 041 (Phase B) — AI 提案 (isUncertain=true edge) のレビュー service。
//  知識 Clip タブの「graph 提案」セクションから:
//  - 採用 (accept): edge.isUncertain=false に確定化、confidence を一段引き上げ
//  - 却下 (reject): edge を削除
//  - ラベル変更 (relabel): label 書き換え + 確定化
//  GraphNodeStore とは責務を分離 (本 service は提案 UX 専用)。
//

import Foundation
import SwiftData

@MainActor
protocol GraphProposalReviewServiceProtocol: AnyObject {
    /// 採用: edge を確定化 (isUncertain=false、confidence を min 0.8 に引き上げ)
    func accept(edge: GraphEdge) throws
    /// 却下: edge を削除
    func reject(edge: GraphEdge) throws
    /// ラベル変更 + 確定化 (空にすると共起扱いになるため、空文字は invalidName を throw)
    func relabel(edge: GraphEdge, to newLabel: String) throws
    /// 全 isUncertain=true edge を返す (UI 表示用、最新 updatedAt 順)
    func pendingProposals() -> [GraphEdge]
}

@MainActor
final class GraphProposalReviewService: GraphProposalReviewServiceProtocol {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?

    /// 採用時の最低 confidence (現在値が低ければここまで引き上げ)
    private let acceptedMinConfidence: Float = 0.8

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) {
        self.context = context
        self.refreshTrigger = refreshTrigger
    }

    func accept(edge: GraphEdge) throws {
        edge.isUncertain = false
        edge.confidence = max(edge.confidence, acceptedMinConfidence)
        edge.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
    }

    func reject(edge: GraphEdge) throws {
        context.delete(edge)
        try context.save()
        refreshTrigger?.bump()
    }

    func relabel(edge: GraphEdge, to newLabel: String) throws {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 40 else {
            throw GraphProposalReviewError.invalidLabel
        }
        edge.label = trimmed
        edge.isUncertain = false
        edge.confidence = max(edge.confidence, acceptedMinConfidence)
        edge.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
    }

    func pendingProposals() -> [GraphEdge] {
        let descriptor = FetchDescriptor<GraphEdge>(
            predicate: #Predicate<GraphEdge> { $0.isUncertain == true },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

enum GraphProposalReviewError: Error {
    case invalidLabel
}
