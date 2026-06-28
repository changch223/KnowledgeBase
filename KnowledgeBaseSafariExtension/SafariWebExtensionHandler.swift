//
//  SafariWebExtensionHandler.swift
//  KnowledgeTreeSafariExtension
//
//  spec 020 — Safari Web Extension からの native message を受信し、
//  ArticleSavingActor 経由で SwiftData に保存する handler。
//
//  受信 actions:
//  - "saveURL": 即時保存 (toolbar tap or auto mode 経由、URL + title 受信)
//  - "getAutoSaveSettings": App Group UserDefaults から自動保存設定を返す
//

import SafariServices
import Foundation
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private let logger = Logger(subsystem: "app.KnowledgeTree.SafariExtension", category: "handler")

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        guard let dict = message as? [String: Any],
              let action = dict["action"] as? String else {
            // 不明なメッセージは silent skip
            context.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        switch action {
        case "saveURL":
            handleSaveURL(message: dict, context: context)
        case "getAutoSaveSettings":
            handleGetAutoSaveSettings(context: context)
        default:
            logger.notice("unknown action: \(action, privacy: .public)")
            context.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func handleSaveURL(message: [String: Any], context: NSExtensionContext) {
        guard let url = message["url"] as? String, !url.isEmpty else {
            context.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        let title = message["title"] as? String ?? ""

        Task { @MainActor in
            try? await ArticleSavingActor.shared.save(url: url, title: title)
            context.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func handleGetAutoSaveSettings(context: NSExtensionContext) {
        // 診断 log: Mac Console.app で subsystem "app.KnowledgeTree.SafariExtension" でフィルタ
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        logger.notice("[settings] App Group ID: \(AppGroup.identifier, privacy: .public)")
        logger.notice("[settings] UserDefaults suite: \(defaults != nil ? "OK" : "NIL", privacy: .public)")

        let autoEnabled = defaults?.bool(forKey: "settings.safari.autoSaveEnabled") ?? false

        // delaySeconds は default 10 (UserDefaults に存在しなければ)
        let storedDelay = defaults?.object(forKey: "settings.safari.autoSaveDelaySeconds") as? Int
        let delaySeconds = storedDelay ?? 10

        logger.notice("[settings] autoEnabled=\(autoEnabled, privacy: .public) delay=\(delaySeconds, privacy: .public)")

        let payload: [String: Any] = [
            "autoSaveEnabled": autoEnabled,
            "autoSaveDelaySeconds": delaySeconds
        ]

        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [SFExtensionMessageKey: payload]
        } else {
            response.userInfo = ["message": payload]
        }

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
