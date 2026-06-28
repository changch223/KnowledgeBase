//
//  SavedAnswerService.swift
//  KnowledgeTree
//
//  spec 043 — SavedAnswer の自動 / 手動 CRUD。
//
//  - Protocol SavedAnswerServiceProtocol — ChatService + KnowledgeExtractionService から呼ばれる
//  - DefaultSavedAnswerService — AI 不要、純粋 SwiftData ロジック層
//    - captureIfWorthy: AI Chat 答えが条件 (引用 2+ + answer 50+) を満たせば SavedAnswer 自動保存 + 関連 ConceptPage 紐付け
//    - setPinned / delete: ユーザー編集
//    - markStaleForArticle: 新記事 ingest → 関連 ConceptPage → SavedAnswer の isStale 連鎖 (WikiLint 仕込み)
//
//  Service は throw しない (captureIfWorthy / markStaleForArticle、silent fail + Logger)。calm UX (Constitution V) 原則。
//

import Foundation
import SwiftData
import os

// MARK: - Protocol

@MainActor
protocol SavedAnswerServiceProtocol: AnyObject {
    /// AI Chat 答えが条件 (citedArticleIDs.count >= 2 && answer.count >= 50 && 同 question 既存なし) を満たせば
    /// SavedAnswer として永続化。silent fire-and-forget、例外を throw しない。
    func captureIfWorthy(
        question: String,
        answer: String,
        citedArticleIDs: [String],
        sessionID: UUID?
    ) async

    /// 手動 pin toggle (UI から throw 可能)。
    func setPinned(_ answer: SavedAnswer, isPinned: Bool) throws

    /// 削除 (UI から throw 可能)。citedArticles は @Relationship.nullify で Article 残る。
    func delete(_ answer: SavedAnswer) throws

    /// 新記事 ingest で関連 ConceptPage が更新されたとき、紐付く SavedAnswer の isStale=true 連鎖。
    /// silent fire-and-forget、本 spec では UI 影響なし (WikiLint で別 spec)。
    func markStaleForArticle(_ article: Article) async

    /// spec 045: ユーザーが「更新済としてマーク」した時に isStale=false に手動更新。
    func markFresh(_ answer: SavedAnswer) throws

    /// spec 045: 「再生成」フロー用。captureIfWorthy と同じ前提チェックだが、
    /// 同 normalizedQuestion で `isStale=true` な既存 SavedAnswer がある場合は
    /// **古いを残しつつ新 SavedAnswer を追加** (履歴保護)。それ以外は通常 captureIfWorthy と同経路。
    func captureIfWorthyOrReplaceStale(
        question: String,
        answer: String,
        citedArticleIDs: [String],
        sessionID: UUID?
    ) async

    /// spec 057: 明示的に SavedAnswer を作成 (auto-save 廃止後の手動保存経路)。
    /// long press menu「保存」から呼ばれる。citations 不要、50 字以上で受付。
    /// 重複時は既存 SavedAnswer を返す (新規 insert しない)。
    @discardableResult
    func saveExplicit(
        question: String,
        answer: String,
        citedArticleIDs: [String],
        sessionID: UUID?
    ) throws -> SavedAnswer
}

// MARK: - Default 実装

