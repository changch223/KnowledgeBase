//
//  KeyFactRow.swift
//  KnowledgeTree
//
//  spec 004 — KeyFact 1 行 (種別アイコン + statement)
//

import SwiftUI

struct KeyFactRow: View {
    let fact: KeyFact

    private var iconName: String {
        switch fact.typeStored {
        case .event:      return "calendar"
        case .claim:      return "bubble.left"
        case .statistic:  return "chart.bar"
        case .definition: return "text.book.closed"
        case .quote:      return "quote.bubble"
        }
    }

    private var typeLocalizedKey: LocalizedStringKey {
        switch fact.typeStored {
        case .event:      return "knowledge.factType.event"
        case .claim:      return "knowledge.factType.claim"
        case .statistic:  return "knowledge.factType.statistic"
        case .definition: return "knowledge.factType.definition"
        case .quote:      return "knowledge.factType.quote"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: iconName)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .center)
            Text(fact.statement)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("knowledgeFactRow")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Text(typeLocalizedKey)): \(fact.statement)")
    }
}
