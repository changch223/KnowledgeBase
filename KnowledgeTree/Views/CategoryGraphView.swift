//
//  CategoryGraphView.swift
//  KnowledgeTree
//
//  spec 041 (Phase B) — Category 内のナレッジグラフを Canvas で描画する read-only view。
//
//  - 中心 = degree 最大 node、周辺 = 円形配置 (GraphLayout 純関数)
//  - エッジ: ラベル付き = 実線、共起 (label=nil) = 破線、isUncertain = 薄色
//  - ノード: 円 (中心は actionBlue 塗り、周辺は薄塗り + actionBlue stroke) + 名前
//  - active==true の node のみ
//
//  本 view は read-only。tap で GraphNodeDetailView に遷移する経路は将来段階で追加。
//

import SwiftUI
import SwiftData

struct CategoryGraphView: View {
    let categoryRaw: String

    /// Category 内 active GraphNode を @Query で監視 (記事保存で graph が更新されたら自動 redraw)
    @Query private var nodes: [GraphNode]

    /// Canvas height (固定、Category 詳細画面の上部に挿入される想定)
    private let canvasHeight: CGFloat = 280

    /// node 描画半径
    private let nodeRadius: CGFloat = 18

    init(categoryRaw: String) {
        self.categoryRaw = categoryRaw
        let predicate = #Predicate<GraphNode> { node in
            node.isActive == true && node.categoryRaw == categoryRaw
        }
        _nodes = Query(filter: predicate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("graph.section.title")
                .font(DS.Typography.sectionTitle)
                .padding(.horizontal, DS.Spacing.xxl)

            if nodes.isEmpty {
                emptyState
            } else {
                canvas
            }
        }
        .accessibilityIdentifier("graph.category.\(categoryRaw)")
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("graph.empty.title")
                .font(.headline)
            Text("graph.empty.description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: canvasHeight)
        .dsCardBackground()
        .padding(.horizontal, DS.Spacing.xxl)
    }

    private var canvas: some View {
        GeometryReader { geo in
            let inputs = nodes.map { node in
                GraphLayout.Input(
                    nodeID: node.id,
                    degree: node.degree,
                    importanceScore: node.importanceScore
                )
            }
            let positions = GraphLayout.compute(
                inputs: inputs,
                canvas: CGSize(width: geo.size.width, height: canvasHeight)
            )
            let positionLookup: [UUID: CGPoint] = Dictionary(
                uniqueKeysWithValues: positions.map { ($0.nodeID, $0.point) }
            )

            ZStack {
                Canvas { context, _ in
                    // edges first (背面)
                    for node in nodes {
                        guard let sourcePoint = positionLookup[node.id] else { continue }
                        for edge in node.outgoingEdges {
                            guard let target = edge.target,
                                  target.isActive,
                                  let targetPoint = positionLookup[target.id] else { continue }
                            drawEdge(
                                context: context,
                                from: sourcePoint,
                                to: targetPoint,
                                edge: edge
                            )
                        }
                    }
                    // nodes on top
                    for (i, position) in positions.enumerated() {
                        let isCenter = (i == 0)
                        guard let node = nodes.first(where: { $0.id == position.nodeID }) else { continue }
                        drawNode(context: context, position: position.point, name: node.name, isCenter: isCenter)
                    }
                }
                .frame(height: canvasHeight)

                // node tap overlay (透明 button を重ねて NavigationLink で push)
                ForEach(positions, id: \.nodeID) { pos in
                    if let node = nodes.first(where: { $0.id == pos.nodeID }) {
                        NavigationLink(value: GraphNodeDetailDestination(nodeID: node.id)) {
                            Color.clear
                                .frame(width: nodeRadius * 2.4, height: nodeRadius * 2.4)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .position(pos.point)
                        .accessibilityLabel(node.name)
                        .accessibilityIdentifier("graph.node.tap.\(node.name)")
                    }
                }
            }
        }
        .frame(height: canvasHeight)
        .dsCardBackground()
        .padding(.horizontal, DS.Spacing.xxl)
    }

    private func drawEdge(
        context: GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        edge: GraphEdge
    ) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)

        let style: StrokeStyle
        if edge.label == nil {
            // 共起 = 破線
            style = StrokeStyle(lineWidth: 1.0, dash: [3, 3])
        } else {
            // ラベル付き = 実線
            style = StrokeStyle(lineWidth: edge.isUncertain ? 1.0 : 1.5)
        }

        let opacity: Double = edge.isUncertain ? 0.35 : 0.55
        context.stroke(path, with: .color(DS.Color.aiBrandEdge.opacity(opacity)), style: style)
    }

    private func drawNode(
        context: GraphicsContext,
        position: CGPoint,
        name: String,
        isCenter: Bool
    ) {
        let rect = CGRect(
            x: position.x - nodeRadius,
            y: position.y - nodeRadius,
            width: nodeRadius * 2,
            height: nodeRadius * 2
        )
        let circle = Path(ellipseIn: rect)

        if isCenter {
            context.fill(circle, with: .color(DS.Color.actionBlue.opacity(0.85)))
            context.stroke(circle, with: .color(DS.Color.actionBlue), lineWidth: 1.5)
        } else {
            context.fill(circle, with: .color(DS.Color.aiBrandNodeFill))
            context.stroke(circle, with: .color(DS.Color.aiBrandNodeStroke), lineWidth: 1.0)
        }

        // ノード名 (中心は white、周辺は primary)
        let truncated = name.count > 8 ? String(name.prefix(7)) + "…" : name
        let text = Text(truncated)
            .font(.caption2)
            .foregroundStyle(isCenter ? Color.white : Color.primary)
        context.draw(text, at: position, anchor: .center)
    }
}
