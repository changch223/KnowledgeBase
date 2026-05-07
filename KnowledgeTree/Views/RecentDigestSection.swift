//
//  RecentDigestSection.swift
//  KnowledgeTree
//
//  spec 035 — 知識 Clip タブ最上部の「最近のあなた」セクション。
//  RecentDigestService が生成した 3 段落を card 形式で表示。
//  差分 0 件 (期間内に新記事なし) の場合は section 自体を非表示。
//

import SwiftUI
import SwiftData

struct RecentDigestSection: View {
    @Query private var allArticles: [Article]
    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var serviceContainer

    @State private var result: RecentDigestResult = .empty
    @State private var isLoading: Bool = false
    @State private var lastGeneratedSince: Date?

    /// 親 view (KnowledgeClipView) から渡される since 値。
    /// onAppear で値が確定するため、binding ではなく @State + .onAppear で更新。
    let since: Date

    var body: some View {
        if result.isEmpty && !isLoading {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, DS.Spacing.lg)
                } else {
                    paragraphsView
                    metaCaption
                }
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCardBackground()
            .padding(.horizontal, DS.Spacing.lg)
            .task(id: since) {
                await regenerateIfNeeded()
            }
            .accessibilityIdentifier("clip.recent.section")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        Text("clip.recent.title")
            .font(DS.Typography.sectionTitle)
            .foregroundStyle(.primary)
    }

    private var paragraphsView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(Array(result.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var metaCaption: some View {
        Text("clip.recent.meta \(result.articleCount)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Action

    private func regenerateIfNeeded() async {
        guard let service = serviceContainer.recentDigestService else { return }
        // 同 since 値で 2 度目以降は再生成スキップ
        if let last = lastGeneratedSince, last == since, !result.isEmpty {
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let r = try await service.generate(since: since, in: modelContext)
            result = r
            lastGeneratedSince = since
        } catch {
            // silent fail (calm UX)
            result = .empty
        }
    }
}
