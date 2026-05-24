//
//  Tag.swift
//  KnowledgeTree
//
//  spec 008 — ユーザーが Article に手動で付けるタグ + 自動提案で採用するタグ。
//  正規化済 (TagNormalizer.normalize 済) name を unique 制約で保持。
//  Article との多対多 relationship。Article 削除時は relationship のみ解除、
//  tag.articles が空になった場合は TagStore が手動で context.delete する。
//

import Foundation
import SwiftData

@Model
final class Tag {
    var name: String = ""
    @Relationship(inverse: \Article.tags) var articles: [Article]? = []

    /// spec 015: AutoCategoryClassifier で 1 回推論された Category 名 (CategorySeed.allSeeds のいずれか)。
    /// nil = 未分類 (新規 Tag 直後 / Foundation Models 利用不可時の初期状態)。
    /// SwiftData lightweight migration で既存 Tag は nil 初期化、AutoCategoryBackfillRunner が後追い分類。
    var categoryRaw: String?

    init(name: String, categoryRaw: String? = nil) {
        // name は呼び出し側で必ず TagNormalizer.normalize 済を渡すこと。
        // 防御的に再正規化までは行わない (パフォーマンス + 呼び出し責務明示)。
        self.name = name
        self.categoryRaw = categoryRaw
    }
}
