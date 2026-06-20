//
//  ArticleCorrectionCoordinator.swift
//  KnowledgeTree
//
//  spec 095 — ユーザー訂正をシートから切り離してバックグラウンド継続実行する。
//  訂正シートを閉じても処理は続き、進捗 (inProgress) を ArticleDetailView が監視して表示する。
//  訂正前の知識 (ExtractedKnowledge + この記事だけが作った概念ページ) を一度 clear してから再生成。
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class ArticleCorrectionCoordinator {
    /// 訂正処理中の記事 ID。画面はこれを見て「反映中…」を表示する。
    private(set) var inProgress: Set<UUID> = []

    func isCorrecting(_ article: Article) -> Bool {
        inProgress.contains(article.id)
    }

    /// 訂正を開始。すぐ return し、実処理は detached な Task で続行 (シートを閉じても継続)。
    func start(
        article: Article,
        instruction: String,
        corrector: TranscriptCorrecting,
        knowledgeService: KnowledgeExtractionServiceProtocol?,
        modelContext: ModelContext,
        refresh: RefreshTrigger
    ) {
        let id = article.id
        let trimmedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !inProgress.contains(id),
              let body = article.body,
              let text = body.extractedText,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !trimmedInstruction.isEmpty else { return }

        inProgress.insert(id)
        // 親 View (シート) の lifecycle に縛られない unstructured Task。
        Task { @MainActor in
            defer {
                inProgress.remove(id)
                refresh.bump()
            }

            let corrected = await corrector.applyInstruction(text, instruction: trimmedInstruction)
            guard corrected != text else { return }  // 変化なし

            body.extractedText = corrected

            // 訂正前の知識を clear (誤認識由来の概念・タグを残さない)。
            if let ek = article.extractedKnowledge {
                article.extractedKnowledge = nil
                modelContext.delete(ek)
            }
            deleteSoleSourceConcepts(of: article, in: modelContext)
            try? modelContext.save()

            // 訂正後の本文で知識 (概念・タグ・要点) を再生成。
            await knowledgeService?.extract(article: article)
        }
    }

    /// この記事だけが source の概念ページを削除 (複数記事が紐づくものは残す)。
    private func deleteSoleSourceConcepts(of article: Article, in context: ModelContext) {
        let aid = article.id
        guard let pages = try? context.fetch(FetchDescriptor<ConceptPage>()) else { return }
        for page in pages {
            let related = page.relatedArticles ?? []
            if related.count == 1, related.first?.id == aid {
                context.delete(page)
            }
        }
    }
}
