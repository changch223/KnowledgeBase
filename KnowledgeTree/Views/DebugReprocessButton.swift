//
//  DebugReprocessButton.swift
//  KnowledgeTree
//
//  テスト専用 (#if DEBUG): 既存の全記事を 0 から AI 再処理する。
//  本文 (ArticleBody) は再取得せず、知識抽出以降を全部やり直す:
//   1. ConceptPage 全削除 (階層を再生成)
//   2. ExtractedKnowledge 全削除 (cascade で keyFacts/entities/chunkProgress も消える)
//   3. Tag.categoryRaw / lastLintedAt リセット (再分類 + lint 周回を 0 から)
//   4. backfill / lint フラグをリセット
//   5. 全記事を knowledgeService.extract で再抽出 (記事レベルゲートで 1 本ずつ直列、各 hook が走る)
//
//  破壊的 + 重い (記事数 × chunked 抽出) ので confirmation 必須。リリースには含めない。
//

#if DEBUG
import SwiftUI
import SwiftData

struct DebugReprocessButton: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refreshTrigger
    @Environment(\.modelContext) private var modelContext

    @State private var isRunning = false
    @State private var progress = ""
    @State private var showConfirm = false

    var body: some View {
        Button(role: .destructive) {
            showConfirm = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if isRunning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(isRunning ? "再処理中… \(progress)" : "🧪 全 AI 再処理 (テスト用)")
                    .font(.body)
            }
        }
        .disabled(isRunning)
        .confirmationDialog(
            "既存の全記事を 0 から AI 再処理します。概念ページ・知識抽出を全削除して作り直すため重く、CloudKit にも反映されます。よろしいですか?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("再処理する", role: .destructive) { Task { await reprocessAll() } }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func reprocessAll() async {
        guard let knowledge = services.knowledgeService else { return }
        isRunning = true
        defer { isRunning = false; progress = "" }

        // 1. ConceptPage 全削除 (階層を新パイプラインで再生成)
        let pages = (try? modelContext.fetch(FetchDescriptor<ConceptPage>())) ?? []
        for page in pages { modelContext.delete(page) }

        // 2. ExtractedKnowledge 全削除 (cascade: keyFacts/entities/chunkProgress も消える)。
        //    Article.extractedKnowledge を nil にして再抽出の冪等 skip を回避。
        let articles = (try? modelContext.fetch(FetchDescriptor<Article>())) ?? []
        for article in articles {
            if let ek = article.extractedKnowledge {
                article.extractedKnowledge = nil
                modelContext.delete(ek)
            }
        }

        // 3. Tag.categoryRaw / lastLintedAt をリセット (再分類 + lint 周回 from 0)
        let tags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
        for tag in tags {
            tag.categoryRaw = nil
            tag.lastLintedAt = nil
        }

        try? modelContext.save()

        // 4. backfill / lint フラグをリセット (起動時 backfill も再実行されるように)
        let defaults = UserDefaults.standard
        for key in [
            "auto_tag_backfill_v1_done",
            "auto_category_backfill_v1_done",
            "ConceptPage.backfillCompleted",
            "ConceptPage.categoryBackfillCompleted.v1",
            "lint.loopStartedAt.v1",
        ] {
            defaults.removeObject(forKey: key)
        }

        // 5. 全記事を再抽出 (記事レベルゲートで 1 本ずつ直列、各 hook = auto-tag / 概念階層 等が走る)
        let total = articles.count
        for (index, article) in articles.enumerated() {
            if Task.isCancelled { break }
            progress = "\(index + 1)/\(total)"
            await knowledge.extract(article: article)
        }
        refreshTrigger.bump()
    }
}
#endif
