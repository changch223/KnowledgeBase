//
//  TranscriptReviewConfirmSheet.swift
//  KnowledgeTree
//
//  spec 096 — 見直し完了後の確認画面。
//  AI が直した候補本文の「変更点レポート」を見せ、必要なら本文を直接編集して最終チェックし、
//  「確定」で初めて本文を反映し、知識 (概念・タグ・要点) を 1 回だけ作り直す。
//  「やめる」で候補を破棄 (本文は未変更)。
//

import SwiftUI
import SwiftData

struct TranscriptReviewConfirmSheet: View {
    let article: Article

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refresh

    @State private var text: String = ""
    @State private var loaded: Bool = false

    private var pending: PendingCorrection? {
        services.correctionCoordinator?.pendingConfirmation(for: article)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let pending {
                    Section {
                        Text(String(format: String(localized: "detail.correct.result.counts"),
                                    pending.original.count, pending.candidate.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        CorrectionChangesList(
                            changes: pending.diff.changes,
                            total: pending.diff.total,
                            detailAvailable: pending.diff.detailAvailable
                        )
                    } header: {
                        Text(String(format: String(localized: "detail.review.confirm.changesHeader"),
                                    pending.diff.total))
                    }

                    Section {
                        TextEditor(text: $text)
                            .frame(minHeight: 220)
                            .accessibilityIdentifier("reviewConfirm.bodyField")
                    } header: {
                        Text("detail.review.confirm.editHeader")
                    } footer: {
                        Text("detail.review.confirm.editFooter")
                    }
                } else {
                    Text("detail.review.confirm.missing")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("detail.review.confirm.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("detail.review.confirm.discard", role: .destructive) { discard() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("detail.review.confirm.commit") { commit() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task {
                guard !loaded, let pending else { return }
                text = pending.candidate
                loaded = true
            }
        }
    }

    private func commit() {
        services.correctionCoordinator?.confirm(
            article: article,
            finalText: text,
            knowledgeService: services.knowledgeService,
            modelContext: modelContext,
            refresh: refresh
        )
        dismiss()
    }

    private func discard() {
        services.correctionCoordinator?.discardReview(article)
        dismiss()
    }
}
