//
//  CorrectionResultBanner.swift
//  KnowledgeTree
//
//  spec 096 — 本文見直しフローの各段階を ArticleDetailView 上に見せるバナー群。
//  - CorrectionProgressBanner: 見直し中 / 知識作り直し中の進捗
//  - ReviewCompleteBanner: 見直し完了 → 確認を促す通知
//  - CorrectionResultBanner: 完了後「何が変わったか」の結果レポート
//  - CorrectionChangesList: before → after の変更一覧 (バナー / 確認シート共用)
//

import SwiftUI

/// before → after の変更一覧 (重複は ×件数)。バナーと確認シートで共用。
struct CorrectionChangesList: View {
    let changes: [CorrectionChange]
    let total: Int
    let detailAvailable: Bool

    var body: some View {
        if !detailAvailable {
            Text("detail.correct.result.noDetail")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if changes.isEmpty {
            Text("detail.correct.result.none")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(changes) { change in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(change.before.isEmpty ? "—" : change.before)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(change.after.isEmpty ? "—" : change.after)
                            .font(.caption.weight(.semibold))
                        if change.count > 1 {
                            Text("×\(change.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// 見直し中 / 知識作り直し中の進捗バナー。
struct CorrectionProgressBanner: View {
    let progress: CorrectionProgress?

    private var message: LocalizedStringKey {
        guard let progress else { return "detail.correct.banner" }
        switch progress.phase {
        case .reExtracting:
            return "detail.correct.progress.reextract"
        case .correcting:
            return "detail.correct.progress.review"
        }
    }

    private var showsBar: Bool {
        guard let progress else { return false }
        return progress.phase == .correcting && progress.total > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: 10) {
                ProgressView()
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if showsBar, let progress {
                ProgressView(value: Double(progress.current), total: Double(max(progress.total, 1)))
                Text(String(format: String(localized: "detail.correct.progress.counts"),
                            progress.current, progress.total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("detail.correct.progress.hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(DS.Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("articleDetail.correctionBanner")
    }
}

/// アプリ全体の上部に出す「見直し完了」通知バナー (どの画面に居ても気づける)。
struct ReviewCompleteTopBanner: View {
    let count: Int
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("detail.review.complete.title")
                    .font(.callout.weight(.semibold))
                Text(String(format: String(localized: "detail.review.complete.subtitle"), count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("detail.review.complete.action", action: onConfirm)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(DS.Spacing.lg)
        .background(.regularMaterial)
        .accessibilityIdentifier("banner.reviewComplete")
    }
}

/// 完了後の結果レポート (何が変わったか)。
struct CorrectionResultBanner: View {
    let result: CorrectionResult
    let onDismiss: () -> Void

    @State private var showDetails: Bool = false

    private var titleText: String {
        if !result.changed {
            return String(localized: "detail.correct.result.none")
        }
        if result.detailAvailable {
            return String(format: String(localized: "detail.correct.result.changed"), result.total)
        }
        return String(localized: "detail.correct.result.changedNoDetail")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: result.changed ? "checkmark.circle.fill" : "info.circle.fill")
                    .foregroundStyle(result.changed ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.subheadline.weight(.semibold))
                    if result.changed {
                        Text(String(format: String(localized: "detail.correct.result.counts"),
                                    result.originalCount, result.correctedCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.close")
            }

            if result.changed, !result.changes.isEmpty {
                DisclosureGroup(isExpanded: $showDetails) {
                    CorrectionChangesList(
                        changes: result.changes, total: result.total, detailAvailable: result.detailAvailable
                    )
                    .padding(.top, 4)
                } label: {
                    Text("detail.correct.result.details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(DS.Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("articleDetail.correctionResult")
    }
}
