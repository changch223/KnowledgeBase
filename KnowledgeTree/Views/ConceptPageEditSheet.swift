//
//  ConceptPageEditSheet.swift
//  KnowledgeTree
//
//  spec 042 — ConceptPage 編集 sheet (rename / merge / delete)。
//  TagEditSheet (spec 024) / GraphNodeEditSheet (spec 041) と同パターン。
//

import SwiftUI
import SwiftData

struct ConceptPageEditSheet: View {
    let conceptPage: ConceptPage
    let store: ConceptPageStore

    @Environment(\.dismiss) private var dismiss
    @Query private var allPages: [ConceptPage]

    @State private var editedName: String = ""
    @State private var selectedMergeTarget: ConceptPage?
    @State private var showDeleteConfirm: Bool = false
    @State private var showMergeConfirm: Bool = false
    @State private var errorMessage: String?

    /// merge 候補は同 categoryRaw、自分自身を除く ConceptPage。
    private var mergeCandidates: [ConceptPage] {
        let myID = conceptPage.id
        let myCategory = conceptPage.categoryRaw
        return allPages
            .filter { $0.id != myID && $0.categoryRaw == myCategory }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Form {
                renameSection
                if !mergeCandidates.isEmpty {
                    mergeSection
                }
                deleteSection
            }
            .navigationTitle("ConceptPage.editSheet.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ConceptPage.editSheet.cancel") {
                        dismiss()
                    }
                }
            }
            .alert("ConceptPage.editSheet.deleteConfirmTitle", isPresented: $showDeleteConfirm) {
                Button("ConceptPage.editSheet.delete", role: .destructive) {
                    performDelete()
                }
                Button("ConceptPage.editSheet.cancel", role: .cancel) {}
            } message: {
                Text("ConceptPage.editSheet.deleteConfirmMessage")
            }
            .alert("ConceptPage.editSheet.mergeConfirmTitle", isPresented: $showMergeConfirm) {
                Button("ConceptPage.editSheet.merge", role: .destructive) {
                    performMerge()
                }
                Button("ConceptPage.editSheet.cancel", role: .cancel) {}
            } message: {
                if let target = selectedMergeTarget {
                    Text(String(
                        format: String(localized: "ConceptPage.editSheet.mergeConfirmMessage"),
                        conceptPage.name,
                        target.name
                    ))
                } else {
                    Text("")
                }
            }
            .alert(
                "エラー",
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
                editedName = conceptPage.name
            }
        }
    }

    // MARK: - Sections

    private var renameSection: some View {
        Section("ConceptPage.editSheet.rename") {
            TextField("ConceptPage.editSheet.namePlaceholder", text: $editedName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("conceptPageEditSheet_nameField")
            Button("ConceptPage.editSheet.save") {
                performRename()
            }
            .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || editedName == conceptPage.name)
            .accessibilityIdentifier("conceptPageEditSheet_renameButton")
        }
    }

    private var mergeSection: some View {
        Section("ConceptPage.editSheet.merge") {
            Picker("ConceptPage.editSheet.pickMergeTarget", selection: $selectedMergeTarget) {
                Text("—").tag(nil as ConceptPage?)
                ForEach(mergeCandidates, id: \.id) { candidate in
                    Text(candidate.name).tag(candidate as ConceptPage?)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("conceptPageEditSheet_mergePicker")
            Button("ConceptPage.editSheet.pickMergeTarget") {
                showMergeConfirm = true
            }
            .disabled(selectedMergeTarget == nil)
            .accessibilityIdentifier("conceptPageEditSheet_mergeButton")
        }
    }

    private var deleteSection: some View {
        Section {
            Button("ConceptPage.editSheet.delete", role: .destructive) {
                showDeleteConfirm = true
            }
            .accessibilityIdentifier("conceptPageEditSheet_deleteButton")
        }
    }

    // MARK: - Actions

    private func performRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try store.rename(conceptPage, to: trimmed)
            dismiss()
        } catch let error as ConceptPageStoreError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performMerge() {
        guard let target = selectedMergeTarget else { return }
        do {
            try store.merge(source: conceptPage, into: target)
            dismiss()
        } catch let error as ConceptPageStoreError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performDelete() {
        do {
            try store.delete(conceptPage)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
