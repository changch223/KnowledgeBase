//
//  ConflictHistoryDisclosure.swift
//  KnowledgeTree
//
//  spec 058 — ArticleDetailView 末尾に表示する「過去の見解 (N) ▼」 DisclosureGroup。
//  ConflictProposal 経由で関連する古い Article を表示、ユーザーが「過去がある」と知れる。
//  Apple HIG calm UX (default 非展開、tap で展開)、データロスゼロ保証。
//

import SwiftUI
import SwiftData

struct ConflictHistoryDisclosure: View {
    let currentArticle: Article

    /// この Article に関連する ConflictProposal (新側 = current)
    @Query private var asNewArticleProposals: [ConflictProposal]
    /// この Article に関連する ConflictProposal (旧側 = current)
    @Query private var asOldArticleProposals: [ConflictProposal]

    init(currentArticle: Article) {
        self.currentArticle = currentArticle
        let articleID = currentArticle.id
        // 新側として登場する proposals
        _asNewArticleProposals = Query(filter: #Predicate<ConflictProposal> { proposal in
            proposal.newArticle?.id == articleID
        })
        // 旧側として登場する proposals
        _asOldArticleProposals = Query(filter: #Predicate<ConflictProposal> { proposal in
            proposal.oldArticle?.id == articleID
        })
    }

    /// 過去の見解 = 現 Article が「新側」のときの old article + 「旧側」のときの new article
    private var pastViewArticles: [(article: Article, proposal: ConflictProposal)] {
        var result: [(article: Article, proposal: ConflictProposal)] = []
        for p in asNewArticleProposals {
            if let old = p.oldArticle {
                result.append((old, p))
            }
        }
        for p in asOldArticleProposals {
            if let new = p.newArticle {
                result.append((new, p))
            }
        }
        return result.sorted { $0.article.savedAt > $1.article.savedAt }
    }

    var body: some View {
        if !pastViewArticles.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(pastViewArticles, id: \.article.id) { (article, proposal) in
                        PastViewArticleRow(article: article, proposal: proposal)
                    }
                }
                .padding(.top, DS.Spacing.md)
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                    Text("conflict.pastViews.label \(pastViewArticles.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DS.Spacing.lg)
            .background(DS.Color.surfaceSecondary, in: .rect(cornerRadius: DS.Radius.chip))
            .accessibilityIdentifier("article.pastViews.disclosure")
        }
    }
}

private struct PastViewArticleRow: View {
    let article: Article
    let proposal: ConflictProposal

    private var relativeAge: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: article.savedAt, relativeTo: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(article.title)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text(relativeAge)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if !proposal.oldFact.isEmpty {
                Text(proposal.oldFact)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
