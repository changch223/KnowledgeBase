//
//  FABButton.swift
//  KnowledgeTree
//
//  spec 056 — 知識 Clip + ライブラリ で再利用する floating action button (FAB)。
//  右下配置、tap で callback 実行 (URL 入力 sheet 等)。
//

import SwiftUI

struct FABButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(DS.Color.sumiFixedInk, in: .circle)
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
        .accessibilityLabel(Text("fab.accessibility.label"))
    }
}
