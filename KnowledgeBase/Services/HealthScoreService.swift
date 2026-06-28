//
//  HealthScoreService.swift
//  KnowledgeTree
//
//  spec 058 — wiki の「健全性スコア」を単一指標で算出。Autoresearch の val_bpb 相当。
//  最初は A (孤立 ConceptPage 数) + B (矛盾未解決数) の合算、将来拡張で重み付き化可能。
//
//  Settings の HealthScoreCard で表示、Lint loop 完了で再計算。
//

import Foundation
import SwiftData

@MainActor
protocol HealthScoreServiceProtocol: AnyObject {
    /// 現状の健全性スコアを計算。0 = 完璧、数値が小さいほど健全。
    func compute() -> HealthScore
}

/// 健全性スコアの構造体。将来拡張用に各 metric を分離保持。
struct HealthScore: Equatable {
    let orphanedConceptPageCount: Int
    let pendingConflictProposalCount: Int
    /// 将来拡張: 「分かりません」率 / カバレッジ率 等
    /// 現在は 0 件、protocol-based metric registry で追加可能。

    var total: Int {
        orphanedConceptPageCount + pendingConflictProposalCount
    }

    var isHealthy: Bool { total == 0 }
}

@MainActor
final class DefaultHealthScoreService: HealthScoreServiceProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func compute() -> HealthScore {
        let orphans = countOrphanedConceptPages()
        // spec 058 で ConflictProposal は autoResolved に統一されたため、pending count は基本 0。
        // 移行期間中の旧 pending 件数があれば表示する。
        let pending = countPendingConflictProposals()
        return HealthScore(
            orphanedConceptPageCount: orphans,
            pendingConflictProposalCount: pending
        )
    }

    private func countOrphanedConceptPages() -> Int {
        let pages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        return pages.filter { page in
            (page.relatedArticles ?? []).count <= 1 && !page.isFollowing
        }.count
    }

    private func countPendingConflictProposals() -> Int {
        let descriptor = FetchDescriptor<ConflictProposal>(
            predicate: #Predicate { $0.status == "pending" }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
