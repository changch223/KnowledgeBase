//
//  ConceptCategoryBackfillRunner.swift
//  KnowledgeTree
//
//  概念ページの categoryRaw を一括再計算 (②) + 同名クロスカテゴリ重複の統合 (③)。
//
//  背景: resolveCategoryRaw の旧ロジックが「その他」も多数決に入れていたため、人名等のノイズ
//  entity の その他 票が実カテゴリを上回り、tech 概念が LLM技術[その他] に倒れていた。
//  ロジック修正後、既存の保存済 categoryRaw は古いまま → このランナーで一括是正する。
//
//  AI 呼び出しゼロ・純 DB 操作。起動時に 1 回 (UserDefaults フラグ)。CloudKit 安全 (@Model 変更なし)。
//

import Foundation
import SwiftData
import os

@MainActor
final class ConceptCategoryBackfillRunner {
    private let context: ModelContext
    private let store: ConceptPageStore
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "concept-category-backfill")

    /// 1 回限り実行のフラグ。ロジック変更で再実行したい時はキー末尾の版数を上げる。
    static let flagKey = "ConceptPage.categoryBackfillCompleted.v1"

    init(context: ModelContext, store: ConceptPageStore) {
        self.context = context
        self.store = store
    }

    func run() {
        guard !UserDefaults.standard.bool(forKey: Self.flagKey) else {
            logger.debug("concept category backfill skipped: already completed")
            return
        }

        // ② 全 ConceptPage の categoryRaw を relatedArticles から再計算
        let pages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        guard !pages.isEmpty else {
            UserDefaults.standard.set(true, forKey: Self.flagKey)
            return
        }

        var recategorized = 0
        for page in pages {
            let articles = page.relatedArticles ?? []
            guard !articles.isEmpty else { continue }
            let newCat = ConceptSynthesisCommon.resolveCategoryRaw(forArticles: articles)
            if !newCat.isEmpty && newCat != page.categoryRaw {
                page.categoryRaw = newCat
                page.updatedAt = .now
                recategorized += 1
            }
        }
        try? context.save()

        // ③ 同名 (大文字小文字無視) の重複ページを統合。target = relatedArticles 最多。
        //    再計算でカテゴリが揃った結果、同名異カテゴリだった重複が浮き彫りになるのでここで畳む。
        let refreshed = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        let groups = Dictionary(grouping: refreshed) { $0.name.lowercased() }
        var merged = 0
        for (_, group) in groups where group.count > 1 {
            let sorted = group.sorted {
                ($0.relatedArticles?.count ?? 0) > ($1.relatedArticles?.count ?? 0)
            }
            guard let target = sorted.first else { continue }
            for source in sorted.dropFirst() {
                do {
                    try store.merge(source: source, into: target)
                    merged += 1
                } catch {
                    logger.error("concept merge failed for \(source.name, privacy: .public): \(String(describing: error), privacy: .public)")
                }
            }
        }

        UserDefaults.standard.set(true, forKey: Self.flagKey)
        logger.notice("concept category backfill done: recategorized=\(recategorized, privacy: .public) merged=\(merged, privacy: .public) pages=\(pages.count, privacy: .public)")
    }
}
