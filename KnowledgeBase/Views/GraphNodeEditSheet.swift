//
//  GraphNodeEditSheet.swift
//  KnowledgeTree
//
//  spec 041 (Phase B) — GraphNode の rename / merge / delete sheet。
//  TagEditSheet (spec 024) と同パターン:
//  - rename: TextField + 保存 (空文字 / 30 文字超は disable)
//  - merge: 同 Category の他 node を選択 → merge → dismiss
//  - delete: 確認 alert → cascade で edges も削除
//

import SwiftUI
import SwiftData

struct GraphNodeEditSheet: View {
    @Bindable var node: GraphNode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refresh

    @State private var draftName: String = ""
    @State private var showDeleteConfirm: Bool = false
    @State private var showMergePicker: Bool = false
    @State private var errorMessage: String?

    /// 同 Category かつ自分以外の active node 候補 (merge 用)
    @Query private var allNodes: [GraphNode]

    private var mergeCandidates: [GraphNode] {
        allNodes.filter { $0.id != node.id && $0.categoryRaw == node.categoryRaw && $0.isActive }
            .sorted { $0.importanceScore > $1.importanceScore }
    }

    private var trimmedDraft: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedDraft.isEmpty && trimmedDraft.count <= 30 && trimmedDraft != node.name
    }

    private var store: GraphNodeStore? {
        services.graphNodeStore
    }

    var body: some View {
        Form {
            Section("名前") {
                TextField("ノード名", text: $draftName)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("graph.node.edit.name")
            }

            Section {
                Button {
                    showMergePicker = true
                } label: {
                    Label("他のノードと統合", systemImage: "arrow.triangle.merge")
                        .foregroundStyle(DS.Color.actionBlue)
                }
                .disabled(mergeCandidates.isEmpty)
                .accessibilityIdentifier("graph.node.edit.merge")
            } footer: {
                if mergeCandidates.isEmpty {
                    Text("統合できる他のノードがありません。")
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("削除", systemImage: "trash")
                }
                .accessibilityIdentifier("graph.node.edit.delete")
            } footer: {
                Text("ノードを削除すると関連する関係 (edge) も削除されます。記事自体は残ります。")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("ノードを編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(!canSave)
                .accessibilityIdentifier("graph.node.edit.save")
            }
        }
        .onAppear {
            draftName = node.name
        }
        .alert("削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) {
                delete()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("「\(node.name)」とこのノードの関係 (edge) を削除します。記事自体は残ります。")
        }
        .sheet(isPresented: $showMergePicker) {
            NavigationStack {
                GraphNodeMergePicker(
                    source: node,
                    candidates: mergeCandidates
                ) { target in
                    merge(into: target)
                }
            }
        }
    }

    private func save() {
        guard let store else { return }
        do {
            _ = try store.rename(node, to: trimmedDraft)
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました。"
        }
    }

    private func merge(into target: GraphNode) {
        guard let store else { return }
        do {
            try store.merge(source: node, into: target)
            dismiss()
        } catch {
            errorMessage = "統合に失敗しました。"
        }
    }

    private func delete() {
        guard let store else { return }
        do {
            try store.delete(node)
            dismiss()
        } catch {
            errorMessage = "削除に失敗しました。"
        }
    }
}

/// merge 先 GraphNode を選ぶ picker (push 遷移版の sheet)。
private struct GraphNodeMergePicker: View {
    let source: GraphNode
    let candidates: [GraphNode]
    let onSelect: (GraphNode) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(candidates, id: \.id) { candidate in
            Button {
                onSelect(candidate)
                dismiss()
            } label: {
                HStack {
                    Text(candidate.name)
                    Spacer()
                    Text("(\(candidate.degree))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("「\(source.name)」を統合")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
        }
    }
}
