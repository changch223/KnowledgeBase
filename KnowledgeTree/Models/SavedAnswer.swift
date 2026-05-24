//
//  SavedAnswer.swift
//  KnowledgeTree
//
//  spec 043 — iKnow V1 Phase A 第 2 弾 / Karpathy LLM Wiki 思想の Compound Moment 条件 1。
//
//  AI Chat (spec 021) の答えに引用 2+ 件 + 50 字+ あれば SavedAnswer として永続化、
//  引用記事 → 関連 ConceptPage (spec 042) を overlap 数 desc top 5 で紐付ける。
//
//  - 自動保存: ChatService.ask 末尾の SavedAnswerService.captureIfWorthy hook で生成
//  - 自動更新: 新記事 ingest → 関連 ConceptPage → SavedAnswer.isStale = true (WikiLint 用、本 spec では仕込みのみ)
//  - 編集: pin / delete (詳細画面 toolbar から SavedAnswerService 経由)
//  - Article への関係: 片方向 @Relationship.nullify (Article 側 inverse property 追加しない、spec 042 ConceptPage と同パターン)
//

import Foundation
import SwiftData

@Model
final class SavedAnswer {
    var id: UUID = UUID()

    /// ユーザー入力 question (trim 済で保存、50-2000 字想定)。重複防止 key としても使う。
    var question: String = ""

    /// AI 答え本文 (3 段落以内、50-5000 字想定、UUID strip 済)
    var answer: String = ""

    /// 引用 Article。`@Relationship(deleteRule: .nullify)` で Article 側に inverse property を追加せず、
    /// Article 削除時には relationship のみ自動 nullify され Article 自体は残る。
    @Relationship(deleteRule: .nullify)
    var citedArticles: [Article] = []

    /// 引用記事から resolve した関連 ConceptPage の id 配列 (overlap 数 desc top 5)。
    /// @Relationship ではなく ID 配列で弱結合、将来 spec 044+ で community-based 拡張時の migration 負担を回避。
    var relatedConceptIDs: [UUID] = []

    /// 元 ChatSession.id (nullable)。ChatSession が削除されても SavedAnswer は残る (履歴保護)。
    var chatSessionID: UUID?

    /// ユーザー手動ピン (履歴画面 / ConceptPage 詳細セクションで上位表示)。
    var isPinned: Bool = false

    /// 新記事 ingest で関連 ConceptPage が isStale 化されたとき true。
    /// 本 spec では DB 仕込みのみ、UI 表示は将来 spec (WikiLint 拡張) で扱う。
    var isStale: Bool = false

    /// 保存日時 (履歴 sort key)。
    var savedAt: Date = Date.now

    /// 更新日時 (pin / isStale 化 / delete で更新)。
    var updatedAt: Date = Date.now

    /// true = ChatService hook 経由 auto-save、false = (将来) 手動保存。
    /// 現状は auto-save のみ、metric / WikiLint 分析用に保持。
    var savedAutomatically: Bool = false

    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        citedArticles: [Article] = [],
        relatedConceptIDs: [UUID] = [],
        chatSessionID: UUID? = nil,
        isPinned: Bool = false,
        isStale: Bool = false,
        savedAt: Date = .now,
        updatedAt: Date = .now,
        savedAutomatically: Bool = true
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.citedArticles = citedArticles
        self.relatedConceptIDs = relatedConceptIDs
        self.chatSessionID = chatSessionID
        self.isPinned = isPinned
        self.isStale = isStale
        self.savedAt = savedAt
        self.updatedAt = updatedAt
        self.savedAutomatically = savedAutomatically
    }
}

// MARK: - Computed properties

extension SavedAnswer {
    /// 履歴 row / セクション内 row 用の 1 行 preview (40 字 + 「…」)。
    var questionPreview: String {
        let trimmed = question.replacingOccurrences(of: "\n", with: " ")
        return trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
    }

    /// 重複判定 key (空白 trim 後、case sensitive)。
    var normalizedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Navigation Destinations (Hashable transient struct)

/// SavedAnswerDetailView への遷移 destination。
/// SwiftData @Model を直接 navigation value にせず ID 経由で安全に遷移する (spec 042 同パターン)。
struct SavedAnswerDetailDestination: Hashable {
    let id: UUID
}

/// 特定 ConceptPage の SavedAnswer フィルター済 list 画面 destination。
/// 「+N すべて見る」遷移先 (MVP では SavedAnswerHistoryView を流用、conceptPageID は無視も可)。
struct SavedAnswerListByConceptDestination: Hashable {
    let conceptPageID: UUID
}
