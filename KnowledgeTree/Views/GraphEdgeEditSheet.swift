//
//  GraphEdgeEditSheet.swift
//  KnowledgeTree
//
//  spec 041 (Phase B) — GraphEdge の label rename / delete sheet。
//  - source / target / confidence / weight は read-only 表示
//  - label を空 → 共起化、文字あり → ラベル付き化
//  - delete: 確認 alert → edge 削除 (node は残る)
//

import SwiftUI

struct GraphEdgeEditSheet: View {
    @Bindable var edge: GraphEdge
    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceContainer.self) private var services

    @State private var draftLabel: String = ""
    @State private var showDeleteConfirm: Bool = false
    @State private var errorMessage: String?

    private var trimmedDraft: String {
        draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentLabel: String { edge.label ?? "" }

    private var canSave: Bool {
        trimmedDraft != currentLabel
    }

    private var store: GraphNodeStore? {
        services.graphNodeStore
    }

    var body: some View {
        Form {
            Section("関係") {
                LabeledContent("From", value: edge.source?.name ?? "(削除済)")
                LabeledContent("To", value: edge.target?.name ?? "(削除済)")
            }

            Section {
                TextField("ラベル (例: 開発, 所属, 発表)", text: $draftLabel)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("graph.edge.edit.label")
            } header: {
                Text("ラベル")
            } footer: {
                Text("空のままにすると「共起」(label なし) 扱いになります。")
            }

            Section("統計") {
                LabeledContent("確信度", value: confidenceDisplay)
                LabeledContent("観測回数", value: "\(edge.weight)")
                if edge.isUncertain {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.secondary)
                        Text("AI 確信度が中程度です。")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("関係を削除", systemImage: "trash")
                }
                .accessibilityIdentifier("graph.edge.edit.delete")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("関係を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!canSave)
                    .accessibilityIdentifier("graph.edge.edit.save")
            }
        }
        .onAppear {
            draftLabel = currentLabel
        }
        .alert("関係を削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) { delete() }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("この関係 (edge) を削除します。両端のノードと記事は残ります。")
        }
    }

    private var confidenceDisplay: String {
        String(format: "%.2f", edge.confidence)
    }

    private func save() {
        guard let store else { return }
        do {
            _ = try store.renameEdgeLabel(edge, to: trimmedDraft.isEmpty ? nil : trimmedDraft)
            dismiss()
        } catch {
            errorMessage = "保存に失敗しました。"
        }
    }

    private func delete() {
        guard let store else { return }
        do {
            try store.deleteEdge(edge)
            dismiss()
        } catch {
            errorMessage = "削除に失敗しました。"
        }
    }
}
