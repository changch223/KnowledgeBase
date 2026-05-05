//
//  ArticleRow.swift
//  KnowledgeTree
//
//  spec 001-003 — タイトル / URL / サムネイル / enrichment summary / status badge
//  spec 004 — essence + entity chips (上位 3) + 「AI 生成」ラベルを追加
//

import SwiftUI

struct ArticleRow: View {
    /// SwiftData @Model は Observation framework に乗っているため、
    /// `@Bindable` で受けると body 内で読んだ relationship target のプロパティ
    /// (article.enrichment.canonicalTitle 等) も Observation tracking 対象になる。
    /// これが SwiftData + SwiftUI の正規な観察手段。
    @Bindable var article: Article
    /// transitive observation が効かない場合のフォールバック refresh tick。
    var refreshTick: Int = 0
    /// spec 008: 検索結果モード時のクエリ文字列。空文字なら通常表示。
    var searchQuery: String = ""

    /// spec 008: 検索結果ハイライト (マッチ行を行末に追加表示)
    private var searchHighlight: SearchHighlight? {
        SearchHighlighter.highlight(article: article, query: searchQuery)
    }

    /// 共有時のタイトル (Article.title) を優先。
    /// 共有時のタイトルが空 / プレースホルダの場合のみ canonicalTitle にフォールバック。
    /// Why: 共有時にユーザーが見たタイトルが保存意図に最も近い。
    /// canonicalTitle は HTML <title> のまま (例: 「KFC」) で情報量が落ちる場合があるため。
    private var displayTitle: String {
        let shareTitle = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !shareTitle.isEmpty, shareTitle != article.url {
            return shareTitle
        }
        if let canonical = article.enrichment?.canonicalTitle, !canonical.isEmpty {
            return canonical
        }
        return article.title
    }

    private var enrichmentSummaryText: String? {
        guard let s = article.enrichment?.summary, !s.isEmpty else { return nil }
        return s
    }

    private var knowledgeAvailable: Bool {
        guard let knowledge = article.extractedKnowledge else { return false }
        return knowledge.status == .succeeded || knowledge.status == .partiallySucceeded
    }

    private var essenceText: String? {
        guard knowledgeAvailable,
              let essence = article.extractedKnowledge?.essence,
              !essence.isEmpty
        else { return nil }
        return essence
    }

    private var topEntities: [KnowledgeEntity] {
        guard knowledgeAvailable,
              let entities = article.extractedKnowledge?.entities,
              !entities.isEmpty
        else { return [] }
        return entities.sorted {
            if $0.salience != $1.salience { return $0.salience > $1.salience }
            return $0.order < $1.order
        }.prefix(3).map { $0 }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Leading edge accent: knowledge 完了記事のみ表示
            if knowledgeAvailable {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DS.Color.aiBrandEnd)
                    .frame(width: 3)
                    .padding(.trailing, DS.Spacing.sm)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .top, spacing: DS.Spacing.xl) {
                    thumbnailOrPlaceholder

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(displayTitle)
                            .font(DS.Typography.rowTitle)
                            .lineLimit(2)

                        if let essence = essenceText {
                            Text(essence)
                                .font(.caption)
                                .foregroundStyle(DS.Color.textEmphasis)
                                .lineLimit(2)
                        } else if let summary = enrichmentSummaryText {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        if !topEntities.isEmpty {
                            HStack(spacing: DS.Spacing.xs) {
                                ForEach(topEntities, id: \.id) { entity in
                                    EntityChip(entity: entity)
                                }
                            }
                        }

                        Text(article.url)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        // spec 004: 「AI 生成」カプセルバッジ
                        if knowledgeAvailable {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "sparkles")
                                    .font(DS.Typography.aiLabel)
                                Text("knowledge.aiGeneratedLabel")
                                    .font(DS.Typography.aiLabel)
                            }
                            .foregroundStyle(DS.Color.aiBrandEnd)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(DS.Color.aiBrandEnd.opacity(0.08), in: Capsule())
                            .accessibilityIdentifier("knowledgeAIGeneratedLabel")
                        }
                    }

                    Spacer(minLength: 0)

                    if let enrichment = article.enrichment {
                        EnrichmentStatusBadge(status: enrichment.status)
                    }
                }

                // spec 008: 検索結果モード時のハイライト excerpt 行
                if let highlight = searchHighlight {
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Text(highlight.fieldName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 60, alignment: .leading)
                        Text(highlight.excerpt)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    .accessibilityIdentifier("searchHighlight")
                }
            }
            .padding(.vertical, DS.Spacing.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(combinedAccessibilityLabel)
        .id(refreshTick)
    }

    /// サムネイル URL なし時は doc.text プレースホルダーで左列アンカーを統一
    private var thumbnailOrPlaceholder: some View {
        Group {
            if article.enrichment?.ogImageURL != nil {
                ThumbnailView(urlString: article.enrichment?.ogImageURL)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.thumb)
                        .fill(DS.Color.overlaySubtle)
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            }
        }
    }

    private var combinedAccessibilityLabel: String {
        var parts: [String] = [displayTitle]
        if let essence = essenceText {
            parts.append(essence)
        } else if let summary = enrichmentSummaryText {
            parts.append(summary)
        }
        parts.append(article.url)
        return parts.joined(separator: ", ")
    }
}
