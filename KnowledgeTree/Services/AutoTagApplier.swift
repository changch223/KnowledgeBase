//
//  AutoTagApplier.swift
//  KnowledgeTree
//
//  spec 012 — knowledge 抽出 succeeded 直後に呼ばれる auto-tag 純粋関数モジュール。
//  spec 008 既存の SuggestedTagFinder + TagStore + TagNormalizer を合成するだけの薄い境界。
//
//  contracts/auto-tag-applier.md 準拠。
//
//  早期 return:
//  - article.tags が空でない (FR-006 / US2 — 手動タグ既存はスキップ)
//  - knowledge.status が .succeeded / .partiallySucceeded のいずれでもない (FR-004 / US4)
//  - limit <= 0 (防御的)
//
//  付与:
//  - SuggestedTagFinder.find() で salience >= 4 上位 N 件を取得
//  - 各候補を TagStore.addTag() で順次付与 (失敗 1 件は skip + log で graceful)
//

import Foundation
import os

@MainActor
enum AutoTagApplier {
    private static let logger = Logger(subsystem: "app.KnowledgeTree", category: "auto-tag")

    /// Article に対して auto-tag を試みる。
    /// 既存タグあり / knowledge 未完了の場合は no-op で早期 return。
    /// - Parameters:
    ///   - article: 対象 Article (extractedKnowledge.entities + tags を読む)
    ///   - tagStore: spec 008 既存 TagStore (TagNormalizer + 既存 Tag 再利用 + RefreshTrigger.bump 担当)
    ///   - limit: 付与上限。MVP では 5 固定 (FR-011)
    static func apply(
        to article: Article,
        using tagStore: TagStore,
        limit: Int = 5
    ) {
        guard limit > 0 else { return }

        // FR-006 / US2: 既存タグあり → 完全スキップ
        guard article.tags.isEmpty else {
            logger.debug("auto-tag skipped: existing tags=\(article.tags.count)")
            return
        }

        // FR-004 / US4: knowledge 未完了なら付与しない
        guard let knowledge = article.extractedKnowledge else {
            logger.debug("auto-tag skipped: no extractedKnowledge")
            return
        }
        switch knowledge.status {
        case .succeeded, .partiallySucceeded:
            break  // proceed
        case .pending, .extracting, .failed, .skipped:
            logger.debug("auto-tag skipped: knowledge status=\(knowledge.statusRaw, privacy: .public)")
            return
        }

        // 候補取得 (salience >= 4 desc Top N、TagNormalizer 経由)
        let suggestions = SuggestedTagFinder.find(
            for: article,
            existingTagNames: [],
            limit: limit
        )
        guard !suggestions.isEmpty else {
            logger.debug("auto-tag no-op: no suggestions for \(article.url, privacy: .public)")
            return
        }

        // 順次付与 (失敗 1 件は skip + log で graceful)
        var appliedCount = 0
        for suggestion in suggestions {
            do {
                if let normalized = try tagStore.addTag(
                    rawName: suggestion.displayName,
                    to: article
                ), !normalized.isEmpty {
                    appliedCount += 1
                }
            } catch {
                logger.error(
                    "auto-tag addTag failed for \(suggestion.displayName, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }

        logger.notice(
            "auto-tag applied \(appliedCount)/\(suggestions.count) for \(article.url, privacy: .public)"
        )
    }
}
