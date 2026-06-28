//
//  GraphNodeDetailView.swift
//  KnowledgeTree
//
//  spec 041 (Phase B) — GraphNode の詳細画面。
//  - ヘッダ: name + categoryRaw + 統計 (mentionCount × salience × degree)
//  - outgoing edges / incoming edges 一覧 (tap で GraphEdgeEditSheet)
//  - 関連記事一覧 (tap で ArticleDetailView)
//  - 編集 button (toolbar) → GraphNodeEditSheet (rename / merge / delete)
//

import SwiftUI
import SwiftData

struct GraphNodeDetailView: View {
    @Bindable var node: GraphNode

    @State private var presentedArticle: Article?
    @State private var showNodeEditSheet: Bool = false
    @State private var presentedEdgeForEdit: GraphEdge?

    var body: some View {
        List {
            statsSection
            outgoingEdgesSection
            incomingEdgesSection
            articlesSection
        }
        .navigationTitle(node.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNodeEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(DS.Color.sumiInk)
                }
                .accessibilityIdentifier("graph.node.edit")
            }
        }
        .sheet(isPresented: $showNodeEditSheet) {
            NavigationStack {
                GraphNodeEditSheet(node: node)
            }
        }
        .sheet(item: $presentedArticle) { article in
            ArticleDetailView(article: article)
        }
        .sheet(item: $presentedEdgeForEdit) { edge in
            NavigationStack {
                GraphEdgeEditSheet(edge: edge)
            }
        }
        .accessibilityIdentifier("graph.node.detail")
    }

    @ViewBuilder
    private var statsSection: some View {
        Section {
            LabeledContent("分野", value: node.categoryRaw)
            LabeledContent("出現記事数", value: "\(node.mentionCount)")
            LabeledContent("重要度", value: "\(node.salience) / 5")
            LabeledContent("関連エンティティ数", value: "\(node.degree)")
        }
    }

    @ViewBuilder
    private var outgoingEdgesSection: some View {
        if !(node.outgoingEdges ?? []).isEmpty {
            Section("関係 (→)") {
                ForEach(node.outgoingEdges ?? []) { edge in
                    Button {
                        presentedEdgeForEdit = edge
                    } label: {
                        edgeRow(edge: edge, otherEnd: edge.target, direction: .outgoing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var incomingEdgesSection: some View {
        if !(node.incomingEdges ?? []).isEmpty {
            Section("関係 (←)") {
                ForEach(node.incomingEdges ?? []) { edge in
                    Button {
                        presentedEdgeForEdit = edge
                    } label: {
                        edgeRow(edge: edge, otherEnd: edge.source, direction: .incoming)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func edgeRow(edge: GraphEdge, otherEnd: GraphNode?, direction: EdgeDirection) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.xs) {
                    if let label = edge.label {
                        Text(label)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    } else {
                        Text("共起")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                    if edge.isUncertain {
                        Image(systemName: "questionmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(otherEnd?.name ?? "(削除済)")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Text("×\(edge.weight)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var articlesSection: some View {
        if !(node.articles ?? []).isEmpty {
            Section("関連記事 (\((node.articles ?? []).count))") {
                ForEach((node.articles ?? []).sorted(by: { $0.savedAt > $1.savedAt }), id: \.id) { article in
                    Button {
                        presentedArticle = article
                    } label: {
                        ArticleRow(article: article, refreshTick: 0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private enum EdgeDirection { case outgoing, incoming }
}

/// CategoryGraphView の node tap から push 遷移する Hashable destination。
struct GraphNodeDetailDestination: Hashable {
    let nodeID: UUID
}

/// destination から GraphNode を fetch して GraphNodeDetailView を表示する loader。
/// fetch 失敗 (削除済 / 不正 ID) は graceful な empty state を表示。
struct GraphNodeDetailDestinationLoader: View {
    let nodeID: UUID

    @Environment(\.modelContext) private var context

    var body: some View {
        if let node = fetchNode() {
            GraphNodeDetailView(node: node)
        } else {
            ContentUnavailableView(
                "ノードが見つかりません",
                systemImage: "questionmark.circle",
                description: Text("このノードは削除されたか、まだ抽出されていません。")
            )
        }
    }

    private func fetchNode() -> GraphNode? {
        let target = nodeID
        var descriptor = FetchDescriptor<GraphNode>(
            predicate: #Predicate<GraphNode> { $0.id == target }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
