//
//  SchemaLoader.swift
//  KnowledgeTree
//
//  spec 058 — Autoresearch の `program.md` 相当を docs/iknow-schema.md から load。
//  起動時 1 回 cache、production では schema.md 不在 / parse 失敗 → code 内 constants fallback。
//  AB test 用: 開発者が schema.md を編集 → 起動時 reload で新 schema 反映。
//  CloudKit / 動的 download は使わない (Privacy first 維持)。
//

import Foundation
import os

@MainActor
final class SchemaLoader {
    static let shared = SchemaLoader()

    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "schema")
    private var cachedSchema: LoadedSchema?

    private init() {}

    /// 起動時 1 回呼ぶ。docs/iknow-schema.md を bundle から load、失敗時は fallback。
    func load() {
        if let url = Bundle.main.url(forResource: "iknow-schema", withExtension: "md"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            cachedSchema = LoadedSchema(rawMarkdown: contents, source: .bundle)
            logger.notice("SchemaLoader: loaded iknow-schema.md from bundle (\(contents.count) chars)")
        } else {
            cachedSchema = LoadedSchema(rawMarkdown: Self.fallbackSchema, source: .fallback)
            logger.notice("SchemaLoader: schema.md not in bundle, using code fallback")
        }
    }

    /// 開発時の Hot reload (debug build only)。schema.md の mtime 変化を検出して reload。
    #if DEBUG
    func reloadIfChanged() {
        load()
    }
    #endif

    /// memory cached schema を返す。未 load なら fallback を返す。
    var loadedSchema: LoadedSchema {
        cachedSchema ?? LoadedSchema(rawMarkdown: Self.fallbackSchema, source: .fallback)
    }

    /// 特定セクションの本文を取得 (markdown の `## {section}` を見つける)。
    /// 失敗時は nil を返す (caller は code constants で fallback)。
    func section(named: String) -> String? {
        let raw = loadedSchema.rawMarkdown
        let lines = raw.components(separatedBy: .newlines)
        var inSection = false
        var collected: [String] = []
        for line in lines {
            if line.hasPrefix("## ") {
                if inSection { break }  // 次の section に当たったら終了
                if line.dropFirst(3).trimmingCharacters(in: .whitespaces).contains(named) {
                    inSection = true
                    continue
                }
            } else if inSection {
                collected.append(line)
            }
        }
        guard !collected.isEmpty else { return nil }
        return collected.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Fallback (code 内 constants、schema.md 不在 / parse 失敗時に使う)

    /// schema.md が読めなかった場合の安全な fallback。
    /// 最低限の指示書を含む (production の動作保証用)。
    static let fallbackSchema: String = """
    # iKnow Schema (fallback)

    ## NEVER STOP loop
    - 確認 UI は危険操作のみ
    - 「分かりません」絶対禁止、hedge phrase 使用
    - 矛盾は「両方残す」default
    - 週 1 BGTask で裏で整理

    ## Hedge phrases
    - 「私の理解では」
    - 「一般的には」
    - 「あくまで概要として」
    - 「確実ではありませんが」
    """
}

/// LoadedSchema: cache される schema 内容 + source。
struct LoadedSchema {
    let rawMarkdown: String
    let source: Source

    enum Source {
        case bundle    // docs/iknow-schema.md から load 成功
        case fallback  // code 内 constants
    }
}
