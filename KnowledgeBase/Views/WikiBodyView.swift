//
//  WikiBodyView.swift
//  KnowledgeTree
//
//  spec 079 — Wiki 本文 (bodyMarkdown) の行ベース Markdown レンダラ。
//
//  従来は `AttributedString(markdown:, .inlineOnlyPreservingWhitespace)` 一発描画で、
//  `## 見出し` や `- 箇条書き` がブロック整形されず literal 表示されていた。
//  本 view は行ごとに見出し / 箇条書き / 段落を判定して整形しつつ、各行はインライン Markdown
//  (太字 + `[名前](concept-id://UUID)` リンク) を解釈する。表示前に WikiBodySanitizer で
//  漏れた候補スキャフォールド (生 concept-id 等) を除去。
//

import SwiftUI

struct WikiBodyView: View {
    let markdown: String

    private var lines: [String] {
        WikiBodySanitizer.sanitize(markdown).components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, raw in
                row(for: raw.trimmingCharacters(in: .whitespaces))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func row(for line: String) -> some View {
        if line.isEmpty {
            EmptyView()
        } else if line.hasPrefix("### ") {
            Text(inline(String(line.dropFirst(4))))
                .font(.subheadline.bold())
                .padding(.top, DS.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if line.hasPrefix("## ") {
            Text(inline(String(line.dropFirst(3))))
                .font(.headline)
                .padding(.top, DS.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if line.hasPrefix("# ") {
            Text(inline(String(line.dropFirst(2))))
                .font(.title3.bold())
                .padding(.top, DS.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Text("•").foregroundStyle(DS.Color.sumiInk)
                Text(inline(String(line.dropFirst(2))))
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(inline(line))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 1 行をインライン Markdown (太字 / `[名前](concept-id://UUID)` リンク) として解釈。
    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(s)
    }
}
