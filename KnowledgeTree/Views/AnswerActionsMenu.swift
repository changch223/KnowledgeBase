//
//  AnswerActionsMenu.swift
//  KnowledgeTree
//
//  spec 057 — assistant 答え bubble の long press (.contextMenu) で表示する
//  3 action menu: 保存 / コピー / 共有。ChatGPT/Gemini と同パターン。
//

import SwiftUI
import UIKit

struct AnswerActionsMenu: View {
    let question: String
    let answer: String
    let citedArticleIDs: [UUID]
    let onSave: () -> Void

    var body: some View {
        Group {
            Button {
                onSave()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("answer.actions.save", systemImage: "star")
            }
            .accessibilityIdentifier("answer.action.save")

            Button {
                UIPasteboard.general.string = answer
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("answer.actions.copy", systemImage: "doc.on.doc")
            }
            .accessibilityIdentifier("answer.action.copy")

            ShareLink(item: answer) {
                Label("answer.actions.share", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("answer.action.share")
        }
    }
}
