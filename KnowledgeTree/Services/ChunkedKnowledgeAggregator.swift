//
//  ChunkedKnowledgeAggregator.swift
//  KnowledgeTree
//
//  spec 006 — 各 chunk の生成結果と meta-summary を統合する純粋関数。
//  重複排除 (keyFacts: trim 完全一致 / entities: case-insensitive trim 一致) と
//  partial success 判定 (.failed / .partiallySucceeded / .succeeded) を担う。
//

import Foundation

struct ChunkResult: Sendable {
    let chunkIndex: Int
    let output: ExtractedKnowledgeOutput?
    let error: Error?
}

struct AggregatedKnowledge: Sendable {
    let essence: String
    let summary: String
    let keyFacts: [KeyFactOutput]
    let entities: [KnowledgeEntityOutput]
    let successfulChunkCount: Int
    let totalChunkCount: Int
    let metaSummarySucceeded: Bool

    /// status 判定 (research.md R7 ルール)
    func determineStatus() -> ExtractionStatus {
        if successfulChunkCount == 0 { return .failed }
        if metaSummarySucceeded { return .succeeded }
        return .partiallySucceeded
    }

    /// SwiftData 永続化用の ExtractedKnowledgeOutput を生成
    func toOutput() -> ExtractedKnowledgeOutput {
        ExtractedKnowledgeOutput(
            essence: essence,
            summary: summary,
            keyFacts: keyFacts,
            entities: entities
        )
    }
}

enum ChunkedKnowledgeAggregator {
    /// 全 chunk の結果 + meta-summary 結果を統合する。
    static func merge(
        results: [ChunkResult],
        metaSummary: ExtractedKnowledgeOutput?
    ) -> AggregatedKnowledge {
        let totalCount = results.count
        let successful = results.compactMap { $0.output }
        let successfulCount = successful.count
        let metaOK = metaSummary != nil

        let mergedKeyFacts = mergeKeyFacts(from: successful)
        let mergedEntities = mergeEntities(from: successful)

        // essence / summary の決定
        let essence: String
        let summary: String
        if let meta = metaSummary {
            essence = meta.essence
            summary = meta.summary
        } else if let firstSuccess = successful.first {
            essence = firstSuccess.essence
            // 全 chunk の essence を改行連結 → 300 文字 truncate
            let joined = successful.map(\.essence).filter { !$0.isEmpty }.joined(separator: "\n")
            summary = String(joined.prefix(300))
        } else {
            essence = ""
            summary = ""
        }

        return AggregatedKnowledge(
            essence: essence,
            summary: summary,
            keyFacts: mergedKeyFacts,
            entities: mergedEntities,
            successfulChunkCount: successfulCount,
            totalChunkCount: totalCount,
            metaSummarySucceeded: metaOK
        )
    }

    // MARK: - Private helpers

    /// keyFacts: trim 済 statement の完全一致で重複排除。最初に出現した順序を保持。
    private static func mergeKeyFacts(from outputs: [ExtractedKnowledgeOutput]) -> [KeyFactOutput] {
        var seen: Set<String> = []
        var deduped: [KeyFactOutput] = []
        for output in outputs {
            for fact in output.keyFacts {
                let key = fact.statement.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty, !seen.contains(key) else { continue }
                seen.insert(key)
                deduped.append(fact)
            }
        }
        return deduped
    }

    /// entities: lowercase + trim の name で重複判定。salience 最大値、type は多数決。
    private static func mergeEntities(from outputs: [ExtractedKnowledgeOutput]) -> [KnowledgeEntityOutput] {
        var grouped: [String: [KnowledgeEntityOutput]] = [:]
        for output in outputs {
            for entity in output.entities {
                let key = entity.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { continue }
                grouped[key, default: []].append(entity)
            }
        }

        return grouped.values.map { group in
            // salience 最大値
            let maxSalience = group.map(\.salience).max() ?? 1
            // type 多数決 (同票時は salience 最大版の type)
            let typeFrequency = Dictionary(grouping: group, by: \.type)
                .mapValues { entities -> (count: Int, maxSalience: Int) in
                    (entities.count, entities.map(\.salience).max() ?? 0)
                }
            let topType = typeFrequency.max { lhs, rhs in
                if lhs.value.count != rhs.value.count {
                    return lhs.value.count < rhs.value.count
                }
                return lhs.value.maxSalience < rhs.value.maxSalience
            }?.key ?? group[0].type

            // name は salience 最大版の元 name を保持 (case 含む)
            let representative = group.max(by: { $0.salience < $1.salience }) ?? group[0]

            return KnowledgeEntityOutput(
                name: representative.name,
                type: topType,
                salience: maxSalience
            )
        }
    }
}
