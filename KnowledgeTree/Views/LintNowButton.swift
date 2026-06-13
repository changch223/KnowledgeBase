//
//  LintNowButton.swift
//  KnowledgeTree
//
//  spec 058 — Settings 内「今すぐ整理する」 button。
//  tap で Lint loop 即時実行、完了後 toast でサマリ表示。
//  60 秒 debounce で連打防止。
//

import SwiftUI

struct LintNowButton: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refreshTrigger

    @State private var isRunning: Bool = false
    @State private var lastRunCompletedAt: Date?
    @State private var lastResult: LintLoopResult?
    @State private var showResultAlert: Bool = false
    /// spec 076: 今周回の残り未整理タグ数 (進捗表示)。
    @State private var remainingTags: Int = 0

    private static let debounceSeconds: TimeInterval = 60
    /// spec 076: 1 batch の再分類タグ数。
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
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                // spec 076: 実行中は残り件数を表示 (バッチ進捗の可視化)
                Text(isRunning && remainingTags > 0
                     ? "整理中… (残り \(remainingTags))"
                     : NSLocalizedString("settings.lintNow.button", comment: ""))
                    .font(.body)
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

        // spec 076: 1 周完走するまで batch を回す。各 batch で進捗 (残り件数) を反映。
        // 途中で View が消える等で Task が cancel されても、lastLintedAt + マーカーが永続化
        // されているので次回押下時は続きから再開する (1 からやり直さない)。
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
            showResultAlert = true
        }
        refreshTrigger.bump()
    }
}
