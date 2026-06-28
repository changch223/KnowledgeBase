//
//  ReaderToolbar.swift
//  KnowledgeTree
//
//  spec 003 — Reader View の toolbar (完了 + 元記事を開く)
//

import SwiftUI

struct ReaderToolbar: ToolbarContent {
    let onDone: () -> Void
    let onOpenOriginal: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("reader.doneButton", action: onDone)
                .accessibilityIdentifier("readerDoneButton")
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: onOpenOriginal) {
                Label("reader.openOriginalButton", systemImage: "safari")
            }
            .accessibilityIdentifier("readerOpenOriginalButton")
        }
    }
}
