//
//  ArticleCorrectionSheet.swift
//  KnowledgeTree
//
//  spec 095 — ユーザーが自然言語で記事本文を訂正する。
//  例:「cloudecod ではなく Claude Code です」と指示 → LLM が本文に適用 →
//  本文を更新し、AI の知識 (概念ページ・タグ・要点) を再生成する。
//  処理は ArticleCorrectionCoordinator が継続実行するため、この画面を閉じても続く。
//

import SwiftUI
import SwiftData

struct ArticleCorrectionSheet: View {
    let article: Article

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refresh

    @State private var instruction: String = ""
    @State private var didStart: Bool = false
    @State private var errorMessage: String?

    private let corrector: TranscriptCorrecting =
        LLMTranscriptCorrectionService(session: FoundationModelLanguageModelSession())

    private var isCorrecting: Bool {
        services.correctionCoordinator?.isCorrecting(article) ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                if didStart || isCorrecting {
                    // 開始済み: 進捗 + 「閉じても続く」明示。
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("detail.correct.running")
                                    .font(.subheadline.weight(.semibold))
                                Text("detail.correct.keepsRunning")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section {
                        TextField("detail.correct.placeholder", text: $instruction, axis: .vertical)
                            .lineLimit(3...8)
                            .accessibilityIdentifier("articleCorrect.instructionField")
                    } footer: {
                        Text("detail.correct.footer")
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("detail.correct.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didStart ? "common.close" : "common.cancel") { dismiss() }
                }
                if !didStart {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("detail.correct.run") { start() }
                            .disabled(instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func start() {
        guard let coordinator = services.correctionCoordinator else { return }
        guard let body = article.body,
              let text = body.extractedText,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = String(localized: "detail.correct.error.noBody")
            return
        }
        coordinator.start(
            article: article,
            instruction: instruction,
            corrector: corrector,
            knowledgeService: services.knowledgeService,
            modelContext: modelContext,
            refresh: refresh
        )
        didStart = true
    }
}
