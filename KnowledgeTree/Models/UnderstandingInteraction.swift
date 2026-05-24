//
//  UnderstandingInteraction.swift
//  KnowledgeTree
//
//  spec 044 — iKnow V1 Phase A 核心ロジック完成 (家庭教師ループ + 学習タブ)。
//  Karpathy「You can outsource your thinking, but you cannot outsource your understanding」を実体化する。
//
//  - @Model `UnderstandingInteraction`: 学習行動の永続履歴 (5 フィールド、孤立 ID 参照、Relationship なし)
//  - transient struct `UnderstandingCard`: 学習タブで surface される統一カード (ConceptPage / SavedAnswer 両対応)
//  - enum `UnderstandingCardKind` / `UnderstandingCardLabel`
//  - Hashable struct `UnderstandingCardListDestination`: 「+N すべて見る」NavigationLink 用 destination
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - UnderstandingInteraction @Model

@Model
final class UnderstandingInteraction {
    @Attribute(.unique) var id: UUID

    /// 対象 entity 種別。`Kind.rawValue` のいずれか。
    var targetKind: String

    /// 対象 entity の id (ConceptPage.id / SavedAnswer.id / Article.id)。
    /// 弱結合 (Relationship なし)、参照先削除後の孤立残存は許容。
    var targetID: UUID

    /// ユーザー操作種別。`Action.rawValue` のいずれか。
    var action: String

    /// 行動発生時刻 (sort key + 集計の cutoff date 用)。
    var occurredAt: Date

    init(
        id: UUID = UUID(),
        targetKind: String,
        targetID: UUID,
        action: String,
        occurredAt: Date = .now
    ) {
        self.id = id
        self.targetKind = targetKind
        self.targetID = targetID
        self.action = action
        self.occurredAt = occurredAt
    }
}

// MARK: - Type-safe enum

extension UnderstandingInteraction {
    enum Kind: String, CaseIterable {
        case conceptPage
        case savedAnswer
        case article
    }

    enum Action: String, CaseIterable {
        case understood      // ✓ わかった
        case needMore        // 🤔 もっと
        case openedChat      // カードタップで deep dive chat 起動
        case dismissed       // ✗ 違う
        case propagated      // 1-hop graph 波及 (内部のみ、UI 露出なし)
    }

    var kindEnum: Kind? { Kind(rawValue: targetKind) }
    var actionEnum: Action? { Action(rawValue: action) }

    /// 便利 init: enum で渡せる。
    convenience init(
        kind: Kind,
        targetID: UUID,
        action: Action,
        occurredAt: Date = .now
    ) {
        self.init(
            targetKind: kind.rawValue,
            targetID: targetID,
            action: action.rawValue,
            occurredAt: occurredAt
        )
    }
}

// MARK: - UnderstandingCard (transient struct)

/// 学習タブで surface される統一カード。SwiftData @Model **ではない** (永続化不要、表示専用)。
/// `UnderstandingCardSurfaceService.surfaceTopCards()` が ConceptPage / SavedAnswer を都度 wrap して返却。
struct UnderstandingCard: Identifiable, Hashable {
    let id: UUID
    let kind: UnderstandingCardKind
    let priorityScore: Int          // 内部 surface 順位 (UI 非表示)
    let label: UnderstandingCardLabel
    let lastInteractedAt: Date?

    static func == (lhs: UnderstandingCard, rhs: UnderstandingCard) -> Bool {
        lhs.id == rhs.id && lhs.label == rhs.label && lhs.lastInteractedAt == rhs.lastInteractedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(label)
    }
}

enum UnderstandingCardKind: Hashable {
    case conceptPage(ConceptPage)
    case savedAnswer(SavedAnswer)

    var kindString: String {
        switch self {
        case .conceptPage: return UnderstandingInteraction.Kind.conceptPage.rawValue
        case .savedAnswer: return UnderstandingInteraction.Kind.savedAnswer.rawValue
        }
    }
}

enum UnderstandingCardLabel: String, Hashable, CaseIterable {
    case newKnowledge   // 「新しい知識」
    case needsUpdate    // 「更新が必要」
    case shallow        // 「理解が浅い」
    case deepDive       // 「深掘り余地あり」
    case review         // 「復習」

    var localizationKey: LocalizedStringKey {
        switch self {
        case .newKnowledge: return "新しい知識"
        case .needsUpdate:  return "更新が必要"
        case .shallow:      return "理解が浅い"
        case .deepDive:     return "深掘り余地あり"
        case .review:       return "復習"
        }
    }

    /// VoiceOver 用日本語文字列 (`accessibilityLabel` に直接渡せる)。
    var voiceOverText: String {
        switch self {
        case .newKnowledge: return "新しい知識"
        case .needsUpdate:  return "更新が必要"
        case .shallow:      return "理解が浅い"
        case .deepDive:     return "深掘り余地あり"
        case .review:       return "復習"
        }
    }
}

// MARK: - UnderstandingCard convenience

extension UnderstandingCard {
    /// ConceptPage を card に wrap (ConceptPageDetailView「学習する」Button 等で使う)。
    static func fromConceptPage(
        _ page: ConceptPage,
        label: UnderstandingCardLabel = .deepDive,
        priorityScore: Int = 0,
        lastInteractedAt: Date? = nil
    ) -> UnderstandingCard {
        UnderstandingCard(
            id: page.id,
            kind: .conceptPage(page),
            priorityScore: priorityScore,
            label: label,
            lastInteractedAt: lastInteractedAt
        )
    }

    /// SavedAnswer を card に wrap。
    static func fromSavedAnswer(
        _ answer: SavedAnswer,
        label: UnderstandingCardLabel = .needsUpdate,
        priorityScore: Int = 0,
        lastInteractedAt: Date? = nil
    ) -> UnderstandingCard {
        UnderstandingCard(
            id: answer.id,
            kind: .savedAnswer(answer),
            priorityScore: priorityScore,
            label: label,
            lastInteractedAt: lastInteractedAt
        )
    }

    /// 表示用主タイトル (UnderstandingCardRow + DeepDiveChatView navigationTitle 用)。
    var titleText: String {
        switch kind {
        case .conceptPage(let page):
            return page.name
        case .savedAnswer(let answer):
            let trimmed = answer.question.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count > 80 ? String(trimmed.prefix(80)) + "…" : trimmed
        }
    }

    /// DeepDiveChatView の navigationTitle 用 (「{name} を深掘り」)。
    /// `%@ を深掘り` xcstrings key と組み合わせて使う。
    var deepDiveTitleFormatArg: String {
        switch kind {
        case .conceptPage(let page):
            return page.name
        case .savedAnswer(let answer):
            let trimmed = answer.question.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
        }
    }

    /// ChatSession title 用 (xcstrings 経由しない、AI prompt context 注入時にも使う)。
    var deepDiveTitle: String {
        "「\(deepDiveTitleFormatArg)」を深掘り"
    }

    /// `kindEnum` rawValue 文字列 (a11y identifier / xcstrings 補助)。
    var kindString: String { kind.kindString }
}

// MARK: - UnderstandingCardListDestination (Hashable)

/// 「+N すべて見る」NavigationLink 用 transient destination。
struct UnderstandingCardListDestination: Hashable {
    enum Scope: Hashable { case all }
    let scope: Scope

    init(scope: Scope = .all) {
        self.scope = scope
    }
}
