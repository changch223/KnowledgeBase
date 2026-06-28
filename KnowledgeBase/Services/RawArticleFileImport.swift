//
//  RawArticleFileImport.swift
//  KnowledgeTree
//
//  spec 091 ③ — fileImporter / 共有ファイルからの取り込み。
//  PDFFetcher (PDFKit 依存) を使うためアプリ target 専用に分離する
//  (RawArticleIntake.swift は Share Extension にも入るので PDFFetcher を参照できない)。
//

import Foundation

extension RawArticleIntake {
    /// ファイル URL から (タイトル, 本文) を抽出 (PDF / プレーンテキスト)。
    /// セキュリティスコープを取得して読み込む。抽出不可は nil。
    static func extractFile(at url: URL) -> (title: String, body: String)? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return nil }

        if url.pathExtension.lowercased() == "pdf" {
            guard let parsed = PDFFetcher.parse(data: data, sourceURL: url) else { return nil }
            let body = parsed.fullText.isEmpty ? (parsed.summary ?? "") : parsed.fullText
            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return (parsed.title, body)
        }

        // テキスト系 (txt / md / その他 UTF-8・UTF-16 で読めるもの)
        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (PDFFetcher.titleFromFilename(url: url), text)
        }

        return nil
    }
}
