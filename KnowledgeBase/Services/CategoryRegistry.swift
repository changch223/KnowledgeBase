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
        // spec 088: CloudKit 同期競合等で生じた同名重複を先に除去 (分野が複数表示される不具合)。
        deduplicate()
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

    /// spec 088: 同名 (大文字小文字無視) の重複 CategoryDefinition を 1 件に統合。
    /// CloudKit 同期競合や複数回 seed で生じた重複を除去する。残す 1 件は isSeed 優先→order 昇順。
    /// いずれかが非表示なら統合先も非表示を維持 (ユーザーの hide 意図を尊重)。
    /// categoryRaw は name 文字列参照ゆえ、重複行削除は Tag/ConceptPage の参照を壊さない (CloudKit 安全)。
    func deduplicate() {
        let all = (try? context.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
        guard all.count > 1 else { return }

        var keeperByName: [String: CategoryDefinition] = [:]
        var anyHiddenByName: [String: Bool] = [:]
        var toDelete: [CategoryDefinition] = []

        for def in all {
            let key = def.name.lowercased()
            anyHiddenByName[key] = (anyHiddenByName[key] ?? false) || def.isHidden
            guard let current = keeperByName[key] else {
                keeperByName[key] = def
                continue
            }
            // より良い keeper を選ぶ: isSeed 優先 → order 昇順
            let preferNew: Bool
            if def.isSeed != current.isSeed {
                preferNew = def.isSeed
            } else {
                preferNew = def.order < current.order
            }
            if preferNew {
                toDelete.append(current)
                keeperByName[key] = def
            } else {
                toDelete.append(def)
            }
        }

        guard !toDelete.isEmpty else { return }
        for (key, keeper) in keeperByName where anyHiddenByName[key] == true {
            keeper.isHidden = true
        }
        for dup in toDelete { context.delete(dup) }
        try? context.save()
        logger.notice("category registry deduplicated, removed \(toDelete.count, privacy: .public) duplicate(s)")
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
