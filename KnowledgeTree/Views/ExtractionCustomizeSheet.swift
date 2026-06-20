//
//  ExtractionCustomizeSheet.swift
//  KnowledgeTree
//
//  spec 096 — カスタマイズ抽出。本文は同じまま、AI 抽出の「方向性」を指定して
//  要約・重要な事実の選び方を寄せる (例:「技術的な詳細を重視」「登場人物の関係を中心に」)。
//  「この方向で抽出し直す」で知識 (概念・タグ・要点) を 1 回作り直す。
//  開いた瞬間に走行中の抽出を停止し、参考表示も安定スナップショットを使う (入力が消えない)。
//

import SwiftUI
import SwiftData

struct ExtractionCustomizeSheet: View {
    let article: Article

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refresh

    @State private var guidance: String = ""
    @State private var summary: String = ""
    @State private var facts: [String] = []
    @State private var loaded: Bool = false

    /// よく使う生成の方向性 (タップで guidance に入力)。
    private struct Preset { let title: LocalizedStringKey; let text: String }
    private static let presets: [Preset] = [
        Preset(title: "detail.customize.preset.brief", text: "結論と要点だけを短くまとめる"),
        Preset(title: "detail.customize.preset.technical", text: "技術的な仕組み・実装の詳細を重視する"),
        Preset(title: "detail.customize.preset.people", text: "登場する人物・組織とその関係を中心にする"),
        Preset(title: "detail.customize.preset.beginner", text: "専門用語をかみ砕き、初心者にも分かるようにやさしく"),
        Preset(title: "detail.customize.preset.data", text: "数値・日付・統計などの具体的なデータを重視する")
    ]

    private var hasCurrent: Bool { !summary.isEmpty || !facts.isEmpty }

    /// 実行できる条件: 新しい方向を入れた or 既存の方向を消して既定に戻す。両方空なら無意味。
    private var canRun: Bool {
        let g = guidance.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = (article.extractionGuidance ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !g.isEmpty || !current.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // プリセット (タップで方向性を入力)。
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.presets, id: \.text) { preset in
                                Button {
                                    guidance = preset.text
                                } label: {
                                    Text(preset.title)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule().fill(DS.Color.surfaceSecondary)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 0))
                } header: {
                    Text("detail.customize.presets")
                }

                Section {
                    TextField("detail.customize.placeholder", text: $guidance, axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityIdentifier("customize.guidanceField")
                } header: {
                    Text("detail.customize.header")
                } footer: {
                    Text("detail.customize.footer")
                }

                // 参考: 今の抽出結果 (どの方向に寄せるか決める手がかり)。
                if hasCurrent {
                    Section {
                        if !summary.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("detail.review.ref.summary")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(summary).font(.callout)
                            }
                        }
                        if !facts.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("detail.review.ref.facts")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                                    Text("・\(fact)").font(.callout)
                                }
                            }
                        }
                    } header: {
                        Text("detail.customize.currentHeader")
                    }
                }
            }
            .navigationTitle("detail.customize.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("detail.customize.run") { run() }
                        .disabled(!canRun)
                }
            }
            .task {
                guard !loaded else { return }
                await services.knowledgeService?.cancelInFlight(article: article)
                guidance = article.extractionGuidance ?? ""
                let k = article.extractedKnowledge
                summary = (k?.summary ?? k?.essence ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                facts = (k?.keyFacts ?? [])
                    .sorted { $0.order < $1.order }
                    .map(\.statement)
                    .filter { !$0.isEmpty }
                loaded = true
            }
        }
    }

    private func run() {
        services.correctionCoordinator?.customizeExtraction(
            article: article,
            guidance: guidance,
            knowledgeService: services.knowledgeService,
            modelContext: modelContext,
            refresh: refresh
        )
        dismiss()
    }
}
