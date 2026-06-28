//
//  SaveURLToKnowledgeTreeIntent.swift
//  KnowledgeTree
//
//  spec 019 — iOS 16+ App Intent。「URL を iKnow に保存」アクションを Shortcuts.app +
//  Spotlight + Siri から呼び出し可能にする。
//
//  - openAppWhenRun: false でバックグラウンド完了 (アプリを起動しない)
//  - perform() 完了後 silent return (.result()、dialog なし)
//  - URL + 任意 title を受信 → ArticleSavingActor 経由で SwiftData 保存
//  - 重複 / 無効 URL は silent skip
//
//  AppShortcutsProvider はインストール時に Shortcuts.app に自動登録。
//

import AppIntents
import Foundation

struct SaveURLToKnowledgeBaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Knowledge Base に保存"

    static var description: IntentDescription = IntentDescription(
        "URL を Knowledge Base に保存します",
        categoryName: "コンテンツ"
    )

    static var openAppWhenRun: Bool = false

    @Parameter(title: "URL")
    var url: URL

    @Parameter(title: "タイトル", default: nil)
    var title: String?

    func perform() async throws -> some IntentResult {
        try await ArticleSavingActor.shared.save(
            url: url.absoluteString,
            title: title ?? ""
        )
        return .result()
    }
}

/// AppShortcutsProvider — iOS 16+ で Shortcuts.app + Spotlight + Siri に自動登録。
/// ユーザーがアクションを手動追加する操作不要。
struct KnowledgeTreeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveURLToKnowledgeBaseIntent(),
            phrases: [
                // App Intents 仕様: 各 phrase に \(.applicationName) を含める必要あり
                "\(.applicationName) に保存",
                "URL を \(.applicationName) に保存",
                "Save to \(.applicationName)",
            ],
            shortTitle: "保存",
            systemImageName: "square.and.arrow.down"
        )
    }
}
