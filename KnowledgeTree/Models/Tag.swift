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
    @Attribute(.unique) var name: String
    @Relationship(inverse: \Article.tags) var articles: [Article] = []

    init(name: String) {
        // name は呼び出し側で必ず TagNormalizer.normalize 済を渡すこと。
        // 防御的に再正規化までは行わない (パフォーマンス + 呼び出し責務明示)。
        self.name = name
    }
}
