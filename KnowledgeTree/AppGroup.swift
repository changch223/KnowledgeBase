//
//  AppGroup.swift
//  KnowledgeTree
//
//  Apple Developer Team / Bundle ID 確定後にここを更新する。
//  KnowledgeTree.entitlements / KnowledgeTreeShareExtension.entitlements の
//  application-groups と必ず一致させること。
//

import Foundation

enum AppGroup {
    static let identifier = "group.com.changchiawei.KnowledgeTree.shared"

    /// App Group container 内の `Library/Application Support` を事前作成する。
    /// SwiftData の SQLite 永続化先がこのパスで、初回起動時に存在しないと
    /// CoreData が自動 recovery を試みてログに大量の "Sandbox access denied" を吐く。
    /// アプリ側で先に作っておけばログがうるさくならず、recovery にかかる時間も省ける。
    static func ensureContainerDirectoryExists() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else { return }
        let appSupport = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )
    }
}
