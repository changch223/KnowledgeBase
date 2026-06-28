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

    /// spec 092 Part 2: 共有された音声ファイルを一時保管する App Group 内ディレクトリ。
    /// Share 拡張が書き込み、アプリ起動時の文字起こし runner が読み出して削除する。
    static func pendingAudioDirectory() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else { return nil }
        let dir = containerURL.appendingPathComponent("PendingAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
