//
//  ArticleSavingActor.swift
//  KnowledgeTree
//
//  spec 019 — App Intent から SwiftData への保存を仲介する actor。
//
//  - actor singleton (ArticleSavingActor.shared) で thread safety
//  - ModelContainer は lazy init + cache (App Group ModelContainer 共有)
//  - static performSave(url:title:in:) は純関数、test で in-memory ModelContext 検証可能
//  - 重複検出 (spec 001 ArticleSavingService 同パターン): URL 完全一致で silent skip
//  - 無効 URL (空 / 非 http/https): silent skip
//

import Foundation
import SwiftData

actor ArticleSavingActor {
    static let shared = ArticleSavingActor()

    private var sharedContainer: ModelContainer?

    private init() {}

    /// App Intent から呼ばれる主入口。
    /// 内部で App Group ModelContainer を lazy 取得 → static performSave に delegate。
    func save(url: String, title: String) async throws {
        let container = try getContainer()
        let context = ModelContext(container)
        _ = try Self.performSave(url: url, title: title, in: context)
    }

    private func getContainer() throws -> ModelContainer {
        if let existing = sharedContainer { return existing }
        AppGroup.ensureContainerDirectoryExists()
        let container = try ModelContainer(
            for: SharedSchema.all,
            configurations: [SharedSchema.sharedConfiguration()]
        )
        sharedContainer = container
        return container
    }

    /// testable 純関数: validation + 重複検出 + insert。
    /// 戻り値: true = insert 成功 / false = silent skip (invalid or duplicate)。
    @discardableResult
    static func performSave(
        url: String,
        title: String,
        in context: ModelContext
    ) throws -> Bool {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty,
              let parsed = URL(string: trimmedURL),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false  // silent skip on invalid
        }

        // 重複検出 (spec 001 同パターン)
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.url == trimmedURL }
        )
        if let _ = try? context.fetch(descriptor).first {
            return false  // silent skip on duplicate
        }

        // 新規 insert
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleToUse = trimmedTitle.isEmpty ? trimmedURL : trimmedTitle
        let article = Article(url: trimmedURL, title: titleToUse)
        context.insert(article)
        try context.save()
        return true
    }
}