@MainActor
final class DefaultSavedAnswerService: SavedAnswerServiceProtocol {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "saved-answer")

    /// 答え本文の最小 char 数 (auto-save 判定の質的閾値)。
    static let minAnswerChars: Int = 50
    /// 引用件数の最小 (auto-save 判定の質的閾値)。
    static let minCitedCount: Int = 2
    /// relatedConceptIDs の最大件数。
    static let maxRelatedConcepts: Int = 5

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) {
        self.context = context
        self.refreshTrigger = refreshTrigger
    }

    // MARK: - captureIfWorthy

    func captureIfWorthy(
        question: String,
        answer: String,
        citedArticleIDs: [String],
        sessionID: UUID?
    ) async {
        let trimmedQ = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQ.isEmpty else { return }
        guard citedArticleIDs.count >= Self.minCitedCount else {
            return
        }
        guard answer.count >= Self.minAnswerChars else {
            return
        }

        // 重複判定 (normalized question 完全一致、case sensitive)
        let dupDescriptor = FetchDescriptor<SavedAnswer>(
            predicate: #Predicate { $0.question == trimmedQ }
        )
        let existing = (try? context.fetch(dupDescriptor)) ?? []
        guard existing.isEmpty else {
            logger.notice("duplicate question skipped: \(trimmedQ.prefix(40), privacy: .public)")
            return
        }

        // 引用記事 fetch
        let uuids = citedArticleIDs.compactMap { UUID(uuidString: $0) }
        guard !uuids.isEmpty else { return }
        let uuidSet = Set(uuids)
        let articleDescriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { uuidSet.contains($0.id) }
        )
        let citedArticles = (try? context.fetch(articleDescriptor)) ?? []
        guard !citedArticles.isEmpty else {
            logger.error("captureIfWorthy: no articles found for ids \(citedArticleIDs, privacy: .public)")
            return
        }

        // 関連 ConceptPage を resolve (overlap 数 desc top 5)
        let topConceptIDs = resolveTopConceptIDs(citedArticles: citedArticles)

        // SavedAnswer 生成 + 永続化
        let saved = SavedAnswer(
            question: trimmedQ,
            answer: answer,
            citedArticles: citedArticles,
            relatedConceptIDs: topConceptIDs,
            chatSessionID: sessionID,
            savedAutomatically: true
        )
        context.insert(saved)
        do {
            try context.save()
            refreshTrigger?.bump()
            logger.notice("captured: question=\(saved.questionPreview, privacy: .public) cited=\(citedArticles.count) concepts=\(topConceptIDs.count)")
        } catch {
            logger.error("captureIfWorthy save failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - setPinned

    func setPinned(_ answer: SavedAnswer, isPinned: Bool) throws {
        guard answer.isPinned != isPinned else { return }
        answer.isPinned = isPinned
        answer.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
    }

    // MARK: - delete

    func delete(_ answer: SavedAnswer) throws {
        context.delete(answer)
        try context.save()
        refreshTrigger?.bump()
    }

    // MARK: - markStaleForArticle

    func markStaleForArticle(_ article: Article) async {
        // 引用記事に関連する ConceptPage 集合を取得
        let articleID = article.id
        let allPages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        let affectedPages = allPages.filter { page in
            page.relatedArticles?.contains(where: { $0.id == articleID }) ?? false
        }
        guard !affectedPages.isEmpty else { return }
        let pageIDs = Set(affectedPages.map(\.id))

        // 該当 ConceptPage に紐付く SavedAnswer を fetch (in-memory filter)
        let allAnswers = (try? context.fetch(FetchDescriptor<SavedAnswer>())) ?? []
        let affected = allAnswers.filter { ans in
            ans.relatedConceptIDs.contains(where: { pageIDs.contains($0) })
        }
        guard !affected.isEmpty else { return }

        // isStale = true で更新
        for ans in affected {
            ans.isStale = true
            ans.updatedAt = .now
        }
        do {
            try context.save()
            refreshTrigger?.bump()
            logger.notice("markStale: \(affected.count) answers affected by article \(article.url, privacy: .public)")
        } catch {
            logger.error("markStaleForArticle save failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - markFresh (spec 045)

    func markFresh(_ answer: SavedAnswer) throws {
        guard answer.isStale else { return }
        answer.isStale = false
        answer.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
    }

    // MARK: - captureIfWorthyOrReplaceStale (spec 045)

    func captureIfWorthyOrReplaceStale(
        question: String,
        answer: String,
        citedArticleIDs: [String],
        sessionID: UUID?
    ) async {
        let trimmedQ = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQ.isEmpty else { return }
        guard citedArticleIDs.count >= Self.minCitedCount else { return }
        guard answer.count >= Self.minAnswerChars else { return }

        // 重複判定: 同 question の既存 SavedAnswer を fetch
        let dupDescriptor = FetchDescriptor<SavedAnswer>(
            predicate: #Predicate { $0.question == trimmedQ }
        )
        let existing = (try? context.fetch(dupDescriptor)) ?? []
        let staleOnes = existing.filter(\.isStale)
        let freshOnes = existing.filter { !$0.isStale }

        // 既に fresh な (isStale=false) SavedAnswer があれば skip (通常 captureIfWorthy 同等)
        if !freshOnes.isEmpty {
            logger.notice("captureIfWorthyOrReplaceStale: fresh duplicate exists, skipped: \(trimmedQ.prefix(40), privacy: .public)")
            return
        }

        // 引用記事 fetch
        let uuids = citedArticleIDs.compactMap { UUID(uuidString: $0) }
        guard !uuids.isEmpty else { return }
        let uuidSet = Set(uuids)
        let articleDescriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { uuidSet.contains($0.id) }
        )
        let citedArticles = (try? context.fetch(articleDescriptor)) ?? []
        guard !citedArticles.isEmpty else { return }

        // 新 SavedAnswer を insert (isStale=false)、古 stale ones は残す (FR-009)
        let relatedConceptIDs = resolveTopConceptIDs(citedArticles: citedArticles)
        let newAnswer = SavedAnswer(
            question: trimmedQ,
            answer: answer,
            citedArticles: citedArticles,
            relatedConceptIDs: relatedConceptIDs,
            chatSessionID: sessionID,
            isPinned: false,
            isStale: false,
            savedAt: .now,
            updatedAt: .now,
            savedAutomatically: true
        )
        context.insert(newAnswer)
        do {
            try context.save()
            refreshTrigger?.bump()
            logger.notice("captureIfWorthyOrReplaceStale: new answer inserted, \(staleOnes.count) stale ones preserved: \(trimmedQ.prefix(40), privacy: .public)")
        } catch {
            logger.error("captureIfWorthyOrReplaceStale save failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - spec 057: saveExplicit (long press menu「保存」)

    @discardableResult
    func saveExplicit(
        question: String,
        answer: String,
        citedArticleIDs: [String],
        sessionID: UUID?
    ) throws -> SavedAnswer {
        let trimmedQ = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedA = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQ.isEmpty, !trimmedA.isEmpty else {
            throw NSError(domain: "SavedAnswerService", code: 1, userInfo: [NSLocalizedDescriptionKey: "question or answer is empty"])
        }

        // 重複判定: 同 question 既存あれば既存を返す (新規 insert しない)
        let dupDescriptor = FetchDescriptor<SavedAnswer>(
            predicate: #Predicate { $0.question == trimmedQ }
        )
        if let existing = (try? context.fetch(dupDescriptor))?.first {
            return existing
        }

        // citedArticleIDs (String) → UUID → Article 解決
        let uuids = citedArticleIDs.compactMap { UUID(uuidString: $0) }
        let articles: [Article] = uuids.compactMap { id in
            let desc = FetchDescriptor<Article>(predicate: #Predicate { $0.id == id })
            return try? context.fetch(desc).first
        }
        let relatedConceptIDs = resolveTopConceptIDs(citedArticles: articles)

        // 新規 SavedAnswer 作成 (savedAutomatically=false で「明示保存」と区別)
        let newAnswer = SavedAnswer(
            question: trimmedQ,
            answer: trimmedA,
            citedArticles: articles,
            relatedConceptIDs: relatedConceptIDs,
            chatSessionID: sessionID,
            isPinned: false,
            isStale: false,
            savedAt: .now,
            updatedAt: .now,
            savedAutomatically: false
        )
        context.insert(newAnswer)
        try context.save()
        refreshTrigger?.bump()
        logger.notice("saveExplicit: new SavedAnswer inserted (manual): \(trimmedQ.prefix(40), privacy: .public)")
        return newAnswer
    }

    // MARK: - Private

    /// 引用記事から関連 ConceptPage を overlap 数 desc で top 5 解決。
    private func resolveTopConceptIDs(citedArticles: [Article]) -> [UUID] {
        let citedIDs = Set(citedArticles.map(\.id))
        let allPages: [ConceptPage] = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        let scored: [(UUID, Int)] = allPages.compactMap { page in
            let overlap = (page.relatedArticles ?? []).filter { citedIDs.contains($0.id) }.count
            return overlap > 0 ? (page.id, overlap) : nil
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(Self.maxRelatedConcepts)
            .map(\.0)
    }
}
