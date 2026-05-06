//
//  ChatTabView.swift
//  KnowledgeTree
//
//  spec 021 — AI チャット (4 タブ目) の root view。
//  最新 ChatSession の messages 時系列表示 + 入力欄。
//  - .task で起動時に session 復元 (なければ create)
//  - 質問送信 → ChatService.send → message 追加 → auto scroll
//  - 引用記事タップ → ArticleDetailView (NavigationLink)
//

import SwiftUI
import SwiftData

struct ChatTabView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var serviceContainer

    @State private var currentSession: ChatSession?
    @State private var inputText: String = ""
    @State private var isThinking: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let session = currentSession {
                    if session.messages.isEmpty && !isThinking {
                        emptyStateView
                    } else {
                        messageList(for: session)
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
            .task {
                await ensureSession()
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

    private func messageList(for session: ChatSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    let sortedMessages = session.messages.sorted { $0.timestamp < $1.timestamp }
                    ForEach(sortedMessages) { msg in
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
            .onChange(of: session.messages.count) { _, _ in
                scrollToBottom(proxy: proxy, session: session)
            }
            .onChange(of: isThinking) { _, newValue in
                if newValue {
                    withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                }
            }
            .onAppear {
                scrollToBottom(proxy: proxy, session: session)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, session: ChatSession) {
        let sortedMessages = session.messages.sorted { $0.timestamp < $1.timestamp }
        if let last = sortedMessages.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Actions

    private func ensureSession() async {
        guard currentSession == nil else { return }
        // 最新 session を fetch、なければ create
        let descriptor = FetchDescriptor<ChatSession>(
            sortBy: [SortDescriptor(\.lastMessageAt, order: .reverse)]
        )
        if let latest = try? modelContext.fetch(descriptor).first {
            currentSession = latest
        } else {
            currentSession = try? serviceContainer.chatService?.createSession()
        }
    }

    private func sendQuestion() async {
        guard let chatService = serviceContainer.chatService else { return }
        guard let session = currentSession ?? (try? chatService.createSession()) else { return }
        if currentSession == nil {
            currentSession = session
        }

        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

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
