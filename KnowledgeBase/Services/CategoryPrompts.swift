//
//  CategoryPrompts.swift
//  KnowledgeTree
//
//  spec 097 Phase 3 — 概念合成 (wiki 生成) を分野ごとに最適化するためのプロンプト素材。
//  概念のカテゴリ (categoryRaw) に応じて「この分野で重視すること」「表記を統一する固有名詞」を
//  各合成プロンプト (oneShot / meta / broad / chunk) に注入する。
//  プロファイルが無いカテゴリ (その他 / 動的カテゴリ) は空ブロック = 既定の汎用生成。
//  ※ 実行時 token は 1 呼び出し 1 プロンプトのまま (分岐で差し替えるだけ)。
//

import Foundation

enum CategoryPrompts {
    struct Profile: Sendable {
        /// この分野でまとめる時に重視すべき観点。
        let emphasis: String
        /// 表記ゆれしやすい固有名詞の統一ヒント。
        let glossary: String
    }

    /// CategorySeed の 10 分野のうち「その他」を除く 9 分野に最適化プロファイルを用意。
    static let byCategory: [String: Profile] = [
        "テクノロジー": Profile(
            emphasis: "技術の仕組み・用途・他技術との関係・できること/制約を重視。",
            glossary: "クロード→Claude、GPT/ChatGPT、LLM/大規模言語モデル、生成AI など表記を統一。"),
        "経済": Profile(
            emphasis: "数値 (株価・金額・成長率)・企業や市場の動き・原因と結果を重視。",
            glossary: "社名・通貨・指標 (GDP/CPI 等) の表記を統一。"),
        "健康": Profile(
            emphasis: "症状・原因・対処/予防・エビデンスの有無を重視。断定しすぎない。",
            glossary: "病名・成分・栄養素・身体部位の表記を統一。"),
        "デザイン": Profile(
            emphasis: "目的・原則・手法・使うツールを重視。",
            glossary: "ツール名 (Figma 等)・専門用語 (UI/UX 等) の表記を統一。"),
        "学術": Profile(
            emphasis: "主張・根拠・手法・結論を重視。論理の流れを保つ。",
            glossary: "専門用語・人名・理論名の表記を統一。"),
        "アート": Profile(
            emphasis: "作品・作者・様式・時代背景・受け取られ方を重視。",
            glossary: "作品名・作者名・流派名の表記を統一。"),
        "ニュース": Profile(
            emphasis: "いつ・どこで・誰が・何を・結果/影響 を重視。事実関係を正確に。",
            glossary: "人名・地名・組織名の表記を統一。"),
        "スポーツ": Profile(
            emphasis: "選手・チーム・試合結果・記録・大会を重視。",
            glossary: "選手名・チーム名・大会名の表記を統一。"),
        "エンタメ": Profile(
            emphasis: "作品・出演者/制作者・公開や配信・話題性を重視。",
            glossary: "作品名・人物名・サービス名の表記を統一。"),
    ]

    /// spec 106: 英語指示版 (生成言語が日本語以外) のプロファイル。キーは byCategory と同じ分野名。
    static let englishByCategory: [String: Profile] = [
        "テクノロジー": Profile(
            emphasis: "Emphasize how the technology works, what it is used for, its relation to other technologies, and what it can / cannot do.",
            glossary: "Keep spellings consistent for terms such as Claude, GPT/ChatGPT, LLM / large language model, generative AI."),
        "経済": Profile(
            emphasis: "Emphasize figures (stock prices, amounts, growth rates), moves of companies and markets, and causes and effects.",
            glossary: "Keep spellings of company names, currencies and indicators (GDP, CPI, etc.) consistent."),
        "健康": Profile(
            emphasis: "Emphasize symptoms, causes, treatment / prevention, and whether evidence exists. Do not over-assert.",
            glossary: "Keep spellings of disease names, ingredients, nutrients and body parts consistent."),
        "デザイン": Profile(
            emphasis: "Emphasize purpose, principles, methods and the tools used.",
            glossary: "Keep spellings of tool names (e.g. Figma) and terms (e.g. UI/UX) consistent."),
        "学術": Profile(
            emphasis: "Emphasize claims, evidence, methods and conclusions. Preserve the logical flow.",
            glossary: "Keep spellings of technical terms, personal names and theory names consistent."),
        "アート": Profile(
            emphasis: "Emphasize works, creators, styles, historical background and reception.",
            glossary: "Keep spellings of work titles, creator names and school names consistent."),
        "ニュース": Profile(
            emphasis: "Emphasize when, where, who, what, and the result / impact. Keep the facts accurate.",
            glossary: "Keep spellings of personal names, place names and organization names consistent."),
        "スポーツ": Profile(
            emphasis: "Emphasize players, teams, match results, records and tournaments.",
            glossary: "Keep spellings of player names, team names and tournament names consistent."),
        "エンタメ": Profile(
            emphasis: "Emphasize works, cast / creators, release or streaming, and buzz.",
            glossary: "Keep spellings of work titles, personal names and service names consistent."),
    ]

    /// 概念の categoryRaw に対応する分野最適化ブロック。
    /// プロファイルが無い (その他 / 動的カテゴリ / nil) なら空文字 = 汎用生成。
    static func block(forCategoryRaw raw: String?, language: PipelineLanguage = .ja) -> String {
        if !PromptLocalizer.usesJapaneseInstructions(language) {
            guard let raw, let profile = englishByCategory[raw] else { return "" }
            return """

            ## Focus for this field
            \(profile.emphasis)
            ## Consistent spelling of proper nouns
            \(profile.glossary)
            """
        }
        guard let raw, let profile = byCategory[raw] else { return "" }
        return """

        ## この分野での重視点
        \(profile.emphasis)
        ## 固有名詞の表記統一
        \(profile.glossary)
        """
    }
}
