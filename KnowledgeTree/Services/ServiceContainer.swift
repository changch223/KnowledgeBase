//
//  ServiceContainer.swift
//  KnowledgeTree
//
//  spec 005 — 各 Service への参照を Environment 経由でビューに配るためのコンテナ。
//  bootstrap で 3 service を生成 → ServiceContainer に bind →
//  ArticleListView / ArticleDetailView から再抽出などの手動操作で参照する。
//

import Foundation
import Observation

@MainActor
@Observable
final class ServiceContainer {
    var enrichmentService: ArticleEnrichmentServiceProtocol?
    var bodyService: BodyExtractionServiceProtocol?
    var knowledgeService: KnowledgeExtractionServiceProtocol?
    /// spec 008: タグの CRUD を担当
    var tagStore: TagStore?
}
