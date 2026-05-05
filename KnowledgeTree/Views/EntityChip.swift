//
//  EntityChip.swift
//  KnowledgeTree
//
//  spec 004 — KnowledgeEntity 1 chip (種別アイコン + name)
//

import SwiftUI

struct EntityChip: View {
    let entity: KnowledgeEntity

    private var iconName: String {
        switch entity.typeStored {
        case .person:       return "person.fill"
        case .organization: return "building.2.fill"
        case .location:     return "mappin.circle.fill"
        case .concept:      return "lightbulb.fill"
        case .product:      return "shippingbox.fill"
        case .work:         return "book.fill"
        }
    }

    private var typeLocalizedKey: LocalizedStringKey {
        switch entity.typeStored {
        case .person:       return "knowledge.entityType.person"
        case .organization: return "knowledge.entityType.organization"
        case .location:     return "knowledge.entityType.location"
        case .concept:      return "knowledge.entityType.concept"
        case .product:      return "knowledge.entityType.product"
        case .work:         return "knowledge.entityType.work"
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: iconName)
                .font(DS.Typography.chipIcon)
                .foregroundStyle(.secondary)
            Text(entity.name)
                .font(DS.Typography.chipLabel)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.chip)
                .fill(DS.Color.overlayLight)
        )
        .accessibilityIdentifier("knowledgeEntityChip")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Text(typeLocalizedKey)): \(entity.name)")
    }
}
