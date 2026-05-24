//
//  GraphNodeStore.swift
//  KnowledgeTree
//
//  spec 041 (Phase B) — GraphNode の rename / merge / delete を担う。
//  TagStore (spec 024) と同パターン。RefreshTrigger.bump で UI 更新を伝播。
//
//  - rename: name のみ書き換え、同 (name, categoryRaw) の既存 node があれば自動 merge
//  - merge: source の articles / mentionCount を target に合算、edge は target 経路に付け替え、
//           同 (source, target, label) 重複 edge は weight += 1 で 1 本に統合、source 削除
//  - delete: source の edges を cascade 削除、source 削除
//
//  edges の付け替えは「source.outgoingEdges → target.outgoingEdges」「source.incomingEdges
//  → target.incomingEdges」両方向で行い、self-loop (source→source merge 後の target→target)
//  は破棄する。
//

import Foundation
import SwiftData

@MainActor
final class GraphNodeStore {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) {
        self.context = context
        self.refreshTrigger = refreshTrigger
    }

    // MARK: - rename

    /// GraphNode.name を書き換える。
    /// 同 (name, categoryRaw) の既存 node があれば自動 merge して target を返す。
    /// 空白のみ / 30 文字超過は throws。
    @discardableResult
    func rename(_ node: GraphNode, to newRawName: String) throws -> GraphNode {
        let trimmed = newRawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 30 else {
            throw GraphNodeStoreError.invalidName
        }

        if trimmed == node.name {
            return node
        }

        // 同 (name, categoryRaw) の既存 node を探す
        let categoryRaw = node.categoryRaw
        let nodeID = node.id
        var descriptor = FetchDescriptor<GraphNode>(
            predicate: #Predicate<GraphNode> { other in
                other.name == trimmed && other.categoryRaw == categoryRaw && other.id != nodeID
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            try merge(source: node, into: existing)
            return existing
        }

        node.name = trimmed
        node.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
        return node
    }

    // MARK: - merge

    /// source GraphNode を target に統合する。
    /// articles / mentionCount / salience (max) / edges を target に集約、source 削除。
    /// 同 (target, otherEnd, label) の重複 edge は weight += 1 で 1 本に統合。
    /// self-loop (target → target) は破棄。Category が異なれば throws。
    func merge(source: GraphNode, into target: GraphNode) throws {
        guard source.id != target.id else { return }
        guard source.categoryRaw == target.categoryRaw else {
            throw GraphNodeStoreError.differentCategory
        }

        // articles を target に集約 (重複 skip)
        // spec 051 Phase A: articles を Optional 化、`?? []` で safe unwrap。
        let sourceArticles = source.articles ?? []
        for article in sourceArticles where !(target.articles?.contains(where: { $0.id == article.id }) ?? false) {
            if target.articles == nil { target.articles = [] }
            target.articles?.append(article)
        }
        target.mentionCount = max(target.mentionCount, source.mentionCount) +
            min(target.mentionCount, source.mentionCount) / 2  // 部分加算で sum 爆発を抑える
        target.salience = max(target.salience, source.salience)

        // outgoing edges を target に付け替え
        let outgoing = source.outgoingEdges ?? []
        for edge in outgoing {
            guard let other = edge.target else {
                context.delete(edge)
                continue
            }
            // self-loop は破棄
            if other.id == target.id {
                context.delete(edge)
                continue
            }
            try upsertOrReassignEdge(edge: edge, newSource: target, otherEnd: other, isOutgoing: true)
        }

        // incoming edges を target に付け替え
        let incoming = source.incomingEdges ?? []
        for edge in incoming {
            guard let other = edge.source else {
                context.delete(edge)
                continue
            }
            if other.id == target.id {
                context.delete(edge)
                continue
            }
            try upsertOrReassignEdge(edge: edge, newSource: other, otherEnd: target, isOutgoing: false)
        }

        target.updatedAt = .now
        context.delete(source)
        try context.save()
        refreshTrigger?.bump()
    }

    /// 既存の同方向 + 同 label edge があれば weight 加算 + edge 削除、無ければ source/target を付け替えるだけ。
    /// isOutgoing == true: newSource → otherEnd の edge を探す
    /// isOutgoing == false: otherEnd → newSource は incoming 経路、edge の target を newSource にする
    private func upsertOrReassignEdge(
        edge: GraphEdge,
        newSource: GraphNode,
        otherEnd: GraphNode,
        isOutgoing: Bool
    ) throws {
        let label = edge.label
        // 既存重複 edge を探す
        let duplicate: GraphEdge? = isOutgoing
            ? (newSource.outgoingEdges ?? []).first { e in
                e.id != edge.id && e.target?.id == otherEnd.id && e.label == label
            }
            : (newSource.incomingEdges ?? []).first { e in
                e.id != edge.id && e.source?.id == otherEnd.id && e.label == label
            }

        if let duplicate {
            // weight 加算 + confidence は max
            duplicate.weight += max(1, edge.weight)
            duplicate.confidence = max(duplicate.confidence, edge.confidence)
            duplicate.isUncertain = duplicate.isUncertain && edge.isUncertain
            duplicate.updatedAt = .now
            context.delete(edge)
        } else {
            // 付け替え
            if isOutgoing {
                edge.source = newSource
                edge.target = otherEnd
            } else {
                edge.source = otherEnd
                edge.target = newSource
            }
            edge.updatedAt = .now
        }
    }

    // MARK: - delete

    /// GraphNode を削除。cascade で outgoing/incoming edges も削除される (@Relationship deleteRule: .cascade)。
    /// articles との relationship は nullify。
    func delete(_ node: GraphNode) throws {
        context.delete(node)
        try context.save()
        refreshTrigger?.bump()
    }

    // MARK: - edge label rename / delete (GraphEdgeEditSheet 用)

    @discardableResult
    func renameEdgeLabel(_ edge: GraphEdge, to newLabel: String?) throws -> GraphEdge {
        let trimmed = newLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        edge.label = (trimmed?.isEmpty == true) ? nil : trimmed
        edge.updatedAt = .now
        try context.save()
        refreshTrigger?.bump()
        return edge
    }

    func deleteEdge(_ edge: GraphEdge) throws {
        context.delete(edge)
        try context.save()
        refreshTrigger?.bump()
    }
}

enum GraphNodeStoreError: Error {
    case invalidName
    case differentCategory
}
