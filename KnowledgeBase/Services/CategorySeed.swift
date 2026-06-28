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
    /// allSeeds は 10 個固定だが、force unwrap を避けリテラル fallback で防御 (クラッシュ回避)。
    static let otherCategory = Category(
        name: "その他", englishName: "Other", order: 9, symbolName: "ellipsis.circle"
    )

    /// AutoCategoryClassifier の prompt 用、候補 name を " / " 区切りで返す。
    static var promptCandidatesString: String {
        allSeeds.map(\.name).joined(separator: " / ")
    }

    /// spec 072: 各カテゴリの「定義 + 例 + 反例」(name 順)。単一の真実源。
    /// promptCandidatesWithDefinitions と CategoryDefinition seed (spec 074) の両方がここから派生する。
    static let seedDefinitions: [(name: String, definition: String)] = [
        ("テクノロジー", "AI/プログラミング/ソフトウェア/ガジェット/IT 全般。例: Claude, RAG, embedding, GitHub, ハルシネーション, 人工知能, 機械学習, LLM, 生成AI。※AI・人工知能・機械学習・LLM は迷わずテクノロジー。"),
        ("経済", "ビジネス/金融/市場/企業経営/マーケティング。例: 株価, 決算, スタートアップ資金調達。"),
        ("健康", "医療/身体/栄養/メンタルヘルス/病気。例: 腸内細菌, 睡眠, ワクチン。※AI のハルシネーションは健康ではなくテクノロジー。"),
        ("デザイン", "UI/UX/グラフィック/プロダクトデザイン/建築意匠。例: Figma, タイポグラフィ。"),
        ("学術", "研究/論文/学問分野/教育/理論。例: 数学, 物理学, PMBOK, 学会。"),
        ("アート", "芸術/音楽/絵画/文学/創作。例: 現代美術, 小説。"),
        ("ニュース", "時事/政治/事件/社会一般。例: 選挙, 法改正, 災害。"),
        ("スポーツ", "競技/選手/チーム/試合。例: サッカー, 大谷翔平。※スポーツ選手以外の人名はスポーツにしない。"),
        ("エンタメ", "映画/TV/ゲーム/芸能/娯楽。例: 映画作品, 配信サービス。"),
        ("その他", "上記いずれにも明確に当てはまらないもの。判断に迷う人名・組織名・一般語 (男性/企業/ユーザー 等) はここ。"),
    ]

    /// 指定 name の seed 定義 (無ければ nil)。CategoryDefinition seed 用。
    static func seedDefinition(for name: String) -> String? {
        seedDefinitions.first { $0.name == name }?.definition
    }

    /// spec 072: 各カテゴリに「定義 + 例 + 反例」を付けた prompt 用候補リスト。
    /// 1 語だけで分類する際の誤分類 (ハルシネーション→健康、人名→スポーツ等) を減らすため、
    /// AI に各カテゴリの境界を明示する。
    /// spec 074: 動的カテゴリ対応時は CategoryRegistry がレジストリから同形式を生成する。
    static var promptCandidatesWithDefinitions: String {
        seedDefinitions.map { "- \($0.name): \($0.definition)" }.joined(separator: "\n")
    }

    /// spec 097: 第1段分類の「迷ったらこの分野」特例 (主要分野のみ、token 微増)。
    /// 既定の「迷ったらその他」から各分野の代表語を救い、IT 偏重を是正。各 1 行 + 反例 1 つ。
    static let firstPassTieBreakers = """
        - 明確な技術用語 (AI / 人工知能 / 機械学習 / LLM / 生成AI / プログラミング / クラウド) は迷わずテクノロジー (反例:「AIのハルシネーション」は健康でなくテクノロジー)
        - 病気 / 栄養 / 睡眠 / メンタル / 医療 は迷わず健康 (反例:「医療AI」の AI はテクノロジー)
        - 株価 / 決算 / 資金調達 / マーケティング / 経営 は迷わず経済
        - 競技 / 選手 / 試合 / チーム は迷わずスポーツ (反例: スポーツ以外の人名はスポーツにしない)
        - 政治 / 事件 / 災害 / 法改正 は迷わずニュース
        """
}
