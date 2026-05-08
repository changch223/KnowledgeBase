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

struct ChatMessageRow: View {
    let message: ChatMessage
    /// spec 033: 擬似 streaming 表示用 override (nil の時は message.text を表示)
    var streamingTextOverride: String? = nil

    @Query private var allArticles: [Article]
    @Environment(\.openURL) private var openURL

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
                        // article-id://UUID を捕捉、Article fetch + 詳細遷移
                        if let id = Self.extractArticleID(from: url),
                           let article = allArticles.first(where: { $0.id == id }) {
                            // navigationDestination(for: Article.self) は ChatTabView 側にある想定
                            // SwiftUI の openURL は NavigationStack に value を push できないため、
                            // 代替: NotificationCenter or environment を介す。本 MVP では .systemAction で
                            // 「処理した」だけ返し、tap で何か起きない。tap-to-navigate は補助 DisclosureGroup
                            // で代替 (見つけやすさは確保)。inline link は視覚的アクセント役を担う。
                            _ = article
                            return .handled
                        }
                        return .systemAction
                    })
            }

            if !message.citedArticleIDs.isEmpty {
                CitedArticlesSection(articleIDs: message.citedArticleIDs)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
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
