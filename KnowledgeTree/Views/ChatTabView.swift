//
//  ChatTabView.swift
//  KnowledgeTree
//
//  spec 021 — AI チャット (4 タブ目) の root view。
//  最新 ChatSession の messages 時系列表示 + 入力欄。
//
//  spec 021 fix (2026-05-06):
//  - currentSession を @State Object 保持しない。@Query で全 ChatSession を取得し、
//    `pinnedSessionID` (ユーザー選択用) と `allSessions.first` (最新) を組み合わせて
//    動的に算出。これで全削除後の dead reference 問題 / 履歴復活ハングを根本解決。
//  - 質問送信時に session 無ければ create (lazy)
//  - 引用記事タップ → ArticleDetailView (NavigationLink)
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

    /// ユーザーが特定 session を選択した時にピン留め (将来 spec 033 のサイドバー用)。
    /// nil の時は allSessions.first (最新) を使用。
    @State private var pinnedSessionID: UUID?

    @State private var inputText: String = ""
    @State private var isThinking: Bool = false
    @State private var errorMessage: String?

    /// 動的算出: pinned があればそれ、なければ最新。allSessions が空 (全削除後) なら nil。
    /// 削除済みの ChatSession は @Query から消えているので dead reference にならない。
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

    var body: some View {
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
                        ChatMessageRow(message: msg)
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

        inputText = ""
        isThinking = true
        defer { isThinking = false }

        do {
            _ = try await chatService.send(question: question, in: session)
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
