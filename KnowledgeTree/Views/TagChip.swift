//
//  TagChip.swift
//  KnowledgeTree
//
//  spec 008 — タグの小さなチップ。手動タグ (× 削除可能) と自動提案 (+ アイコン) を切替。
//

import SwiftUI

struct TagChip: View {
    let name: String
    /// nil なら × 削除ボタン非表示 (提案チップ用)
    let onRemove: (() -> Void)?
    /// 自動提案チップなら + アイコン + 半透明背景
    let isSuggested: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isSuggested {
                Image(systemName: "plus")
                    .font(.caption2)
            }
            Text(name)
                .font(.caption)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tagChipDeleteButton-\(name)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isSuggested ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.tertiary), in: Capsule())
        .accessibilityIdentifier(isSuggested ? "tagChipSuggested-\(name)" : "tagChip-\(name)")
    }
}
