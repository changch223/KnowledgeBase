//
//  ShareViewController.swift
//  KnowledgeTreeShareExtension
//
//  spec 001 / US1 / research.md R2 + R6
//

import UIKit
import SwiftData
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        statusLabel.text = NSLocalizedString("share.savedConfirmation", comment: "")
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.accessibilityIdentifier = "shareExtensionStatusLabel"
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { @MainActor in
            await processShare()
        }
    }

    @MainActor
    private func processShare() async {
        let item = await extractReceivedItem()
        let result = await save(item: item)
        showResult(result)
        try? await Task.sleep(for: .seconds(1))
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func extractReceivedItem() async -> ShareReceivedItem {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            return ShareReceivedItem(url: nil, suppliedTitle: nil)
        }

        let suppliedTitle = extensionItem.attributedTitle?.string
        let contentText = extensionItem.attributedContentText?.string

        // (1) URL 共有 (既存): Web ページ / リンク。
        if let urlAttachment = extensionItem.attachments?.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) {
            let url: URL? = await withCheckedContinuation { continuation in
                urlAttachment.loadItem(forTypeIdentifier: UTType.url.identifier) { value, _ in
                    continuation.resume(returning: value as? URL)
                }
            }
            if let url, url.scheme?.lowercased().hasPrefix("http") == true {
                return ShareReceivedItem(url: url, suppliedTitle: suppliedTitle ?? contentText)
            }
        }

        // (2) spec 091: PDF 共有 (Gmail 添付など)。
        if let pdfAttachment = extensionItem.attachments?.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
        }) {
            let data: Data? = await withCheckedContinuation { continuation in
                pdfAttachment.loadItem(forTypeIdentifier: UTType.pdf.identifier) { value, _ in
                    if let d = value as? Data {
                        continuation.resume(returning: d)
                    } else if let url = value as? URL, let d = try? Data(contentsOf: url) {
                        continuation.resume(returning: d)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            if let data,
               let parsed = PDFFetcher.parse(data: data, sourceURL: URL(fileURLWithPath: suppliedTitle ?? "shared.pdf")),
               !parsed.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ShareReceivedItem(url: nil, suppliedTitle: parsed.title, text: parsed.fullText, intakeSource: .file)
            }
        }

        // (3) spec 091: ファイル URL 共有 (md / txt / その他テキスト、PDF が fileURL で来る場合も)。
        if let fileAttachment = extensionItem.attachments?.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) {
            let fileURL: URL? = await withCheckedContinuation { continuation in
                fileAttachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { value, _ in
                    continuation.resume(returning: value as? URL)
                }
            }
            if let fileURL, let extracted = RawArticleIntake.extractFile(at: fileURL) {
                return ShareReceivedItem(url: nil, suppliedTitle: extracted.title, text: extracted.body, intakeSource: .file)
            }
        }

        // (4) spec 091: テキスト共有 (メモ / メール本文 / 選択テキスト)。
        if let textAttachment = extensionItem.attachments?.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                || $0.hasItemConformingToTypeIdentifier(UTType.text.identifier)
        }) {
            let typeID = textAttachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                ? UTType.plainText.identifier : UTType.text.identifier
            let loaded: String? = await withCheckedContinuation { continuation in
                textAttachment.loadItem(forTypeIdentifier: typeID) { value, _ in
                    if let s = value as? String {
                        continuation.resume(returning: s)
                    } else if let data = value as? Data {
                        continuation.resume(returning: String(data: data, encoding: .utf8))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            let body = loaded ?? contentText
            return ShareReceivedItem(url: nil, suppliedTitle: suppliedTitle, text: body)
        }

        // (5) attachment 無し: 共有シートが本文を attributedContentText に乗せる場合。
        if let contentText, !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ShareReceivedItem(url: nil, suppliedTitle: suppliedTitle, text: contentText)
        }

        return ShareReceivedItem(url: nil, suppliedTitle: suppliedTitle)
    }

    @MainActor
    private func save(item: ShareReceivedItem) async -> SaveResult {
        // App Group container 内の Library/Application Support を事前作成
        // (CoreData の sandbox recovery ログ抑止)
        AppGroup.ensureContainerDirectoryExists()

        let container: ModelContainer
        do {
            // spec 005: main app と完全に同一の Schema を使う。
            // Schema mismatch は cross-process state を破壊し、
            // 「閉じて再起動するまで反映されない」根本原因になる。
            let configuration = SharedSchema.sharedConfiguration()
            container = try ModelContainer(
                for: SharedSchema.all,
                configurations: configuration
            )
        } catch {
            return .persistenceFailure(String(describing: error))
        }
        // spec 091: URL が無い共有はテキスト/ファイルとして取り込む (合成 URL + 本文事前投入)。
        if item.url == nil, let text = item.text {
            return RawArticleIntake.save(
                into: container.mainContext,
                title: item.suppliedTitle,
                bodyText: text,
                source: item.intakeSource
            )
        }

        let store = SwiftDataArticleStore(context: container.mainContext)
        let service = DefaultArticleSavingService(store: store)
        return await service.save(url: item.url, suppliedTitle: item.suppliedTitle)
    }

    @MainActor
    private func showResult(_ result: SaveResult) {
        let key: String
        switch result {
        case .saved: key = "share.savedConfirmation"
        case .duplicate: key = "share.duplicateMessage"
        case .missingURL: key = "share.errorNoURL"
        case .unsupportedScheme: key = "share.errorUnsupportedScheme"
        case .persistenceFailure: key = "share.errorStorage"
        }
        statusLabel.text = NSLocalizedString(key, comment: "")
    }
}
