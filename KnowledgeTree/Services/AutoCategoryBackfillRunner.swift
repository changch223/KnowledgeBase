//
//  AutoCategoryBackfillRunner.swift
//  KnowledgeTree
//
//  spec 015 — bootstrap で 1 度限り、既存全 Tag (categoryRaw == nil) を
//  AutoCategoryClassifier で classify、categoryRaw を更新。
//
//  spec 013 AutoTagBackfillRunner と同パターン (BackfillFlagStore 再利用、
//  ProcessingMonitor.Phase `.categoryClassifying` で進捗表示)。
//
//  contracts/auto-category-backfill-runner.md 準拠。
//

import Foundation
import SwiftData
import os

@MainActor
final class AutoCategoryBackfillRunner {
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "auto-category-backfill")

    private let context: ModelContext
    private let classifier: AutoCategoryClassifier
    private let processingMonitor: ProcessingMonitor?
    private let flagStore: BackfillFlagStore

    /// backfill 中の ProcessingMonitor key として使う固定 UUID。
    /// 通常の Article.id (UUID) と衝突しないよう上位 8 桁を全 0 + 識別文字列。
    static let backfillProcessingID = UUID(
        uuidString: "00000000-0000-0000-0000-CA7E0CEAA70F"
    )!

    init(
        context: ModelContext,
        classifier: AutoCategoryClassifier,
        processingMonitor: ProcessingMonitor? = nil,
        flagStore: BackfillFlagStore = UserDefaultsBackfillFlagStore(key: "auto_category_backfill_v1_done")
    ) {
        self.context = context
        self.classifier = classifier
        self.processingMonitor = processingMonitor
        self.flagStore = flagStore
    }

    /// bootstrap で 1 回呼ばれる。フラグが既に true なら early return。
    /// `Tag.categoryRaw == nil` の Tag を順次 classify → categoryRaw 更新 → save。
    func run() async {
        // 1. フラグ early return
        guard !flagStore.isCompleted() else {
            logger.debug("auto-category backfill skipped: already completed")
            return
        }

        // 2. categoryRaw == nil の Tag を fetch
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.categoryRaw == nil },
            sortBy: [SortDescriptor(\.name)]
        )
        let candidates: [Tag] = (try? context.fetch(descriptor)) ?? []

        logger.notice("auto-category backfill starting: \(candidates.count) candidates")

        // 候補 0 件 → flag だけ true、return
        guard !candidates.isEmpty else {
            flagStore.markCompleted()
            logger.notice("auto-category backfill completed: 0 candidates")
            return
        }

        // 3. ProcessingMonitor 開始
        let backfillID = Self.backfillProcessingID
        processingMonitor?.start(
            .categoryClassifying,
            articleID: backfillID,
            title: "全タグのカテゴリー分類中",
            progressIndex: 0,
            progressTotal: candidates.count
        )

        // 4. 1 件ずつ classify + save (中断時の部分結果保存のため per-Tag save)
        var processedIndex = 0
        for tag in candidates {
            // spec 072: Tag が付く記事のタイトル/essence を文脈として渡す。
            let contextText = (tag.articles ?? []).prefix(2)
                .flatMap { [$0.title, $0.extractedKnowledge?.essence] }
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " / ")
            let categoryName = await classifier.classify(tagName: tag.name, context: contextText)
            tag.categoryRaw = categoryName
            try? context.save()
            processedIndex += 1
            processingMonitor?.updateProgress(
                articleID: backfillID,
                index: processedIndex
            )
        }

        // 5. ProcessingMonitor 終了
        processingMonitor?.finish(articleID: backfillID)

        // 6. フラグ true セット
        flagStore.markCompleted()

        logger.notice("auto-category backfill completed: classified \(processedIndex) tags")
    }
}
