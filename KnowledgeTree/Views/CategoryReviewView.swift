//
//  CategoryReviewView.swift
//  KnowledgeTree
//
//  spec 097 Phase 4 — 分類の整理レポート。
//  確信度が低い (Low/Medium) or 「その他」のタグだけを一覧し、その場で正しい分野に直せる。
//  修正は学習ストアに記録され (誤り→正解)、次回以降の分類で few-shot として効く (精度向上ループ)。
//

import SwiftUI
import SwiftData

struct CategoryReviewView: View {
    @Query private var allTags: [Tag]
    @Query(sort: \CategoryDefinition.order) private var allCategories: [CategoryDefinition]
    @Query private var allConcepts: [ConceptPage]

    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refresh

    // spec 097 Phase 4: 精度の可視化。
    private var confidenceCounts: (high: Int, medium: Int, low: Int) {
        var h = 0, m = 0, l = 0
        for t in allTags {
            switch t.categoryConfidence {
            case ClassificationConfidence.high.rawValue: h += 1
            case ClassificationConfidence.medium.rawValue: m += 1
            case ClassificationConfidence.low.rawValue: l += 1
            default: break
            }
        }
        return (h, m, l)
    }
    private var splitConceptCount: Int {
        allConcepts.filter { !$0.isHidden && CategoryConsistency.isSplit($0) }.count
    }

    private var uncertainTags: [Tag] {
        allTags
            .filter { Self.isUncertain($0) }
            // 記事数が多い = 影響が大きい順に。同数なら名前順。
            .sorted { lhs, rhs in
                let lc = (lhs.articles ?? []).count, rc = (rhs.articles ?? []).count
                if lc != rc { return lc > rc }
                return lhs.name < rhs.name
            }
    }

    /// 確信度 Low/Medium or その他 = 要確認。
    static func isUncertain(_ t: Tag) -> Bool {
        let c = t.categoryConfidence
        return c == ClassificationConfidence.low.rawValue
            || c == ClassificationConfidence.medium.rawValue
            || (t.categoryRaw ?? "") == CategorySeed.otherCategory.name
    }

    var body: some View {
        List {
            statsSection
            if uncertainTags.isEmpty {
                Section {
                    ContentUnavailableView(
                        "category.review.empty",
                        systemImage: "checkmark.seal",
                        description: Text("category.review.empty.desc")
                    )
                }
            } else {
                Section {
                    ForEach(uncertainTags) { tag in
                        row(tag)
                    }
                } header: {
                    Text("category.review.hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .navigationTitle("category.review.title")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("category.review.root")
    }

    // spec 097 Phase 4: 精度の可視化 (学習量 / 確信度内訳 / 不一致)。
    @ViewBuilder
    private var statsSection: some View {
        let c = confidenceCounts
        Section {
            statRow("category.review.stats.learned", value: "\(services.correctionStore?.count ?? 0)")
            statRow("category.review.stats.confidence", value: "High \(c.high) / Med \(c.medium) / Low \(c.low)")
            statRow("category.review.stats.split", value: "\(splitConceptCount)")
        } header: {
            Text("category.review.stats.title")
                .textCase(nil)
        }
    }

    @ViewBuilder
    private func statRow(_ label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func row(_ tag: Tag) -> some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name).font(.body)
                Text(tag.categoryRaw ?? CategorySeed.otherCategory.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("tag.management.row.articleCount \((tag.articles ?? []).count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Menu {
                ForEach(allCategories.filter { !$0.isHidden }) { cat in
                    Button(cat.name) { apply(tag, to: cat.name) }
                }
            } label: {
                Label("category.review.fix", systemImage: "square.grid.2x2")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(DS.Color.actionBlue)
            }
            .accessibilityIdentifier("category.review.fix")
        }
        .padding(.vertical, 4)
    }

    private func apply(_ tag: Tag, to category: String) {
        CategoryCorrectionApplier.apply(
            tag: tag, to: category,
            store: services.correctionStore, context: modelContext, refresh: refresh
        )
    }
}
