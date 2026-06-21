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
    /// spec 077: タグ分類完了時に呼ぶ closure (概念の [その他] 再ヒール用、疎結合 DI)。
    private let onTagClassified: ((Tag) -> Void)?

    init(
        context: ModelContext,
        refreshTrigger: RefreshTrigger? = nil,
        categoryClassifier: AutoCategoryClassifier? = nil,
        onTagClassified: ((Tag) -> Void)? = nil
    ) {
        self.context = context
        self.refreshTrigger = refreshTrigger
        self.categoryClassifier = categoryClassifier
        self.onTagClassified = onTagClassified
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
        if !(article.tags?.contains(where: { $0.name == normalized }) ?? false) {
            if article.tags == nil { article.tags = [] }
            article.tags?.append(tag)
        }

        try context.save()
        refreshTrigger?.bump()

        // spec 015: 新規 Tag のみ Category 分類 (fire-and-forget)。
        // Tag 作成自体は同期完了済、categorize は非同期で後追い。
        // 失敗しても Tag は残る (graceful)。
        if isNewTag, let classifier = categoryClassifier {
            // spec 072: 記事のタイトル + essence を文脈として渡し、1 語分類の誤りを減らす。
            let contextText = [article.title, article.extractedKnowledge?.essence]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " / ")
            Task { [weak self] in
                let result = await classifier.classifyDetailed(tagName: normalized, context: contextText)
                await MainActor.run {
                    guard let self else { return }
                    tag.categoryRaw = result.category
                    tag.categoryConfidence = result.confidence.rawValue
                    try? self.context.save()
                    self.refreshTrigger?.bump()
                    // spec 077: 分類完了 → この tag に紐づく [その他] 概念を再ヒール (タイミング競合の解消)
                    self.onTagClassified?(tag)
                }
            }
        }

        return normalized
    }

    /// 正規化済 name で article から Tag を除去。tag.articles が空になったら自動削除。
    func removeTag(normalizedName: String, from article: Article) throws {
        guard let tag = (article.tags ?? []).first(where: { $0.name == normalizedName }) else {
            return
        }
        article.tags?.removeAll { $0.name == normalizedName }
        if (tag.articles ?? []).isEmpty {
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
        let orphans = allTags.filter { ($0.articles ?? []).isEmpty }
        guard !orphans.isEmpty else { return }
        for tag in orphans {
            context.delete(tag)
        }
        try context.save()
        refreshTrigger?.bump()
    }

    // MARK: - spec 024: Tag rename / merge / delete

    /// Tag 名を変更。新名と同じ name の既存 Tag があれば自動 merge。
    /// 失敗時は throws、成功時は最終的に articles を保持する Tag を返す。
    @discardableResult
    func rename(_ tag: Tag, to newRawName: String) throws -> Tag {
        guard let normalized = TagNormalizer.normalize(newRawName) else {
            throw TagStoreError.invalidName
        }

        // 同名なら no-op
        if normalized == tag.name {
            return tag
        }

        // 同名既存 Tag があるか
        var descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate<Tag> { $0.name == normalized }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first, existing.id != tag.id {
            // merge 経路: tag を existing に統合
            try merge(source: tag, into: existing)
            return existing
        }

        // 単純 rename
        tag.name = normalized
        try context.save()
        refreshTrigger?.bump()
        return tag
    }

    /// source Tag を target Tag に統合。source.articles を target に append、source 削除。
    func merge(source: Tag, into target: Tag) throws {
        guard source.id != target.id else { return }

        // source の articles を target に移動 (重複は skip)
        let sourceArticles = source.articles ?? []
        for article in sourceArticles {
            // article.tags から source を除去
            article.tags?.removeAll { $0.id == source.id }
            // 既に target が article に紐付いていれば skip
            if !(article.tags?.contains(where: { $0.id == target.id }) ?? false) {
                if article.tags == nil { article.tags = [] }
                article.tags?.append(target)
            }
        }

        // source Tag 削除
        context.delete(source)
        try context.save()
        refreshTrigger?.bump()
    }

    /// Tag を削除。全 articles の relationship を解除してから Tag 削除。
    func delete(_ tag: Tag) throws {
        // 全 articles から Tag relationship を解除
        let articles = tag.articles ?? []
        for article in articles {
            article.tags?.removeAll { $0.id == tag.id }
        }
        context.delete(tag)
        try context.save()
        refreshTrigger?.bump()
    }
}

enum TagStoreError: Error {
    case invalidName
}
