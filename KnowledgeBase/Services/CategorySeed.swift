//
//  CategorySeed.swift
//  KnowledgeTree
//
//  spec 015 — Tag より上位の階層として 10 個のシードカテゴリーを hardcoded で定義。
//  Tag.categoryRaw に保存される値は CategorySeed.allSeeds のいずれかの name。
//
//  i18n Phase B/C: シードは PipelineLanguage 別に用意する (ja / zh-Hans / zh-Hant / en / ko / es / de)。
//  既定引数なしの API (`allSeeds` / `otherCategory` / `seedDefinitions` / `promptCandidatesWithDefinitions` /
//  `promptCandidatesString` / `firstPassTieBreakers`) は `PipelineLanguage.current` を参照する computed
//  property のままなので、既存の全呼び出し箇所は無改修で動く (既定 ja では完全に同じ値を返す)。
//  テスト容易化のため `for language:` 引数付きの純関数版も併設する。
//
//  data-model.md Section B 準拠。
//

import Foundation

/// シードカテゴリーの transient struct。永続化されない (= Tag.categoryRaw に String で保存)。
struct Category: Hashable, Sendable {
    let name: String          // 表示名 (パイプライン言語に追従、Tag.categoryRaw に保存される値)
    let englishName: String   // 将来 i18n 用 (現状 accessibilityIdentifier 等の生成に使用)
    let order: Int            // 表示順 (0 = 最上位)
    let symbolName: String    // 将来 UI でアイコン表示する用 (現状未使用)
}

/// 10 個のシードカテゴリーの single source of truth。
/// 順序は order で保証 (allSeeds の Array 順と一致)。
enum CategorySeed {

    // MARK: - 言語非依存 API (`.current` を参照、既存呼び出し箇所は無改修)

    /// 現在のパイプライン言語のシードカテゴリー一覧 (10 個)。
    static var allSeeds: [Category] { allSeeds(for: .current) }

    /// nil / unknown を「その他」に正規化。UI 側の defensive code を不要にする。
    static func category(for name: String?) -> Category {
        guard let name else { return otherCategory }
        return allSeeds.first { $0.name == name } ?? otherCategory
    }

    /// fallback 用「その他」カテゴリー。
    /// spec 085: allSeeds.last! の強制アンラップを避け、リテラルで防御 (allSeeds 破損時のクラッシュ回避)。
    static var otherCategory: Category { otherCategory(for: .current) }

    /// AutoCategoryClassifier の prompt 用、候補 name を " / " 区切りで返す。
    static var promptCandidatesString: String {
        allSeeds.map(\.name).joined(separator: " / ")
    }

    /// spec 072: 各カテゴリの「定義 + 例 + 反例」(name 順)。単一の真実源。
    /// promptCandidatesWithDefinitions と CategoryDefinition seed (spec 074) の両方がここから派生する。
    static var seedDefinitions: [(name: String, definition: String)] { seedDefinitions(for: .current) }

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
    static var firstPassTieBreakers: String { firstPassTieBreakers(for: .current) }

    // MARK: - i18n Phase B: 言語別 API

    /// 指定言語のシードカテゴリー一覧 (10 個、順序は固定)。
    static func allSeeds(for language: PipelineLanguage) -> [Category] {
        switch language {
        case .ja: return jaSeeds
        case .zhHans: return zhHansSeeds
        case .zhHant: return zhHantSeeds
        case .en: return enSeeds
        case .ko: return koSeeds
        case .es: return esSeeds
        case .de: return deSeeds
        }
    }

    /// 指定言語の fallback 用「その他」カテゴリー (リテラル、allSeeds に依存しない)。
    static func otherCategory(for language: PipelineLanguage) -> Category {
        switch language {
        case .ja: return Category(name: "その他", englishName: "Other", order: 9, symbolName: "ellipsis.circle")
        case .zhHans: return Category(name: "其他", englishName: "Other", order: 9, symbolName: "ellipsis.circle")
        case .zhHant: return Category(name: "其他", englishName: "Other", order: 9, symbolName: "ellipsis.circle")
        case .en: return Category(name: "Other", englishName: "Other", order: 9, symbolName: "ellipsis.circle")
        case .ko: return Category(name: "기타", englishName: "Other", order: 9, symbolName: "ellipsis.circle")
        case .es: return Category(name: "Otros", englishName: "Other", order: 9, symbolName: "ellipsis.circle")
        case .de: return Category(name: "Sonstiges", englishName: "Other", order: 9, symbolName: "ellipsis.circle")
        }
    }

