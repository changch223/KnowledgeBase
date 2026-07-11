//
//  LanguageMismatchBanner.swift
//  KnowledgeTree
//
//  全タブ共通のトップバナー。端末の言語設定と AI 生成言語 (PipelineLanguage) がズレているとき、
//  起動時に 1 回だけ気づかせる (AIAvailabilityBanner と同じ見た目の文法を踏襲)。
//  タップで生成言語の設定画面 (LanguageSettingsView) をシート表示、✕ / シートを閉じた場合の
//  どちらでも「案内済み」を記録し、以後は同じ組み合わせでは二度と出さない。
//

import SwiftUI

struct LanguageMismatchBanner: View {
    let pipelineEndonym: String
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "globe")
                .foregroundStyle(DS.Color.actionBlue)
                .frame(width: 20)
            Text("langMismatch.banner.body \(pipelineEndonym)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: DS.Spacing.sm)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(Text("common.close"))
            .accessibilityIdentifier("langMismatch.topBanner.dismiss")
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.vertical, DS.Spacing.lg)
        .background(.regularMaterial)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityIdentifier("langMismatch.topBanner")
    }
}

/// アプリルートの safeAreaInset に置く LanguageMismatchBanner のホスト View。
/// 表示対象は起動時 1 回の判定で決まる (親から Binding で受け取る、リアルタイム再判定はしない)。
/// バナー ✕ / シートを閉じるのどちらでも「案内済み」を記録して自身を非表示にする。
struct LanguageMismatchBannerHost: View {
    /// バナー表示対象の生成言語。nil なら非表示。閉じると nil に戻す。
    @Binding var pipelineToNotify: PipelineLanguage?
    var store: LanguageMismatchNotificationStore = UserDefaultsLanguageMismatchNotificationStore()

    @State private var showLanguageSettings: Bool = false

    var body: some View {
        if let pipeline = pipelineToNotify {
            LanguageMismatchBanner(
                pipelineEndonym: pipeline.endonym,
                onTap: { showLanguageSettings = true },
                onDismiss: { markNotified() }
            )
            .sheet(isPresented: $showLanguageSettings, onDismiss: { markNotified() }) {
                NavigationStack {
                    LanguageSettingsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("common.close") { showLanguageSettings = false }
                            }
                        }
                }
            }
        }
    }

    /// 案内済みの組を記録し、バナーを非表示にする (✕ タップ / シートを閉じた場合の共通処理)。
    /// シート内で言語を変更してから閉じた場合に備え、バナー表示開始時に捕まえた `pipelineToNotify`
    /// ではなく **書き込み時点** の実際の生成言語 (`PipelineLanguage.current`) を読んで記録する
    /// (旧値のまま書くと、シート内の変更で既に記録済みの新しい combo を古い値で上書きしてしまう。
    /// `LanguageSettingsView` 側の記録と一致する場合は同じ値になるため二重書き込みは無害)。
    private func markNotified() {
        LanguageMismatchDetector.markResolved(
            devicePreferred: Locale.preferredLanguages,
            pipeline: PipelineLanguage.current,
            store: store
        )
        pipelineToNotify = nil
    }
}
