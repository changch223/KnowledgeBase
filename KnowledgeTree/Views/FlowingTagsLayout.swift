//
//  FlowingTagsLayout.swift
//  KnowledgeTree
//
//  spec 008 — タグチップを折り返し表示する簡易 Layout。
//  SwiftUI 6 の `Layout` プロトコルで proper flow layout を実装。
//

import SwiftUI

struct FlowingTagsLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let result = layoutPositions(maxWidth: maxWidth, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layoutPositions(maxWidth: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            let origin = CGPoint(
                x: bounds.minX + position.x,
                y: bounds.minY + position.y
            )
            subviews[index].place(at: origin, proposal: .unspecified)
        }
    }

    private func layoutPositions(
        maxWidth: CGFloat,
        subviews: Subviews
    ) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth, x > 0 {
                // 折り返し
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + lineHeight))
    }
}
