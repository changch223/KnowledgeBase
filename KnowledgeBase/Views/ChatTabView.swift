//
//  ChatTabView.swift
//  KnowledgeTree
//
//  spec 021 — AI チャット (4 タブ目) の root view。
//  spec 033 (2026-05-08) — モダン UI 刷新:
//  - NavigationSplitView で履歴サイドバー (iPad: 常時 / iPhone: overlay)
//  - multi-turn context (直前 4 message を ChatService に渡す)
//  - 擬似 token streaming (assistant 回答完了後、1 文字ずつ追加表示)
//  - inline 引用 link は ChatMessageRow 側で AttributedString 描画
//  - session 個別削除 (sidebar 経由) + 新規 session 作成
//

import SwiftUI
import SwiftData

struct ChatTabView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var serviceContainer

    /// 全 ChatSession を最新順で取得 (空なら全削除直後)
    @Query(sort: \ChatSession.lastMessageAt, order: .reverse)
    private var allSessions: [ChatSession]

    /// 全 ChatMessage を取得し、currentSession.id でフィルタする (Relationship reactive 対応)
    @Query(sort: \ChatMessage.timestamp)
    private var allMessages: [ChatMessage]

    /// ユーザーが特定 session を選択した時にピン留め。
    /// nil の時は allSessions.first (最新) を使用。
    @State private var pinnedSessionID: UUID?

    @State private var inputText: String = ""
    /// spec 083: clarification「その他（自由に入力）」から入力欄にフォーカスする。
    @FocusState private var inputFocused: Bool
    @State private var isThinking: Bool = false
    @State private var errorMessage: String?
    /// spec 099: Quick (⚡) / Think (🧠) モード切り替え。メッセージごとに独立。
    @State private var chatMode: ChatMode = .think

    /// spec 033: 擬似 streaming 中の assistant message ID と表示中の text
    @State private var streamingMessageID: UUID?
    @State private var streamingDisplayedText: String = ""

    /// spec 033 fix (2026-05-09): NavigationSplitView は iPhone で columnVisibility が
    /// 確実に動かない問題があったため、シンプルな sheet ベースに変更。
    /// iPhone / iPad 両方で確実に動く UX を優先。
    @State private var showSidebar: Bool = false

    /// spec 059 (P0-4): 引用リンク tap → Article を push するための navigation path。
    /// 既存の .navigationDestination(for: Article.self) がそのまま発火する。
    @State private var navigationPath = NavigationPath()

    /// 動的算出: pinned があればそれ、なければ最新。allSessions が空 (全削除後) なら nil。
    private var currentSession: ChatSession? {
        if let id = pinnedSessionID,
           let pinned = allSessions.first(where: { $0.id == id }) {
            return pinned
        }
        return allSessions.first
    }

    private var currentSessionMessages: [ChatMessage] {
        guard let sessionID = currentSession?.id else { return [] }
        return allMessages.filter { $0.session?.id == sessionID }
    }

    /// spec 033/083: multi-turn context = 直前 6 message (= 3 ペア)。会話の記憶を強化。
    private var contextMessages: [ChatMessage] {
        let sorted = currentSessionMessages.sorted { $0.timestamp < $1.timestamp }
        return Array(sorted.suffix(6))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("chat.thinking.banner")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Color.surfaceSecondary.opacity(0.8))
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
            .navigationTitle("chat.tab.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 履歴 sidebar (sheet) を開く button
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSidebar = true
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .accessibilityIdentifier("chat.toolbar.sidebar")
                    .accessibilityLabel(Text("chat.sidebar.title"))
                }
                // spec 056: 📊 Knowledge Graph 全体画面アイコン
                // spec 090: ユーザー要望で非表示 (グラフ機能を一旦 UI から外す)。
            }
            .navigationDestination(for: Article.self) { article in
                // spec 043 bug fix: 外側 NavigationStack 経由 → 内側 NavigationStack 作らない (入れ子防止)
                ArticleDetailView(article: article, embedNavigationStack: false)
            }
            // spec 047: chat 答えの関連 ConceptPage chips からの遷移先
            .navigationDestination(for: ConceptPageDetailDestination.self) { dest in
                ConceptPageDetailLoader(destinationID: dest.id)
            }
            // spec 056: AI チャット toolbar 📊 アイコン遷移先
            .navigationDestination(for: KnowledgeGraphFullScreenDestination.self) { _ in
                KnowledgeGraphFullScreenView()
            }
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
        .sheet(isPresented: $showSidebar) {
            NavigationStack {
                ChatHistorySidebar(
                    pinnedSessionID: $pinnedSessionID,
                    onCreate: {
                        createNewSession()
                        showSidebar = false
                    },
                    onSelect: { id in
                        pinnedSessionID = id
                        showSidebar = false
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("OK") { showSidebar = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        // spec 045: SavedAnswer の「再生成」trigger を消費
        // - 新 ChatSession を作る + question を pin + 自動 send
        // - ChatService の hook 経由で captureIfWorthyOrReplaceStale が走り、新 SavedAnswer auto-save
        .onChange(of: serviceContainer.pendingRegenerateRequest) { _, new in
            guard let req = new, let chatService = serviceContainer.chatService else { return }
            Task { @MainActor in
                do {
                    let newSession = try chatService.createSession()
                    pinnedSessionID = newSession.id
                    serviceContainer.pendingRegenerateRequest = nil
                    isThinking = true
                    let assistantMsg = try await chatService.send(
                        question: req.question,
                        in: newSession,
                        contextMessages: []
                    )
                    isThinking = false
                    await streamDisplayMessage(message: assistantMsg)
                } catch {
                    isThinking = false
                    errorMessage = String(describing: error)
                    serviceContainer.pendingRegenerateRequest = nil
                }
            }
        }
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
                            onArticleLinkTap: { navigationPath.append($0) }
                        )
                        .id(msg.id)
                    }
                    if isThinking {
                        HStack(spacing: DS.Spacing.sm) {
                            ProgressView()
                            Text("chat.message.assistant.thinking")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

    private func createNewSession() {
        guard let chatService = serviceContainer.chatService else { return }
        do {
            let s = try chatService.createSession()
            pinnedSessionID = s.id
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func sendQuestion() async {
        guard let chatService = serviceContainer.chatService else { return }

        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        // session 解決: pinned / 最新 / なければ新規 create
        let session: ChatSession
        if let existing = currentSession {
            session = existing
        } else {
            do {
                session = try chatService.createSession()
                pinnedSessionID = session.id
            } catch {
                errorMessage = String(describing: error)
                return
            }
        }

        // multi-turn context: 直前 4 message (この時点では新 user message はまだ追加されていない)
        let context = contextMessages

        inputText = ""
        isThinking = true

        let mode = chatMode
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
