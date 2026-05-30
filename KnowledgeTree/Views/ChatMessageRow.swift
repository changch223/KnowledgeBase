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
            .background(DS.Color.actionBlue, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
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
                    }
                )
            }

            if !message.citedArticleIDs.isEmpty {
                CitedArticlesSection(articleIDs: message.citedArticleIDs)
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

    /// AttributedString を生成 — `[タイトル](article-id://UUID)` を inline link 化、
    /// 同時に下線 + actionBlue 色を付ける。
    private var attributedAnswerText: AttributedString {
        let raw = message.text
        var attributed = AttributedString(raw)

        // Markdown link 形式を regex で抽出
        let pattern = #"\[([^\]]+)\]\(article-id://([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return attributed
        }
        let nsText = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(location: 0, length: nsText.length))

        // 後ろから置換 (range が前から処理すると壊れるため)
        var output = AttributedString()
        var cursor = raw.startIndex
        for match in matches {
            guard let fullRange = Range(match.range, in: raw),
                  let titleRange = Range(match.range(at: 1), in: raw),
                  let uuidRange = Range(match.range(at: 2), in: raw) else { continue }

            // 前置部分
            output.append(AttributedString(raw[cursor..<fullRange.lowerBound]))

            // link 部分
            let title = String(raw[titleRange])
            let uuidString = String(raw[uuidRange])
            var linkAttr = AttributedString(title)
            if let url = URL(string: "article-id://\(uuidString)") {
                linkAttr.link = url
            }
            linkAttr.foregroundColor = DS.Color.actionBlue
            linkAttr.underlineStyle = .single
            output.append(linkAttr)

            cursor = fullRange.upperBound
        }
        // 残り
        if cursor < raw.endIndex {
            output.append(AttributedString(raw[cursor..<raw.endIndex]))
        }
        attributed = output
        return attributed
    }

    /// `article-id://UUID` URL から UUID を抽出
    static func extractArticleID(from url: URL) -> UUID? {
        guard url.scheme == "article-id" else { return nil }
        let host = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return UUID(uuidString: host)
    }
}

private struct CitedArticlesSection: View {
    let articleIDs: [String]
    @Query private var allArticles: [Article]

    private var citedArticles: [Article] {
        let idSet = Set(articleIDs)
        // 順序を citedArticleIDs の順に保つ
        let mapped = allArticles.filter { idSet.contains($0.id.uuidString) }
        let dict = Dictionary(uniqueKeysWithValues: mapped.map { ($0.id.uuidString, $0) })
        return articleIDs.compactMap { dict[$0] }
    }

    var body: some View {
        if citedArticles.isEmpty {
            EmptyView()
        } else {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(citedArticles) { article in
                        NavigationLink(value: article) {
                            HStack(spacing: DS.Spacing.sm) {
                                Text(article.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                Spacer()
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
            } label: {
                Text("chat.message.cited.count \(citedArticles.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("chat.message.citedSection")
        }
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
