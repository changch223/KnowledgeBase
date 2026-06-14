//
//  CategoryRegistry.swift
//  KnowledgeTree
//
//  spec 074 — 動的カテゴリのレジストリ。CategoryDefinition (@Model) の seed + 読み出しを担う。
//
//  - 起動時に CategorySeed の 10 個を idempotent に seed (name で重複判定)。
//  - AutoCategoryClassifier に候補 (定義付き) + 有効名集合を供給。
//  - agent loop (spec 076) はここに新カテゴリを insert する。
//
//  production 安全: レジストリが空 / fetch 失敗時は CategorySeed (code) に fallback。
//

import Foundation
import SwiftData
import os

@MainActor
final class CategoryRegistry {
    private let context: ModelContext
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "category-registry")

    init(context: ModelContext) {
        self.context = context
    }

    /// 起動時に CategorySeed の 10 個を CategoryDefinition として idempotent に seed。
    /// 既に同名 (大文字小文字無視) があれば skip。新規インストール / 既存ユーザー両対応。
    func seedIfNeeded() {
        let existing = (try? context.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
        let existingNames = Set(existing.map { $0.name.lowercased() })

        var inserted = 0
        for seed in CategorySeed.allSeeds {
            guard !existingNames.contains(seed.name.lowercased()) else { continue }
            let def = CategoryDefinition(
                name: seed.name,
                definition: CategorySeed.seedDefinition(for: seed.name) ?? "",
                isSeed: true,
                isHidden: false,
                order: seed.order
            )
            context.insert(def)
            inserted += 1
        }
        if inserted > 0 {
            try? context.save()
            logger.notice("category registry seeded \(inserted, privacy: .public) categories")
        }
    }

    /// 非表示でない全カテゴリ (order 昇順)。空ならレジストリ未 seed とみなし nil。
    func activeCategories() -> [CategoryDefinition]? {
        let all = (try? context.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
        let active = all.filter { !$0.isHidden }
        guard !active.isEmpty else { return nil }
        return active.sorted { $0.order < $1.order }
    }

    /// 分類 prompt 用の「- 名前: 定義」候補リスト。レジストリが空なら CategorySeed に fallback。
    func promptCandidatesWithDefinitions() -> String {
        guard let active = activeCategories() else {
            return CategorySeed.promptCandidatesWithDefinitions
        }
        return active.map { cat in
            let def = cat.definition.isEmpty ? "(定義なし)" : cat.definition
            return "- \(cat.name): \(def)"
        }.joined(separator: "\n")
    }

    /// 分類出力の検証用、有効カテゴリ名集合。レジストリが空なら CategorySeed に fallback。
    func validNames() -> Set<String> {
        guard let active = activeCategories() else {
            return Set(CategorySeed.allSeeds.map { $0.name })
        }
        return Set(active.map { $0.name })
    }

    /// 指定 name のカテゴリが既に存在するか (大文字小文字無視)。agent loop の重複防止用。
    func categoryExists(name: String) -> Bool {
        validNames().contains { $0.lowercased() == name.lowercased() }
    }

    /// spec 077: agent loop (lint) がクラスタ検知した新カテゴリを動的追加する (auto-adopt)。
    /// 既存 (非表示・seed 含む全件) と同名 (大文字小文字無視) なら追加せず false。idempotent。
    /// order は末尾、isSeed=false。CloudKit: record type 追加済ゆえ insert は非破壊。
    @discardableResult
    func insertCategory(name: String, definition: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let all = (try? context.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
        if all.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) { return false }
        let maxOrder = all.map(\.order).max() ?? (CategorySeed.allSeeds.count - 1)
        let def = CategoryDefinition(
            name: trimmed,
            definition: definition,
            isSeed: false,
            isHidden: false,
            order: maxOrder + 1
        )
        context.insert(def)
        try? context.save()
        logger.notice("category registry inserted dynamic category '\(trimmed, privacy: .public)'")
        return true
    }
}
