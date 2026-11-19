//
//  SearchTabView.swift
//  KnowledgeTree
//
//  spec 104 — 検索タブ (iOS 26 の Tab(role: .search))。「探す」と「聞く」を 1 か所に統合。
//  - 入力が空: 「最近聞いたこと」(ChatSession 履歴、タップで続きから / スワイプ削除)
//  - 入力あり: 「“…” を AI に聞く」行 + トピック (上位 5) + 記事 (上位 30)
//  - Return / 「AI に聞く」行 → 新規 ChatSession を作り ChatConversationView へ push (初回質問を自動送信)
//  - 保存済み回答の「再生成」(pendingRegenerateRequest) もここで消費 (spec 045 動線維持)
//

import SwiftUI
import SwiftData

/// 会話画面への遷移先。initialQuestion があれば会話画面が 1 回だけ自動送信する。
struct ChatConversationDestination: Hashable {
    let sessionID: UUID
    let initialQuestion: String?
    /// 初回送信の回答モード。既定 .quick (検索の「AI に聞く」= 旧 UI の入力既定と同じ)。
    var initialMode: ChatMode = .quick
}

struct SearchTabView: View {
    @Environment(ServiceContainer.self) private var serviceContainer

    @Query(sort: \Article.savedAt, order: .reverse) private var articles: [Article]
    @Query(filter: #Predicate<ConceptPage> { !$0.isHidden },
           sort: \ConceptPage.updatedAt, order: .reverse) private var concepts: [ConceptPage]
    @Query(sort: \ChatSession.lastMessageAt, order: .reverse) private var allSessions: [ChatSession]

    @State private var query: String = ""
    @State private var path = NavigationPath()
    @State private var errorMessage: String?
    @State private var showDeleteError: Bool = false

    static let maxRecentSessions = 20
    static let maxConceptResults = 5
    static let maxArticleResults = 30

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var aiUnavailable: Bool {
        serviceContainer.availabilityChecker?.unavailabilityReason != nil
    }

    /// 「最近聞いたこと」= 一般チャットで、メッセージが 1 件以上ある session。
    private var recentSessions: [ChatSession] {
        allSessions
            .filter { $0.mode == .general && !($0.messages ?? []).isEmpty }
            .prefix(Self.maxRecentSessions)
            .map { $0 }
    }

    private var matchingConcepts: [ConceptPage] {
        guard !trimmedQuery.isEmpty else { return [] }
        return SearchService.searchConceptPages(query: trimmedQuery, in: concepts)
            .prefix(Self.maxConceptResults)
            .map { $0.conceptPage }
    }

