//
//  CategorySeed.swift
//  KnowledgeTree
//
//  spec 015 — Tag より上位の階層として 10 個のシードカテゴリーを hardcoded で定義。
//  Tag.categoryRaw に保存される値は CategorySeed.allSeeds のいずれかの name。
//
//  data-model.md Section B 準拠。
//

import Foundation

/// シードカテゴリーの transient struct。永続化されない (= Tag.categoryRaw に String で保存)。
struct Category: Hashable, Sendable {
    let name: String          // 日本語表示名 (Tag.categoryRaw に保存される値)
    let englishName: String   // 将来 i18n 用 (現状 accessibilityIdentifier 等の生成に使用)
    let order: Int            // 表示順 (0 = 最上位)
    let symbolName: String    // 将来 UI でアイコン表示する用 (現状未使用)
}

/// 10 個のシードカテゴリーの single source of truth。
/// 順序は order で保証 (allSeeds の Array 順と一致)。
enum CategorySeed {
    static let allSeeds: [Category] = [
        Category(name: "テクノロジー", englishName: "Technology",    order: 0, symbolName: "cpu"),
        Category(name: "経済",         englishName: "Economy",       order: 1, symbolName: "chart.line.uptrend.xyaxis"),
        Category(name: "健康",         englishName: "Health",        order: 2, symbolName: "heart"),
        Category(name: "デザイン",     englishName: "Design",        order: 3, symbolName: "paintbrush"),
        Category(name: "学術",         englishName: "Academic",      order: 4, symbolName: "book"),
        Category(name: "アート",       englishName: "Art",           order: 5, symbolName: "paintpalette"),
        Category(name: "ニュース",     englishName: "News",          order: 6, symbolName: "newspaper"),
        Category(name: "スポーツ",     englishName: "Sports",        order: 7, symbolName: "figure.run"),
        Category(name: "エンタメ",     englishName: "Entertainment", order: 8, symbolName: "tv"),
        Category(name: "その他",       englishName: "Other",         order: 9, symbolName: "ellipsis.circle"),
    ]

    /// nil / unknown を「その他」に正規化。UI 側の defensive code を不要にする。
    static func category(for name: String?) -> Category {
        guard let name else { return otherCategory }
        return allSeeds.first { $0.name == name } ?? otherCategory
    }

    /// fallback 用「その他」カテゴリー (allSeeds 末尾)。
    static var otherCategory: Category {
        // allSeeds は 10 個固定なので force unwrap は安全
        allSeeds.last!
    }

    /// AutoCategoryClassifier の prompt 用、候補 name を " / " 区切りで返す。
    static var promptCandidatesString: String {
        allSeeds.map(\.name).joined(separator: " / ")
    }
}
