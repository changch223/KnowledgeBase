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
        case enrichment = 0      // メタデータ取得中
        case body = 1            // 本文抽出中
        case knowledge = 2       // 知識抽出中 (AI)
        case tagBackfilling = 3  // spec 013: 既存記事への auto-tag backfill 中

        static func < (lhs: Phase, rhs: Phase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    struct ActiveTask: Identifiable, Sendable {
        let id: UUID
        let articleTitle: String
        let phase: Phase
        let startedAt: Date
        /// spec 006 chunked summarization 等で「N/M」進捗を表示するための完了済件数。
        /// 単発処理では nil。
        var progressIndex: Int?
        /// spec 006: 総数 (chunks + meta-summary など)。単発処理では nil。
        var progressTotal: Int?
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

    /// 単発処理 (spec 005 既存挙動) 用 start。progressIndex/Total なし。
    func start(_ phase: Phase, articleID: UUID, title: String) {
        let task = ActiveTask(
            id: articleID,
            articleTitle: title,
            phase: phase,
            startedAt: Date(),
            progressIndex: nil,
            progressTotal: nil
        )
        tasksByArticle[articleID] = task
    }

    /// spec 006: 進捗付き start。N/M 表示が必要な chunked パス等で使う。
    func start(
        _ phase: Phase,
        articleID: UUID,
        title: String,
        progressIndex: Int,
        progressTotal: Int
    ) {
        let task = ActiveTask(
            id: articleID,
            articleTitle: title,
            phase: phase,
            startedAt: Date(),
            progressIndex: progressIndex,
            progressTotal: progressTotal
        )
        tasksByArticle[articleID] = task
    }

    /// spec 006: 進捗を更新する。articleID が tasksByArticle に存在しないなら no-op。
    /// progressIndex のみ更新、その他のフィールドは保持。
    func updateProgress(articleID: UUID, index: Int) {
        guard var existing = tasksByArticle[articleID] else { return }
        existing.progressIndex = index
        tasksByArticle[articleID] = existing
    }

    func finish(articleID: UUID) {
        tasksByArticle.removeValue(forKey: articleID)
    }

    func reset() {
        tasksByArticle.removeAll()
    }
}
