//
//  LintNowButton.swift
//  KnowledgeTree
//
//  spec 058 — Settings 内「今すぐ検知・修正する」 button。
//  tap で Lint loop 即時実行、完了後 alert でサマリ表示。
//  60 秒 debounce で連打防止。アイコンなし、件数非表示。
//

import SwiftUI

struct LintNowButton: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refreshTrigger

    @State private var isRunning: Bool = false
    @State private var lastRunCompletedAt: Date?
    @State private var lastResult: LintLoopResult?
    @State private var showResultAlert: Bool = false
    @State private var remainingTags: Int = 0

    private static let debounceSeconds: TimeInterval = 60
    private static let batchSize: Int = 15

    private var isDebounced: Bool {
        guard let lastRunCompletedAt else { return false }
        return Date.now.timeIntervalSince(lastRunCompletedAt) < Self.debounceSeconds
    }

    var body: some View {
        Button {
            Task { await run() }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if isRunning {
                    ProgressView().controlSize(.small)
                }
                if isRunning {
                    Text(remainingTags > 0
                         ? "検知・修正中… (残り \(remainingTags))"
                         : NSLocalizedString("settings.lintNow.button.running", comment: ""))
                        .font(.body)
                } else {
                    Text("settings.lintNow.button")
                        .font(.body)
                }
            }
        }
        .disabled(isRunning || isDebounced)
        .accessibilityIdentifier("settings.lintNowButton")
        .alert("settings.lintNow.result.title", isPresented: $showResultAlert, presenting: lastResult) { _ in
            Button("common.ok", role: .cancel) {}
        } message: { result in
            Text("settings.lintNow.result.summary \(result.totalOperations)")
        }
    }

    private func run() async {
        guard let engine = services.lintEngine else { return }
        isRunning = true
        defer { isRunning = false; remainingTags = 0 }

        var accumulated = LintLoopResult()
        var complete = false
        while !complete {
            if Task.isCancelled { break }
            let batch = await engine.runBatch(maxTags: Self.batchSize)
            accumulated.mergedCount += batch.mergedCount
            accumulated.deletedConceptPageCount += batch.deletedConceptPageCount
            accumulated.deletedTagCount += batch.deletedTagCount
            accumulated.linkedCount += batch.linkedCount
            accumulated.reclassifiedCount += batch.reclassifiedCount
            accumulated.refreshedSavedAnswerCount += batch.refreshedSavedAnswerCount
            remainingTags = batch.remainingTags
            complete = batch.loopComplete
        }

        if complete {
            accumulated.loopComplete = true
            lastResult = accumulated
            lastRunCompletedAt = .now
            LintRunStore.markRan()
            showResultAlert = true
        }
        refreshTrigger.bump()
    }
}
