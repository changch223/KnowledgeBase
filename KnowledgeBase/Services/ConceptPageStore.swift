//
//  ConceptPageStore.swift
//  KnowledgeTree
//
//  spec 042 — ConceptPage の rename / merge / delete / setFollowing。
//  TagStore (spec 024) + GraphNodeStore (spec 041) と同パターン。
//  RefreshTrigger.bump で UI 更新を伝播。
//
//  - rename: 空 / 30 字超 / 同 category 内重複を reject、isStale=true で再合成 trigger
//  - merge: source.relatedArticles を target に union、aliases / understanding / following を吸収、
//           source 削除、target.isStale=true
//  - delete: 他 ConceptPage.relatedConceptIDs から id 除去、Article は @Relationship.nullify で残る
//  - setFollowing: isFollowing toggle (DB 反映 + UI refresh)
//
//  contracts/concept-page-store.md 準拠。
//

import Foundation
import SwiftData

@MainActor
final class ConceptPageStore {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) {
        self.context = context
        self.refreshTrigger = refreshTrigger
    }

    // MARK: - rename

    /// ConceptPage.name を変更。
    /// trim 後 1〜30 字、同 categoryRaw 内で大文字小文字無視 unique。
    /// rename 後は isStale = true (名前変更で要点が変わる可能性 → 再合成 trigger)。
    @discardableResult
    func rename(_ conceptPage: ConceptPage, to newName: String) throws -> ConceptPage {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ConceptPageStoreError.emptyName
        }
        guard trimmed.count <= 30 else {
            throw ConceptPageStoreError.nameTooLong
        }

        // 同名なら no-op
        if trimmed == conceptPage.name {
            return conceptPage
        }

        // 同 category 内重複チェック (大文字小文字無視、自身は除外)
        let trimmedLower = trimmed.lowercased()
        let categoryRaw = conceptPage.categoryRaw
        let conceptPageID = conceptPage.id
        let descriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate<ConceptPage> { other in
                other.id != conceptPageID && other.categoryRaw == categoryRaw
            }
        )
        let others = (try? context.fetch(descriptor)) ?? []
        let conflict = others.first { other in
            other.name.lowercased() == trimmedLower ||
                other.nameAliases.contains(where: { $0.lowercased() == trimmedLower })
        }
        if conflict != nil {
            throw ConceptPageStoreError.duplicateInCategory
        }

        conceptPage.name = trimmed
        conceptPage.isStale = true
        conceptPage.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
        return conceptPage
    }

    // MARK: - merge

    /// source ConceptPage を target に統合し、source を削除。
    /// - relatedArticles: union (ID 重複除外)
    /// - relatedConceptIDs: union、self-ref 除外
    /// - nameAliases: union + source.name 追加
    /// - userUnderstanding: max
    /// - isFollowing: OR
    /// - target.isStale = true で再合成 trigger
    func merge(source: ConceptPage, into target: ConceptPage) throws {
        guard source.id != target.id else {
            throw ConceptPageStoreError.sameSourceTarget
        }

        // relatedArticles を union (重複 skip)
        for article in (source.relatedArticles ?? []) where !(target.relatedArticles?.contains(where: { $0.id == article.id }) ?? false) {
            if target.relatedArticles == nil { target.relatedArticles = [] }
            target.relatedArticles?.append(article)
        }

        // relatedConceptIDs を union (target 自身 + source 自身を除外)
        let merged = Set(target.relatedConceptIDs + source.relatedConceptIDs)
            .subtracting([target.id, source.id])
        target.relatedConceptIDs = Array(merged)

        // nameAliases に source.name と source.aliases を吸収 (target 自身の name は除外)
        var aliases = Set(target.nameAliases + [source.name] + source.nameAliases)
        aliases.remove(target.name)
        target.nameAliases = Array(aliases).sorted()

        // userUnderstanding: max、isFollowing: OR
        target.userUnderstanding = max(target.userUnderstanding, source.userUnderstanding)
        target.isFollowing = target.isFollowing || source.isFollowing

        // 他 ConceptPage の relatedConceptIDs から source.id を target.id に置換
        let allDescriptor = FetchDescriptor<ConceptPage>()
        let allPages = (try? context.fetch(allDescriptor)) ?? []
        for other in allPages where other.id != source.id && other.id != target.id {
            if other.relatedConceptIDs.contains(source.id) {
                var ids = other.relatedConceptIDs.filter { $0 != source.id }
                if !ids.contains(target.id) {
                    ids.append(target.id)
                }
                other.relatedConceptIDs = ids
            }
        }

        // spec 043: SavedAnswer.relatedConceptIDs の source.id → target.id 置換 (data integrity)
        let savedAnswerDescriptor = FetchDescriptor<SavedAnswer>()
        let allAnswers = (try? context.fetch(savedAnswerDescriptor)) ?? []
        for answer in allAnswers where answer.relatedConceptIDs.contains(source.id) {
            var ids = answer.relatedConceptIDs.filter { $0 != source.id }
            if !ids.contains(target.id) {
                ids.append(target.id)
            }
            answer.relatedConceptIDs = Array(ids.prefix(DefaultSavedAnswerService.maxRelatedConcepts))
            answer.updatedAt = .now
        }

        target.isStale = true
        target.updatedAt = .now
        context.delete(source)
        try context.save()
        refreshTrigger?.bump()
    }

    // MARK: - delete

    /// ConceptPage を削除。他 ConceptPage.relatedConceptIDs から id を掃除。
    /// Article は @Relationship deleteRule: .nullify で自動的に nullify、Article 自体は残る。
    func delete(_ conceptPage: ConceptPage) throws {
        let deletedID = conceptPage.id

        // 他 ConceptPage の relatedConceptIDs から削除
        let allDescriptor = FetchDescriptor<ConceptPage>()
        let allPages = (try? context.fetch(allDescriptor)) ?? []
        for other in allPages where other.id != deletedID {
            other.relatedConceptIDs.removeAll { $0 == deletedID }
        }

        context.delete(conceptPage)
        try context.save()
        refreshTrigger?.bump()
    }

    // MARK: - setFollowing

    /// pin (フォロー) 状態を変更。
    func setFollowing(_ conceptPage: ConceptPage, isFollowing: Bool) throws {
        guard conceptPage.isFollowing != isFollowing else { return }
        conceptPage.isFollowing = isFollowing
        conceptPage.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
    }
}

// MARK: - Errors

enum ConceptPageStoreError: LocalizedError {
    case emptyName
    case nameTooLong
    case duplicateInCategory
    case sameSourceTarget

    var errorDescription: String? {
        switch self {
        case .emptyName: String(localized: "ConceptPageStore.error.emptyName")
        case .nameTooLong: String(localized: "ConceptPageStore.error.nameTooLong")
        case .duplicateInCategory: String(localized: "ConceptPageStore.error.duplicateInCategory")
        case .sameSourceTarget: String(localized: "ConceptPageStore.error.sameSourceTarget")
        }
    }
}
