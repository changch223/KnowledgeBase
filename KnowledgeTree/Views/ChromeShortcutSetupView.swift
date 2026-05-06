//
//  ChromeShortcutSetupView.swift
//  KnowledgeTree
//
//  spec 019 — Chrome 自動保存セットアップガイド。
//  3 ステップの Step Card + 「Shortcuts アプリを開く」deeplink ボタン
//  + 「セットアップ完了」/「ガイドを見直す」切替。
//
//  Apple-quiet 路線 (gradient なし、shadow なし、actionBlue 1 色)。
//

import SwiftUI
import UIKit

struct ChromeShortcutSetupView: View {
    @AppStorage("settings.shortcutSetupCompleted") private var setupCompleted: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                // 説明文
                Text("settings.chromeSetup.description")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Step 1: Shortcuts アプリを開く (アクションボタン付き)
                stepCard(
                    number: 1,
                    titleKey: "settings.chromeSetup.step1.title",
                    descriptionKey: "settings.chromeSetup.step1.description",
                    actionButton: AnyView(openShortcutsButton)
                )

                // Step 2: 自動化を作成
                stepCard(
                    number: 2,
                    titleKey: "settings.chromeSetup.step2.title",
                    descriptionKey: "settings.chromeSetup.step2.description",
                    actionButton: nil
                )

                // Step 3: アクションを追加
                stepCard(
                    number: 3,
                    titleKey: "settings.chromeSetup.step3.title",
                    descriptionKey: "settings.chromeSetup.step3.description",
                    actionButton: nil
                )

                // 完了 / リセット ボタン
                if setupCompleted {
                    Button("settings.chromeSetup.resetLink") {
                        setupCompleted = false
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, DS.Spacing.md)
                    .accessibilityIdentifier("settings.chromeSetup.resetButton")
                } else {
                    Button {
                        setupCompleted = true
                    } label: {
                        Text("settings.chromeSetup.completeButton")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Color.actionBlue)
                    .padding(.top, DS.Spacing.md)
                    .accessibilityIdentifier("settings.chromeSetup.completeButton")
                }
            }
            .padding(DS.Spacing.xxl)
        }
        .navigationTitle("settings.chromeSetup.title")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.chromeSetup.root")
    }

    // MARK: - Subviews

    private var openShortcutsButton: some View {
        Button {
            if let url = URL(string: "shortcuts://") {
                UIApplication.shared.open(url)
            }
        } label: {
            Label("settings.chromeSetup.openShortcutsButton", systemImage: "arrow.up.forward.app")
        }
        .buttonStyle(.bordered)
        .tint(DS.Color.actionBlue)
        .accessibilityIdentifier("settings.chromeSetup.openShortcutsButton")
    }

    @ViewBuilder
    private func stepCard(
        number: Int,
        titleKey: LocalizedStringKey,
        descriptionKey: LocalizedStringKey,
        actionButton: AnyView?
    ) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DS.Color.actionBlue)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(titleKey)
                    .font(DS.Typography.sectionTitle)
                Text(descriptionKey)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let actionButton {
                    actionButton.padding(.top, DS.Spacing.sm)
                }
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
    }
}
