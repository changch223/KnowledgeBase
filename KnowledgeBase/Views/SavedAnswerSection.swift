//
//  SavedAnswerSection.swift
//  KnowledgeTree
//
//  spec 043 — ConceptPage 詳細画面の「この概念についての質問と答え」セクション。
//  該当 ConceptPage に紐付く SavedAnswer (relatedConceptIDs.contains(conceptPageID)) を
//  isPinned 優先 + savedAt desc で上位 5 件表示、6+ 件で「+N すべて見る」リンク。
//

import SwiftUI
import SwiftData

struct SavedAnswerSection: View {
    let conceptPageID: UUID
    @Query private var allAnswers: [SavedAnswer]

    init(conceptPageID: UUID) {
        self.conceptPageID = conceptPageID
        _allAnswers = Query(
            sort: [SortDescriptor(\SavedAnswer.savedAt, order: .reverse)]
        )
    }

    /// in-memory filter (SwiftData @Predicate は [UUID].contains を直接サポートしないため) + sort
    private var relatedAnswers: [SavedAnswer] {
        allAnswers
            .filter { $0.relatedConceptIDs.contains(conceptPageID) }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.savedAt > rhs.savedAt
            }
    }

    var body: some View {
        if relatedAnswers.isEmpty {
            // 関連 SavedAnswer 0 件で section 自体非表示 (Constitution V calm UX)
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(String(format: String(localized: "ConceptPage.detail.savedAnswers.title"), relatedAnswers.count))
                    .font(.title3.bold())

                ForEach(relatedAnswers.prefix(5), id: \.id) { answer in
                    NavigationLink(value: SavedAnswerDetailDestination(id: answer.id)) {
                        SavedAnswerRow(answer: answer)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }

                if relatedAnswers.count > 5 {
                    NavigationLink(value: SavedAnswerListByConceptDestination(conceptPageID: conceptPageID)) {
                        Text(String(format: String(localized: "ConceptPage.detail.savedAnswers.showAll"), relatedAnswers.count - 5))
                            .font(.caption)
                            .foregroundStyle(DS.Color.sumiInk)
                    }
                }
            }
            .accessibilityIdentifier("conceptPageDetail_savedAnswersSection")
        }
    }
}
