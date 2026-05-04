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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                ThumbnailView(urlString: article.enrichment?.ogImageURL)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.body)
                        .lineLimit(2)

                    // spec 004: essence 優先、なければ enrichment summary
                    if let essence = essenceText {
                        Text(essence)
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.85))
                            .lineLimit(2)
                    } else if let summary = enrichmentSummaryText {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    // spec 004: entity chips (上位 3、salience 順)
                    if !topEntities.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(topEntities, id: \.id) { entity in
                                EntityChip(entity: entity)
                            }
                        }
                    }

                    Text(article.url)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    // spec 004: 「AI 生成」ラベル (knowledge 表示があるとき)
                    if knowledgeAvailable {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text("knowledge.aiGeneratedLabel")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
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
                HStack(alignment: .top, spacing: 6) {
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
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(combinedAccessibilityLabel)
        // refreshTick を ID として使い、parent の refreshTick incremenet で
        // ArticleRow の view tree を再生成 → enrichment / knowledge を読み直す。
        .id(refreshTick)
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
