//
//  ConflictProposal.swift
//  KnowledgeTree
//
//  spec 037 — 時系列事実上書き提案 @Model。
//  AI が新記事 vs 既存記事の同 entity に対する事実矛盾を検出した時に作成され、
//  ユーザーが「上書き」「両方残す」「却下」を選択するまで pending 状態。
//

import Foundation
import SwiftData

@Model
final class ConflictProposal {
    var id: UUID = UUID()

    /// 新しい記事 (この記事の事実を採用するかが論点)
    @Relationship(deleteRule: .nullify) var newArticle: Article?

    /// 古い記事 (上書きされる候補)
    @Relationship(deleteRule: .nullify) var oldArticle: Article?

    /// 矛盾検出のトリガとなった entity 名 (例: "〇〇店")
    var entityName: String = ""

    /// AI 生成の矛盾内容説明 (20-50 字、UI に表示)
    var conflictDescription: String = ""

    /// 新記事側の事実 (1 文)
    var newFact: String = ""

    /// 旧記事側の事実 (1 文)
    var oldFact: String = ""

    /// 状態: "pending" / "overwrite" / "keepBoth" / "dismissed"
    var status: String = ""

    var createdAt: Date = Date.now
    var resolvedAt: Date?

    /// spec 041: graph 衝突の場合に該当 GraphEdge.id を保持。
    /// nil = 通常の fact 矛盾 (spec 037)、非 nil = graph triple 衝突 (同 source+predicate 複数 target)。
    /// SwiftData lightweight migration: optional + default nil。
    var graphEdgeID: UUID?

    init(
        id: UUID = UUID(),
        newArticle: Article?,
        oldArticle: Article?,
        entityName: String,
        conflictDescription: String,
        newFact: String,
        oldFact: String,
        status: String = ConflictStatus.pending.rawValue,
        createdAt: Date = .now,
        resolvedAt: Date? = nil,
        graphEdgeID: UUID? = nil
    ) {
        self.id = id
        self.newArticle = newArticle
        self.oldArticle = oldArticle
        self.entityName = entityName
        self.conflictDescription = conflictDescription
        self.newFact = newFact
        self.oldFact = oldFact
        self.status = status
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.graphEdgeID = graphEdgeID
    }
}

/// ConflictProposal.status の許容値。
enum ConflictStatus: String {
    case pending      // ユーザー未確認 (spec 058 で廃止、新規生成しない)
    case overwrite    // ユーザーが「上書き」採用 (oldArticle.isObsolete = true)
    case keepBoth     // ユーザーが「両方残す」採用
    case dismissed    // ユーザーが「却下」(矛盾ではないと判断)
    /// spec 058: AI 自動採用 (両方残す、UI 通知なし、ArticleDetailView「過去の見解」で閲覧可能)。
    /// oldArticle.isObsolete = false (両方主表示、ArticleDetailView 末尾の DisclosureGroup で hidden)。
    case autoResolved
}
