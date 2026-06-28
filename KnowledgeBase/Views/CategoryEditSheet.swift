//
//  CategoryEditSheet.swift
//  KnowledgeTree
//
//  spec 075 — 分野 (CategoryDefinition) 編集 sheet。TagEditSheet をミラー。
//  ・分野名 rename (属する Tag/概念の categoryRaw を cascade 更新)
//  ・他の分野に統合 (Picker)
//  ・AI 分類用の定義を編集
//  ・非表示 / 再表示 (削除はしない、calm UX)
//

import SwiftUI
import SwiftData

struct CategoryEditSheet: View {
    let category: CategoryDefinition
    let onCompletion: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceContainer.self) private var serviceContainer

    @Query(sort: \CategoryDefinition.order) private var allCategories: [CategoryDefinition]

    @State private var editedName: String = ""
    @State private var editedDefinition: String = ""
    @State private var selectedMergeTarget: CategoryDefinition?
    @State private var showMergeConfirm: Bool = false
    @State private var errorMessage: String?

    /// 統合先候補 = 自分以外の非表示でない分野。
    private var otherCategories: [CategoryDefinition] {
        allCategories.filter { $0.id != category.id && !$0.isHidden }
    }

    var body: some View {
        NavigationStack {
            Form {
                renameSection
                definitionSection
                if !otherCategories.isEmpty {
                    mergeSection
                }
                visibilitySection
            }
            .navigationTitle("category.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("tag.edit.action.cancel") { dismiss() }
                }
            }
            .alert("category.edit.confirmMerge.title", isPresented: $showMergeConfirm) {
                Button("category.edit.action.merge", role: .destructive) { performMerge() }
                Button("tag.edit.action.cancel", role: .cancel) {}
            } message: {
                if let target = selectedMergeTarget {
                    Text("category.edit.confirmMerge.message \(target.name)")
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
                editedName = category.name
                editedDefinition = category.definition
            }
        }
        .accessibilityIdentifier("category.edit.sheet")
    }

    // MARK: - Sections

    private var renameSection: some View {
        Section {
            TextField("category.edit.section.rename", text: $editedName)
                .accessibilityIdentifier("category.edit.field.name")
            Button {
                performRename()
            } label: {
                Text("tag.edit.action.save")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .disabled(!canRename)
            .accessibilityIdentifier("category.edit.button.save")
        } header: {
            Text("category.edit.section.rename")
        } footer: {
            Text("category.edit.section.rename.help")
        }
    }

    private var definitionSection: some View {
        Section {
            TextEditor(text: $editedDefinition)
                .frame(minHeight: 80)
                .accessibilityIdentifier("category.edit.field.definition")
            Button {
                performUpdateDefinition()
            } label: {
                Text("tag.edit.action.save")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .disabled(editedDefinition == category.definition)
            .accessibilityIdentifier("category.edit.button.saveDefinition")
        } header: {
            Text("category.edit.section.definition")
        } footer: {
            Text("category.edit.section.definition.help")
        }
    }

    private var mergeSection: some View {
        Section {
            Picker(selection: $selectedMergeTarget) {
                Text("tag.edit.merge.placeholder").tag(nil as CategoryDefinition?)
                ForEach(otherCategories) { other in
                    Text(other.name).tag(other as CategoryDefinition?)
                }
            } label: {
                Text("category.edit.section.merge")
            }
            .accessibilityIdentifier("category.edit.picker.merge")
            Button {
                showMergeConfirm = true
            } label: {
                Text("category.edit.action.merge")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .disabled(selectedMergeTarget == nil)
            .accessibilityIdentifier("category.edit.button.merge")
        } header: {
            Text("category.edit.section.merge")
        } footer: {
            Text("category.edit.section.merge.help")
        }
    }

    private var visibilitySection: some View {
        Section {
            if category.isHidden {
                Button {
                    perform { try $0.unhide(category) }
                } label: {
                    HStack {
                        Image(systemName: "eye")
                        Text("category.edit.action.unhide")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .accessibilityIdentifier("category.edit.button.unhide")
            } else {
                Button(role: .destructive) {
                    perform { try $0.hide(category) }
                } label: {
                    HStack {
                        Image(systemName: "eye.slash")
                        Text("category.edit.action.hide")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .accessibilityIdentifier("category.edit.button.hide")
            }
        } footer: {
            Text("category.edit.section.visibility.help")
        }
    }

    // MARK: - Computed

    private var canRename: Bool {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != category.name
    }

    // MARK: - Actions

    private func performRename() {
        perform { try $0.rename(category, to: editedName) }
    }

    private func performUpdateDefinition() {
        perform { try $0.updateDefinition(category, to: editedDefinition) }
    }

    private func performMerge() {
        guard let target = selectedMergeTarget else { return }
        perform { try $0.merge(source: category, into: target) }
    }

    /// store 操作の共通ラッパー (成功で完了 + dismiss、失敗で error alert)。
    private func perform(_ action: (CategoryStore) throws -> Void) {
        guard let store = serviceContainer.categoryStore else { return }
        do {
            try action(store)
            onCompletion()
            dismiss()
        } catch CategoryStoreError.duplicateName {
            errorMessage = String(localized: "category.edit.error.duplicate")
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
