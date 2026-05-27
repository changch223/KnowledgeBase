//
//  AddArticleSheet.swift
//  KnowledgeTree
//
//  spec 056 — FAB tap で表示する URL 入力 modal sheet。
//  URL validation (http/https) + 重複検知 + 既存 ArticleSavingService 経由保存。
//

import SwiftUI
import SwiftData

struct AddArticleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var urlText: String = ""
    @State private var errorMessage: String?
    @State private var isProcessing: Bool = false
    @State private var showDuplicateAlert: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("addArticle.url.placeholder", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("addArticle.urlField")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("addArticle.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        Task { await save() }
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                    .accessibilityIdentifier("addArticle.saveButton")
                }
            }
            .alert("addArticle.duplicate.title", isPresented: $showDuplicateAlert) {
                Button("common.ok", role: .cancel) {
                    dismiss()
                }
            }
        }
        .accessibilityIdentifier("sheet.addArticle")
    }

    private func save() async {
        isProcessing = true
        defer { isProcessing = false }
        errorMessage = nil

        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            errorMessage = String(localized: "addArticle.error.invalidURL")
            return
        }

        // 既存 ArticleSavingService を local 構築 (ServiceContainer に入っていないため)
        let store = SwiftDataArticleStore(context: context)
        let service = DefaultArticleSavingService(store: store)
        let result = await service.save(url: url, suppliedTitle: nil)

        switch result {
        case .saved:
            dismiss()
        case .duplicate:
            showDuplicateAlert = true
        case .missingURL, .unsupportedScheme:
            errorMessage = String(localized: "addArticle.error.invalidURL")
        case .persistenceFailure:
            errorMessage = String(localized: "addArticle.error.saveFailed")
        }
    }
}
