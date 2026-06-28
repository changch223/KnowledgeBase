//
//  AppErrorReporter.swift
//  KnowledgeTree
//
//  spec 061 (P1-3) — ユーザー能動操作のサイレント失敗 (try?) を可視化する軽量 reporter。
//  従来 `try?` で握り潰していた削除・タグ編集・ピン・フォロー等の失敗を os.Logger に記録し、
//  「成功表示のまま DB と乖離する」問題を解消する。外部送信はせず端末内ログのみ (Privacy first)。
//
//  裏側の自動処理 (backfill / regenerateAllStale 等) の try? は calm UX 原則で対象外。
//

import Foundation
import os

@MainActor
protocol AppErrorReporting: AnyObject {
    /// ユーザー操作の失敗を記録する。
    /// - Parameters:
    ///   - error: 捕捉した error
    ///   - operation: 失敗した操作の識別子 (例: "deleteChatSession")
    func report(_ error: Error, operation: String)
}

@MainActor
final class AppErrorReporter: AppErrorReporting {
    static let shared = AppErrorReporter()

    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "user-action-error")

    private init() {}

    func report(_ error: Error, operation: String) {
        logger.error("user action failed [\(operation, privacy: .public)]: \(String(describing: error), privacy: .public)")
    }
}
