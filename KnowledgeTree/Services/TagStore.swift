//
//  TagStore.swift
//  KnowledgeTree
//
//  spec 008 — Article への Tag 追加・削除、孤児 Tag の自動削除を担う。
//  TagNormalizer.normalize 経由で正規化済 name を保持。
//  RefreshTrigger.bump で UI 更新を伝播 (spec 005 既存メカニズム)。
//

import Foundation
import SwiftData

@MainActor
final class TagStore {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?
    /// spec 015: 新規 Tag 作成時の Category 自動分類用 (optional、nil なら classify せず)
    private let categoryClassifier: AutoCategoryClassifier?

    init(
        context: ModelContext,
        refreshTrigger: RefreshTrigger? = nil,
        categoryClassifier: AutoCategoryClassifier? = nil
    ) {
        self.context = context
        self.refreshTrigger = refreshTrigger
        self.categoryClassifier = categoryClassifier
    }

    /// raw タグ名を正規化して article に追加。
    /// 既存 Tag があれば再利用、無ければ新規 insert。同 article への重複は no-op。
    /// 新規 Tag 作成時、categoryClassifier が設定されていれば fire-and-forget で
    /// Category を分類して `tag.categoryRaw` に保存する (spec 015)。
    /// - Returns: 正規化後の name (成功 / 既存)、空文字列等で正規化失敗なら nil
    @discardableResult
    func addTag(rawName: String, to article: Article) throws -> String? {
        guard let normalized = TagNormalizer.normalize(rawName) else {
            return nil
        }

        // 既存 Tag を fetch (unique 制約あり)
        var descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate<Tag> { $0.name == normalized }
        )
        descriptor.fetchLimit = 1
        let existing = try context.fetch(descriptor).first

        let tag: Tag
        let isNewTag: Bool
        if let existing {
            tag = existing
            isNewTag = false
        } else {
            tag = Tag(name: normalized)
            context.insert(tag)
            isNewTag = true
        }

        // 重複チェック
        if !article.tags.contains(where: { $0.name == normalized }) {
            article.tags.append(tag)
        }

        try context.save()
        refreshTrigger?.bump()

        // spec 015: 新規 Tag のみ Category 分類 (fire-and-forget)。
        // Tag 作成自体は同期完了済、categorize は非同期で後追い。
        // 失敗しても Tag は残る (graceful)。
        if isNewTag, let classifier = categoryClassifier {
            Task { [weak self] in
                let categoryName = await classifier.classify(tagName: normalized)
                await MainActor.run {
                    guard let self else { return }
                    tag.categoryRaw = categoryName
                    try? self.context.save()
                    self.refreshTrigger?.bump()
                }
            }
        }

        return normalized
    }

    /// 正規化済 name で article から Tag を除去。tag.articles が空になったら自動削除。
    func removeTag(normalizedName: String, from article: Article) throws {
        guard let tag = article.tags.first(where: { $0.name == normalizedName }) else {
            return
        }
        article.tags.removeAll { $0.name == normalizedName }
        if tag.articles.isEmpty {
            context.delete(tag)
        }
        try context.save()
        refreshTrigger?.bump()
    }

    /// 全 Tag を name 昇順で取得 (タグ一覧画面用)。
    func fetchAllTags() throws -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    /// 全 Tag をスキャンして articles 空のものを削除。bootstrap 等で定期実行。
    func cleanupOrphans() throws {
        let allTags = try fetchAllTags()
        let orphans = allTags.filter { $0.articles.isEmpty }
        guard !orphans.isEmpty else { return }
        for tag in orphans {
            context.delete(tag)
        }
        try context.save()
        refreshTrigger?.bump()
    }
}
