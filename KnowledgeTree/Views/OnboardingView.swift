//
//  OnboardingView.swift
//  KnowledgeTree
//
//  spec 049 — 初回起動 onboarding。4 ページ TabView (PageStyle) で iKnow の核を説明。
//
//  Karpathy「保存したものが時間と共に compound する」原則を最初に体験させる:
//    Page 1: ようこそ — iKnow は「あなた専用の第二の脳」
//    Page 2: 保存する — Share Sheet で記事 / PDF をどこからでも
//    Page 3: 自動で整理 — AI が概念ページ + 知識ダイジェストを作る
//    Page 4: 家庭教師と学ぶ — 「✓ わかった」で理解度を育てる
//
//  完了後 UserDefaults `iKnow_onboarding_v1_done` を true、再起動でスキップ。
//  KnowledgeTreeApp の WindowGroup root で fullScreenCover として表示。
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "brain.head.profile",
            title: "ようこそ iKnow へ",
            body: "iKnow はあなたが読んだ記事を AI が自動で整理し、必要なときに思い出せる「あなた専用の第二の脳」です。",
            highlightColor: .blue
        ),
        OnboardingPage(
            symbol: "square.and.arrow.down.on.square",
            title: "Share Sheet で保存",
            body: "Safari / Chrome / X / 他のアプリの共有メニューから「iKnow」を選ぶだけ。記事の本文 + 知識を端末内で自動抽出します。",
            highlightColor: .green
        ),
        OnboardingPage(
            symbol: "lightbulb.fill",
            title: "AI が自動で整理",
            body: "保存した記事を AI が読み、人物・モノ・概念ごとに「概念ページ」を作成。複数記事の知見を統合した最新の理解が常に手元に。",
            highlightColor: .orange
        ),
        OnboardingPage(
            symbol: "book.fill",
            title: "家庭教師と一緒に学ぶ",
            body: "「学習タブ」では AI が次に深めるべきカードを 5 つ提案。タップで家庭教師と対話、「✓ わかった」で理解度が育ちます。",
            highlightColor: .purple
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            HStack {
                if currentPage < pages.count - 1 {
                    Button("スキップ") {
                        finish()
                    }
                    .accessibilityIdentifier("onboarding.skip")
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "次へ" : "はじめる")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.xxl)
                        .padding(.vertical, DS.Spacing.lg)
                        .background(DS.Color.actionBlue, in: Capsule())
                }
                .accessibilityIdentifier("onboarding.next")
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xxxl)
        }
        .background(Color(.systemBackground))
        .accessibilityIdentifier("onboarding.root")
    }

    private func finish() {
        OnboardingFlagStore.shared.markCompleted()
        withAnimation {
            isPresented = false
        }
    }
}

// MARK: - OnboardingPage data + view

private struct OnboardingPage {
    let symbol: String
    let title: String
    let body: String
    let highlightColor: Color
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()
            Image(systemName: page.symbol)
                .font(.system(size: 96))
                .foregroundStyle(page.highlightColor)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.lg) {
                Text(page.title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xxl)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Spacer()  // ボタン用 spacing
        }
        .padding(.horizontal, DS.Spacing.xxl)
    }
}

// MARK: - OnboardingFlagStore

/// spec 049: onboarding 完了 flag を UserDefaults に永続化。
@MainActor
final class OnboardingFlagStore {
    static let shared = OnboardingFlagStore()
    private let key = "iKnow_onboarding_v1_done"
    private let defaults = UserDefaults.standard

    private init() {}

    var hasCompleted: Bool {
        defaults.bool(forKey: key)
    }

    func markCompleted() {
        defaults.set(true, forKey: key)
    }

    /// テスト / debug 用 reset。
    func reset() {
        defaults.removeObject(forKey: key)
    }
}
