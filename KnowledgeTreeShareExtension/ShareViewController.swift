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
        guard
            let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
            let attachment = extensionItem.attachments?.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
            })
        else {
            return ShareReceivedItem(url: nil, suppliedTitle: nil)
        }

        let suppliedTitle = extensionItem.attributedTitle?.string
            ?? extensionItem.attributedContentText?.string

        let url: URL? = await withCheckedContinuation { continuation in
            attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { value, _ in
                continuation.resume(returning: value as? URL)
            }
        }

        return ShareReceivedItem(url: url, suppliedTitle: suppliedTitle)
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
