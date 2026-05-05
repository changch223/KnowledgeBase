//
//  KnowledgeMapView.swift
//  KnowledgeTree
//
//  spec 011 Phase 5 / US2 — AI ブレインタブ Section 2 のナレッジマップ。
//  Canvas + GeometryReader (依存なし) で Tag をノード、共通 KnowledgeEntity を
//  エッジとして描画。ノードタップで TagFilteredListView へ遷移。
//
//  contracts/knowledge-map-builder.md (グラフ計算) +
//  contracts/ai-brain-view.md (配置) 準拠。
//

import SwiftUI
import SwiftData

struct KnowledgeMapView: View {
    let tags: [Tag]

    @Environment(RefreshTrigger.self) private var refresh

    @State private var graph: MapGraph = .empty
    @State private var canvasSize: CGSize = .zero
    @State private var newlyVisibleIDs: Set<String> = []
    @State private var hasPerformedInitialBuild: Bool = false

    // Pinch zoom (0.5x - 3.0x)
    @State private var scale: CGFloat = 1.0
    @State private var accumulatedScale: CGFloat = 1.0

    // Drag pan
    @State private var offset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero

    var body: some View {
        Group {
            if tags.isEmpty {
                emptyState
            } else {
                mapBody
            }
        }
        .accessibilityIdentifier("aibrain.knowledge_map")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("aibrain.map.empty.title", systemImage: "square.dashed")
        } description: {
            Text("まだ記事がありません。Safari から記事を保存しよう！")
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .accessibilityIdentifier("aibrain.map.empty")
    }

    // MARK: - Map body

    private var mapBody: some View {
        GeometryReader { proxy in
            ZStack {
                Canvas { context, _ in
                    drawEdges(in: context)
                    drawNodes(in: context)
                }
                .accessibilityHidden(true)

                ForEach(graph.nodes) { node in
                    nodeButton(for: node)
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(panGesture)
            .gesture(zoomGesture)
            .onAppear {
                if !hasPerformedInitialBuild {
                    canvasSize = proxy.size
                    rebuildGraph(initial: true)
                    hasPerformedInitialBuild = true
                }
            }
            .onChange(of: proxy.size) { _, newSize in
                canvasSize = newSize
                rebuildGraph(initial: false)
            }
            .onChange(of: tags.map { $0.name }) { _, _ in
                rebuildGraph(initial: false)
            }
            .onChange(of: refresh.version) { _, _ in
                rebuildGraph(initial: false)
            }
        }
        .frame(minHeight: 300)
    }

    // MARK: - Drawing

    private func drawEdges(in context: GraphicsContext) {
        let nodePositions: [String: CGPoint] = Dictionary(
            uniqueKeysWithValues: graph.nodes.map { ($0.id, $0.position) }
        )
        for edge in graph.edges {
            guard let a = nodePositions[edge.from],
                  let b = nodePositions[edge.to] else { continue }
            var path = Path()
            path.move(to: a)
            path.addLine(to: b)
            context.stroke(
                path,
                with: .color(.secondary.opacity(0.3)),
                lineWidth: 1
            )
        }
    }

    private func drawNodes(in context: GraphicsContext) {
        for node in graph.nodes {
            let rect = CGRect(
                x: node.position.x - node.radius,
                y: node.position.y - node.radius,
                width: node.radius * 2,
                height: node.radius * 2
            )
            let circle = Path(ellipseIn: rect)
            context.fill(circle, with: .color(.accentColor.opacity(0.18)))
            context.stroke(circle, with: .color(.accentColor.opacity(0.6)), lineWidth: 1.5)

            // Label centered
            let label = Text(node.id)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
            context.draw(label, at: node.position, anchor: .center)
        }
    }

    // MARK: - Node tap target

    @ViewBuilder
    private func nodeButton(for node: MapNode) -> some View {
        let isNewlyVisible = newlyVisibleIDs.contains(node.id)
        NavigationLink(value: TagFilteredDestination(tagName: node.id)) {
            Color.clear
                .frame(width: node.radius * 2, height: node.radius * 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(node.position)
        .opacity(isNewlyVisible ? 0 : 1)
        .accessibilityIdentifier("aibrain.map.node.\(node.id)")
        .accessibilityLabel(Text("タグ \(node.id)、\(node.articleCount) 記事"))
        .onAppear {
            if isNewlyVisible {
                withAnimation(.easeIn(duration: 0.4)) {
                    _ = newlyVisibleIDs.remove(node.id)
                }
            }
        }
    }

    // MARK: - Gestures

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = accumulatedScale * value
                scale = min(3.0, max(0.5, proposed))
            }
            .onEnded { _ in
                accumulatedScale = scale
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: accumulatedOffset.width + value.translation.width,
                    height: accumulatedOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                accumulatedOffset = offset
            }
    }

    // MARK: - Graph rebuild

    private func rebuildGraph(initial: Bool) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        let oldIDs = Set(graph.nodes.map { $0.id })
        let newGraph = KnowledgeMapBuilder.buildGraph(
            tags: tags,
            canvasSize: canvasSize
        )
        let newIDs = Set(newGraph.nodes.map { $0.id })
        let appeared = newIDs.subtracting(oldIDs)
        graph = newGraph
        if !initial {
            // 初回 build では fade-in しない (起動時に全ノードが「新登場」扱いになる回避)
            newlyVisibleIDs.formUnion(appeared)
        }
    }
}
