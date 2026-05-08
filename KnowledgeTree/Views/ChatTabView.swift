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
    @State private var isThinking: Bool = false
    @State private var errorMessage: String?

    /// spec 033: 擬似 streaming 中の assistant message ID と表示中の text
    @State private var streamingMessageID: UUID?
    @State private var streamingDisplayedText: String = ""

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

    /// spec 033: multi-turn context = 直前 4 message (= 2 ペア)
    private var contextMessages: [ChatMessage] {
        let sorted = currentSessionMessages.sorted { $0.timestamp < $1.timestamp }
        return Array(sorted.suffix(4))
    }

    var body: some View {
        NavigationSplitView {
            ChatHistorySidebar(
                pinnedSessionID: $pinnedSessionID,
                onCreate: { createNewSession() },
                onSelect: { id in pinnedSessionID = id }
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            NavigationStack {
                VStack(spacing: 0) {
                    if currentSession != nil {
                        if currentSessionMessages.isEmpty && !isThinking {
                            emptyStateView
                        } else {
                            messageList
                        }
                    } else {
                        emptyStateView
                    }

                    ChatInputField(
                        text: $inputText,
                        isThinking: $isThinking,
                        onSend: { Task { await sendQuestion() } }
                    )
                }
                .navigationTitle("chat.tab.title")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Article.self) { article in
                    ArticleDetailView(article: article)
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
        }
        .navigationSplitViewStyle(.balanced)
        .accessibilityIdentifier("chat.tab.root")
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack {
            Spacer()
            ContentUnavailableView(
                "chat.empty.title",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("chat.empty.subtitle")
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(currentSessionMessages) { msg in
                        ChatMessageRow(
                            message: msg,
                            streamingTextOverride: streamingMessageID == msg.id ? streamingDisplayedText : nil
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

        do {
            // ChatService が user/assistant message を永続化する
            let assistantMsg = try await chatService.send(
                question: question,
                in: session,
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

        // 文字ごとに 15ms ずつ追加 (体感は本物 streaming に近い)
        let perCharDelayNs: UInt64 = 15_000_000
        for char in fullText {
            streamingDisplayedText.append(char)
            try? await Task.sleep(nanoseconds: perCharDelayNs)
        }

        // 完了後は override をクリア (永続化済の text に戻る)
        streamingMessageID = nil
        streamingDisplayedText = ""
    }
}
