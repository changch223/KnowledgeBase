//
//  FirstSaveGuide.swift
//  KnowledgeTree
//
//  spec 104 — 記事 0 件のときナレッジタブに出す「保存方法 3 つ」の案内。
//  ① 他アプリの共有ボタン ② 右上の ＋ ③ Safari 拡張 (SafariSetupView へ)。
//

import SwiftUI

struct FirstSaveGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            Text("firstSave.title")
                .font(.title3)
                .fontWeight(.semibold)
                .fontDesign(.serif)
                .foregroundStyle(DS.Color.sumiInk)

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                stepRow(icon: "square.and.arrow.up", number: 1, text: "firstSave.share")
                stepRow(icon: "plus.circle", number: 2, text: "firstSave.plus")
                NavigationLink(value: SafariSetupDestination()) {
                    HStack(spacing: DS.Spacing.md) {
                        stepLabel(icon: "safari", number: 3, text: "firstSave.safari")
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DS.Color.sumiLight)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("firstSaveGuide")
    }

    private func stepRow(icon: String, number: Int, text: LocalizedStringKey) -> some View {
        stepLabel(icon: icon, number: number, text: text)
    }

    private func stepLabel(icon: String, number: Int, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DS.Color.sumiInk)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(DS.Color.sumiMid)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }
}
