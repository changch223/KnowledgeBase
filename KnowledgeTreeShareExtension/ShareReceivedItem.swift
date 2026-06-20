//
//  ShareReceivedItem.swift
//  KnowledgeTreeShareExtension
//
//  spec 001 / contracts/share-received-item.md
//  spec 091 — URL だけでなく共有テキストも受け取れるよう text を追加。
//

import Foundation

struct ShareReceivedItem: Equatable, Sendable {
    let url: URL?
    let suppliedTitle: String?
    /// URL が無い共有 (メモ / メール本文 / 選択テキスト / PDF / ファイル) の本文。
    var text: String? = nil
    /// text 取り込み時の source 種別 (合成 URL の名前空間)。
    var intakeSource: RawArticleIntake.Source = .sharedText
}
