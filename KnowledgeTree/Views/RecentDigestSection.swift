//
//  RecentDigestSection.swift
//  KnowledgeTree
//
//  spec 035 — 知識 Clip タブ最上部の「最近のあなた」セクション。
//  RecentDigestService が生成した 3 段落を card 形式で表示。
//
//  spec 035 fix (2026-05-09): body を常に Group container で返し、
//  .task が呼ばれない問題を解消。差分 0 件は読み込み後に判定して非表示にする。
//

import SwiftUI
import SwiftData

struct RecentDigestSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var serviceContainer

    @State private var result: RecentDigestResult = .empty
    @State private var isLoading: Bool = false
    @State private var hasGenerated: Bool = false
    @State private var lastGeneratedSince: Date?

    /// 親 view (KnowledgeClipView) から渡される since 値。
    let since: Date

    var body: some View {
        // Group で常に view tree に存在させて、.task が呼ばれるようにする
        Group {
            if isLoading {
                loadingCard
            } else if !result.isEmpty {
                contentCard
            } else if hasGenerated {
                // 生成完了 + 結果空 → 完全非表示 (calm UX)
                EmptyView()
            } else {
                // 生成前: 1px の placeholder で .task を発動
                Color.clear.frame(height: 1)
            }
        }
        .task(id: since) {
            await regenerateIfNeeded()
        }
        .accessibilityIdentifier("clip.recent.section")
    }

    // MARK: - Subviews

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header
            HStack(spacing: DS.Spacing.sm) {
                ProgressView()
                Text("clip.message.assistant.thinking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, DS.Spacing.md)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header
            paragraphsView
            metaCaption
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(DS.Color.actionBlue)
            Text("clip.recent.title")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(.primary)
        }
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
        guard let service = serviceContainer.recentDigestService else {
            hasGenerated = true
            return
        }
        // 同 since 値で 2 度目以降は再生成スキップ
        if let last = lastGeneratedSince, last == since, !result.isEmpty {
            return
        }
        isLoading = true
        defer {
            isLoading = false
            hasGenerated = true
        }

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
