//
//  RawArticleIntake.swift
//  KnowledgeTree
//
//  spec 091 — 非 URL コンテンツ (手動メモ / 共有テキスト / ファイル / 画像OCR) を
//  既存の知識抽出パイプラインに乗せる共通の取り込み口。
//
//  合成 URL `knowledgebase://<source>/<本文hash>` で identity を確保し、
//  ArticleBody.extractedText に本文を事前投入 → enrichment(https fetch)/body(HTML抽出) を
//  スキップして KnowledgeExtractionService が本文を直接処理する。
//  重複検知は本文ハッシュ込みの合成 URL で既存の URL ベース判定を再利用 (@Model 変更ゼロ)。
//

import Foundation
import SwiftData

@MainActor
enum RawArticleIntake {
    /// 取り込み元の種別 (合成 URL の名前空間 + 将来の出し分け用)。
    enum Source: String {
        case note        // アプリ内の手動メモ
        case sharedText  // 他アプリからの共有テキスト
        case file        // PDF / テキストファイル
        case image       // 画像 OCR
        case audio       // 音声ファイル文字起こし
    }

    /// 本文テキストから raw article を作成 (重複なら .duplicate)。
    /// 既存 `SaveResult` を再利用 (空本文は .missingURL に相当)。
    @discardableResult
    static func save(
        into context: ModelContext,
        title rawTitle: String?,
        bodyText: String,
        source: Source
    ) -> SaveResult {
        let body = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return .missingURL }

        let syntheticURL = "knowledgebase://\(source.rawValue)/\(stableHash(body))"
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.url == syntheticURL })
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return .duplicate
        }

        let article = Article(url: syntheticURL, title: derivedTitle(rawTitle: rawTitle, body: body))
        context.insert(article)

        // 本文を事前投入 → body 抽出 (HTML fetch) をスキップ、知識抽出が直接拾う。
        let bodyModel = ArticleBody(article: article, status: .succeeded, extractedText: body)
        context.insert(bodyModel)
        article.body = bodyModel

        // 合成 URL は fetch 不可。enrichment を terminal にして backfill が触らないように。
        let enrichment = ArticleEnrichment(article: article, status: .permanentlyFailed)
        context.insert(enrichment)
        article.enrichment = enrichment

        do {
            try context.save()
            return .saved(article)
        } catch {
            return .persistenceFailure(String(describing: error))
        }
    }

    /// spec 092 Part 2: 共有された音声を「文字起こし待ち (pending)」の記事として保存。
    /// 音声バイトは App Group に書き、ArticleBody は .pending (本文なし) にする。
    /// アプリ起動時の `AudioTranscriptionBackfillRunner` が文字起こしして .succeeded に遷移させる。
    @discardableResult
    static func savePendingAudio(
        into context: ModelContext,
        audioData: Data,
        fileExtension: String,
        title rawTitle: String?
    ) -> SaveResult {
        guard !audioData.isEmpty else { return .missingURL }

        let hash = stableHash(audioData)
        let syntheticURL = "knowledgebase://\(Source.audio.rawValue)/\(hash)"
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.url == syntheticURL })
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return .duplicate
        }

        // 音声バイトを App Group に保存 (起動時 runner が読み出す)。
        guard let dir = AppGroup.pendingAudioDirectory() else {
            return .persistenceFailure("app group unavailable")
        }
        let ext = fileExtension.isEmpty ? "m4a" : fileExtension
        let fileURL = dir.appendingPathComponent("\(hash).\(ext)")
        do {
            try audioData.write(to: fileURL, options: .atomic)
        } catch {
            return .persistenceFailure("audio write failed: \(error)")
        }

        let title = derivedTitle(rawTitle: rawTitle, body: rawTitle ?? "")
        let article = Article(url: syntheticURL, title: title)
        context.insert(article)

        // 本文は未確定 (.pending)。enrichment は terminal で fetch を抑止。
        let bodyModel = ArticleBody(article: article, status: .pending, extractedText: nil)
        context.insert(bodyModel)
        article.body = bodyModel

        let enrichment = ArticleEnrichment(article: article, status: .permanentlyFailed)
        context.insert(enrichment)
        article.enrichment = enrichment

        do {
            try context.save()
            return .saved(article)
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            return .persistenceFailure(String(describing: error))
        }
    }

    /// タイトル: 明示 > 本文先頭行 (40 字) > 既定。
    static func derivedTitle(rawTitle: String?, body: String) -> String {
        if let t = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return String(t.prefix(80))
        }
        let firstLine = body
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first.map(String.init) ?? body
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? String(localized: "rawIntake.untitled") : String(trimmed.prefix(40))
    }

    /// 本文の決定的ハッシュ (FNV-1a 64bit)。launch 間で安定 → 重複検知に使える。
    static func stableHash(_ s: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return String(hash, radix: 16)
    }

    /// バイト列の決定的ハッシュ (FNV-1a 64bit)。音声ファイル等の重複検知に使う。
    static func stableHash(_ data: Data) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return String(hash, radix: 16)
    }
}
