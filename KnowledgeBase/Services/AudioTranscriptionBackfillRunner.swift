//
//  AudioTranscriptionBackfillRunner.swift
//  KnowledgeTree
//
//  spec 092 Part 2 — 共有された音声 (pending) をアプリ起動時に文字起こしする。
//  Share 拡張は音声を App Group に保存し ArticleBody を .pending にするだけ。
//  ここで音声を読み出し、AudioTranscriptionService で書き起こし、
//  ArticleBody.extractedText に投入 → .succeeded に遷移させ、知識抽出に乗せる。
//  アプリ target 専用 (AudioTranscriptionService = Speech 依存)。
//

import Foundation
import SwiftData

@MainActor
final class AudioTranscriptionBackfillRunner {
    private let context: ModelContext
    private let transcriber: AudioTranscribing
    private let corrector: TranscriptCorrecting?

    init(context: ModelContext, transcriber: AudioTranscribing, corrector: TranscriptCorrecting? = nil) {
        self.context = context
        self.transcriber = transcriber
        self.corrector = corrector
    }

    /// pending 音声を文字起こし。1 件でも本文を確定したら true (呼び出し側が知識抽出を再走できる)。
    @discardableResult
    func run() async -> Bool {
        let prefix = "knowledgebase://\(RawArticleIntake.Source.audio.rawValue)/"
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.url.starts(with: prefix) }
        )
        guard let candidates = try? context.fetch(descriptor) else { return false }
        let pending = candidates.filter { $0.body?.status != .succeeded }
        guard !pending.isEmpty, let dir = AppGroup.pendingAudioDirectory() else { return false }

        var didTranscribe = false
        for article in pending {
            guard let hash = article.url.split(separator: "/").last.map(String.init),
                  let fileURL = locateAudioFile(hash: hash, in: dir) else { continue }

            do {
                let raw = try await transcriber.transcribe(fileURL: fileURL)
                // spec 094: 既知の用語集で誤認識 (Claude Code → cloadcod 等) を補正。
                let text: String
                if let corrector {
                    let glossary = TranscriptGlossaryBuilder.build(context: context)
                    text = await corrector.correct(raw, glossary: glossary)
                } else {
                    text = raw
                }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }  // 空なら次回再試行

                if let body = article.body {
                    body.extractedText = trimmed
                    body.status = .succeeded
                } else {
                    let body = ArticleBody(article: article, status: .succeeded, extractedText: trimmed)
                    context.insert(body)
                    article.body = body
                }
                try? context.save()
                try? FileManager.default.removeItem(at: fileURL)
                didTranscribe = true
            } catch {
                // 失敗 (未許可 / モデル未DL 等) は pending のまま残し、次回起動で再試行。
            }
        }
        return didTranscribe
    }

    /// `<hash>.<ext>` を探す (拡張子は保存時のものに依存するため hash 前方一致で探索)。
    private func locateAudioFile(hash: String, in dir: URL) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return nil }
        return files.first { $0.lastPathComponent.hasPrefix(hash + ".") }
    }
}
