//
//  ProcessingMonitor.swift
//  KnowledgeTree
//
//  spec 005 — バックグラウンド処理の状態を集約する Observable。
//  enrichment / body / knowledge の 3 service が start/finish を report する。
//  ArticleListView の下部 BottomStatusBar が監視する。
//

import Foundation
import Observation

@MainActor
@Observable
final class ProcessingMonitor {
    enum Phase: Int, Comparable, Sendable {
        case enrichment = 0   // メタデータ取得中
        case body = 1         // 本文抽出中
        case knowledge = 2    // 知識抽出中 (AI)

        static func < (lhs: Phase, rhs: Phase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    struct ActiveTask: Identifiable, Sendable {
        let id: UUID
        let articleTitle: String
        let phase: Phase
        let startedAt: Date
    }

    private(set) var tasksByArticle: [UUID: ActiveTask] = [:]

    /// 現在表示すべき代表タスク。
    /// 優先度: knowledge > body > enrichment。同 phase 内では最新開始を優先。
    var current: ActiveTask? {
        tasksByArticle.values.max { lhs, rhs in
            if lhs.phase != rhs.phase { return lhs.phase < rhs.phase }
            return lhs.startedAt < rhs.startedAt
        }
    }

    var totalActiveCount: Int {
        tasksByArticle.count
    }

    var isIdle: Bool { tasksByArticle.isEmpty }

    func start(_ phase: Phase, articleID: UUID, title: String) {
        let task = ActiveTask(
            id: articleID,
            articleTitle: title,
            phase: phase,
            startedAt: Date()
        )
        tasksByArticle[articleID] = task
    }

    func finish(articleID: UUID) {
        tasksByArticle.removeValue(forKey: articleID)
    }

    func reset() {
        tasksByArticle.removeAll()
    }
}
