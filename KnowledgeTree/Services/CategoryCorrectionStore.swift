//
//  CategoryCorrectionStore.swift
//  KnowledgeTree
//
//  spec 097 Phase 2 — カテゴリ分類の「ユーザー修正の正解例」を貯め、分類プロンプトに
//  few-shot として供給する学習ストア。
//
//  ※ アプリ専用の別 ModelContainer に保存 (SharedSchema に入れない = 拡張ターゲットの
//     pbxproj 編集が不要)。CloudKit private DB で端末間同期、失敗時はローカルにフォールバック。
//

import Foundation
import SwiftData
import os

@MainActor
final class CategoryCorrectionStore {
    private static let logger = Logger(subsystem: "app.KnowledgeTree", category: "category-learning")
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// アプリ専用の学習用 ModelContainer を作る。
    /// CloudKit 有効時は private DB 同期を試み、失敗したらローカルのみにフォールバック (crash しない)。
    static func makeContainer(cloudKitEnabled: Bool) -> ModelContainer? {
        let schema = Schema([CategoryCorrectionExample.self])
        if cloudKitEnabled {
            let cloud = ModelConfiguration(
                "CategoryLearning",
                schema: schema,
                cloudKitDatabase: .private("iCloud.app.KnowledgeTree")
            )
            if let container = try? ModelContainer(for: schema, configurations: cloud) {
                logger.notice("category learning container: CloudKit")
                return container
            }
            logger.notice("category learning container: CloudKit failed → local fallback")
        }
        let local = ModelConfiguration("CategoryLearning", schema: schema)
        if let container = try? ModelContainer(for: schema, configurations: local) {
            logger.notice("category learning container: local")
            return container
        }
        logger.error("category learning container: failed to create")
        return nil
    }

    /// ユーザー修正を 1 件記録する。同じ (tagName, correctCategory) が既にあれば createdAt を更新するだけ。
    func record(tagName: String, contextSnippet: String = "", wrongCategory: String? = nil, correctCategory: String) {
        let tag = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        let correct = correctCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty, !correct.isEmpty else { return }

        let all = (try? context.fetch(FetchDescriptor<CategoryCorrectionExample>())) ?? []
        if let existing = all.first(where: {
            $0.tagName.lowercased() == tag.lowercased() && $0.correctCategory == correct
        }) {
            existing.createdAt = .now
            if existing.wrongCategory == nil { existing.wrongCategory = wrongCategory }
        } else {
            context.insert(CategoryCorrectionExample(
                tagName: tag,
                contextSnippet: String(contextSnippet.prefix(120)),
                wrongCategory: wrongCategory,
                correctCategory: correct
            ))
        }
        try? context.save()
    }

    /// 分類対象 tagName の few-shot 例を返す。同名タグの修正を最優先、続いて新しい順。
    func fewShot(for tagName: String, limit: Int = 8) -> [CategoryFewShot] {
        let descriptor = FetchDescriptor<CategoryCorrectionExample>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        guard !all.isEmpty else { return [] }
        let lower = tagName.lowercased()
        let matches = all.filter { $0.tagName.lowercased() == lower }
        let rest = all.filter { $0.tagName.lowercased() != lower }
        return (matches + rest).prefix(limit).map {
            CategoryFewShot(tagName: $0.tagName, correctCategory: $0.correctCategory, wrongCategory: $0.wrongCategory)
        }
    }

    var count: Int {
        (try? context.fetchCount(FetchDescriptor<CategoryCorrectionExample>())) ?? 0
    }
}
