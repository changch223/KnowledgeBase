//
//  CategoryStore.swift
//  KnowledgeTree
//
//  spec 075 — 動的カテゴリ (CategoryDefinition) の編集 store。TagStore をミラー。
//
//  ★中心リスク: Tag.categoryRaw / ConceptPage.categoryRaw は「名前文字列」で分野に紐づく。
//  ゆえに分野を rename / merge するときは、両モデルの categoryRaw を必ず cascade 更新する。
//  これを怠ると分野カードや AI 分類候補と実体がズレる。
//
//  CloudKit 安全: 物理削除はせず isHidden で隠す (可逆 + record 破壊なし + classifier 候補から自動的に外れる)。
//  CategoryRegistry は read-only facade のまま、mutation はこの store に集約する。
//

import Foundation
import SwiftData

@MainActor
final class CategoryStore {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) {
        self.context = context
        self.refreshTrigger = refreshTrigger
    }

    /// 全カテゴリを order 昇順で取得 (管理画面用)。
    func fetchAll() throws -> [CategoryDefinition] {
        let descriptor = FetchDescriptor<CategoryDefinition>(
            sortBy: [SortDescriptor(\.order, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    /// 分野名を変更。属する Tag.categoryRaw / ConceptPage.categoryRaw を cascade 更新。
    /// 別の非表示でないカテゴリと同名になる場合は duplicateName を throw (統合は merge を使う)。
    func rename(_ category: CategoryDefinition, to newRawName: String) throws {
        let trimmed = newRawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CategoryStoreError.invalidName }
        if trimmed == category.name { return }

        let all = (try? context.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
        let duplicate = all.contains {
            $0.id != category.id && !$0.isHidden && $0.name.lowercased() == trimmed.lowercased()
        }
        if duplicate { throw CategoryStoreError.duplicateName }

        reassignCategoryRaw(from: category.name, to: trimmed)
        category.name = trimmed
        category.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
    }

    /// source 分野を target 分野に統合。属する Tag / ConceptPage の categoryRaw を target 名に移し、
    /// source は非表示にする (削除しない = CloudKit 安全 + 可逆)。
    func merge(source: CategoryDefinition, into target: CategoryDefinition) throws {
        guard source.id != target.id else { return }
        reassignCategoryRaw(from: source.name, to: target.name)
        source.isHidden = true
        source.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
    }

    /// 分野を非表示にする (削除でなく隠す)。一覧 / 分類候補から外れる。
    func hide(_ category: CategoryDefinition) throws {
        category.isHidden = true
        category.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
    }

    /// 非表示を解除する。
    func unhide(_ category: CategoryDefinition) throws {
        category.isHidden = false
        category.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
    }

    /// AI 分類用の定義 (定義 + 例 + 反例) を更新する。
    func updateDefinition(_ category: CategoryDefinition, to definition: String) throws {
        category.definition = definition
        category.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
    }

    /// oldName の categoryRaw を持つ Tag / ConceptPage をすべて newName に振り替える (in-memory)。
    /// Tag.categoryRaw は Optional、ConceptPage.categoryRaw は非 Optional なので in-memory filter で統一。
    private func reassignCategoryRaw(from oldName: String, to newName: String) {
        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        for tag in tags where tag.categoryRaw == oldName {
            tag.categoryRaw = newName
        }
        let pages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        for page in pages where page.categoryRaw == oldName {
            page.categoryRaw = newName
        }
    }
}

enum CategoryStoreError: Error {
    case invalidName
    case duplicateName
}
