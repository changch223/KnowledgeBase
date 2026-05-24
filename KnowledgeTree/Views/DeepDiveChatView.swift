//
//  DeepDiveChatView.swift
//  KnowledgeTree
//
//  spec 044 — 学習カードタップで起動する「家庭教師」モードの chat 画面。
//
//  spec 044 brushup (2026-05-23):
//    - DeepDiveChatStarter → DeepDiveChatService に切替 (Foundation Models 直接呼び、retrieval なし)
//    - 「分かりません」連発 + system prompt 露出 bug 解消
//    - 3 ボタンの意図を説明する banner を追加 (calm UX、ユーザーが「✗ 興味ない」の意味を理解できるように)
//    - 「✗ 違う」 → 「✗ 興味ない」に文言変更 (surface 下位化の意味を明示)
//

import SwiftUI
import SwiftData
import UIKit

struct DeepDiveChatView: View {
    let card: UnderstandingCard

    @Environment(ServiceContainer.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var session: ChatSession?
    @State private var isInitializing: Bool = true
    @State private var startError: String?
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    /// spec 044 brushup 2: 「✓ わかった」「🤔 もっと」「✗ 興味ない」tap 直後の視覚 fb (2 秒で消える)
    @State private var ackToast: String?

    var body: some View {
        VStack(spacing: 0) {
            chatBody
            inputArea
            buttonHint
            actionBar
        }
        .navigationTitle(Text(card.deepDiveTitle))
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let ackToast {
                Text(ackToast)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.md)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.green.opacity(0.4), lineWidth: 1))
                    .padding(.bottom, 140)  // action bar + input の上に出す
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("deepdive.ackToast")
            }
        }
        .task {
            await startChat()
        }
    }

    @ViewBuilder
    private var chatBody: some View {
        if isInitializing {
            VStack {
                Spacer()
                ProgressView { Text("家庭教師を起動中…") }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let startError {
            ContentUnavailableView(
                "家庭教師を起動できませんでした",
                systemImage: "exclamationmark.bubble",
                description: Text("もう一度開いてみてください。")
            )
            .accessibilityLabel(Text(startError))
        } else if let session {
            DeepDiveMessageList(sessionID: session.id, isThinking: isSending)
        } else {
            Color.clear
        }
    }

    private var inputArea: some View {
        HStack(spacing: DS.Spacing.md) {
            TextField("入力…", text: $inputText, axis: .vertical)
                .lineLimit(1 ... 4)
                .textFieldStyle(.roundedBorder)
                .disabled(isSending || isInitializing)
                .accessibilityIdentifier("deepdive.input")

            Button {
                Task { await handleSend() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundStyle(canSend ? DS.Color.actionBlue : Color.gray)
            }
            .disabled(!canSend)
            .accessibilityIdentifier("deepdive.send")
            .accessibilityLabel(Text("送信"))
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.md)
        .background(.regularMaterial)
    }

    private var canSend: Bool {
        !isSending && !isInitializing && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 3 ボタンの意図説明 banner。calm UX のため小さく 1 行。
    private var buttonHint: some View {
        Text("✓ 理解した / 🤔 もっと聞く / ✗ 今は表示不要")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xs)
            .background(.regularMaterial)
            .accessibilityIdentifier("deepdive.button_hint")
    }

    private var actionBar: some View {
        HStack(spacing: DS.Spacing.lg) {
            DeepDiveActionButton(
                title: Text("✓ わかった"),
                tint: .green,
                accessibilityLabelKey: "はい、わかりました",
                identifier: "button.understood"
            ) {
                await handleUnderstood()
            }
            DeepDiveActionButton(
                title: Text("🤔 もっと"),
                tint: .blue,
                accessibilityLabelKey: "もっと教えてください",
                identifier: "button.needMore"
            ) {
                await handleNeedMore()
            }
            DeepDiveActionButton(
                title: Text("✗ 興味ない"),
                tint: .orange,
                accessibilityLabelKey: "興味ない、戻る",
                identifier: "button.dismissed"
            ) {
                await handleDismissed()
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    // MARK: - actions

    private func startChat() async {
        guard isInitializing, let service = services.deepDiveChatService else {
            isInitializing = false
            return
        }
        do {
            session = try await service.startTutorSession(for: card)
            isInitializing = false
        } catch {
            startError = String(describing: error)
            isInitializing = false
        }
    }

    private func handleSend() async {
        guard let service = services.deepDiveChatService, let session else { return }
        let text = inputText
        inputText = ""
        isSending = true
        defer { isSending = false }
        do {
            _ = try await service.sendUserMessage(text, in: session, card: card)
        } catch {
            // 失敗時は input を復元
            inputText = text
        }
    }

    private func handleUnderstood() async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let tracker = services.understandingTrackerService else { return }
        try? await tracker.recordUnderstood(card: card)
        // 視覚 fb: toast 表示 + AI に「次の確認質問」を投げる (家庭教師ループ継続)
        await showAck("✓ 記録しました")
        if let service = services.deepDiveChatService, let session {
            isSending = true
            defer { isSending = false }
            _ = try? await service.sendUserMessage(
                "今のところまでは理解しました。もう少し進んだ次の確認質問を 1 つお願いします。",
                in: session,
                card: card
            )
        }
    }

    private func handleNeedMore() async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let tracker = services.understandingTrackerService,
              let service = services.deepDiveChatService,
              let session else { return }
        try? await tracker.recordNeedMore(card: card)
        await showAck("🤔 別の角度で聞きます")
        isSending = true
        defer { isSending = false }
        _ = try? await service.sendUserMessage("もう少し別の角度から教えてください。", in: session, card: card)
    }

    private func handleDismissed() async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let tracker = services.understandingTrackerService else { return }
        try? await tracker.recordDismissed(card: card)
        dismiss()
    }

    /// 2 秒間 ack toast を表示して fade out。calm UX。
    private func showAck(_ text: String) async {
        withAnimation(.easeOut(duration: 0.25)) {
            ackToast = text
        }
        try? await Task.sleep(nanoseconds: 1_800_000_000)
        withAnimation(.easeIn(duration: 0.3)) {
            ackToast = nil
        }
    }
}

// MARK: - DeepDiveMessageList

private struct DeepDiveMessageList: View {
    let sessionID: UUID
    let isThinking: Bool

    @Query private var messages: [ChatMessage]

    init(sessionID: UUID, isThinking: Bool) {
        self.sessionID = sessionID
        self.isThinking = isThinking
        _messages = Query(
            filter: #Predicate<ChatMessage> { $0.session?.id == sessionID },
            sort: [SortDescriptor(\.timestamp, order: .forward)]
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(messages) { msg in
                        ChatMessageRow(message: msg, streamingTextOverride: nil)
                            .id(msg.id)
                    }
                    if isThinking {
                        HStack(spacing: DS.Spacing.sm) {
                            ProgressView()
                            Text("考えています…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(DS.Spacing.lg)
                        .id("thinking")
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isThinking) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if isThinking {
            withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
        } else if let last = messages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }
}

// MARK: - DeepDiveActionButton

private struct DeepDiveActionButton: View {
    let title: Text
    let tint: Color
    let accessibilityLabelKey: LocalizedStringKey
    let identifier: String
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            title
                .font(.callout)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.lg)
                .background(tint.opacity(0.18))
                .foregroundStyle(tint)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(accessibilityLabelKey))
    }
}
