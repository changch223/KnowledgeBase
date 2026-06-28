//
//  GraphLayout.swift
//  KnowledgeTree
//
//  spec 041 (Phase B) — Knowledge Graph の静的 layout 計算 (純関数)。
//
//  中心 = degree 最大 node (tiebreak: importanceScore desc)。
//  周辺 = 残りの node を degree 降順で角度均等に円形配置。
//  半径 = min(canvas.width, canvas.height) / 2 * 0.7。
//
//  GraphNode 直接ではなく、軽量 Input struct を受け取ることで SwiftData 依存ゼロ、
//  pure function として簡潔にテストできる。
//

import Foundation
import CoreGraphics

enum GraphLayout {

    /// Layout 計算用の最小入力 (GraphNode → Input への map は View 側で行う)
    struct Input: Hashable {
        let nodeID: UUID
        let degree: Int
        let importanceScore: Int
    }

    struct NodePosition: Equatable {
        let nodeID: UUID
        let point: CGPoint
    }

    /// 円形 + 中心の静的 layout を計算する。
    /// - Parameters:
    ///   - inputs: active GraphNode の軽量表現
    ///   - canvas: 描画領域の size
    /// - Returns: 各 node の position (入力順ではなく描画順)
    static func compute(inputs: [Input], canvas: CGSize) -> [NodePosition] {
        guard !inputs.isEmpty else { return [] }
        guard canvas.width > 0, canvas.height > 0 else { return [] }

        let sorted = inputs.sorted { lhs, rhs in
            if lhs.degree != rhs.degree { return lhs.degree > rhs.degree }
            return lhs.importanceScore > rhs.importanceScore
        }

        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        if sorted.count == 1 {
            return [NodePosition(nodeID: sorted[0].nodeID, point: center)]
        }

        let radius = min(canvas.width, canvas.height) / 2 * 0.7
        var positions: [NodePosition] = [
            NodePosition(nodeID: sorted[0].nodeID, point: center)
        ]

        let peripheryCount = sorted.count - 1
        let step = (2 * Double.pi) / Double(peripheryCount)
        for i in 0..<peripheryCount {
            let node = sorted[i + 1]
            // top (12 時方向) から時計回り
            let angle = step * Double(i) - .pi / 2
            let x = center.x + radius * CGFloat(cos(angle))
            let y = center.y + radius * CGFloat(sin(angle))
            positions.append(NodePosition(nodeID: node.nodeID, point: CGPoint(x: x, y: y)))
        }
        return positions
    }
}
