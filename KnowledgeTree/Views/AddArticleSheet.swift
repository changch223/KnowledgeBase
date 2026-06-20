//
//  AddArticleSheet.swift
//  KnowledgeTree
//
//  spec 056 — FAB tap で表示する追加 modal sheet。
//  spec 091 — URL に加え「メモ (手動テキスト)」も追加できるよう 2 モード化。
//  URL: validation (http/https) + 重複検知 + ArticleSavingService 経由保存。
//  メモ: タイトル(任意) + 本文 → RawArticleIntake で合成 URL の raw article 化 → 知識抽出。
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI

struct AddArticleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ServiceContainer.self) private var services

    private enum Mode: String, CaseIterable, Identifiable {
        case url, note, file, image, audio
        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            switch self {
            case .url: return "addArticle.mode.url"
            case .note: return "addArticle.mode.note"
            case .file: return "addArticle.mode.file"
            case .image: return "addArticle.mode.image"
            case .audio: return "addArticle.mode.audio"
            }
        }
    }

    /// fileImporter で取り込める型 (PDF / プレーンテキスト / Markdown 等)。
    /// `.text` は public.text の上位型で .md も含むが、確実に選べるよう Markdown を明示追加。
    private static let importableTypes: [UTType] = {
        var types: [UTType] = [.pdf, .plainText, .text]
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let markdown = UTType("net.daringfireball.markdown") { types.append(markdown) }
        return types
    }()

    private let ocrService: OCRServicing = VisionOCRService()
    private let audioService: AudioTranscribing = AudioTranscriptionService()
    private let transcriptCorrector: TranscriptCorrecting =
        LLMTranscriptCorrectionService(session: FoundationModelLanguageModelSession())

    @State private var mode: Mode = .url
    @State private var urlText: String = ""
    @State private var noteTitle: String = ""
    @State private var noteBody: String = ""
    @State private var pickedFileURL: URL?
    @State private var pickedFileName: String?
    @State private var showFileImporter: Bool = false
    @State private var photoItem: PhotosPickerItem?
    @State private var ocrText: String = ""
    @State private var isOCRRunning: Bool = false
    @State private var showAudioImporter: Bool = false
    @State private var pickedAudioName: String?
    @State private var audioText: String = ""
    @State private var isTranscribing: Bool = false
    @State private var errorMessage: String?
    @State private var isProcessing: Bool = false
    @State private var showDuplicateAlert: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("addArticle.mode.label", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.titleKey).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("addArticle.modePicker")

                switch mode {
                case .url:
                    Section {
                        TextField("addArticle.url.placeholder", text: $urlText)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("addArticle.urlField")
                    }
                case .note:
                    Section {
                        TextField("addArticle.note.titlePlaceholder", text: $noteTitle)
                            .accessibilityIdentifier("addArticle.noteTitleField")
                        TextField("addArticle.note.bodyPlaceholder", text: $noteBody, axis: .vertical)
                            .lineLimit(6...20)
                            .accessibilityIdentifier("addArticle.noteBodyField")
                    } footer: {
                        Text("addArticle.note.footer")
                    }
                case .file:
                    Section {
                        Button {
                            showFileImporter = true
                        } label: {
                            Label(
                                pickedFileName ?? String(localized: "addArticle.file.choose"),
                                systemImage: "doc.badge.plus"
                            )
                        }
                        .accessibilityIdentifier("addArticle.fileChooseButton")
                    } footer: {
                        Text("addArticle.file.footer")
                    }
                case .image:
                    Section {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("addArticle.image.choose", systemImage: "photo.badge.plus")
                        }
                        .accessibilityIdentifier("addArticle.imagePickerButton")

                        if isOCRRunning {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("addArticle.image.recognizing")
                                    .foregroundStyle(.secondary)
                            }
                        } else if !ocrText.isEmpty {
                            TextField("addArticle.note.bodyPlaceholder", text: $ocrText, axis: .vertical)
                                .lineLimit(6...20)
                                .accessibilityIdentifier("addArticle.ocrTextField")
                        }
                    } footer: {
                        Text("addArticle.image.footer")
                    }
                case .audio:
                    Section {
                        Button {
                            showAudioImporter = true
                        } label: {
                            Label(
                                pickedAudioName ?? String(localized: "addArticle.audio.choose"),
                                systemImage: "waveform"
                            )
                        }
                        .accessibilityIdentifier("addArticle.audioChooseButton")

                        if isTranscribing {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("addArticle.audio.transcribing")
                                    .foregroundStyle(.secondary)
                            }
                        } else if !audioText.isEmpty {
                            TextField("addArticle.note.bodyPlaceholder", text: $audioText, axis: .vertical)
                                .lineLimit(6...20)
                                .accessibilityIdentifier("addArticle.audioTextField")
                        }
                    } footer: {
                        Text("addArticle.audio.footer")
                    }
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
                    .disabled(!canSave || isProcessing)
                    .accessibilityIdentifier("addArticle.saveButton")
                }
            }
            .alert("addArticle.duplicate.title", isPresented: $showDuplicateAlert) {
                Button("common.ok", role: .cancel) { dismiss() }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: Self.importableTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        pickedFileURL = url
                        pickedFileName = url.lastPathComponent
                        errorMessage = nil
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task { await runOCR(on: newItem) }
            }
            .fileImporter(
                isPresented: $showAudioImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        pickedAudioName = url.lastPathComponent
                        errorMessage = nil
                        Task { await runTranscription(on: url) }
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
        .accessibilityIdentifier("sheet.addArticle")
    }

    private var canSave: Bool {
        switch mode {
        case .url: return !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .note: return !noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file: return pickedFileURL != nil
        case .image: return !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .audio: return !audioText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func save() async {
        isProcessing = true
        defer { isProcessing = false }
        errorMessage = nil

        switch mode {
        case .url:
            await saveURL()
        case .note:
            saveNote()
        case .file:
            saveFile()
        case .image:
            saveImage()
        case .audio:
            saveAudio()
        }
    }

    private func runTranscription(on url: URL) async {
        isTranscribing = true
        audioText = ""
        errorMessage = nil
        defer { isTranscribing = false }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let raw = try await audioService.transcribe(fileURL: url)
            if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMessage = String(localized: "addArticle.audio.error.noText")
            } else {
                // spec 094: 既知の用語集で誤認識を補正してからプレビュー表示。
                let glossary = TranscriptGlossaryBuilder.build(context: context)
                audioText = await transcriptCorrector.correct(raw, glossary: glossary)
            }
        } catch AudioTranscriptionError.unauthorized {
            errorMessage = String(localized: "addArticle.audio.error.unauthorized")
        } catch {
            errorMessage = String(localized: "addArticle.audio.error.failed")
        }
    }

    private func saveAudio() {
        let result = RawArticleIntake.save(
            into: context,
            title: pickedAudioName,
            bodyText: audioText,
            source: .audio
        )
        handle(result)
    }

    private func runOCR(on item: PhotosPickerItem) async {
        isOCRRunning = true
        ocrText = ""
        errorMessage = nil
        defer { isOCRRunning = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = String(localized: "addArticle.image.error.unreadable")
            return
        }
        let recognized = await ocrService.recognizeText(in: data)
        if recognized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = String(localized: "addArticle.image.error.noText")
        } else {
            ocrText = recognized
        }
    }

    private func saveImage() {
        let result = RawArticleIntake.save(
            into: context,
            title: nil,
            bodyText: ocrText,
            source: .image
        )
        handle(result)
    }

    private func saveURL() async {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            errorMessage = String(localized: "addArticle.error.invalidURL")
            return
        }
        let store = SwiftDataArticleStore(context: context)
        let service = DefaultArticleSavingService(store: store)
        let result = await service.save(url: url, suppliedTitle: nil)
        handle(result)
    }

    private func saveNote() {
        let result = RawArticleIntake.save(
            into: context,
            title: noteTitle,
            bodyText: noteBody,
            source: .note
        )
        handle(result)
    }

    private func saveFile() {
        guard let url = pickedFileURL else { return }
        guard let extracted = RawArticleIntake.extractFile(at: url) else {
            errorMessage = String(localized: "addArticle.file.error.unreadable")
            return
        }
        let result = RawArticleIntake.save(
            into: context,
            title: extracted.title,
            bodyText: extracted.body,
            source: .file
        )
        handle(result)
    }

    private func handle(_ result: SaveResult) {
        switch result {
        case .saved:
            // spec 091: 本文ありで保存済 → 知識抽出を即時起動 (要点・概念・タグ生成)。
            Task { await services.knowledgeService?.backfillAll() }
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
