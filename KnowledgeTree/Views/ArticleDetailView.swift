//
//  ArticleDetailView.swift
//  KnowledgeTree
//
//  spec 005 — 記事タップ時の主要遷移先 (旧 ReaderView を吸収)。
//  thumbnail / title / 知識サマリ / 本文 / 元記事ボタン を 1 画面に統合。
//  - body が succeeded のときだけ knowledge セクションを意味あるものとして扱う
//  - knowledge が failed なら手動再試行ボタンを表示
//  - RefreshTrigger を読むことで Store の save 完了で自動再描画
//

import SwiftUI
import SwiftData
import Combine

struct ArticleDetailView: View {
    /// `@Bindable` で SwiftData @Model を観察。body 内で読んだ relationship target の
    /// プロパティ (article.body.extractedText 等) も Observation tracking 対象になる。
    @Bindable var article: Article
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(RefreshTrigger.self) private var refresh
    @Environment(ServiceContainer.self) private var services
    @Environment(ProcessingMonitor.self) private var monitor
    @State private var presentedSafariURL: ArticleDetailSafariWrapper?
    @State private var isRetryingKnowledge: Bool = false
    /// refresh.version の変化を SwiftUI が確実に tracking するための local @State。
    /// .onChange で increment され、LazyVStack の .id() に紐付く。
    @State private var refreshTick: Int = 0
    /// spec 008: 関連記事タップで sheet を切り替えるための state
    @State private var presentedRelatedArticle: Article?
    /// spec 016: 本文 DisclosureGroup の展開状態。初期 collapsed、毎回 sheet 起動時にリセット。
    @State private var isBodyExpanded: Bool = false

    /// 1秒 Timer ポーリング: 5 つの通知経路がすべて穴になる場合の最終保険。
    /// completion (knowledge succeeded + body succeeded) になったら止まる条件で
    /// CPU 影響を最小化する。
    private let pollTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private var isFullyComplete: Bool {
        bodySucceeded && hasKnowledge
    }

    private var displayTitle: String {
        let shareTitle = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !shareTitle.isEmpty, shareTitle != article.url { return shareTitle }
        if let canonical = article.enrichment?.canonicalTitle, !canonical.isEmpty { return canonical }
        return article.title
    }

