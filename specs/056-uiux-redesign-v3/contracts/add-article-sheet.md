# Contract: AddArticleSheet

## Purpose

FAB tap で表示する URL 入力 modal sheet。手動で記事を追加できる新動線。

## View

```swift
struct AddArticleSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @Environment(ServiceContainer.self) var services
    
    @State private var urlText = ""
    @State private var errorMessage: String?
    @State private var existingArticle: Article?
    @State private var isProcessing = false
    
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
                    Button("common.save") { save() }
                        .disabled(urlText.isEmpty || isProcessing)
                        .accessibilityIdentifier("addArticle.saveButton")
                }
            }
            .alert(
                "addArticle.duplicate.title",
                isPresented: .constant(existingArticle != nil),
                presenting: existingArticle
            ) { article in
                Button("addArticle.duplicate.open") {
                    // 既存記事ジャンプ (navigation)
                    dismiss()
                    // 上位 view に通知 (TODO: NavigationPath 経由)
                }
                Button("common.ok", role: .cancel) {
                    existingArticle = nil
                }
            } message: { article in
                Text(article.title)
            }
        }
        .accessibilityIdentifier("sheet.addArticle")
    }
    
    private func save() {
        isProcessing = true
        defer { isProcessing = false }
        
        // 1. URL validation
        guard let url = URL(string: urlText),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            errorMessage = String(localized: "addArticle.error.invalidURL")
            return
        }
        
        // 2. 重複検知
        let urlStr = url.absoluteString
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.url == urlStr }
        )
        if let existing = try? context.fetch(descriptor).first {
            existingArticle = existing
            return
        }
        
        // 3. 保存 (既存 ArticleSavingService)
        Task {
            do {
                _ = try await services.articleSavingService.save(url: url)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = String(localized: "addArticle.error.saveFailed")
                }
            }
        }
    }
}
```

## Validation

- URL scheme は http or https のみ受付
- 空欄なら保存ボタン disabled
- 重複 URL は alert + 既存記事ジャンプ option

## アクセシビリティ

- `sheet.addArticle`
- `addArticle.urlField`
- `addArticle.saveButton`

## xcstrings 追加

- `addArticle.title` = "記事を追加"
- `addArticle.url.placeholder` = "URL を入力"
- `addArticle.error.invalidURL` = "有効な URL を入力してください"
- `addArticle.error.saveFailed` = "保存に失敗しました"
- `addArticle.duplicate.title` = "既に保存済です"
- `addArticle.duplicate.open` = "開く"
- `common.cancel` = "キャンセル"
- `common.save` = "保存"
- `common.ok` = "OK"
