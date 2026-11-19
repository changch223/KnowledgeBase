//
//  CitationPreviewSheet.swift
//  KnowledgeTree
//
//  spec 104 — 出典 (チャットの番号リンク / 出典リスト / トピックの要点の出典) をタップしたとき、
//  いきなり記事詳細へ飛ばさず、下からプレビューを出す。「記事を開く」で記事詳細へ。
//

import SwiftUI

struct CitationPreviewSheet: View {
    let article: Article
    let onOpen: () -> Void

    private var title: String {
        let raw = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = raw.isEmpty ? (article.enrichment?.canonicalTitle ?? article.url) : raw
        return TitleCleaner.clean(base, host: TitleCleaner.webHost(of: article.url))
    }

    private var sourceAndDate: String {
        let source = ArticleSourceLabel.label(for: article.url).localizedText
        let date = SavedAtFormatter.format(article.savedAt)
        return source.isEmpty ? date : "\(source) ・ \(date)"
    }

    /// essence (無ければ enrichment.summary)。
    private var previewText: String? {
        if let e = article.extractedKnowledge?.essence?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty {
            return e
        }
        if let s = article.enrichment?.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return s
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .font(.headline)
                .fontDesign(.serif)
                .foregroundStyle(DS.Color.sumiInk)
                .lineLimit(2)
            Text(sourceAndDate)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let previewText {
                Text(previewText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(5)
            }
            Spacer(minLength: 0)
            Button {
                onOpen()
            } label: {
                Text("citation.preview.open")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("citation.preview.open")
        }
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.washiBackground)
        .presentationDetents([.height(280), .medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("citationPreviewSheet")
    }
}
