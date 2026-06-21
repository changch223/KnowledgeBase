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
    /// spec 100 fix: **local-only**。別 ModelContainer で 2 つ目の CloudKit private DB ミラーリングを
    /// 張ると、実機でメイン store と同一 iCloud コンテナ (`iCloud.app.KnowledgeTree`) を二重ミラーリング
    /// して競合し、"has no persistent stores / Store Removed" で学習 store が落ち、記録が保存されなく
    /// なる。学習例は端末内のパーソナライズ補助なので local で十分 (cloudKitEnabled は無視)。
    /// 端末間同期が要るなら別 iCloud コンテナ or 別方式で再設計する。
    static func makeContainer(cloudKitEnabled: Bool) -> ModelContainer? {
        let schema = Schema([CategoryCorrectionExample.self])
        let local = ModelConfiguration("CategoryLearning", schema: schema)
        if let container = try? ModelContainer(for: schema, configurations: local) {
            logger.notice("category learning container: local-only")
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

/// spec 097 Phase 2b/4: タグの分野手修正を一貫して適用する共通処理。
/// 記録 (学習) + categoryRaw 反映 + 確信度 High + 概念ヒール。
/// TagManagementView / CategoryReviewView で共用 (ロジックの drift 防止)。
enum CategoryCorrectionApplier {
    @MainActor
    static func apply(
        tag: Tag,
        to newCategory: String,
        store: CategoryCorrectionStore?,
        context: ModelContext,
        refresh: RefreshTrigger?
    ) {
        let old = tag.categoryRaw
        guard newCategory != (old ?? "") else { return }
        let snippet = (tag.articles ?? []).first.map {
            [$0.title, $0.extractedKnowledge?.essence ?? ""].joined(separator: " ")
        } ?? ""
        store?.record(tagName: tag.name, contextSnippet: snippet, wrongCategory: old, correctCategory: newCategory)
        tag.categoryRaw = newCategory
        tag.categoryConfidence = ClassificationConfidence.high.rawValue
        try? context.save()
        ConceptSynthesisCommon.healConcepts(forTag: tag, context: context, refreshTrigger: refresh)
    }
}