    /// 指定言語の「定義 + 例 + 反例」一覧 (name 順)。
    static func seedDefinitions(for language: PipelineLanguage) -> [(name: String, definition: String)] {
        switch language {
        case .ja: return jaSeedDefinitions
        case .zhHans: return zhHansSeedDefinitions
        case .zhHant: return zhHantSeedDefinitions
        case .en: return enSeedDefinitions
        case .ko: return koSeedDefinitions
        case .es: return esSeedDefinitions
        case .de: return deSeedDefinitions
        }
    }

    /// 指定言語の「迷ったらこの分野」特例テキスト。
    static func firstPassTieBreakers(for language: PipelineLanguage) -> String {
        switch language {
        case .ja: return jaFirstPassTieBreakers
        case .zhHans: return zhHansFirstPassTieBreakers
        case .zhHant: return zhHantFirstPassTieBreakers
        case .en: return enFirstPassTieBreakers
        case .ko: return koFirstPassTieBreakers
        case .es: return esFirstPassTieBreakers
        case .de: return deFirstPassTieBreakers
        }
    }

    /// i18n Phase B (言語混在バグ修正): 全言語のシード名 union から、指定言語自身のシード名を
    /// 除いた集合。端末の言語切替後に CategoryRegistry へ残る「前の言語のシード」名を検出するために使う
    /// (例: zh 切替後に残る ja の「テクノロジー」)。
    /// 複数言語で同一表記のシード名 (例: 「健康」は ja/zh-Hans/zh-Hant で共通、「其他」は
    /// zh-Hans/zh-Hant で共通) は、指定言語にも属するので foreign から除外されない (= 含まれない)。
    /// 純関数、テスト容易。
    static func foreignSeedNames(excluding language: PipelineLanguage) -> Set<String> {
        let currentNames = Set(allSeeds(for: language).map(\.name))
        var union = Set<String>()
        for candidate in PipelineLanguage.allCases {
            union.formUnion(allSeeds(for: candidate).map(\.name))
        }
        return union.subtracting(currentNames)
    }

    // MARK: - ja (既定、Phase A 以前と完全同一の値)

