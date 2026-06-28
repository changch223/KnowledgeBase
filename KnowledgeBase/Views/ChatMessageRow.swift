//
//  ChatMessageRow.swift
//  KnowledgeTree
//
//  spec 021 — AI Chat (RAG) の 1 message 表示。
//  spec 033 (2026-05-08): 擬似 streaming + inline 引用 link 対応。
//  - user: 右寄せ actionBlue 背景 + white text
//  - assistant: 左寄せ dsCardBackground
//    - inline link `[タイトル](article-id://UUID)` を AttributedString で描画、tap で ArticleDetailView
//    - streamingTextOverride が設定されると本文をその text に置き換え (1 文字ずつ追加表示)
//    - DisclosureGroup の引用記事一覧は補助的に併記 (spec 033 FR-025)
//

import SwiftUI
import SwiftData
import Combine

struct ChatMessageRow: View {
    let message: ChatMessage
    /// spec 033: 擬似 streaming 表示用 override (nil の時は message.text を表示)
    var streamingTextOverride: String? = nil
    /// spec 059 (P0-4): 引用リンク tap 時に親へ Article を通知。nil の時は遷移しない。
    var onArticleLinkTap: ((Article) -> Void)? = nil

    @Query private var allArticles: [Article]
    @Environment(\.openURL) private var openURL
    /// spec 057: long press menu 「保存」で SavedAnswerService 利用
    @Environment(ServiceContainer.self) private var serviceContainer

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == ChatMessageRole.user.rawValue {
                Spacer(minLength: 40)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 40)
            }
        }
        .accessibilityIdentifier("chat.message.row.\(message.role)")
    }

    private var userBubble: some View {
        Text(message.text)
            .font(.body)
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Color.sumiFixedInk, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // spec 081: ナレッジベース外の一般回答には『一般知識』バッジ
            if message.answeredFromGeneralKnowledge {
                GeneralKnowledgeBadge()
            }

            // streaming 中は AttributedString による inline link が崩れないよう、plain Text にフォールバック
            if let streamingText = streamingTextOverride {
                Text(streamingText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(attributedAnswerText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.openURL, OpenURLAction { url in
                        // spec 059 (P0-4): 引用リンク tap → 親 (ChatTabView) へ Article を通知し遷移。
                        if let id = Self.extractArticleID(from: url),
                           let article = allArticles.first(where: { $0.id == id }) {
                            onArticleLinkTap?(article)
                            return .handled
                        }
                        return .systemAction
                    })
            }

            // spec 057: clarification suggestions chip 表示 (assistant + suggestions 非空)
            if !message.clarificationSuggestions.isEmpty {
                ClarificationChipsView(
                    suggestions: message.clarificationSuggestions,
                    onTap: { selected in
                        ChatMessageRow.clarificationTapNotificationPublisher.send(selected)
                    },
                    onOther: {
                        // spec 083: 「その他（自由に入力）」→ 送信せず入力欄にフォーカス
                        ChatMessageRow.clarificationOtherTapNotificationPublisher.send(())
                    }
                )
            }

            // spec 081: ChatGPT/Gemini スタイルの番号付き「出典」リスト
            let sources = citationResult.sources
            if !sources.isEmpty {
                CitationSourcesSection(sources: sources)
            }
            if !message.citedArticleIDs.isEmpty {
                // spec 047: 引用記事から関連 ConceptPage chips を導出
                RelatedConceptsChips(articleIDs: message.citedArticleIDs)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
        // spec 057: long press → 保存 / コピー / 共有
        .contextMenu {
            AnswerActionsMenu(
                question: previousUserQuestion,
                answer: message.text,
                citedArticleIDs: message.citedArticleIDs.compactMap { UUID(uuidString: $0) },
                onSave: { saveExplicit() }
            )
        }
    }

    /// spec 057: clarification chip tap を ChatTabView に通知する Combine subject (static)。
    static let clarificationTapNotificationPublisher = PassthroughSubject<String, Never>()

    /// spec 083: clarification「その他（自由に入力）」tap を ChatTabView に通知 (入力欄フォーカス用)。
    static let clarificationOtherTapNotificationPublisher = PassthroughSubject<Void, Never>()

    /// spec 057: assistant message に紐付く直前の user message text (long press 「保存」用)。
    /// 同 session 内で本 message より前の user message を探す。
    private var previousUserQuestion: String {
        guard let session = message.session else { return "" }
        let sorted = (session.messages ?? []).sorted { $0.timestamp < $1.timestamp }
        guard let myIndex = sorted.firstIndex(where: { $0.id == message.id }) else { return "" }
        let earlier = sorted.prefix(myIndex)
        return earlier.reversed().first(where: { $0.role == ChatMessageRole.user.rawValue })?.text ?? ""
    }

    private func saveExplicit() {
        guard !message.clarificationSuggestions.isEmpty == false else {
            // clarification message は保存しない (assistant answer のみ)
            return
        }
        guard let service = serviceContainer.savedAnswerService else { return }
        do {
            _ = try service.saveExplicit(
                question: previousUserQuestion,
                answer: message.text,
                citedArticleIDs: message.citedArticleIDs,
                sessionID: message.session?.id
            )
        } catch {
            // silent fail (logger なし、UI feedback は haptic で代替)
        }
    }

    /// spec 081: 本文 + citedArticleIDs を番号引用 segments + 出典リストに整形 (純粋関数)。
    private var citationResult: ChatCitationFormatter.Result {
        ChatCitationFormatter.format(body: message.text, citedArticleIDs: message.citedArticleIDs)
    }

    /// spec 081: 本文を組み立て — 引用マーカーを上付き青 `[n]` リンク (tap で記事へ) に変換。
    /// 旧形式 `[タイトル](article-id://UUID)` も formatter が後方互換で番号化する。
    private var attributedAnswerText: AttributedString {
        var output = AttributedString()
        for segment in citationResult.segments {
            switch segment {
            case .text(let text):
                output.append(AttributedString(text))
            case .citation(let number, let articleID):
                var marker = AttributedString("[\(number)]")
                if let url = URL(string: "article-id://\(articleID.uuidString)") {
                    marker.link = url
                }
                marker.foregroundColor = DS.Color.sumiInk
                marker.font = .footnote
                output.append(marker)
            }
        }
        return output
    }

    /// `article-id://UUID` URL から UUID を抽出
    static func extractArticleID(from url: URL) -> UUID? {
        guard url.scheme == "article-id" else { return nil }
        let host = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return UUID(uuidString: host)
    }
}

/// spec 081: ChatGPT/Gemini スタイルの番号付き「出典」リスト。
/// `[n] 記事タイトル` を常時表示、tap で ArticleDetailView 遷移。引用元 Article が削除済なら行を省く。
private struct CitationSourcesSection: View {
    let sources: [ChatCitationFormatter.Source]
    @Query private var allArticles: [Article]

    private var resolved: [(number: Int, article: Article)] {
        let byID = Dictionary(uniqueKeysWithValues: allArticles.map { ($0.id, $0) })
        return sources.compactMap { source in
            guard let article = byID[source.articleID] else { return nil }
            return (source.number, article)
        }
    }

    var body: some View {
        let rows = resolved
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("chat.message.sources.title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(rows, id: \.number) { row in
                    NavigationLink(value: row.article) {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                            Text("[\(row.number)]")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(DS.Color.sumiInk)
                            Text(row.article.title)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, DS.Spacing.xs)
                    }
                    .accessibilityIdentifier("chat.message.citedRow")
                }
            }
            .padding(.top, DS.Spacing.sm)
            .accessibilityIdentifier("chat.message.citedSection")
        }
    }
}

