//
//  GraphExtractionService.swift
//  KnowledgeTree
//
//  spec 040 (Phase A) — 記事保存時に Knowledge Graph を自動抽出。
//  knowledge extraction succeeded 後に fire-and-forget で呼ばれる。
//
//  処理フロー:
//  1. Article の Category を tag.categoryRaw 経由で解決 (CategoryFilter と整合)
//  2. AI で triple (subject, predicate, object, confidence) を抽出
//  3. 各 triple について:
//     - confidence < 0.5 → silent skip
//     - GraphNode (source/target) を Category 内 unique 名で upsert
//     - GraphEdge を (source.id, target.id, label) で upsert (weight += 1)
//  4. Category 内 GraphNode が 30 を超えたら、importanceScore 低を deactivate
//  5. AI 不可端末 → Fallback で entity 共起のみの graph (label なし)
//

import Foundation
import SwiftData
import os

@MainActor
protocol GraphExtractionServiceProtocol: AnyObject {
    /// 記事から graph triple を抽出して GraphNode / GraphEdge を upsert。
    /// fire-and-forget、失敗は silent (本フロー継続を阻害しない)。
    func extract(article: Article) async
}

@MainActor
final class GraphExtractionService: GraphExtractionServiceProtocol {

    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "graph-extract")
    private let context: ModelContext
    private let session: LanguageModelSessionProtocol
    private let availability: AvailabilityChecker

    /// Category 内 active GraphNode 上限
    private let maxActiveNodesPerCategory: Int = 30

    /// AI 確信度しきい値 (これ未満は silent skip)
    private let minConfidence: Double = 0.5

    /// 「中確信」レンジ (isUncertain=true、Phase B で UI 表示)
    private let uncertainConfidence: Double = 0.7

    init(
        context: ModelContext,
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker = SystemLanguageModelAvailabilityChecker()
    ) {
        self.context = context
        self.session = session
        self.availability = availability
    }

    // MARK: - Entry Point

    func extract(article: Article) async {
        // Category を tag.categoryRaw 経由で解決
        guard let categoryRaw = resolveCategory(article: article) else {
            logger.notice("graph extract skipped: no category for \(article.url, privacy: .public)")
            return
        }

        if availability.isAvailable {
            await extractWithAI(article: article, categoryRaw: categoryRaw)
        } else {
            extractFallback(article: article, categoryRaw: categoryRaw)
        }

        // Category 内 上限 enforce
        enforceNodeLimit(categoryRaw: categoryRaw)
    }

    // MARK: - AI 経路

    private func extractWithAI(article: Article, categoryRaw: String) async {
        let prompt = Self.buildPrompt(article: article)
        let output: GraphTripleOutput
        do {
            output = try await session.generateGraphTriples(prompt: prompt)
        } catch {
            logger.error("graph extract AI failed: \(String(describing: error), privacy: .public), falling back")
            extractFallback(article: article, categoryRaw: categoryRaw)
            return
        }

        var insertedAny = false
        for item in output.triples {
            guard item.confidence >= minConfidence else { continue }
            let subjectTrimmed = item.subject.trimmingCharacters(in: .whitespacesAndNewlines)
            let predicateTrimmed = item.predicate.trimmingCharacters(in: .whitespacesAndNewlines)
            let objectTrimmed = item.object.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !subjectTrimmed.isEmpty, !predicateTrimmed.isEmpty, !objectTrimmed.isEmpty else { continue }
            guard subjectTrimmed != objectTrimmed else { continue }  // self-loop は除外

            let source = upsertNode(name: subjectTrimmed, categoryRaw: categoryRaw, article: article)
            let target = upsertNode(name: objectTrimmed, categoryRaw: categoryRaw, article: article)

            let confidence = Float(item.confidence)
            let isUncertain = item.confidence < uncertainConfidence
            upsertEdge(
                source: source,
                target: target,
                label: predicateTrimmed,
                confidence: confidence,
                isUncertain: isUncertain,
                categoryRaw: categoryRaw
            )
            insertedAny = true
        }

        if insertedAny {
            try? context.save()
        }
    }

    // MARK: - Fallback (entity 共起のみ)

    private func extractFallback(article: Article, categoryRaw: String) {
        // ExtractedKnowledge.entities を name でユニーク化、上位 salience 5 件で共起 edge 作成
        guard let entities = article.extractedKnowledge?.entities, entities.count >= 2 else {
            return
        }
        let topEntities = entities
            .sorted { $0.salience > $1.salience }
            .prefix(5)
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 各ペアで共起 edge (label nil、confidence 0)
        let nodes: [GraphNode] = topEntities.map { name in
            upsertNode(name: name, categoryRaw: categoryRaw, article: article)
        }

        for i in 0..<nodes.count {
            for j in (i + 1)..<nodes.count {
                upsertEdge(
                    source: nodes[i],
                    target: nodes[j],
                    label: nil,
                    confidence: 0,
                    isUncertain: false,
                    categoryRaw: categoryRaw
                )
            }
        }
        try? context.save()
    }

    // MARK: - Upsert

    /// Category 内 name で GraphNode upsert。既存なら mentionCount++、salience も合算更新、article relationship 追加。
    private func upsertNode(name: String, categoryRaw: String, article: Article) -> GraphNode {
        let key = name.lowercased()
        let descriptor = FetchDescriptor<GraphNode>(
            predicate: #Predicate<GraphNode> { node in
                node.categoryRaw == categoryRaw
            }
        )
        let candidates = (try? context.fetch(descriptor)) ?? []
        if let existing = candidates.first(where: { $0.name.lowercased() == key }) {
            // mention 重複防止: 同記事に対する mention は 1 度のみ
            if !existing.articles.contains(where: { $0.id == article.id }) {
                existing.articles.append(article)
                existing.mentionCount += 1
            }
            // active 再開 (deactivate 後の再 mention で復帰)
            if !existing.isActive {
                existing.isActive = true
            }
            existing.updatedAt = .now
            return existing
        } else {
            // 新規 GraphNode
            // 元 KnowledgeEntity から entityType / salience 取得 (記事内 entity と name match)
            let matchedEntity = article.extractedKnowledge?.entities.first(where: {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key
            })
            let entityType = matchedEntity?.typeRaw ?? EntityTypeStored.concept.rawValue
            let salience = matchedEntity?.salience ?? 3

            let node = GraphNode(
                name: name,
                categoryRaw: categoryRaw,
                entityType: entityType,
                salience: salience,
                mentionCount: 1,
                isActive: true
            )
            node.articles.append(article)
            context.insert(node)
            return node
        }
    }

    /// (source, target, label) で GraphEdge upsert。既存なら weight++ + confidence max。
    /// 共起の場合 (label=nil) は (source, target) で同一視。
    private func upsertEdge(
        source: GraphNode,
        target: GraphNode,
        label: String?,
        confidence: Float,
        isUncertain: Bool,
        categoryRaw: String
    ) {
        // 既存 edge を探す (source.outgoingEdges から target 一致のものを線形 scan)
        let existing = source.outgoingEdges.first { edge in
            edge.target?.id == target.id && edge.label == label
        }
        if let existing {
            existing.weight += 1
            if confidence > existing.confidence {
                existing.confidence = confidence
            }
            // confidence 上昇で isUncertain 解除可能
            if confidence >= Float(uncertainConfidence) {
                existing.isUncertain = false
            }
            existing.updatedAt = .now
        } else {
            let edge = GraphEdge(
                source: source,
                target: target,
                label: label,
                confidence: confidence,
                isUncertain: isUncertain,
                weight: 1,
                categoryRaw: categoryRaw
            )
            context.insert(edge)
        }
    }

    // MARK: - Node 上限 enforce

    private func enforceNodeLimit(categoryRaw: String) {
        let descriptor = FetchDescriptor<GraphNode>(
            predicate: #Predicate<GraphNode> { node in
                node.categoryRaw == categoryRaw && node.isActive == true
            }
        )
        let activeNodes = (try? context.fetch(descriptor)) ?? []
        guard activeNodes.count > maxActiveNodesPerCategory else { return }

        // importanceScore (salience * max(1, mentionCount)) 低い順に deactivate
        let sorted = activeNodes.sorted { $0.importanceScore < $1.importanceScore }
        let excess = activeNodes.count - maxActiveNodesPerCategory
        for node in sorted.prefix(excess) {
            node.isActive = false
            node.updatedAt = .now
        }
        try? context.save()
    }

    // MARK: - Category 解決

    /// Article の Category を tag.categoryRaw 経由で解決。
    /// 複数 tag に異なる Category があれば、最初のもの (出現順) を採用。
    private func resolveCategory(article: Article) -> String? {
        for tag in article.tags {
            if let categoryRaw = tag.categoryRaw, !categoryRaw.isEmpty {
                return categoryRaw
            }
        }
        return nil
    }

    // MARK: - Prompt

    static func buildPrompt(article: Article) -> String {
        let essence = article.extractedKnowledge?.essence ?? ""
        let keyFacts = article.extractedKnowledge?.keyFacts.prefix(5).map { $0.statement }.joined(separator: " / ") ?? ""
        let entityNames = article.extractedKnowledge?.entities.prefix(8).map { $0.name }.joined(separator: ", ") ?? ""

        return """
        以下の記事から、主要な事実関係を triple 形式 (subject, predicate, object) で抽出してください。

        ## ルール
        1. subject / object は entity (人物・場所・モノ・概念) で、記事に明示されているものに限る (30 字以内)
        2. predicate は短い動詞句 (release / lead / succeed / criticize / create / belong to 等、日本語可、30 字以内)
        3. confidence は 0.0-1.0:
           - 記事に明確に書かれている → 0.8 以上
           - 推測が必要 → 0.5-0.7
           - 推測の域を出ない → 0.5 未満は出力しない
        4. 同じ entity ペアに複数 triple があれば最も重要なものだけ
        5. 最大 10 triple
        6. subject == object となる self-loop は出力しない
        7. 一般論ではなく、この記事固有の関係を抽出する

        ## 記事
        タイトル: \(article.title)
        要点: \(essence)
        主な事実: \(keyFacts)
        登場 entity: \(entityNames)
        """
    }
}
