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

    private static let debounceSeconds: TimeInterval = 60

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
                Text("settings.lintNow.button")
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
        defer { isRunning = false }

        let result = await engine.runFullLintLoop()
        lastResult = result
        lastRunCompletedAt = .now
        showResultAlert = true
        refreshTrigger.bump()
    }
}
