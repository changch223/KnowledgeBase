//
//  TranscriptReviewComposeSheet.swift
//  KnowledgeTree
//
//  spec 096 — 見直しフローの入口。
//  上から ① 修正の指示(任意) ② 参考: AI が抽出した内容 ③ 本文 を並べ、
//  「何を直せばよいか」を見ながら指示を書ける。「AI で見直す」で背景レビュー開始。
//
//  bug 修正: 画面を開いた瞬間に走行中の抽出を停止する。これにより裏の didSave / 翻訳の
//  連発が止まり、入力中に IME の変換途中テキストが消える問題を防ぐ。参考表示も停止後の
//  安定スナップショットを使う (再描画しない)。
//

import SwiftUI
import SwiftData

struct TranscriptReviewComposeSheet: View {
    let article: Article

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var services

    @State private var instruction: String = ""
    @State private var bodyText: String = ""
    @State private var summary: String = ""
    @State private var tags: [String] = []
    @State private var entities: [String] = []
    @State private var facts: [String] = []
    @State private var loaded: Bool = false

    private let corrector: TranscriptCorrecting =
        LLMTranscriptCorrectionService(session: FoundationModelLanguageModelSession())

    private var hasKnowledge: Bool {
        !summary.isEmpty || !tags.isEmpty || !entities.isEmpty || !facts.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("detail.correct.placeholder", text: $instruction, axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityIdentifier("reviewCompose.instructionField")
                } header: {
                    Text("detail.review.compose.instructionHeader")
                } footer: {
                    Text("detail.review.compose.footer")
                }

                // 参考: AI が抽出した内容 (なければ非表示)。
                if hasKnowledge {
                    Section {
                        if !summary.isEmpty {
                            referenceRow("detail.review.ref.summary", value: summary)
                        }
                        if !tags.isEmpty {
                            referenceRow("detail.review.ref.tags", value: tags.joined(separator: "、"))
                        }
                        if !entities.isEmpty {
                            referenceRow("detail.review.ref.entities", value: entities.joined(separator: "、"))
                        }
                        if !facts.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("detail.review.ref.facts")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                                    Text("・\(fact)")
                                        .font(.callout)
                                }
                            }
                        }
                    } header: {
                        Text("detail.review.ref.header")
                    }
                }

                // 本文 (誤りを見ながら指示を書くため)。
                Section {
                    Text(bodyText)
                        .font(.callout)
                        .textSelection(.enabled)
                } header: {
                    Text("detail.review.ref.body")
                }
            }
            .navigationTitle("detail.review.compose.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("detail.review.compose.start") { start() }
                }
            }
            .task {
                guard !loaded else { return }
                // 画面を開いたら走行中の抽出を停止 (入力中の再描画/churn を止める)。
                await services.knowledgeService?.cancelInFlight(article: article)
                snapshot()
                loaded = true
            }
        }
    }

    @ViewBuilder
    private func referenceRow(_ label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
        }
    }

    /// 停止後の安定状態を読み取って固定 (以後は再描画しない)。
    private func snapshot() {
        bodyText = article.body?.extractedText ?? ""
        let k = article.extractedKnowledge
        summary = (k?.summary ?? k?.essence ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        tags = (article.tags ?? []).map(\.name).filter { !$0.isEmpty }
        entities = (k?.entities ?? [])
            .sorted { $0.order < $1.order }
            .map(\.name)
            .filter { !$0.isEmpty }
        facts = (k?.keyFacts ?? [])
            .sorted { $0.order < $1.order }
            .map(\.statement)
            .filter { !$0.isEmpty }
    }

    private func start() {
        services.correctionCoordinator?.beginReview(
            article: article,
            instruction: instruction,
            corrector: corrector,
            knowledgeService: services.knowledgeService,
            modelContext: modelContext
        )
        dismiss()
    }
}
