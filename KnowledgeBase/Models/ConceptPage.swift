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

    /// spec 089: crossSourceInsights と同 index で並ぶ「最も関連する元記事の id (UUID 文字列)」。
    /// 合成時に embedding/キーワードで照合し保存。空文字 = 該当なし。CloudKit lightweight 安全 (default [])。
    var insightSourceArticleIDs: [String] = []

    /// 原典 Article への参照 (片方向、deleteRule: .nullify で Article 側に影響ゼロ)。
    /// Article 削除時は relationship が自動 nullify、ConceptPage 側 relatedArticles からは除外される。
    @Relationship(deleteRule: .nullify)
    var relatedArticles: [Article]? = []

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

    // MARK: - spec 063 (LLM Wiki 土台) 追加フィールド

    /// AI が書く Wiki 本文 (Markdown)。summary より詳しい「全体像」(VISION v2 LLM Wiki)。
    /// plain string 生成 (generateWikiBody) で token 超過を回避。空 = 未生成 (次回 ingest で埋まる)。
    var bodyMarkdown: String = ""

    /// 種別 rawValue (WikiPageKind: person / concept / project)。
    /// Generable enum 非対応のため String 保存 + computed `kind` で enum 変換 (spec 044/057 同パターン)。
    var kindRaw: String = "concept"

    /// ユーザーが非表示にしたページ (AI 誤生成の抑制)。一覧・関連表示から除外、削除はしない。
    var isHidden: Bool = false

    /// ユーザーが bodyMarkdown を手で訂正したフラグ。true の間は自動再生成で無断上書きしない (FR-007)。
    var bodyEditedByUser: Bool = false

    // MARK: - spec 074 (概念階層) 追加フィールド

    /// 上位 (広い) 概念ページの id。nil = L1 広い概念ページ自身 or 未分類。
    /// 階層: カテゴリ(L0=既存 categoryRaw) > 広い概念(L1) > 具体概念(L2)。
    /// 例: 「Text-to-SQL」(L2, parent=「生成AI」) / 「生成AI」(L1, parent=nil)。
    /// @Relationship でなく ID 参照 (relatedConceptIDs と同方針、スキーマ進化に柔軟)。
    var parentConceptID: UUID? = nil

    /// 概念のレベル rawValue (ConceptLevel: broad / specific)。
    /// Generable enum 非対応・CloudKit 安全のため String 保存 + computed `level` で enum 変換。
    /// default "specific" = 既存フラットページは具体概念扱い (backfill で広い概念へ昇格 = spec 076)。
    var conceptLevelRaw: String = "specific"

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// spec 080拡張: ユーザーが iKnow フィードでこの概念カードを見た最終時刻。
    /// `updatedAt > lastSeenAt` (or nil) = 未読/更新あり → フィード上位に。CloudKit lightweight 安全 (default nil)。
    var lastSeenAt: Date? = nil

    init(
        id: UUID = UUID(),
        name: String,
        nameAliases: [String] = [],
        categoryRaw: String,
        summary: String = "",
        crossSourceInsights: [String] = [],
        insightSourceArticleIDs: [String] = [],
        relatedArticles: [Article] = [],
        relatedConceptIDs: [UUID] = [],
        userUnderstanding: Int = 0,
        isFollowing: Bool = false,
        isStale: Bool = true,
        embedding: Data? = nil,
        bodyMarkdown: String = "",
        kindRaw: String = "concept",
        isHidden: Bool = false,
        bodyEditedByUser: Bool = false,
        parentConceptID: UUID? = nil,
        conceptLevelRaw: String = "specific",
        createdAt: Date = .now,
        updatedAt: Date = Date.now,
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.nameAliases = nameAliases
        self.categoryRaw = categoryRaw
        self.summary = summary
        self.crossSourceInsights = crossSourceInsights
        self.insightSourceArticleIDs = insightSourceArticleIDs
        self.relatedArticles = relatedArticles
        self.relatedConceptIDs = relatedConceptIDs
        self.userUnderstanding = max(0, min(5, userUnderstanding))
        self.isFollowing = isFollowing
        self.isStale = isStale
        self.embedding = embedding
        self.bodyMarkdown = bodyMarkdown
        self.kindRaw = kindRaw
        self.isHidden = isHidden
        self.bodyEditedByUser = bodyEditedByUser
        self.parentConceptID = parentConceptID
        self.conceptLevelRaw = conceptLevelRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastSeenAt = lastSeenAt
    }
}

// MARK: - ConceptLevel (spec 074, 概念階層)

/// 概念のレベル。ConceptPage.conceptLevelRaw に rawValue 保存。
/// 階層: カテゴリ(L0) > 広い概念(broad/L1) > 具体概念(specific/L2)。
enum ConceptLevel: String, CaseIterable {
    case broad     // 広い概念 (例: 生成AI / LLM、データエンジニアリング)
    case specific  // 具体概念 (例: Text-to-SQL、コンテキストエンジニアリング)
}

// MARK: - WikiPageKind (spec 063, LLM Wiki)

/// Wiki ページの種別。ConceptPage.kindRaw に rawValue 保存。
enum WikiPageKind: String, CaseIterable {
    case person   // 人物
    case concept  // 概念
    case project  // プロジェクト

    var displayNameKey: String { "wiki.kind.\(rawValue)" }

    var symbolName: String {
        switch self {
        case .person: return "person.fill"
        case .concept: return "lightbulb.fill"
        case .project: return "folder.fill"
        }
    }
}

// MARK: - Computed properties

extension ConceptPage {
    /// spec 063: kindRaw <-> WikiPageKind 変換。不正値は .concept に fallback。
    var kind: WikiPageKind {
        get { WikiPageKind(rawValue: kindRaw) ?? .concept }
        set { kindRaw = newValue.rawValue }
    }

    /// spec 074: conceptLevelRaw <-> ConceptLevel 変換。不正値は .specific に fallback。
    var level: ConceptLevel {
        get { ConceptLevel(rawValue: conceptLevelRaw) ?? .specific }
        set { conceptLevelRaw = newValue.rawValue }
    }

    /// 広い概念ページか (L1)。
    var isBroadConcept: Bool { level == .broad }

    /// 同名判定用 (大文字小文字無視 + aliases 含む) のキー文字列配列。
    /// in-memory fetch で `searchableNames.contains(lowercased(name))` のように使う。
    /// (spec 078 の canonical 照合は app target 専用 `ConceptNameNormalizer.canonicalNames(of:)` で行う。
    ///  ConceptPage は Share/Safari extension とも共有するため Services 依存をここに持たせない。)
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
