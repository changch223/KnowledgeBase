//
//  OnboardingView.swift
//  KnowledgeTree
//
//  spec 049 — 初回起動 onboarding。5 ページ TabView (PageStyle) で Knowledge Base の核を説明。
//
//  「保存したものが時間と共に compound する」体験を最初に伝える:
//    Page 1: ようこそ — Knowledge Base は「あなた専用の第二の脳」
//    Page 2: 保存する — Share Sheet / ＋ボタン で記事 / PDF / 写真 / 音声 / 多言語
//    Page 3: 自動で整理 — AI が概念ページ (Wiki) を作り iKnow フィードに育てる
//    Page 4: 直せる・育てられる — 本文訂正 (spec 095) + 分類自己学習 (spec 097)
//    Page 5: AI チャット — 保存した知識に質問、出典付きで答える
//
//  完了後 UserDefaults `iKnow_onboarding_v1_done` を true、再起動でスキップ。
//  KnowledgeTreeApp の WindowGroup root で fullScreenCover として表示。
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage: Int = 0

    // spec 049/099: 5 ページ構成。
    // Page 3: lightbulb → newspaper.fill (iKnow タブの実アイコンに統一)
    // Page 4: 新規 — 本文訂正 (spec 095) + 分類自己学習 (spec 097)
    // Page 5: 旧 Page 4 の AI チャット
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "brain.head.profile",
            title: "onboarding.page1.title",
            body: "onboarding.page1.body",
            highlightColor: .blue
        ),
        OnboardingPage(
            symbol: "square.and.arrow.down.on.square",
            title: "onboarding.page2.title",
            body: "onboarding.page2.body",
            highlightColor: .green
        ),
        OnboardingPage(
            symbol: "newspaper.fill",
            title: "onboarding.page3.title",
            body: "onboarding.page3.body",
            highlightColor: .orange
        ),
        OnboardingPage(
            symbol: "pencil.and.scribble",
            title: "onboarding.page4.title",
            body: "onboarding.page4.body",
            highlightColor: .mint
        ),
        OnboardingPage(
            symbol: "bubble.left.and.bubble.right.fill",
            title: "onboarding.page5.title",
            body: "onboarding.page5.body",
            highlightColor: .purple
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                        .accessibilityIdentifier("onboarding.page.\(index)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            HStack {
                if currentPage < pages.count - 1 {
                    Button("onboarding.skip") {
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
                    Text(currentPage < pages.count - 1 ? "onboarding.next" : "onboarding.start")
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
    let title: LocalizedStringKey
    let body: LocalizedStringKey
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
