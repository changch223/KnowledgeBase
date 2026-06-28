//
//  GraphTraversalService.swift
//  KnowledgeTree
//
//  spec 040 (Phase A) — Knowledge Graph の traversal (近傍取得 / 中心度計算)。
//  AI Chat RAG (ChatService) と KnowledgeDigestService の prompt 拡張で使用。
//
//  - resolveNodes(entityNames:in:) — entity 名から GraphNode を解決 (active のみ)
//  - neighbors(of:hop:) — 1-hop 近傍ノード取得 (outgoing + incoming)
//  - topByDegree(category:limit:) — Category 内 degree 上位の主要 entity
//

import Foundation
import SwiftData

@MainActor
protocol GraphTraversalServiceProtocol: AnyObject {
    /// entity 名 (大文字小文字無視) から GraphNode を解決。active のみ返す。
    func resolveNodes(entityNames: [String], categoryRaw: String?, in context: ModelContext) -> [GraphNode]

    /// 1-hop 近傍ノード (outgoing.target + incoming.source) を取得。
    /// 重複除外、isActive == true のみ。
    func neighbors(of node: GraphNode) -> [GraphNode]

    /// Category 内 degree (= outgoing + incoming edge 数) 上位の主要 entity を返す。
    /// importanceScore (salience × mentionCount) で並び替えのオプションも。
    func topByDegree(categoryRaw: String, limit: Int, in context: ModelContext) -> [GraphNode]
}

@MainActor
final class GraphTraversalService: GraphTraversalServiceProtocol {

    init() {}

    func resolveNodes(entityNames: [String], categoryRaw: String?, in context: ModelContext) -> [GraphNode] {
        let normalized = Set(entityNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty })
        guard !normalized.isEmpty else { return [] }

        let descriptor: FetchDescriptor<GraphNode>
        if let categoryRaw {
            descriptor = FetchDescriptor<GraphNode>(
                predicate: #Predicate<GraphNode> { node in
                    node.isActive == true && node.categoryRaw == categoryRaw
                }
            )
        } else {
            descriptor = FetchDescriptor<GraphNode>(
                predicate: #Predicate<GraphNode> { node in
                    node.isActive == true
                }
            )
        }
        let candidates = (try? context.fetch(descriptor)) ?? []
        return candidates.filter { normalized.contains($0.name.lowercased()) }
    }

    func neighbors(of node: GraphNode) -> [GraphNode] {
        var seen: Set<UUID> = [node.id]
        var result: [GraphNode] = []
        for edge in (node.outgoingEdges ?? []) {
            guard let target = edge.target, target.isActive, !seen.contains(target.id) else { continue }
            seen.insert(target.id)
            result.append(target)
        }
        for edge in (node.incomingEdges ?? []) {
            guard let source = edge.source, source.isActive, !seen.contains(source.id) else { continue }
            seen.insert(source.id)
            result.append(source)
        }
        return result
    }

    func topByDegree(categoryRaw: String, limit: Int, in context: ModelContext) -> [GraphNode] {
        let descriptor = FetchDescriptor<GraphNode>(
            predicate: #Predicate<GraphNode> { node in
                node.isActive == true && node.categoryRaw == categoryRaw
            }
        )
        let nodes = (try? context.fetch(descriptor)) ?? []
        // degree desc → importanceScore desc tiebreak
        let sorted = nodes.sorted { lhs, rhs in
            if lhs.degree != rhs.degree {
                return lhs.degree > rhs.degree
            }
            return lhs.importanceScore > rhs.importanceScore
        }
        return Array(sorted.prefix(max(0, limit)))
    }
}
