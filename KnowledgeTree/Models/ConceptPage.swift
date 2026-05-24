//
//  ConceptPage.swift
//  KnowledgeTree
//
//  spec 042 — iKnow V1 Phase A 第 1 弾 / Karpathy LLM Wiki 思想の中核「概念ページ」。
//
//  複数の保存記事に登場する entity (人物 / モノ / 概念) を 1 つの読める単位に統合し、
//  Foundation Models が複数ソースを横断した summary と crossSourceInsights を AI 合成する。
//
//  - 自動生成: 同名 entity が 2+ Article に登場した時点で auto-create (isStale=true 初期)
//  - 自動更新: 新記事 ingest で関連 ConceptPage が isStale=true → BGTask で再合成
//  - 編集可能: rename / merge / delete / setFollowing (ConceptPageStore 経由)
//  - Article への関係: 片方向 @Relationship.nullify (Article 側 inverse property は追加しない)
//

import Foundation
import SwiftData

@Model
final class ConceptPage {
    var id: UUID = UUID()

    /// 表示用「主名」(例: "Apple"、"Tim Cook"、"Foundation Models")
    var name: String = ""

    /// 同義語 / 別名 (例: ["アップル", "Apple Inc."])。merge 時に source.name + source.nameAliases を吸収。
    /// 大文字小文字無視同一視 (searchableNames) で利用。
    var nameAliases: [String] = []

    /// 所属カテゴリー (spec 015 CategorySeed と同 vocab、`category.name` 文字列)
    var categoryRaw: String = ""

    /// AI 合成「今わかっていること」、200-400 字目標 (Service post-process で 500 chars 超は trim)。
    /// 初期値 ""、isStale=true な間は「整理中…」placeholder を表示する判定に使う。
    var summary: String = ""

    /// 複数記事を横断して見える知見 bullet 配列、最大 7 件 (Service post-process で truncate)。
    /// 各 50-150 字想定。
    var crossSourceInsights: [String] = []

    /// 原典 Article への参照 (片方向、deleteRule: .nullify で Article 側に影響ゼロ)。
    /// Article 削除時は relationship が自動 nullify、ConceptPage 側 relatedArticles からは除外される。
    @Relationship(deleteRule: .nullify)
    var relatedArticles: [Article] = []

    /// graph 経由で関連が判明した他 ConceptPage の id 配列。
    /// @Relationship ではなく ID 配列とすることで、将来 spec 045 (Community) /
    /// spec 047 (WikiLint) でのスキーマ進化に柔軟に対応する。
    var relatedConceptIDs: [UUID] = []

    /// ユーザー理解度 0-5 (本 spec では永続化のみ実装、surface は spec 049 = Understanding Chat)。
    var userUnderstanding: Int = 0

    /// ピン (フォロー) 状態。知識 Clip タブの上位 5 件で `isFollowing` 優先表示。
    var isFollowing: Bool = false

    /// BGTask 再合成フラグ。初期値 true (= 未合成)、再合成完了で false。
    /// 新記事 ingest で関連 ConceptPage は true に戻る。
    var isStale: Bool = false

    /// summary の embedding (NLEmbedding.sentenceEmbedding(for: .japanese) 経由、L2 正規化済 [Float])。
    /// 検索拡張 (spec 044) で使う。`@Attribute(.externalStorage)` で SQLite から外出し。
    /// nil = 未生成 (Apple Intelligence 不可端末 / 初期 / 失敗)。
    @Attribute(.externalStorage)
    var embedding: Data?

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        nameAliases: [String] = [],
        categoryRaw: String,
        summary: String = "",
        crossSourceInsights: [String] = [],
        relatedArticles: [Article] = [],
        relatedConceptIDs: [UUID] = [],
        userUnderstanding: Int = 0,
        isFollowing: Bool = false,
        isStale: Bool = true,
        embedding: Data? = nil,
        createdAt: Date = .now,
        updatedAt: Date = Date.now
    ) {
        self.id = id
        self.name = name
        self.nameAliases = nameAliases
        self.categoryRaw = categoryRaw
        self.summary = summary
        self.crossSourceInsights = crossSourceInsights
        self.relatedArticles = relatedArticles
        self.relatedConceptIDs = relatedConceptIDs
        self.userUnderstanding = max(0, min(5, userUnderstanding))
        self.isFollowing = isFollowing
        self.isStale = isStale
        self.embedding = embedding
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed properties

extension ConceptPage {
    /// 同名判定用 (大文字小文字無視 + aliases 含む) のキー文字列配列。
    /// in-memory fetch で `searchableNames.contains(lowercased(name))` のように使う。
    var searchableNames: [String] {
        ([name] + nameAliases).map { $0.lowercased() }
    }

    /// 知識 Clip カード preview 用 (改行を空白に圧縮した summary の冒頭部)。
    var summaryPreview: String {
        summary.replacingOccurrences(of: "\n", with: " ")
    }

    /// 「整理中…」placeholder を表示すべき状態か (summary 空 or isStale=true)。
    var isSynthesisInProgress: Bool {
        summary.isEmpty || isStale
    }
}

// MARK: - Navigation Destinations (Hashable transient struct)

/// ConceptPageDetailView への遷移 destination。
/// SwiftData @Model を直接 navigation value にせず ID 経由で安全に遷移する (spec 016 同パターン)。
struct ConceptPageDetailDestination: Hashable {
    let id: UUID
}

/// 「+N すべて見る」遷移先の全 ConceptPage 一覧画面 destination。
struct ConceptPageListDestination: Hashable {}
