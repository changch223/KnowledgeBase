//
//  CategoryCorrectionStore.swift
//  KnowledgeTree
//
//  spec 097 Phase 2 — カテゴリ分類の「ユーザー修正の正解例」を貯め、分類プロンプトに
//  few-shot として供給する学習ストア。
//
//  ※ アプリ専用の別 ModelContainer (SharedSchema に入れない = 拡張ターゲット pbxproj 編集不要)。
//  CloudKit は使わない (local-only)。
//
//  クラッシュ防止: SwiftData の context.fetchCount は store が削除されると try? で
//  捕捉できない EXC_BREAKPOINT (precondition failure) を起こす。
//  NSPersistentStoreCoordinator の storesDidChange 通知でストア削除を検知し、
//  isValid=false 後は context に一切触れない。
//

import Foundation
import SwiftData
import CoreData
import os

@MainActor
final class CategoryCorrectionStore {
    private static let logger = Logger(subsystem: "app.KnowledgeTree", category: "category-learning")
    private let context: ModelContext
    /// ストアが削除された後は false になり、以降の fetch/save を全てスキップする。
    private(set) var isValid: Bool = true
    private var storeObserver: NSObjectProtocol?

    init(context: ModelContext, container: ModelContainer) {
        self.context = context
        // ストア削除を監視して isValid を下げる。
        // object: nil だと main SharedSchema の Coordinator のイベントも拾い、
        // iCloud 同期時のストア置換で isValid=false になる誤動作が起きる。
        // 自分の container のストア URL だけを対象にする。
        let storeURL = container.configurations.first?.url
        storeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSPersistentStoreCoordinatorStoresDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            if let removed = note.userInfo?[NSRemovedPersistentStoresKey] as? [NSPersistentStore],
               !removed.isEmpty,
               let ourURL = storeURL,
               removed.contains(where: { $0.url == ourURL }) {
                Self.logger.warning("category learning store: our store removed — invalidating context")
                self.isValid = false
            }
        }
    }

    deinit {
        if let obs = storeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Container factory

    static func makeContainer(cloudKitEnabled: Bool) -> ModelContainer? {
        let schema = Schema([CategoryCorrectionExample.self])
        // cloudKitDatabase: .none — アプリ entitlements があっても CloudKit を無効化。
        // .automatic だとメイン store と同一 iCloud コンテナを二重ミラーリングして競合し
        // "Store Removed" → fetchCount で EXC_BREAKPOINT になる。
        let config = ModelConfiguration(
            "CategoryLearningLocal",
            schema: schema,
            cloudKitDatabase: .none
        )
        if let container = try? ModelContainer(for: schema, configurations: config) {
            logger.notice("category learning container: ready (local-only, cloudKit=none)")
            return container
        }
        logger.error("category learning container: failed to create")
        return nil
    }

    // MARK: - Public API

    /// ユーザー修正を 1 件記録する。
    func record(tagName: String, contextSnippet: String = "", wrongCategory: String? = nil, correctCategory: String) {
        guard isValid else { return }
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

    /// 分類対象 tagName の few-shot 例を返す。
    func fewShot(for tagName: String, limit: Int = 8) -> [CategoryFewShot] {
        guard isValid else { return [] }
        let descriptor = FetchDescriptor<CategoryCorrectionExample>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        guard !all.isEmpty else { return [] }
        let lower = tagName.lowercased()
        let matches = all.filter { $0.tagName.lowercased() == lower }
        let rest    = all.filter { $0.tagName.lowercased() != lower }
        return (matches + rest).prefix(limit).map {
            CategoryFewShot(tagName: $0.tagName, correctCategory: $0.correctCategory, wrongCategory: $0.wrongCategory)
        }
    }

    var count: Int {
        guard isValid else { return 0 }
        return (try? context.fetchCount(FetchDescriptor<CategoryCorrectionExample>())) ?? 0
    }
}

// MARK: - CategoryCorrectionApplier

/// spec 097 Phase 2b/4: タグの分野手修正を一貫して適用する共通処理。
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
