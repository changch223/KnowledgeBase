//
//  ConceptPageDetailView.swift
//  KnowledgeTree
//
//  spec 042 — ConceptPage 詳細画面。
//  5 セクション (header / summary / crossSourceInsights / relatedArticles / relatedConcepts)
//  + toolbar (pin Toggle + 編集 ⋯)。
//

import SwiftUI
import SwiftData

/// spec 064: 本文中 concept-id:// リンクの navigationDestination(item:) 用ラッパー。
struct WikiLinkTarget: Identifiable, Hashable {
    let id: UUID
}

struct ConceptPageDetailView: View {
    @Bindable var conceptPage: ConceptPage
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceContainer.self) private var services
    @State private var showEditSheet: Bool = false
    /// 削除/merge で page が消えた瞬間に空配列になる reactive guard。
    /// body 冒頭で `liveMatches.isEmpty` を見て短絡することで、@Bindable conceptPage の
    /// プロパティ (crossSourceInsights / relatedArticles 等) を一切読まず crash 回避。
    @Query private var liveMatches: [ConceptPage]

    /// spec 075: 親子階層の解決用 (非表示除外)。parentConceptID は #Predicate 直クエリ不可なので
    /// in-memory filter (件数は小)。子セクション・上位概念ブレッドクラムに使う。
    @Query(filter: #Predicate<ConceptPage> { !$0.isHidden })
    private var hierarchyPages: [ConceptPage]

    init(conceptPage: ConceptPage) {
        self.conceptPage = conceptPage
        let id = conceptPage.id
        _liveMatches = Query(filter: #Predicate<ConceptPage> { $0.id == id })
    }

    /// page がまだ DB に存在しているか (削除 / merge で消えた直後は false)。
    private var isAlive: Bool { !liveMatches.isEmpty }

    /// spec 075: 上位概念 (親) ページ。parentConceptID が指す先、無ければ nil。
    private var parentPage: ConceptPage? {
        guard let pid = conceptPage.parentConceptID else { return nil }
        return hierarchyPages.first { $0.id == pid }
    }

    /// spec 075: この概念の子 specific 概念 (updatedAt 降順)。
    private var childPages: [ConceptPage] {
        hierarchyPages
            .filter { $0.parentConceptID == conceptPage.id }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// 「つながる人物・モノ」セクションで表示する他 ConceptPage を resolve。
    /// relatedConceptIDs 配列を fetch、最大 8 件まで。
    private func relatedConcepts() -> [ConceptPage] {
        guard !conceptPage.relatedConceptIDs.isEmpty else { return [] }
        let ids = Set(conceptPage.relatedConceptIDs)
        let descriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate<ConceptPage> { ids.contains($0.id) },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        var bounded = descriptor
        bounded.fetchLimit = 8
        return (try? context.fetch(bounded)) ?? []
    }

    /// pin Toggle binding — store 経由で永続化。
    /// spec 061 (P1-3): 失敗を記録 (非破壊操作なので log のみ、calm UX)。
    private var pinBinding: Binding<Bool> {
        Binding(
            get: { conceptPage.isFollowing },
            set: { newValue in
                if let store = services.conceptPageStore {
                    do {
                        try store.setFollowing(conceptPage, isFollowing: newValue)
                    } catch {
                        AppErrorReporter.shared.report(error, operation: "setFollowingConceptPage")
                    }
                } else {
                    conceptPage.isFollowing = newValue
                }
            }
        )
    }

    /// spec 064: 本文中の concept-id:// リンク tap 先 (self-contained 遷移)。
    @State private var wikiLinkTarget: WikiLinkTarget?

    var body: some View {
        // page が削除/merge で消えた瞬間に短絡 → conceptPage プロパティ参照を一切させない (crash 防止)
        // Loader 側の @Query auto-pop で navigation も pop されるので、ここは描画スキップだけで OK
        if !isAlive {
            Color.clear
                .onAppear { dismiss() }
        } else {
            aliveBody
        }
    }

    @ViewBuilder
    private var aliveBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── グループ A: タイトル + 知識セクション ──────────────
                Group {
                    parentBreadcrumb
                        .padding(.bottom, DS.Spacing.md)
                    heroTitleSection
                    sumiRuleDivider.padding(.vertical, DS.Spacing.section)
                    // spec 080: 要点先出し
                    crossSourceInsightsSection
                    if !conceptPage.crossSourceInsights.isEmpty {
                        sumiRuleDivider.padding(.vertical, DS.Spacing.section)
                    }
                    wikiBodySection
                    if !conceptPage.bodyMarkdown.isEmpty {
                        sumiRuleDivider.padding(.vertical, DS.Spacing.section)
                    }
                    summarySection
                        .padding(.bottom, DS.Spacing.section)
                }

                // ── グループ B: 階層 + 記事 + 関連 ──────────────────
                Group {
                    let children = childPages
                    if !children.isEmpty {
                        sumiRuleDivider.padding(.bottom, DS.Spacing.section)
                        childConceptsSection
                            .padding(.bottom, DS.Spacing.section)
                    }
                    sumiRuleDivider.padding(.bottom, DS.Spacing.section)
                    relatedArticlesSection
                        .padding(.bottom, DS.Spacing.section)
                    // spec 043: この概念についての質問と答え
                    SavedAnswerSection(conceptPageID: conceptPage.id)
                    let others = relatedConcepts()
                    if !others.isEmpty {
                        sumiRuleDivider.padding(.vertical, DS.Spacing.section)
                        relatedConceptsSection
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(conceptPage.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DS.Color.washiBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DS.Spacing.md) {
                    Toggle(isOn: pinBinding) {
                        Image(systemName: conceptPage.isFollowing ? "pin.fill" : "pin")
                    }
                    .toggleStyle(.button)
                    .accessibilityIdentifier("conceptPageDetail_pinToggle")
                    .accessibilityLabel(String(localized: "ConceptPage.editSheet.pin"))
                    Menu {
                        Button { showEditSheet = true } label: {
                            Label("編集", systemImage: "square.and.pencil")
                        }
                        Button(role: .destructive) {
                            conceptPage.isHidden = true
                            try? context.save()
                            dismiss()
                        } label: {
                            Label("wiki.hide.action", systemImage: "eye.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("conceptPageDetail_editButton")
                }
                .foregroundStyle(DS.Color.sumiInk)
            }
        }
        .navigationDestination(item: $wikiLinkTarget) { target in
            // spec 064: 本文リンク → 既存 Loader 経由で push (削除済は Loader の @Query guard で安全)
            ConceptPageDetailLoader(destinationID: target.id)
        }
        // spec 058 polish: 親 NavigationStack (KnowledgeClipView) で同 destination 宣言済、
        // 重複宣言で warning が出るため削除。「学習する」 button からの navigation は親経由で動作。
        .sheet(isPresented: $showEditSheet) {
            if let store = services.conceptPageStore {
                ConceptPageEditSheet(
                    conceptPage: conceptPage,
                    store: store,
                    onSourceGone: {
                        // merge / delete で source page が消えた → sheet 閉じ
                        // (DetailView の short-circuit + Loader auto-pop で navigation 戻る)
                        showEditSheet = false
                    }
                )
            }
        }
        .accessibilityIdentifier("conceptPageDetail_root")
    }

    // MARK: - Sections

    private var categoryDisplay: String {
        CategorySeed.category(for: conceptPage.categoryRaw).name
    }

    /// 全幅0.5px墨線（セクション間区切り）
    private var sumiRuleDivider: some View {
        Rectangle()
            .fill(DS.Color.sumiRule)
            .frame(height: 0.5)
    }

    /// セクション見出し — 太細縦線 + serif（SumiSectionHeader の padding なし版）
    private func sectionHeader(_ titleKey: LocalizedStringKey) -> some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            HStack(spacing: 2) {
                Rectangle().frame(width: 3, height: 14).foregroundStyle(DS.Color.sumiInk)
                Rectangle().frame(width: 1, height: 14).foregroundStyle(DS.Color.sumiMid)
            }
            Text(titleKey)
                .font(.subheadline.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(DS.Color.sumiInk)
            Spacer()
        }
        .accessibilityAddTraits(.isHeader)
    }

    /// スクロール内大タイトル + カテゴリチップ + メタデータ
    private var heroTitleSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(conceptPage.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontDesign(.serif)
                .foregroundStyle(DS.Color.sumiInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DS.Spacing.md) {
                Text(categoryDisplay)
                    .font(.caption)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xxs)
                    .overlay(Capsule().stroke(DS.Color.sumiRule, lineWidth: 0.5))
                    .foregroundStyle(DS.Color.sumiMid)

                Text(String(format: String(localized: "ConceptPage.card.relatedCount"), (conceptPage.relatedArticles ?? []).count))
                    .font(.caption)
                    .foregroundStyle(DS.Color.sumiLight)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(DS.Color.sumiLight)
                Text(SavedAtFormatter.format(conceptPage.updatedAt))
                    .font(.caption)
                    .foregroundStyle(DS.Color.sumiLight)
            }
        }
        .accessibilityIdentifier("conceptPageDetail_header")
    }

    /// 旧 headerSection — heroTitleSection に統合のため空にする
    private var headerSection: some View {
        EmptyView()
    }

    /// spec 063 (LLM Wiki): AI が書いた Markdown 本文を整形表示。空なら非表示。
    @ViewBuilder
    private var wikiBodySection: some View {
        if !conceptPage.bodyMarkdown.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                sectionHeader("wiki.body.sectionTitle")
                // spec 079: 行ベースレンダラで見出し/箇条書きを整形 + 生 concept-id 漏れを除去。
                WikiBodyView(markdown: conceptPage.bodyMarkdown)
                    .environment(\.openURL, OpenURLAction { url in
                        // spec 064: concept-id:// は自前遷移、それ以外は OS 標準動作
                        if let id = Self.extractConceptID(from: url) {
                            wikiLinkTarget = WikiLinkTarget(id: id)
                            return .handled
                        }
                        return .systemAction
                    })
            }
            .accessibilityIdentifier("conceptPageDetail_wikiBody")
        }
    }

    /// Markdown を AttributedString に整形 (失敗時は plain text fallback)。
    /// spec 064: `concept-id://<UUID>` URL から UUID を復元 (spec 033 article-id:// と同型)。
    static func extractConceptID(from url: URL) -> UUID? {
        guard url.scheme == "concept-id" else { return nil }
        let raw = url.host ?? url.absoluteString.replacingOccurrences(of: "concept-id://", with: "")
        return UUID(uuidString: raw)
    }

    static func renderMarkdown(_ markdown: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(markdown)
    }

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("ConceptPage.detail.summary.title")
            if conceptPage.isSynthesisInProgress {
                HStack(spacing: DS.Spacing.md) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("ConceptPage.detail.synthesisInProgress")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(conceptPage.summary)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(DS.Typography.bodyLineSpacing)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("conceptPageDetail_summarySection")
    }

    /// spec 089: index 番目の要点の出典記事 (insightSourceArticleIDs と relatedArticles から解決)。
    private func insightSourceArticle(at index: Int) -> Article? {
        guard index < conceptPage.insightSourceArticleIDs.count else { return nil }
        let id = conceptPage.insightSourceArticleIDs[index]
        guard !id.isEmpty else { return nil }
        return (conceptPage.relatedArticles ?? []).first { $0.id.uuidString == id }
    }

    @ViewBuilder
    private var crossSourceInsightsSection: some View {
        if !conceptPage.crossSourceInsights.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                sectionHeader("ConceptPage.detail.crossSourceInsights.title")
                ForEach(Array(conceptPage.crossSourceInsights.enumerated()), id: \.offset) { index, insight in
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(alignment: .top, spacing: DS.Spacing.sm) {
                            Text("•")
                                .font(.body)
                                .foregroundStyle(DS.Color.sumiInk)
                            Text(insight)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // spec 089: 各要点の出典 (最も関連する元記事) をタップで開ける。
                        if let article = insightSourceArticle(at: index) {
                            NavigationLink(value: article) {
                                HStack(spacing: DS.Spacing.xxs) {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                    Text("ConceptPage.insight.source \(article.title)")
                                        .font(.caption)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                }
                                .foregroundStyle(DS.Color.sumiInk)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, DS.Spacing.lg)
                        }
                    }
                }
            }
            .accessibilityIdentifier("conceptPageDetail_crossSourceInsightsSection")
        }
    }

    @ViewBuilder
    private var relatedArticlesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            sectionHeader("ConceptPage.detail.relatedArticles.title")
            if (conceptPage.relatedArticles ?? []).isEmpty {
                Text("ConceptPage.detail.emptyRelatedArticles")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach((conceptPage.relatedArticles ?? []).sorted(by: { $0.savedAt > $1.savedAt }), id: \.id) { article in
                    NavigationLink(value: article) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(article.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(SavedAtFormatter.format(article.savedAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .accessibilityIdentifier("conceptPageDetail_relatedArticlesSection")
    }

    @ViewBuilder
    private var relatedConceptsSection: some View {
        let others = relatedConcepts()
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                sectionHeader("ConceptPage.detail.relatedConcepts.title")
                FlowingTagsLayout(spacing: DS.Spacing.sm) {
                    ForEach(others, id: \.id) { other in
                        NavigationLink(value: ConceptPageDetailDestination(id: other.id)) {
                            Text(other.name)
                                .font(.caption)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Color.tagFill, in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .accessibilityIdentifier("conceptPageDetail_relatedConceptsSection")
        }
    }

    // MARK: - spec 075: 階層ドリルダウン

    /// 上位概念 (親) へのブレッドクラムリンク。親がいる specific 概念のみ表示。
    @ViewBuilder
    private var parentBreadcrumb: some View {
        if let parent = parentPage {
            NavigationLink(value: ConceptPageDetailDestination(id: parent.id)) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.up.left")
                        .font(.caption2)
                    Text("concept.parent.label")
                    Text("▸")
                    Text(parent.name)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(DS.Color.sumiInk)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("conceptPageDetail_parentBreadcrumb")
        }
    }

    /// 「詳細トピック (子 N)」セクション。子 specific 概念へドリルダウン。子がいる broad のみ表示。
    @ViewBuilder
    private var childConceptsSection: some View {
        let children = childPages
        if !children.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                sectionHeader("concept.children.title")
                ForEach(children, id: \.id) { child in
                    NavigationLink(value: ConceptPageDetailDestination(id: child.id)) {
                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            Image(systemName: child.kind.symbolName)
                                .font(.body)
                                .foregroundStyle(DS.Color.sumiInk)
                                .frame(width: 24, alignment: .center)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(child.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if !child.summaryPreview.isEmpty {
                                    Text(child.summaryPreview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
            .accessibilityIdentifier("conceptPageDetail_childConceptsSection")
        }
    }
}
