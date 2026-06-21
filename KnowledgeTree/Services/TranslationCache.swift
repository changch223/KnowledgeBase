//
//  TranslationCache.swift
//  KnowledgeTree
//
//  spec 096 (perf) — 翻訳結果のセッションキャッシュ。
//  中国語/英語記事の知識抽出は本文を日本語へ翻訳するが、訂正後の再抽出・生成カスタマイズ・
//  起動時 backfill で同じチャンク本文が何度も翻訳され、1 回 20〜45 秒 + translationd クラッシュの
//  原因になっていた。source+本文 をキーに成功した翻訳を保持し、再翻訳を回避する。
//  - 失敗 (空/極端に短い/例外) はキャッシュしない → 次回再試行できる
//  - アプリ起動中のみ有効 (永続化はしない)。FIFO 上限で頭打ち。
//

import Foundation

@MainActor
final class TranslationCache {
    private var entries: [String: String] = [:]
    private var order: [String] = []
    private let capacity: Int

    /// spec 101: 翻訳モデル未インストール (notInstalled) で失敗した言語。以後この言語はスキップ。
    private var unavailableLanguages: Set<String> = []

    init(capacity: Int = 256) {
        self.capacity = capacity
    }

    /// この言語は翻訳できない (notInstalled) と記録。
    func markUnavailable(source: String) { unavailableLanguages.insert(source) }
    /// この言語は翻訳できない (記録済み) か。
    func isUnavailable(source: String) -> Bool { unavailableLanguages.contains(source) }

    private func key(source: String, text: String) -> String {
        source + "\u{0}" + text
    }

    /// 翻訳済みなら返す (なければ nil)。
    func cached(source: String, text: String) -> String? {
        entries[key(source: source, text: text)]
    }

    /// 成功した翻訳を保持する (FIFO 上限超過で最古を破棄)。
    func put(source: String, text: String, translated: String) {
        let k = key(source: source, text: text)
        if entries[k] == nil { order.append(k) }
        entries[k] = translated
        while order.count > capacity {
            let evict = order.removeFirst()
            entries[evict] = nil
        }
    }

    var count: Int { entries.count }
}
