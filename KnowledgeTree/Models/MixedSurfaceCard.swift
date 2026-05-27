//
//  MixedSurfaceCard.swift
//  KnowledgeTree
//
//  spec 056 — 知識 Clip タブ「続きが気になるもの」セクションで
//  ConceptPage 深掘りカード (UnderstandingCard) と Topic Dashboard カード (KnowledgeDigest)
//  を 1 list 内で混在表示するための transient enum。
//
//  SwiftData @Model **ではない** (永続化不要、表示専用)。
//

import Foundation
import SwiftUI

enum MixedSurfaceCard: Identifiable, Hashable {
    case understanding(UnderstandingCard)
    case digest(KnowledgeDigest)

    var id: UUID {
        switch self {
        case .understanding(let card): return card.id
        case .digest(let digest): return digest.id
        }
    }

    /// 共通優先順位スケール 0-100。混在ソートに使う。
    /// - UnderstandingCard: 既存 priorityScore (0-100、5-tier scoring) をそのまま
    /// - KnowledgeDigest: createdAt desc で 60 (新) → 30 (古)、上限 60 で UnderstandingCard 上位を優先
    var priorityScore: Int {
        switch self {
        case .understanding(let card):
            return card.priorityScore
        case .digest(let digest):
            let days = Calendar.current.dateComponents([.day], from: digest.generatedAt, to: .now).day ?? 999
            return max(30, 60 - days * 2)
        }
    }

    /// 表示用主タイトル。
    var displayTitle: String {
        switch self {
        case .understanding(let card):
            return card.titleText
        case .digest(let digest):
            return digest.categoryRaw
        }
    }

    /// 表示用 subtitle / プレビュー 1 行。
    var displaySubtitle: String {
        switch self {
        case .understanding(let card):
            switch card.kind {
            case .conceptPage(let page):
                let summary = page.summary
                let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return "" }
                return trimmed.count > 80 ? String(trimmed.prefix(80)) + "…" : trimmed
            case .savedAnswer(let answer):
                let preview = answer.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                return preview.count > 80 ? String(preview.prefix(80)) + "…" : preview
            }
        case .digest(let digest):
            let summary = digest.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            return summary.count > 80 ? String(summary.prefix(80)) + "…" : summary
        }
    }

    /// カード種別ラベル (「新しい知識」「テクノロジー 分野」等)。
    var labelText: LocalizedStringKey {
        switch self {
        case .understanding(let card):
            return card.label.localizationKey
        case .digest:
            return "interestingNext.label.topicDashboard"
        }
    }

    /// カード種別 icon (SF Symbol)。
    var iconName: String {
        switch self {
        case .understanding:
            return "lightbulb.fill"
        case .digest:
            return "chart.bar.fill"
        }
    }
}