    private var paragraphs: [String] {
        guard let text = article.body?.extractedText else { return [] }
        return text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var bodySucceeded: Bool {
        article.body?.status == .succeeded
    }

    private var hasKnowledge: Bool {
        guard let k = article.extractedKnowledge else { return false }
        return k.status == .succeeded || k.status == .partiallySucceeded
    }

    /// 本文抽出が完了している記事のみ知識セクションを意味あるものとして扱う。
    /// 本文が抽出失敗 / 未取得なら知識セクション自体を非表示にして UI を簡潔にする。
    private var shouldShowKnowledgeSection: Bool {
        bodySucceeded || hasKnowledge
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.xxxl) {
                    // headerSection (サムネ AsyncImage) は refreshTick rebuild から外す。
                    // Timer による毎秒 rebuild で AsyncImage が再 download → loading に戻り
                    // 「写真が表示/消える」を繰り返す問題を回避。
                    // @Bindable article で ogImageURL の変化は auto observe される。
                    headerSection

                    // spec 008: タグセクション (手動 + 自動提案)
                    tagsSection

                    // knowledge / body セクションだけ refreshTick で rebuild する。
                    // 完了状態 (本文・知識サマリ) を確実に live update するため。
                    Group {
                        if shouldShowKnowledgeSection {
                            knowledgeSection
                        }
                        bodySection
                    }
                    .id(refreshTick)

                    // spec 008: 関連記事セクション (共通 entity 0 件なら非表示)
                    RelatedArticlesSection(article: article) { related in
                        // タップで現在の sheet を上書き表示
                        presentedRelatedArticle = related
                    }

                    openOriginalButton
                }
                .padding(.horizontal, DS.Spacing.xxxl)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .navigationTitle("reader.navigationTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("reader.doneButton") { dismiss() }
                }
            }
            .sheet(item: $presentedSafariURL) { wrapper in
                SafariView(url: wrapper.url)
            }
            .sheet(item: $presentedRelatedArticle) { related in
                ArticleDetailView(article: related)
            }
            .onChange(of: refresh.version) { _, _ in
                refreshTick &+= 1
            }
            // SwiftData の didSave 通知 (同 process 同 ModelContainer)
            .onReceive(
                NotificationCenter.default.publisher(for: ModelContext.didSave)
            ) { _ in
                refreshTick &+= 1
            }
            // CoreData レベル: 同 process の context 変更 (save 前でも fire)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("NSManagedObjectContextObjectsDidChange")
                )
            ) { _ in
                refreshTick &+= 1
            }
            // CoreData レベル: 別 process (Share Extension) の save
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("NSPersistentStoreRemoteChange")
                )
            ) { _ in
                refreshTick &+= 1
            }
            // Timer 1秒ポーリング fallback: 完了状態でないときのみ tick increment。
            // 5 つの通知経路がすべて届かないケースの最終保険。
            // tick → .id() の変化 → view tree rebuild → @Bindable article 再評価。
            .onReceive(pollTimer) { _ in
                guard !isFullyComplete else { return }
                refreshTick &+= 1
            }
        }
        .accessibilityIdentifier("articleDetailView")
    }

    // MARK: - Sections

    /// spec 008: タグセクション (既存タグ chips + 自動提案 chips + 入力欄)
    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("detail.tags.heading")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // 既存タグ
            if !article.tags.isEmpty {
                FlowingTagsLayout {
                    ForEach(article.tags) { tag in
                        TagChip(
                            name: tag.name,
                            onRemove: { removeTag(name: tag.name) },
                            isSuggested: false
                        )
                    }
                }
            }

            // 自動提案
            let existingNames = Set(article.tags.map(\.name))
            let suggestions = SuggestedTagFinder.find(for: article, existingTagNames: existingNames)
            if !suggestions.isEmpty {
                Text("detail.suggestedTags.heading")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                FlowingTagsLayout {
                    ForEach(suggestions) { suggestion in
                        Button {
                            addTag(rawName: suggestion.displayName)
                        } label: {
                            TagChip(
                                name: suggestion.displayName,
                                onRemove: nil,
                                isSuggested: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 入力欄
            TagInputField { rawText in
                addTag(rawName: rawText)
            }
        }
        .accessibilityIdentifier("articleDetailTagsSection")
    }

    private func addTag(rawName: String) {
        guard let store = services.tagStore else { return }
        try? store.addTag(rawName: rawName, to: article)
    }

    private func removeTag(name: String) {
        guard let store = services.tagStore else { return }
        try? store.removeTag(normalizedName: name, from: article)
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            if let urlString = article.enrichment?.ogImageURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    DS.Color.overlaySubtle
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip))
            }

            Text(displayTitle)
                .font(.title2.bold())
                .lineSpacing(2)
                .accessibilityIdentifier("articleDetailTitle")

            Text(article.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            // spec 007: マルチページ追跡の取得状況
            if let enrichment = article.enrichment, enrichment.pageCountFetched > 1 {
                if enrichment.pageCountSkipped > 0 {
                    Text("detail.pages.skippedNotice \(enrichment.pageCountFetched)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityIdentifier("pagesSkippedNotice")
                } else {
                    Text("detail.pages.fetchedNotice \(enrichment.pageCountFetched)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityIdentifier("pagesFetchedNotice")
                }
            }
        }
    }

    @ViewBuilder
    private var knowledgeSection: some View {
        if hasKnowledge, let knowledge = article.extractedKnowledge {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                KnowledgeSummaryView(knowledge: knowledge)
                // spec 006: 10000 文字超で要約対象外となった末尾がある場合の注記
                if knowledge.skippedTailChars > 0 {
                    Text("detail.knowledge.truncatedTailNotice")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityIdentifier("knowledgeTruncatedTailNotice")
                }
            }
        } else if let knowledge = article.extractedKnowledge {
            knowledgePlaceholder(status: knowledge.status)
        } else {
            knowledgePlaceholder(status: nil)
        }
    }

    @ViewBuilder
    private func knowledgePlaceholder(status: ExtractionStatus?) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "sparkles").font(DS.Typography.aiLabel)
                Text("knowledge.aiGeneratedLabel").font(DS.Typography.aiLabel)
            }
            .foregroundStyle(.secondary)

            Text("detail.section.knowledge")
                .font(DS.Typography.sectionTitle)

            HStack(spacing: DS.Spacing.md) {
                if status == .extracting || status == .pending || status == nil || isRetryingKnowledge {
                    ProgressView().controlSize(.small).tint(DS.Color.phaseKnowledge)
                }
                Text(messageKey(for: status))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(DS.Spacing.md)
            .background(DS.Color.aiBrandEnd.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: DS.Radius.thumb))

            if status == .failed,
               let reason = article.extractedKnowledge?.failureReason,
               !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, DS.Spacing.xs)
                    .accessibilityIdentifier("knowledgeFailureReason")
            }

            if shouldShowRetryButton(status: status) {
                Button {
                    retryKnowledge()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("detail.knowledge.retry")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                }
                .buttonStyle(.bordered)
                .disabled(isRetryingKnowledge)
                .accessibilityIdentifier("knowledgeRetryButton")
            }

            Divider().padding(.top, DS.Spacing.xs)
        }
    }

    /// 再試行ボタンの表示判定:
    /// - body が succeeded であること (前提条件)
    /// - status が .failed: 通常の再試行
    /// - status が .extracting で、ProcessingMonitor に active task が無い: stale 状態 → 再開可能
    private func shouldShowRetryButton(status: ExtractionStatus?) -> Bool {
        guard bodySucceeded else { return false }
        switch status {
        case .failed:
            return true
        case .extracting:
            // active task が在れば本当に処理中、無ければ stale
            return monitor.tasksByArticle[article.id] == nil
        default:
            return false
        }
    }

    private func messageKey(for status: ExtractionStatus?) -> LocalizedStringKey {
        switch status {
        case .pending, .none: return "detail.knowledge.pending"
        case .extracting:     return "detail.knowledge.extracting"
        case .failed:         return "detail.knowledge.failed"
        case .skipped:        return "detail.knowledge.skipped"
        case .succeeded, .partiallySucceeded:
            return "detail.knowledge.pending"
        }
    }

    @ViewBuilder
    private var bodySection: some View {
        if !paragraphs.isEmpty {
            DisclosureGroup(
                isExpanded: $isBodyExpanded,
                content: {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, p in
                            Text(p)
                                .font(.body)
                                .lineSpacing(DS.Typography.bodyLineSpacing)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, DS.Spacing.md)
                },
                label: {
                    Text("reader.bodyDisclosureLabel")
                        .font(DS.Typography.sectionTitle)
                }
            )
            .accessibilityIdentifier("reader.bodyDisclosure")
            .accessibilityHint(Text("タップして本文を展開"))
        } else if let body = article.body, body.status == .failed || body.status == .permanentlyFailed {
            Text("detail.body.failed")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.vertical, DS.Spacing.md)
        } else {
            HStack(spacing: DS.Spacing.md) {
                ProgressView().controlSize(.small)
                Text("detail.body.pending")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, DS.Spacing.md)
        }
    }

    @ViewBuilder
    private var openOriginalButton: some View {
        Button {
            if let url = URL(string: article.url) {
                presentedSafariURL = ArticleDetailSafariWrapper(url: url)
            }
        } label: {
            Label("detail.openOriginal", systemImage: "safari")
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xl)
                .background(.tint.opacity(0.1),
                             in: RoundedRectangle(cornerRadius: DS.Radius.thumb, style: .continuous))
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("articleDetailOpenOriginal")
    }

    // MARK: - Actions

    private func retryKnowledge() {
        guard let service = services.knowledgeService else { return }
        // 既存の failureReason を空に戻す前に extracting 状態へ
        article.extractedKnowledge?.status = .extracting
        article.extractedKnowledge?.failureReason = nil
        isRetryingKnowledge = true
        Task {
            await service.extract(article: article)
            await MainActor.run {
                isRetryingKnowledge = false
            }
        }
    }
}

private struct ArticleDetailSafariWrapper: Identifiable {
    let id = UUID()
    let url: URL
}
