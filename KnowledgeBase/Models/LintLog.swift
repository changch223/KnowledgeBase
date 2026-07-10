//
//  LintLog.swift
//  KnowledgeTree
//
//  spec 058 — LintEngine が実行した整理操作の履歴。Settings 内の「整理ログ」で表示。
//  FIFO で最古から削除、cap 100 件。
//

import Foundation
import SwiftData

@Model
final class LintLog {
    var id: UUID = UUID()
    /// 操作種別 ("merge" / "deleteConceptPage" / "deleteTag" / "linkConceptPage" / "reclassifyTag" / "refreshSavedAnswer")
    var actionRaw: String = ""
    /// 操作対象の name (ConceptPage 名 / Tag 名 / SavedAnswer.question prefix 等)
    var targetName: String = ""
    /// 変更前の状態 (max 200 chars)
    var beforeState: String?
    /// 変更後の状態 (max 200 chars)
    var afterState: String?
    /// 操作実行時刻
    var timestamp: Date = Date.now

    init(
        id: UUID = UUID(),
        action: LintAction,
        targetName: String,
        beforeState: String? = nil,
        afterState: String? = nil,
        timestamp: Date = .now
    ) {
        self.id = id
        self.actionRaw = action.rawValue
        self.targetName = String(targetName.prefix(100))
        self.beforeState = beforeState.map { String($0.prefix(200)) }
        self.afterState = afterState.map { String($0.prefix(200)) }
        self.timestamp = timestamp
    }

    var action: LintAction {
        LintAction(rawValue: actionRaw) ?? .unknown
    }
}

/// LintEngine の操作種別。
enum LintAction: String, CaseIterable {
    case merge
    case deleteConceptPage
    case deleteTag
    case linkConceptPage
    case reclassifyTag
    case refreshSavedAnswer
    case promoteCategory  // spec 077: その他 クラスタ → 新カテゴリ自動昇格
    case healCategoryLanguage  // i18n Phase B: 言語切替で残った foreign シード名の categoryRaw を現在言語へ張り替え
    case unknown
}
