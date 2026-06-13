//
//  CategoryDefinition.swift
//  KnowledgeTree
//
//  spec 074 — 動的カテゴリ。L0 カテゴリを固定 10 個から「増やせる」レジストリに進化させる。
//
//  従来 CategorySeed (固定 10 個、code) が唯一の真実だったが、本 spec で:
//  - 初回起動で CategorySeed の 10 個を CategoryDefinition として idempotent に seed (isSeed=true)
//  - agent loop (spec 076) が「その他」等の同質クラスタを検知したら新カテゴリを自動追加 (isSeed=false)
//  - AutoCategoryClassifier はこのレジストリ (seed + 動的) を候補に使う
//
//  CloudKit: 新 @Model の追加は record type 追加 = lightweight migration 安全 (削除・rename が破壊的)。
//  Tag.categoryRaw は String のまま無改修 = 有効値の集合が増えるだけ。
//

import Foundation
import SwiftData

@Model
final class CategoryDefinition {
    var id: UUID = UUID()

    /// カテゴリ名 (Tag.categoryRaw に保存される値と一致する。例: "テクノロジー")。
    var name: String = ""

    /// 分類 prompt 用の短い定義 (定義 + 例 + 反例)。seed は CategorySeed 由来、動的は AI 命名時に生成。
    var definition: String = ""

    /// 元の 10 シードカテゴリか (true = CategorySeed 由来、false = agent loop が後から追加)。
    var isSeed: Bool = false

    /// ユーザーが非表示にしたカテゴリ (削除はしない、calm UX)。候補・表示から除外。
    var isHidden: Bool = false

    /// 表示順 (seed は CategorySeed.order、動的は末尾)。
    var order: Int = 0

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        definition: String = "",
        isSeed: Bool = false,
        isHidden: Bool = false,
        order: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.definition = definition
        self.isSeed = isSeed
        self.isHidden = isHidden
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