/// spec 081: ナレッジベース外の一般回答を示す控えめなバッジ。
private struct GeneralKnowledgeBadge: View {
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "info.circle")
                .font(.caption2)
            Text("chat.message.generalKnowledge.badge")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Color.tagFill, in: Capsule())
        .accessibilityIdentifier("chat.message.generalKnowledgeBadge")
    }
}

// MARK: - spec 047: RelatedConceptsChips

/// 引用記事から関連 ConceptPage を overlap top 3 で chip 表示。
/// 0 件で `EmptyView()` (calm UX)、タップで `ConceptPageDetailDestination` 遷移。
private struct RelatedConceptsChips: View {
    let articleIDs: [String]
    @Query private var allConceptPages: [ConceptPage]

    /// overlap 数 desc で top 3 (overlap > 0 のみ)
    private var topRelated: [(page: ConceptPage, overlap: Int)] {
        let citedIDSet = Set(articleIDs.compactMap(UUID.init(uuidString:)))
        guard !citedIDSet.isEmpty else { return [] }
        let scored = allConceptPages.compactMap { page -> (ConceptPage, Int)? in
            let overlap = (page.relatedArticles ?? []).filter { citedIDSet.contains($0.id) }.count
            return overlap > 0 ? (page, overlap) : nil
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { ($0.0, $0.1) }
    }

    var body: some View {
        let top = topRelated
        if top.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(String(format: String(localized: "関連する概念 (%lld)"), top.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                FlowingTagsLayout(spacing: DS.Spacing.sm) {
                    ForEach(top, id: \.page.id) { entry in
                        NavigationLink(value: ConceptPageDetailDestination(id: entry.page.id)) {
                            Text(entry.page.name)
                                .font(.caption)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Color.tagFill, in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("chat.message.relatedConcept.\(entry.page.id.uuidString)")
                        .accessibilityLabel(Text("\(entry.page.name) 概念"))
                    }
                }
            }
            .padding(.top, DS.Spacing.xs)
        }
    }
}
