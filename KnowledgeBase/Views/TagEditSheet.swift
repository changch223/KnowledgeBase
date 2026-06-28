//
//  TagEditSheet.swift
//  KnowledgeTree
//
//  spec 024 — Tag 編集 sheet。
//  ・タグ名 rename (同名既存があれば自動 merge)
//  ・他のタグに統合 (Picker)
//  ・削除 (確認 alert)
//

import SwiftUI
import SwiftData

struct TagEditSheet: View {
    let tag: Tag
    let onCompletion: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceContainer.self) private var serviceContainer

    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var editedName: String = ""
    @State private var selectedMergeTarget: Tag?
    @State private var showDeleteConfirm: Bool = false
    @State private var showMergeConfirm: Bool = false
    @State private var errorMessage: String?

    private var otherTags: [Tag] {
        allTags.filter { $0.id != tag.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                renameSection
                if !otherTags.isEmpty {
                    mergeSection
                }
                deleteSection
            }
            .navigationTitle("tag.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("tag.edit.action.cancel") {
                        dismiss()
                    }
                }
            }
            .alert("tag.edit.confirmDelete.title", isPresented: $showDeleteConfirm) {
                Button("tag.edit.action.delete", role: .destructive) {
                    performDelete()
                }
                Button("tag.edit.action.cancel", role: .cancel) {}
            } message: {
                Text("tag.edit.confirmDelete.message \((tag.articles ?? []).count)")
            }
            .alert("tag.edit.confirmMerge.title", isPresented: $showMergeConfirm) {
                Button("tag.edit.action.merge", role: .destructive) {
                    performMerge()
                }
                Button("tag.edit.action.cancel", role: .cancel) {}
            } message: {
                if let target = selectedMergeTarget {
                    Text("tag.edit.confirmMerge.message \(target.name) \((tag.articles ?? []).count)")
                }
            }
            .alert(
                Text("エラー"),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                editedName = tag.name
            }
        }
        .accessibilityIdentifier("tag.edit.sheet")
    }

    // MARK: - Sections

    private var renameSection: some View {
        Section {
            TextField("tag.edit.section.rename", text: $editedName)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("tag.edit.field.name")
            Button {
                performRename()
            } label: {
                Text("tag.edit.action.save")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .disabled(!canRename)
            .accessibilityIdentifier("tag.edit.button.save")
        } header: {
            Text("tag.edit.section.rename")
        } footer: {
            Text("tag.edit.section.rename.help")
        }
    }

    private var mergeSection: some View {
        Section {
            Picker(selection: $selectedMergeTarget) {
                Text("tag.edit.merge.placeholder").tag(nil as Tag?)
                ForEach(otherTags) { other in
                    Text(other.name).tag(other as Tag?)
                }
            } label: {
                Text("tag.edit.section.merge")
            }
            .accessibilityIdentifier("tag.edit.picker.merge")
            Button {
                showMergeConfirm = true
            } label: {
                Text("tag.edit.action.merge")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .disabled(selectedMergeTarget == nil)
            .accessibilityIdentifier("tag.edit.button.merge")
        } header: {
            Text("tag.edit.section.merge")
        } footer: {
            Text("tag.edit.section.merge.help")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("tag.edit.section.delete")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .accessibilityIdentifier("tag.edit.button.delete")
        } header: {
            Text("tag.edit.section.delete")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("tag.edit.section.delete.help")
                Text("tag.management.row.articleCount \((tag.articles ?? []).count)")
            }
        }
    }

    // MARK: - Computed

    private var canRename: Bool {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != tag.name
    }

    // MARK: - Actions

    private func performRename() {
        guard let store = serviceContainer.tagStore else { return }
        do {
            _ = try store.rename(tag, to: editedName)
            onCompletion()
            dismiss()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func performMerge() {
        guard let store = serviceContainer.tagStore,
              let target = selectedMergeTarget else { return }
        do {
            try store.merge(source: tag, into: target)
            onCompletion()
            dismiss()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func performDelete() {
        guard let store = serviceContainer.tagStore else { return }
        do {
            try store.delete(tag)
            onCompletion()
            dismiss()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
