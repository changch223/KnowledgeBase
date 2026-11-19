//
//  ChatConversationView.swift
//  KnowledgeTree
//
//  spec 021 — AI チャット (4 タブ目) の root view。
//  spec 033 (2026-05-08) — モダン UI 刷新:
//  - NavigationSplitView で履歴サイドバー (iPad: 常時 / iPhone: overlay)
//  - multi-turn context (直前 4 message を ChatService に渡す)
//  - 擬似 token streaming (assistant 回答完了後、1 文字ずつ追加表示)
//  - inline 引用 link は ChatMessageRow 側で AttributedString 描画
//  - session 個別削除 (sidebar 経由) + 新規 session 作成
//  spec 104 — AI チャットタブ廃止に伴い会話画面だけを切り出し。検索タブ (SearchTabView) の
//  NavigationStack に push される。履歴は検索タブのトップ「最近聞いたこと」に移動。
//

import SwiftUI
import SwiftData

struct ChatConversationView: View {

    /// spec 104: 表示する session (検索タブから固定で渡される)。
    let sessionID: UUID
    /// spec 104: 検索欄から「AI に聞く」で来たときの初回質問 (メッセージ 0 件のときだけ 1 回送信)。
    var initialQuestion: String? = nil
    /// 初回送信の回答モード (再生成は .think、検索の「AI に聞く」は .quick)
    var initialMode: ChatMode = .quick
    /// spec 104: 引用 / 関連記事の「記事を開く」を親 (検索タブの stack) に通知。
    let onOpenArticle: (Article) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceContainer.self) private var serviceContainer

    /// 全 ChatSession を最新順で取得 (空なら全削除直後)
    @Query(sort: \ChatSession.lastMessageAt, order: .reverse)
    private var allSessions: [ChatSession]

    /// 全 ChatMessage を取得し、currentSession.id でフィルタする (Relationship reactive 対応)
    @Query(sort: \ChatMessage.timestamp)
    private var allMessages: [ChatMessage]

    /// spec 104: 初回質問の二重送信防止。
    @State private var hasSentInitial: Bool = false
    /// spec 104: session を一度でも見つけたか (全削除後の dismiss 判定用)。
    @State private var sessionWasSeen: Bool = false

    @State private var inputText: String = ""
    /// spec 083: clarification「その他（自由に入力）」から入力欄にフォーカスする。
    @FocusState private var inputFocused: Bool
    @State private var isThinking: Bool = false
    @State private var errorMessage: String?
    /// spec 099: Quick (⚡) / Think (🧠) モード切り替え。メッセージごとに独立。
    @State private var chatMode: ChatMode = .quick

    /// spec 033: 擬似 streaming 中の assistant message ID と表示中の text
    @State private var streamingMessageID: UUID?
    @State private var streamingDisplayedText: String = ""

    /// spec 104: 渡された sessionID に固定 (最新 fallback は廃止)。消えていれば nil。
    private var currentSession: ChatSession? {
        allSessions.first(where: { $0.id == sessionID })
    }

    private var currentSessionMessages: [ChatMessage] {
        allMessages.filter { $0.session?.id == sessionID }
    }

    /// spec 033/083: multi-turn context = 直前 6 message (= 3 ペア)。会話の記憶を強化。
    private var contextMessages: [ChatMessage] {
        let sorted = currentSessionMessages.sorted { $0.timestamp < $1.timestamp }
        return Array(sorted.suffix(6))
    }

    var body: some View {
        Group {
            VStack(spacing: 0) {
                // spec 048: AI 不可端末で「分かりません」連発を防ぐ説明 banner
                if let reason = serviceContainer.availabilityChecker?.unavailabilityReason {
                    AppleIntelligenceBanner(reason: reason, compact: true)
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.top, DS.Spacing.md)
                }
                if currentSession != nil {
                    if currentSessionMessages.isEmpty && !isThinking {
                        emptyStateView
                    } else {
                        messageList
                    }
                } else {
                    emptyStateView
                }

                // spec 099: 非同期処理中バナー
                if isThinking {
                    HStack(spacing: DS.Spacing.sm) {
                        SumiKnowledgeSpinnerSmall()
                        Text("chat.thinking.banner")
                            .font(.caption)
                            .foregroundStyle(DS.Color.sumiMid)
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Color.washiBackground.opacity(0.9))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                ChatInputField(
                    text: $inputText,
                    isThinking: $isThinking,
                    chatMode: $chatMode,
                    onSend: { Task { await sendQuestion() } },
                    focused: $inputFocused
                )
            }
            .background(DS.Color.washiBackground)
            .navigationTitle(sessionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.Color.washiBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert(
                Text("chat.message.error"),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .accessibilityIdentifier("chat.tab.root")
        // spec 057: clarification chip tap → input field に auto-fill + 自動送信
        .onReceive(ChatMessageRow.clarificationTapNotificationPublisher) { tappedChip in
            inputText = tappedChip
            Task { await sendQuestion() }
        }
        // spec 083: clarification「その他（自由に入力）」tap → 送信せず入力欄にフォーカス
        .onReceive(ChatMessageRow.clarificationOtherTapNotificationPublisher) { _ in
            inputFocused = true
        }
        // spec 104: 初回質問を 1 回だけ送信 / session 消失で dismiss
        .task {
            if currentSession != nil { sessionWasSeen = true }
            guard !hasSentInitial, let q = initialQuestion, !q.isEmpty else { return }
            // session が @Query にまだ反映されていなければ少し待って再試行 (最大 ~1 秒)
            var tries = 0
            while currentSession == nil && tries < 10 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                tries += 1
            }
            // session が確認できなければ立てずに戻る (.task 再実行で再試行できる)
            guard currentSession != nil, !Task.isCancelled else { return }
            hasSentInitial = true
            guard currentSessionMessages.isEmpty else { return }
            let mode = initialMode
            chatMode = mode
            // 画面寿命 (.task のキャンセル) と切り離して送信し、回答を失わない
            Task { await sendQuestion(text: q, mode: mode) }
        }
        .onChange(of: allSessions.map(\.id)) { _, ids in
            if ids.contains(sessionID) {
                sessionWasSeen = true
            } else if sessionWasSeen {
                dismiss()
            }
        }
    }

    private var sessionTitle: String {
        if let t = currentSession?.title, !t.isEmpty { return t }
        return String(localized: "chat.sidebar.untitled")
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxxl) {
                Text("chat.empty.placeholder")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top, DS.Spacing.xxxl)
                // spec 056: Suggested prompts (動的生成 3 件)
                SuggestedPromptsSection { promptText in
                    inputText = promptText
                    Task { await sendQuestion() }
                }
            }
            .padding(DS.Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(currentSessionMessages) { msg in
                        ChatMessageRow(
                            message: msg,
                            streamingTextOverride: streamingMessageID == msg.id ? streamingDisplayedText : nil,
                            onArticleLinkTap: onOpenArticle
                        )
                        .id(msg.id)
                    }
                    if isThinking {
                        HStack(spacing: DS.Spacing.sm) {
                            SumiKnowledgeSpinnerSmall()
                            Text("chat.message.assistant.thinking")
                                .font(.caption)
                                .foregroundStyle(DS.Color.sumiMid)
                        }
                        .padding(DS.Spacing.lg)
                        .id("thinking")
                    }
                }
                .padding(DS.Spacing.lg)
            }
            // 上スクロールで keyboard が指に追従して下がる (iMessage 風)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: currentSessionMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: streamingDisplayedText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isThinking) { _, newValue in
                if newValue {
                    withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                }
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = currentSessionMessages.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else if isThinking {
            withAnimation {
                proxy.scrollTo("thinking", anchor: .bottom)
            }
        }
    }

    // MARK: - Actions

    private func sendQuestion(text: String? = nil, mode explicitMode: ChatMode? = nil) async {
        guard let chatService = serviceContainer.chatService else { return }

        let question = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        // spec 104: session は渡された sessionID に固定 (消えていれば何もしない)
        guard let session = currentSession else { return }

        // multi-turn context: 直前 4 message (この時点では新 user message はまだ追加されていない)
        let context = contextMessages

        if text == nil { inputText = "" }
        isThinking = true

        let mode = explicitMode ?? chatMode
        do {
            // ChatService が user/assistant message を永続化する
            let assistantMsg = try await chatService.send(
                question: question,
                in: session,
                chatMode: mode,
                contextMessages: context
            )
            isThinking = false
            // spec 033: 擬似 streaming で 1 文字ずつ表示
            await streamDisplayMessage(message: assistantMsg)
        } catch {
            isThinking = false
            errorMessage = String(describing: error)
        }
    }

    /// spec 033: 擬似 streaming — 完成済の assistant 本文を 1 文字ずつ追加表示
    private func streamDisplayMessage(message: ChatMessage) async {
        let fullText = message.text
        guard !fullText.isEmpty else { return }
        streamingMessageID = message.id
        streamingDisplayedText = ""

        // spec 082: 文字ごとの追加遅延を 15ms → 4ms に短縮 (生成完了後のタイプ表示の体感を ~1/4 に)
        let perCharDelayNs: UInt64 = 4_000_000
        for char in fullText {
            streamingDisplayedText.append(char)
            try? await Task.sleep(nanoseconds: perCharDelayNs)
        }

        // 完了後は override をクリア (永続化済の text に戻る)
        streamingMessageID = nil
        streamingDisplayedText = ""
    }
}