    private var matchingArticles: [Article] {
        guard !trimmedQuery.isEmpty else { return [] }
        return SearchService.search(query: trimmedQuery, in: articles)
            .prefix(Self.maxArticleResults)
            .map { $0.article }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if trimmedQuery.isEmpty {
                    recentSection
                } else {
                    askRow
                    topicsSection
                    articlesSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DS.Color.washiBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("search.tab.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.Color.washiBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("search.prompt")
            )
            .onSubmit(of: .search) {
                ask(trimmedQuery)
            }
            .navigationDestination(for: ChatConversationDestination.self) { dest in
                ChatConversationView(
                    sessionID: dest.sessionID,
                    initialQuestion: dest.initialQuestion,
                    initialMode: dest.initialMode,
                    onOpenArticle: { path.append($0) }
                )
            }
            .navigationDestination(for: Article.self) { article in
                ArticleDetailView(article: article, embedNavigationStack: false)
            }
            .navigationDestination(for: ConceptPageDetailDestination.self) { dest in
                ConceptPageDetailLoader(destinationID: dest.id)
            }
            .navigationDestination(for: SavedAnswerDetailDestination.self) { dest in
                SavedAnswerDetailLoader(destinationID: dest.id)
            }
            .navigationDestination(for: SavedAnswerListByConceptDestination.self) { _ in
                SavedAnswerHistoryView()
            }
            .alert("error.action.deleteFailed.title", isPresented: $showDeleteError) {
                Button("common.ok", role: .cancel) { }
            } message: {
                Text("error.action.deleteFailed")
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
        .accessibilityIdentifier("search.tab.root")
        // spec 045: SavedAnswer の「再生成」trigger を消費 (新 session + 初回質問を自動送信)
        .onChange(of: serviceContainer.pendingRegenerateRequest) { _, _ in
            consumeRegenerateRequest()
        }
        // タブ切替で初めて表示されたとき、既に trigger がセット済みの場合も拾う
        .task {
            consumeRegenerateRequest()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var recentSection: some View {
        Section {
            if recentSessions.isEmpty {
                Text("search.empty.recent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("search.empty.recent")
            } else {
                ForEach(recentSessions) { session in
                    NavigationLink(
                        value: ChatConversationDestination(sessionID: session.id, initialQuestion: nil)
                    ) {
                        ChatSessionRow(session: session, isActive: false)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteSession(session)
                        } label: {
                            Label("chat.sidebar.deleteAction", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("search.section.recentQuestions")
                .accessibilityIdentifier("search.section.recentQuestions")
        }
    }

    @ViewBuilder
    private var askRow: some View {
        Section {
            Button {
                ask(trimmedQuery)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(DS.Color.sumiInk)
                        Text("search.ask.row \(trimmedQuery)")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    if aiUnavailable {
                        Text("search.ask.unavailable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                    }
                }
            }
            .disabled(aiUnavailable)
            .accessibilityIdentifier("search.ask.row")
        }
    }

    @ViewBuilder
    private var topicsSection: some View {
        let topics = matchingConcepts
        if !topics.isEmpty {
            Section {
                ForEach(topics) { concept in
                    NavigationLink(value: ConceptPageDetailDestination(id: concept.id)) {
                        ConceptSearchRow(concept: concept)
                    }
                }
            } header: {
                Text("search.section.topics")
            }
        }
    }

    @ViewBuilder
    private var articlesSection: some View {
        let results = matchingArticles
        if !results.isEmpty {
            Section {
                ForEach(results) { article in
                    NavigationLink(value: article) {
                        ArticleRow(article: article, searchQuery: trimmedQuery)
                    }
                    .accessibilityIdentifier("search.articleRow")
                }
            } header: {
                Text("search.section.articles")
            }
        }
    }

    // MARK: - Actions

    /// 新規 session を作り、会話画面へ push (初回質問は会話画面が 1 回だけ自動送信)。
    private func ask(_ question: String) {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !aiUnavailable,
              let chatService = serviceContainer.chatService else { return }
        do {
            let session = try reusableEmptySession() ?? chatService.createSession()
            path.append(ChatConversationDestination(sessionID: session.id, initialQuestion: q, initialMode: .quick))
            query = ""
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func consumeRegenerateRequest() {
        guard let req = serviceContainer.pendingRegenerateRequest else { return }
        serviceContainer.pendingRegenerateRequest = nil
        guard let chatService = serviceContainer.chatService else { return }
        do {
            let session = try reusableEmptySession() ?? chatService.createSession()
            path.append(ChatConversationDestination(sessionID: session.id, initialQuestion: req.question, initialMode: .think))
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// メッセージ 0 件の一般 session があれば再利用 (質問ごとの session 作成で 50 件上限を消費しない)。
    private func reusableEmptySession() -> ChatSession? {
        allSessions.first { $0.mode == .general && ($0.messages ?? []).isEmpty }
    }

    private func deleteSession(_ session: ChatSession) {
        do {
            try serviceContainer.chatService?.deleteSession(session)
        } catch {
            AppErrorReporter.shared.report(error, operation: "deleteChatSession")
            showDeleteError = true
        }
    }
}
