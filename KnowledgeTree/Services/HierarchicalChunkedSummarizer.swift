//
//  HierarchicalChunkedSummarizer.swift
//  KnowledgeTree
//
//  spec 010 — chunks > 10 のときの階層化処理 (lvl2 中間 meta + lvl3 最終 meta) を担う
//  純粋関数群。Foundation Models 呼び出し自体は KnowledgeExtractor.extractMetaSummary
//  に委譲する。
//

import Foundation

/// lvl2 中間 meta-summary の 1 グループ分の結果
struct IntermediateMetaResult: Sendable {
    let groupIndex: Int
    let chunkIndices: ClosedRange<Int>
    let output: ExtractedKnowledgeOutput?
    let error: Error?
}

enum HierarchicalChunkedSummarizer {
    /// items を groupSize ごとに分割。
    /// makeGroups([0..<18], 10) → [[0..<10], [10..<18]]
    static func makeGroups<T>(_ items: [T], groupSize: Int = 10) -> [[T]] {
        precondition(groupSize >= 1)
        guard !items.isEmpty else { return [] }
        var result: [[T]] = []
        var index = 0
        while index < items.count {
            let end = Swift.min(index + groupSize, items.count)
            result.append(Array(items[index..<end]))
            index = end
        }
        return result
    }

    /// 各 lvl2 グループに対して中間 meta-summary を逐次生成。
    /// グループ内の chunks の essence を入力に extractor.extractMetaSummary を呼ぶ。
    /// progressCallback は 1 グループ完了ごとに (1, 2, ...) として呼ばれる。
    @MainActor
    static func runIntermediateMetaSummaries(
        groups: [[ChunkResult]],
        extractor: KnowledgeExtractor,
        guidance: String? = nil,
        progressCallback: ((Int) async -> Void)? = nil
    ) async -> [IntermediateMetaResult] {
        var results: [IntermediateMetaResult] = []
        for (i, group) in groups.enumerated() {
            if Task.isCancelled { break }
            guard !group.isEmpty else { continue }
            let firstIndex = group.first?.chunkIndex ?? 0
            let lastIndex = group.last?.chunkIndex ?? firstIndex
            let essences = group.compactMap { $0.output?.essence }.filter { !$0.isEmpty }
            let output = await extractor.extractMetaSummary(chunkEssences: essences, guidance: guidance)
            results.append(IntermediateMetaResult(
                groupIndex: i,
                chunkIndices: firstIndex...lastIndex,
                output: output,
                error: output == nil ? IntermediateError.failed : nil
            ))
            await progressCallback?(i + 1)
        }
        return results
    }

    /// lvl2 中間 meta の essence を入力に lvl3 最終 meta-summary を生成。
    /// 入力空 / 全失敗時は nil を返す。
    @MainActor
    static func runFinalMetaSummary(
        intermediateResults: [IntermediateMetaResult],
        extractor: KnowledgeExtractor,
        guidance: String? = nil
    ) async -> ExtractedKnowledgeOutput? {
        let essences = intermediateResults.compactMap { $0.output?.essence }.filter { !$0.isEmpty }
        guard !essences.isEmpty else { return nil }
        return await extractor.extractMetaSummary(chunkEssences: essences, guidance: guidance)
    }

    private enum IntermediateError: Error {
        case failed
    }
}