    private static let jaSeeds: [Category] = [
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

    private static let jaSeedDefinitions: [(name: String, definition: String)] = [
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

    private static let jaFirstPassTieBreakers = """
        - 明確な技術用語 (AI / 人工知能 / 機械学習 / LLM / 生成AI / プログラミング / クラウド) は迷わずテクノロジー (反例:「AIのハルシネーション」は健康でなくテクノロジー)
        - 病気 / 栄養 / 睡眠 / メンタル / 医療 は迷わず健康 (反例:「医療AI」の AI はテクノロジー)
        - 株価 / 決算 / 資金調達 / マーケティング / 経営 は迷わず経済
        - 競技 / 選手 / 試合 / チーム は迷わずスポーツ (反例: スポーツ以外の人名はスポーツにしない)
        - 政治 / 事件 / 災害 / 法改正 は迷わずニュース
        """

    // MARK: - zh-Hans (简体中文)

    private static let zhHansSeeds: [Category] = [
        Category(name: "科技", englishName: "Technology",    order: 0, symbolName: "cpu"),
        Category(name: "经济", englishName: "Economy",       order: 1, symbolName: "chart.line.uptrend.xyaxis"),
        Category(name: "健康", englishName: "Health",        order: 2, symbolName: "heart"),
        Category(name: "设计", englishName: "Design",        order: 3, symbolName: "paintbrush"),
        Category(name: "学术", englishName: "Academic",      order: 4, symbolName: "book"),
        Category(name: "艺术", englishName: "Art",           order: 5, symbolName: "paintpalette"),
        Category(name: "新闻", englishName: "News",          order: 6, symbolName: "newspaper"),
        Category(name: "体育", englishName: "Sports",        order: 7, symbolName: "figure.run"),
        Category(name: "娱乐", englishName: "Entertainment", order: 8, symbolName: "tv"),
        Category(name: "其他", englishName: "Other",         order: 9, symbolName: "ellipsis.circle"),
    ]

    private static let zhHansSeedDefinitions: [(name: String, definition: String)] = [
        ("科技", "AI/编程/软件/数码产品/IT 全领域。例: Claude, RAG, embedding, GitHub, 幻觉, 人工智能, 机器学习, LLM, 生成式AI。※AI、人工智能、机器学习、LLM 一律归入科技。"),
        ("经济", "商业/金融/市场/企业经营/市场营销。例: 股价, 财报, 创业融资。"),
        ("健康", "医疗/身体/营养/心理健康/疾病。例: 肠道菌群, 睡眠, 疫苗。※AI 的幻觉属于科技，不属于健康。"),
        ("设计", "UI/UX/平面设计/产品设计/建筑设计。例: Figma, 字体排印。"),
        ("学术", "研究/论文/学科/教育/理论。例: 数学, 物理学, PMBOK, 学会。"),
        ("艺术", "艺术/音乐/绘画/文学/创作。例: 当代艺术, 小说。"),
        ("新闻", "时事/政治/事件/社会议题。例: 选举, 修法, 灾害。"),
        ("体育", "竞技/选手/球队/比赛。例: 足球, 大谷翔平。※与体育无关的人物不归入体育。"),
        ("娱乐", "电影/电视/游戏/演艺/娱乐。例: 电影作品, 流媒体服务。"),
        ("其他", "以上都不明确符合的内容。难以判断的人名、组织名、常见词 (男性/企业/用户 等) 归入这里。"),
    ]

    private static let zhHansFirstPassTieBreakers = """
        - 明确的技术术语 (AI / 人工智能 / 机器学习 / LLM / 生成式AI / 编程 / 云计算) 一律归入科技 (反例：「AI 的幻觉」属于科技，不属于健康)
        - 疾病 / 营养 / 睡眠 / 心理 / 医疗 一律归入健康 (反例：「医疗AI」中的 AI 属于科技)
        - 股价 / 财报 / 融资 / 市场营销 / 企业经营 一律归入经济
        - 竞技 / 选手 / 比赛 / 球队 一律归入体育 (反例：与体育无关的人物不归入体育)
        - 政治 / 事件 / 灾害 / 修法 一律归入新闻
        """

    // MARK: - zh-Hant (繁體中文、台湾標準語彙)

    private static let zhHantSeeds: [Category] = [
        Category(name: "科技", englishName: "Technology",    order: 0, symbolName: "cpu"),
        Category(name: "經濟", englishName: "Economy",       order: 1, symbolName: "chart.line.uptrend.xyaxis"),
        Category(name: "健康", englishName: "Health",        order: 2, symbolName: "heart"),
        Category(name: "設計", englishName: "Design",        order: 3, symbolName: "paintbrush"),
        Category(name: "學術", englishName: "Academic",      order: 4, symbolName: "book"),
        Category(name: "藝術", englishName: "Art",           order: 5, symbolName: "paintpalette"),
        Category(name: "新聞", englishName: "News",          order: 6, symbolName: "newspaper"),
        Category(name: "體育", englishName: "Sports",        order: 7, symbolName: "figure.run"),
        Category(name: "娛樂", englishName: "Entertainment", order: 8, symbolName: "tv"),
        Category(name: "其他", englishName: "Other",         order: 9, symbolName: "ellipsis.circle"),
    ]

    private static let zhHantSeedDefinitions: [(name: String, definition: String)] = [
        ("科技", "AI／程式設計／軟體／數位產品／IT 全領域。例: Claude, RAG, embedding, GitHub, 幻覺, 人工智慧, 機器學習, LLM, 生成式AI。※AI、人工智慧、機器學習、LLM 一律歸入科技。"),
        ("經濟", "商業／金融／市場／企業經營／行銷。例: 股價, 財報, 新創募資。"),
        ("健康", "醫療／身體／營養／心理健康／疾病。例: 腸道菌叢, 睡眠, 疫苗。※AI 的幻覺屬於科技，不屬於健康。"),
        ("設計", "UI/UX／平面設計／產品設計／建築設計。例: Figma, 字體排印。"),
        ("學術", "研究／論文／學科／教育／理論。例: 數學, 物理學, PMBOK, 學會。"),
        ("藝術", "藝術／音樂／繪畫／文學／創作。例: 當代藝術, 小說。"),
        ("新聞", "時事／政治／事件／社會議題。例: 選舉, 修法, 災害。"),
        ("體育", "競技／選手／球隊／比賽。例: 足球, 大谷翔平。※與體育無關的人物不歸入體育。"),
        ("娛樂", "電影／電視／遊戲／演藝／娛樂。例: 電影作品, 串流服務。"),
        ("其他", "以上皆不明確符合的內容。難以判斷的人名、組織名、常見詞 (男性/企業/使用者 等) 歸入這裡。"),
    ]

    private static let zhHantFirstPassTieBreakers = """
        - 明確的技術術語 (AI / 人工智慧 / 機器學習 / LLM / 生成式AI / 程式設計 / 雲端運算) 一律歸入科技 (反例：「AI 的幻覺」屬於科技，不屬於健康)
        - 疾病 / 營養 / 睡眠 / 心理 / 醫療 一律歸入健康 (反例：「醫療AI」中的 AI 屬於科技)
        - 股價 / 財報 / 募資 / 行銷 / 企業經營 一律歸入經濟
        - 競技 / 選手 / 比賽 / 球隊 一律歸入體育 (反例：與體育無關的人物不歸入體育)
        - 政治 / 事件 / 災害 / 修法 一律歸入新聞
        """

    // MARK: - en (English)

    private static let enSeeds: [Category] = [
        Category(name: "Technology",    englishName: "Technology",    order: 0, symbolName: "cpu"),
        Category(name: "Economy",       englishName: "Economy",       order: 1, symbolName: "chart.line.uptrend.xyaxis"),
        Category(name: "Health",        englishName: "Health",        order: 2, symbolName: "heart"),
        Category(name: "Design",        englishName: "Design",        order: 3, symbolName: "paintbrush"),
        Category(name: "Academic",      englishName: "Academic",      order: 4, symbolName: "book"),
        Category(name: "Art",           englishName: "Art",           order: 5, symbolName: "paintpalette"),
        Category(name: "News",          englishName: "News",          order: 6, symbolName: "newspaper"),
        Category(name: "Sports",        englishName: "Sports",        order: 7, symbolName: "figure.run"),
        Category(name: "Entertainment", englishName: "Entertainment", order: 8, symbolName: "tv"),
        Category(name: "Other",         englishName: "Other",         order: 9, symbolName: "ellipsis.circle"),
    ]

    private static let enSeedDefinitions: [(name: String, definition: String)] = [
        ("Technology", "AI / programming / software / gadgets / IT in general. Examples: Claude, RAG, embedding, GitHub, hallucination, artificial intelligence, machine learning, LLM, generative AI. Note: AI, artificial intelligence, machine learning, and LLM always go under Technology."),
        ("Economy", "Business / finance / markets / corporate management / marketing. Examples: stock prices, earnings reports, startup funding."),
        ("Health", "Medicine / the body / nutrition / mental health / illness. Examples: gut microbiome, sleep, vaccines. Note: AI hallucination belongs to Technology, not Health."),
        ("Design", "UI/UX / graphic design / product design / architectural design. Examples: Figma, typography."),
        ("Academic", "Research / papers / academic fields / education / theory. Examples: mathematics, physics, PMBOK, academic conferences."),
        ("Art", "Fine art / music / painting / literature / creative work. Examples: contemporary art, novels."),
        ("News", "Current affairs / politics / incidents / society at large. Examples: elections, legal reforms, disasters."),
        ("Sports", "Competitions / athletes / teams / matches. Examples: soccer, Shohei Ohtani. Note: people unrelated to sports should not go under Sports."),
        ("Entertainment", "Movies / TV / games / celebrities / leisure. Examples: films, streaming services."),
        ("Other", "Anything that does not clearly fit the categories above. Ambiguous names of people/organizations and generic terms (e.g. \"man\", \"company\", \"user\") go here."),
    ]

    private static let enFirstPassTieBreakers = """
        - Clear technical terms (AI / artificial intelligence / machine learning / LLM / generative AI / programming / cloud computing) always go under Technology (counterexample: "AI hallucination" is Technology, not Health)
        - Disease / nutrition / sleep / mental health / medicine always go under Health (counterexample: the AI in "medical AI" is Technology)
        - Stock prices / earnings / funding / marketing / management always go under Economy
        - Competitions / athletes / matches / teams always go under Sports (counterexample: people unrelated to sports should not go under Sports)
        - Politics / incidents / disasters / legal reform always go under News
        """

    // MARK: - ko (한국어)

    private static let koSeeds: [Category] = [
        Category(name: "기술",         englishName: "Technology",    order: 0, symbolName: "cpu"),
        Category(name: "경제",         englishName: "Economy",       order: 1, symbolName: "chart.line.uptrend.xyaxis"),
        Category(name: "건강",         englishName: "Health",        order: 2, symbolName: "heart"),
        Category(name: "디자인",       englishName: "Design",        order: 3, symbolName: "paintbrush"),
        Category(name: "학술",         englishName: "Academic",      order: 4, symbolName: "book"),
        Category(name: "예술",         englishName: "Art",           order: 5, symbolName: "paintpalette"),
        Category(name: "뉴스",         englishName: "News",          order: 6, symbolName: "newspaper"),
        Category(name: "스포츠",       englishName: "Sports",        order: 7, symbolName: "figure.run"),
        Category(name: "엔터테인먼트", englishName: "Entertainment", order: 8, symbolName: "tv"),
        Category(name: "기타",         englishName: "Other",         order: 9, symbolName: "ellipsis.circle"),
    ]

    private static let koSeedDefinitions: [(name: String, definition: String)] = [
        ("기술", "AI/프로그래밍/소프트웨어/기기/IT 전반. 예: Claude, RAG, embedding, GitHub, 할루시네이션, 인공지능, 머신러닝, LLM, 생성형 AI. ※AI・인공지능・머신러닝・LLM은 망설이지 말고 기술로 분류."),
        ("경제", "비즈니스/금융/시장/기업 경영/마케팅. 예: 주가, 실적 발표, 스타트업 자금 조달."),
        ("건강", "의료/신체/영양/정신 건강/질병. 예: 장내 미생물, 수면, 백신. ※AI의 할루시네이션은 건강이 아니라 기술."),
        ("디자인", "UI/UX/그래픽/제품 디자인/건축 디자인. 예: Figma, 타이포그래피."),
        ("학술", "연구/논문/학문 분야/교육/이론. 예: 수학, 물리학, PMBOK, 학회."),
        ("예술", "예술/음악/회화/문학/창작. 예: 현대 미술, 소설."),
        ("뉴스", "시사/정치/사건/사회 전반. 예: 선거, 법 개정, 재해."),
        ("스포츠", "경기/선수/팀/시합. 예: 축구, 오타니 쇼헤이. ※스포츠 선수가 아닌 인물은 스포츠로 분류하지 않는다."),
        ("엔터테인먼트", "영화/TV/게임/연예/오락. 예: 영화 작품, 스트리밍 서비스."),
        ("기타", "위 어디에도 명확히 해당하지 않는 것. 판단하기 어려운 인명・조직명・일반어 (남성/기업/사용자 등) 는 여기로 분류."),
    ]

    private static let koFirstPassTieBreakers = """
        - 명확한 기술 용어 (AI / 인공지능 / 머신러닝 / LLM / 생성형 AI / 프로그래밍 / 클라우드) 는 망설이지 말고 기술 (반례: "AI의 할루시네이션"은 건강이 아니라 기술)
        - 질병 / 영양 / 수면 / 정신 건강 / 의료 는 망설이지 말고 건강 (반례: "의료 AI"의 AI는 기술)
        - 주가 / 실적 / 자금 조달 / 마케팅 / 경영 은 망설이지 말고 경제
        - 경기 / 선수 / 시합 / 팀 은 망설이지 말고 스포츠 (반례: 스포츠와 무관한 인물은 스포츠로 분류하지 않는다)
        - 정치 / 사건 / 재해 / 법 개정 은 망설이지 말고 뉴스
        """

    // MARK: - es (Español)

    private static let esSeeds: [Category] = [
        Category(name: "Tecnología",     englishName: "Technology",    order: 0, symbolName: "cpu"),
        Category(name: "Economía",       englishName: "Economy",       order: 1, symbolName: "chart.line.uptrend.xyaxis"),
        Category(name: "Salud",          englishName: "Health",        order: 2, symbolName: "heart"),
        Category(name: "Diseño",         englishName: "Design",        order: 3, symbolName: "paintbrush"),
        Category(name: "Academia",       englishName: "Academic",      order: 4, symbolName: "book"),
        Category(name: "Arte",           englishName: "Art",           order: 5, symbolName: "paintpalette"),
        Category(name: "Noticias",       englishName: "News",          order: 6, symbolName: "newspaper"),
        Category(name: "Deportes",       englishName: "Sports",        order: 7, symbolName: "figure.run"),
        Category(name: "Entretenimiento", englishName: "Entertainment", order: 8, symbolName: "tv"),
        Category(name: "Otros",          englishName: "Other",         order: 9, symbolName: "ellipsis.circle"),
    ]

    private static let esSeedDefinitions: [(name: String, definition: String)] = [
        ("Tecnología", "IA/programación/software/gadgets/TI en general. Ejemplos: Claude, RAG, embedding, GitHub, alucinación, inteligencia artificial, aprendizaje automático, LLM, IA generativa. Nota: IA, inteligencia artificial, aprendizaje automático y LLM siempre van en Tecnología."),
        ("Economía", "Negocios/finanzas/mercados/gestión empresarial/marketing. Ejemplos: precio de acciones, resultados financieros, financiación de startups."),
        ("Salud", "Medicina/el cuerpo/nutrición/salud mental/enfermedad. Ejemplos: microbioma intestinal, sueño, vacunas. Nota: la alucinación de la IA pertenece a Tecnología, no a Salud."),
        ("Diseño", "UI/UX/diseño gráfico/diseño de producto/diseño arquitectónico. Ejemplos: Figma, tipografía."),
        ("Academia", "Investigación/artículos/campos académicos/educación/teoría. Ejemplos: matemáticas, física, PMBOK, congresos académicos."),
        ("Arte", "Bellas artes/música/pintura/literatura/creación. Ejemplos: arte contemporáneo, novelas."),
        ("Noticias", "Actualidad/política/sucesos/sociedad en general. Ejemplos: elecciones, reformas legales, desastres."),
        ("Deportes", "Competiciones/atletas/equipos/partidos. Ejemplos: fútbol, Shohei Ohtani. Nota: las personas no relacionadas con el deporte no deben clasificarse en Deportes."),
        ("Entretenimiento", "Películas/TV/videojuegos/famosos/ocio. Ejemplos: películas, servicios de streaming."),
        ("Otros", "Cualquier cosa que no encaje claramente en las categorías anteriores. Los nombres ambiguos de personas/organizaciones y los términos genéricos (p. ej. \"hombre\", \"empresa\", \"usuario\") van aquí."),
    ]

    private static let esFirstPassTieBreakers = """
        - Los términos técnicos claros (IA / inteligencia artificial / aprendizaje automático / LLM / IA generativa / programación / computación en la nube) siempre van en Tecnología (contraejemplo: "alucinación de la IA" es Tecnología, no Salud)
        - Enfermedad / nutrición / sueño / salud mental / medicina siempre van en Salud (contraejemplo: la IA en "IA médica" es Tecnología)
        - Precio de acciones / resultados financieros / financiación / marketing / gestión siempre van en Economía
        - Competiciones / atletas / partidos / equipos siempre van en Deportes (contraejemplo: las personas no relacionadas con el deporte no van en Deportes)
        - Política / sucesos / desastres / reformas legales siempre van en Noticias
        """

    // MARK: - de (Deutsch)

    private static let deSeeds: [Category] = [
        Category(name: "Technologie",  englishName: "Technology",    order: 0, symbolName: "cpu"),
        Category(name: "Wirtschaft",   englishName: "Economy",       order: 1, symbolName: "chart.line.uptrend.xyaxis"),
        Category(name: "Gesundheit",   englishName: "Health",        order: 2, symbolName: "heart"),
        Category(name: "Design",       englishName: "Design",        order: 3, symbolName: "paintbrush"),
        Category(name: "Wissenschaft", englishName: "Academic",      order: 4, symbolName: "book"),
        Category(name: "Kunst",        englishName: "Art",           order: 5, symbolName: "paintpalette"),
        Category(name: "Nachrichten",  englishName: "News",          order: 6, symbolName: "newspaper"),
        Category(name: "Sport",        englishName: "Sports",        order: 7, symbolName: "figure.run"),
        Category(name: "Unterhaltung", englishName: "Entertainment", order: 8, symbolName: "tv"),
        Category(name: "Sonstiges",    englishName: "Other",         order: 9, symbolName: "ellipsis.circle"),
    ]

    private static let deSeedDefinitions: [(name: String, definition: String)] = [
        ("Technologie", "KI/Programmierung/Software/Gadgets/IT im Allgemeinen. Beispiele: Claude, RAG, Embedding, GitHub, Halluzination, künstliche Intelligenz, maschinelles Lernen, LLM, generative KI. Hinweis: KI, künstliche Intelligenz, maschinelles Lernen und LLM gehören immer zu Technologie."),
        ("Wirtschaft", "Geschäft/Finanzen/Märkte/Unternehmensführung/Marketing. Beispiele: Aktienkurse, Geschäftsberichte, Startup-Finanzierung."),
        ("Gesundheit", "Medizin/Körper/Ernährung/psychische Gesundheit/Krankheit. Beispiele: Darmmikrobiom, Schlaf, Impfstoffe. Hinweis: KI-Halluzinationen gehören zu Technologie, nicht zu Gesundheit."),
        ("Design", "UI/UX/Grafikdesign/Produktdesign/Architekturdesign. Beispiele: Figma, Typografie."),
        ("Wissenschaft", "Forschung/Fachartikel/Wissenschaftsbereiche/Bildung/Theorie. Beispiele: Mathematik, Physik, PMBOK, wissenschaftliche Konferenzen."),
        ("Kunst", "Bildende Kunst/Musik/Malerei/Literatur/kreatives Schaffen. Beispiele: zeitgenössische Kunst, Romane."),
        ("Nachrichten", "Aktuelles/Politik/Ereignisse/Gesellschaft im Allgemeinen. Beispiele: Wahlen, Gesetzesreformen, Katastrophen."),
        ("Sport", "Wettkämpfe/Athleten/Teams/Spiele. Beispiele: Fußball, Shohei Ohtani. Hinweis: Personen ohne Sportbezug gehören nicht zu Sport."),
        ("Unterhaltung", "Filme/TV/Spiele/Prominente/Freizeit. Beispiele: Filme, Streaming-Dienste."),
        ("Sonstiges", "Alles, was nicht eindeutig in die obigen Kategorien passt. Mehrdeutige Namen von Personen/Organisationen und allgemeine Begriffe (z. B. „Mann“, „Unternehmen“, „Nutzer“) gehören hierher."),
    ]

    private static let deFirstPassTieBreakers = """
        - Eindeutige Fachbegriffe (KI / künstliche Intelligenz / maschinelles Lernen / LLM / generative KI / Programmierung / Cloud Computing) gehören immer zu Technologie (Gegenbeispiel: „KI-Halluzination“ ist Technologie, nicht Gesundheit)
        - Krankheit / Ernährung / Schlaf / psychische Gesundheit / Medizin gehören immer zu Gesundheit (Gegenbeispiel: die KI in „medizinische KI“ ist Technologie)
        - Aktienkurse / Geschäftsberichte / Finanzierung / Marketing / Unternehmensführung gehören immer zu Wirtschaft
        - Wettkämpfe / Athleten / Spiele / Teams gehören immer zu Sport (Gegenbeispiel: Personen ohne Sportbezug gehören nicht zu Sport)
        - Politik / Ereignisse / Katastrophen / Gesetzesreformen gehören immer zu Nachrichten
        """
}
