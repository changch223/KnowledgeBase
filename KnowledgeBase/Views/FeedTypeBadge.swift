//
//  FeedTypeBadge.swift
//  KnowledgeTree
//
//  spec 070 (iKnow フィード) — カードの種類を「アイコン + 文字ラベル」で明示する小バッジ。
//  アイコンだけだと種別が分かりづらいため、記事 / まとめ / 分野 / タグ を文字でも示す。
//

import SwiftUI

/// フィードカード左上の種別バッジ (アイコン + 文字)。caption サイズ、tagFill capsule。
struct FeedTypeBadge: View {
    let labelKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(labelKey, systemImage: systemImage)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(DS.Color.sumiInk)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(DS.Color.tagFill, in: Capsule())
    }
}
