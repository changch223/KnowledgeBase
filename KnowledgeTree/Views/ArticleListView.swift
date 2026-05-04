//
//  ArticleListView.swift
//  KnowledgeTree
//
//  spec 001 — 一覧 / 内蔵ブラウザ起動 / スワイプ削除
//  spec 002 — ArticleRow + サムネイル + status badge 表示
//  spec 003 — タップ遷移先を Reader / SVC で出し分け
//  spec 005 — タップで常に ArticleDetailView へ + 下部 BottomStatusBar
//          + RefreshTrigger で relationship 経由の変更を確実に反映
//

import SwiftUI
import SwiftData

struct ArticleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProcessingMonitor.self) private var monitor
    @Environment(RefreshTrigger.self) private var refresh
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Article.savedAt, order: .reverse) private var articles: [Article]
    @State private var selectedArticle: Article?
    @State private var refreshTick: Int = 0

    var body: some View {
        // @State refreshTick は SwiftUI が必ず tracking する値。
        // refresh.version の変化を onChange で検知して refreshTick を increment し、
        // 各 ArticleRow に渡すことで relationship 経由の変更を確実に反映させる。
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if articles.isEmpty {
                        EmptyStateView()
                    } else {
                        List {
                            ForEach(articles) { article in
                                Button {
                                    selectedArticle = article
                                } label: {
                                    ArticleRow(article: article, refreshTick: refreshTick)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("articleListRow")
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(article)
                                    } label: {
                                        Label("list.deleteAction", systemImage: "trash")
                                    }
                                    .accessibilityIdentifier("articleDeleteAction")
                                }
                            }
                        }
                        .safeAreaInset(edge: .bottom) {
                            if !monitor.isIdle {
                                Color.clear.frame(height: 60)
                            }
                        }
                    }
                }
                .navigationTitle("list.title")
                .sheet(item: $selectedArticle) { article in
                    ArticleDetailView(article: article)
                }

                BottomStatusBar(monitor: monitor)
                    .animation(.easeInOut(duration: 0.2), value: monitor.totalActiveCount)
                    .animation(.easeInOut(duration: 0.2), value: monitor.current?.id)
            }
            .onChange(of: refresh.version) { _, _ in
                refreshTick &+= 1
            }
            // SwiftData の didSave 通知 (同 process の同一 ModelContainer save 時)
            .onReceive(
                NotificationCenter.default.publisher(for: ModelContext.didSave)
            ) { _ in
                refreshTick &+= 1
            }
            // CoreData レベル: 同 process の任意の context 変更で fire (save 前でも)
            // SwiftData の Observation 連鎖で穴があった場合のフォールバック。
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("NSManagedObjectContextObjectsDidChange")
                )
            ) { _ in
                refreshTick &+= 1
            }
            // CoreData レベル: 別 process (Share Extension) からの save で fire。
            // tick increment で View 再評価 → @Query が再フェッチ → 最新値表示。
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("NSPersistentStoreRemoteChange")
                )
            ) { _ in
                refreshTick &+= 1
            }
            // 前景復帰時の保険 (Share Extension 処理直後にアプリへ戻った場合等)
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    refreshTick &+= 1
                }
            }
        }
    }

    private func delete(_ article: Article) {
        modelContext.delete(article)
        try? modelContext.save()
    }
}

#Preview("一覧") {
    let container = try! ModelContainer(
        for: Article.self, ArticleEnrichment.self, ArticleBody.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(Article(url: "https://example.com/a", title: "サンプル記事 A"))
    container.mainContext.insert(Article(url: "https://example.com/b", title: "サンプル記事 B"))
    return ArticleListView()
        .modelContainer(container)
        .environment(ProcessingMonitor())
        .environment(RefreshTrigger())
        .environment(ServiceContainer())
}

#Preview("空状態") {
    ArticleListView()
        .modelContainer(for: Article.self, inMemory: true)
        .environment(ProcessingMonitor())
        .environment(RefreshTrigger())
        .environment(ServiceContainer())
}
