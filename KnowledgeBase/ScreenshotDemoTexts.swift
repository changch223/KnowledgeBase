//
//  ScreenshotDemoTexts.swift
//  KnowledgeBase
//
//  ScreenshotDemo のロケール別テキスト (DEBUG 限定)。
//  記事 10 件 (AI 4 / 睡眠 2 / 家計 2 / 家ごはん 2)、トピック 6 件 (生成AI > 2 子 + 3)、タグ 5、チャット 1。
//  実在の企業名・人物・発言は使わない (一般的な話題のみ)。
//

#if DEBUG
import Foundation

struct DemoText {
    let titles: [String]          // 10
    let essences: [String]        // 10
    let a0Facts: [String]         // 3
    let a0Body: [String]          // 3 paragraphs
    let topicNames: [String]      // 6: 親 / 子A / 子B / 睡眠 / 家計 / 家ごはん
    let topicSummaries: [String]  // 6
    let topicInsights: [[String]] // 6 (3-4 件)
    let tags: [String]            // 5: AI / 仕事術 / 睡眠 / 家計 / 料理
    let question: String
    let answer: String            // {A} {B} = 引用マーカー位置
}

enum DemoTexts {
    static func text(for language: PipelineLanguage) -> DemoText {
        switch language {
        case .ja: return ja
        case .en: return en
        case .zhHans: return zhHans
        case .zhHant: return zhHant
        case .ko: return ko
        case .es: return es
        case .de: return de
        }
    }

    // MARK: - ja

    static let ja = DemoText(
        titles: [
            "AIに伝わる質問の書き方：目的・前提・形式を先に置く",
            "プロンプトに例を1つ添えると、回答が安定する理由",
            "会議メモをAIで要約する：失敗しない3つの手順",
            "AIを使った調べ物の時間を半分にする習慣",
            "寝る90分前の入浴が、眠りを深くする",
            "睡眠不足は「週末の寝だめ」では取り戻しにくい",
            "固定費の見直しから始める、無理のない家計管理",
            "つみたて投資の基本：続けやすい金額の決め方",
            "週末30分の作り置きで、平日の夕食がラクになる",
            "減塩でも物足りなくならない、うま味の使い方",
        ],
        essences: [
            "AIには、目的・前提・求める形式の順で伝えると意図がずれにくい。",
            "例を1つ添えるだけで、出力の形式や口調が安定する。",
            "要点・決定事項・宿題の3つに分けて頼むと、要約が使いやすくなる。",
            "検索の前にAIで論点を整理すると、調べ直しが減る。",
            "就寝90分前の入浴は体温の下がり方を助け、寝つきと深い眠りにつながる。",
            "睡眠不足は週末の寝だめでは戻りにくく、毎日の規則性が大切。",
            "家計は固定費から見直すと、我慢せずに支出を減らしやすい。",
            "つみたて投資は、生活に無理のない金額で長く続けることが基本。",
            "週末に下ごしらえをまとめると、平日の調理時間を大きく減らせる。",
            "昆布やきのこのうま味を使うと、塩を減らしても満足感が保てる。",
        ],
        a0Facts: [
            "質問は「目的→前提→形式」の順に書く",
            "あいまいな指示は、条件を足すと精度が上がる",
            "長い依頼は、箇条書きで分けて伝える",
        ],
        a0Body: [
            "AIに質問するとき、最初に書くべきなのは「何のために知りたいのか」という目的です。目的が分かると、AIは回答の方向を絞りやすくなります。",
            "次に、前提を添えます。読み手が初心者なのか専門家なのか、使える時間はどれくらいか。こうした条件があるだけで、回答の深さが変わります。",
            "最後に、欲しい形式を指定します。「3つの箇条書きで」「200字以内で」など、形を先に決めておくと、読み返す手間が減ります。",
        ],
        topicNames: ["生成AI", "プロンプトの工夫", "AIで仕事を効率化", "睡眠と休養", "家計と投資", "家ごはん"],
        topicSummaries: [
            "文章や画像を作り出すAIの総称。使い方次第で、調べ物や仕事の進め方が大きく変わる。",
            "AIに意図を正しく伝えるための書き方。目的・前提・形式を示し、例を添えるのが基本。",
            "会議メモの要約や調べ物の整理など、日々の作業にAIを組み込む方法。",
            "入浴や生活リズムなど、毎日の睡眠の質を上げる工夫。",
            "固定費の見直しと、無理のないつみたて投資で家計を整える考え方。",
            "作り置きと減塩の工夫で、平日の食事を無理なく整える。",
        ],
        topicInsights: [
            ["質問は目的・前提・形式の順に伝えると、意図がずれにくい", "例を1つ添えるだけで、出力の形式や口調が安定する", "要約や整理は、項目を分けて頼むと使いやすい", "AIの答えは下書きとして使い、最後は自分で確認する"],
            ["目的を最初に書くと、回答の方向が定まる", "出してほしい形（箇条書き・字数）を先に決める", "例を1つ添えると、形式がそろう"],
            ["会議メモは「要点・決定事項・宿題」に分けて要約させる", "調べ物は、検索の前にAIで論点を整理する", "毎回の手順をテンプレート化すると時間が減る"],
            ["就寝90分前の入浴が、寝つきと深い眠りを助ける", "週末の寝だめより、毎日の就寝・起床時刻をそろえる", "寝る前の強い光は、眠気を遅らせる"],
            ["まず固定費（通信・保険・サブスク）から見直す", "つみたては、生活に無理のない金額で続ける", "家計簿は、細かさより続けやすさを優先する"],
            ["週末30分の下ごしらえで、平日の調理が短くなる", "昆布・きのこのうま味で、減塩でも満足感が出る", "冷凍できる作り置きを中心に組み立てる"],
        ],
        tags: ["AI", "仕事術", "睡眠", "家計", "料理"],
        question: "AIにうまく質問するコツは？",
        answer: "目的・前提・求める形式の順に伝えると、意図がずれにくくなります{A}。さらに例を1つ添えると、出力の形式や口調が安定します{B}。"
    )

    // MARK: - en

    static let en = DemoText(
        titles: [
            "How to ask AI better: put the goal, context and format first",
            "Why adding one example makes AI answers more consistent",
            "Summarizing meeting notes with AI: three steps that work",
            "A habit that halves your research time with AI",
            "A bath 90 minutes before bed helps you sleep deeper",
            "Weekend catch-up sleep doesn't fully repay a sleep debt",
            "Start with fixed costs for a household budget that lasts",
            "Recurring investing basics: pick an amount you can keep up",
            "30 minutes of weekend meal prep makes weeknight dinners easy",
            "Cooking with less salt without losing flavor: use umami",
        ],
        essences: [
            "Telling AI your goal, context and desired format, in that order, keeps answers on target.",
            "Adding a single example makes the format and tone of the output steadier.",
            "Asking for key points, decisions and to-dos separately makes summaries more useful.",
            "Outlining the questions with AI before searching cuts down on repeat research.",
            "A bath 90 minutes before bed helps body temperature drop, easing you into deeper sleep.",
            "Lost sleep is hard to recover on weekends; a regular daily rhythm matters more.",
            "Reviewing fixed costs first lets you cut spending without feeling deprived.",
            "Recurring investing works best with an amount that fits your life, kept up for years.",
            "Batching prep on the weekend cuts weeknight cooking time a lot.",
            "Umami from kelp and mushrooms keeps meals satisfying even with less salt.",
        ],
        a0Facts: [
            "Write questions in the order: goal, context, format",
            "Vague requests get sharper when you add conditions",
            "Break long requests into a bulleted list",
        ],
        a0Body: [
            "When you ask AI a question, the first thing to write is why you want to know. Once the goal is clear, the AI can narrow down the direction of its answer.",
            "Next, add context. Is the reader a beginner or an expert? How much time is available? Conditions like these change how deep the answer goes.",
            "Finally, specify the format you want. Deciding the shape up front, such as three bullet points or under 200 words, saves you from rereading and rewriting.",
        ],
        topicNames: ["Generative AI", "Better prompts", "AI for everyday work", "Sleep and rest", "Budget and investing", "Home cooking"],
        topicSummaries: [
            "AI that creates text and images. How you use it changes how you research and work.",
            "Ways of writing so AI gets your intent: state the goal, context and format, and add an example.",
            "Ways to fold AI into daily tasks, from summarizing meeting notes to organizing research.",
            "Everyday habits, from baths to routines, that improve the quality of your sleep.",
            "Putting a household budget in order with fixed-cost reviews and steady, modest investing.",
            "Easing weeknight meals with batch prep and lower-salt cooking.",
        ],
        topicInsights: [
            ["Goal, context, then format keeps your intent from drifting", "One example steadies the format and tone of the output", "Ask for summaries in separate parts so they are easier to use", "Treat AI answers as drafts and check the final result yourself"],
            ["Writing the goal first sets the direction of the answer", "Decide the shape you want (bullets, length) up front", "One example makes the format consistent"],
            ["Have meeting notes summarized as key points, decisions and to-dos", "Outline the questions with AI before you search", "Turn your usual steps into a template to save time"],
            ["A bath 90 minutes before bed eases you into deeper sleep", "Keep bed and wake times regular instead of catching up on weekends", "Bright light before bed delays sleepiness"],
            ["Start by reviewing fixed costs: phone, insurance, subscriptions", "Keep recurring investing to an amount that fits your life", "Favor a budget you can keep over one that is detailed"],
            ["30 minutes of prep on the weekend shortens weeknight cooking", "Umami from kelp and mushrooms keeps low-salt meals satisfying", "Build around make-ahead dishes that freeze well"],
        ],
        tags: ["AI", "Productivity", "Sleep", "Budget", "Cooking"],
        question: "What's the best way to ask AI good questions?",
        answer: "Tell it your goal, context and the format you want, in that order, and the answer stays on target{A}. Adding a single example also keeps the format and tone steady{B}."
    )

    // MARK: - zh-Hans

    static let zhHans = DemoText(
        titles: [
            "如何向AI提问：先说明目的、背景和格式",
            "为什么在提示词里加一个示例，回答会更稳定",
            "用AI总结会议记录：不会出错的三个步骤",
            "让AI查资料的时间减半的小习惯",
            "睡前90分钟泡澡，睡得更深",
            "睡眠不足，周末补觉并不能完全补回来",
            "从固定支出入手，轻松管好家庭开支",
            "定投理财入门：如何确定可以长期坚持的金额",
            "周末花30分钟备菜，工作日晚餐更轻松",
            "少盐也不寡淡：善用鲜味",
        ],
        essences: [
            "按目的、背景、格式的顺序告诉AI，回答不容易跑偏。",
            "只要加一个示例，输出的格式和语气就会更稳定。",
            "把要点、决定事项和待办分开请AI总结，结果更好用。",
            "搜索之前先让AI梳理论点，可以减少重复查资料。",
            "睡前90分钟泡澡有助于体温下降，更容易入睡并进入深睡。",
            "睡眠不足很难靠周末补觉弥补，每天规律作息才重要。",
            "先从固定支出开始检视，不用忍耐也能减少开支。",
            "定投的关键是选择生活无负担的金额，并长期坚持。",
            "周末集中备菜，可以大幅缩短工作日的做饭时间。",
            "利用海带和蘑菇的鲜味，减盐后仍然有满足感。",
        ],
        a0Facts: [
            "提问按「目的→背景→格式」的顺序写",
            "含糊的指示补充条件后会更准确",
            "较长的请求用条目分开说明",
        ],
        a0Body: [
            "向AI提问时，首先要写的是「为什么想知道」这个目的。目的明确后，AI更容易缩小回答的方向。",
            "接着补充背景。读者是初学者还是专家？可用的时间有多少？仅仅这些条件，就会改变回答的深度。",
            "最后指定想要的格式。比如「用三条要点」「200字以内」，先定好形式，可以省去反复阅读的麻烦。",
        ],
        topicNames: ["生成式AI", "提示词技巧", "用AI提升工作效率", "睡眠与休息", "家庭开支与理财", "家常饭"],
        topicSummaries: [
            "能生成文字和图像的AI的统称。用法不同，查资料和工作方式也会大不相同。",
            "让AI准确理解意图的写法：说明目的、背景和格式，并附上示例。",
            "把AI融入日常工作的方法，例如总结会议记录、整理资料。",
            "从泡澡到作息规律，提升每天睡眠质量的小办法。",
            "通过检视固定支出和无负担的定投，把家庭开支理顺。",
            "通过备菜和减盐的小技巧，轻松安排工作日的饮食。",
        ],
        topicInsights: [
            ["按目的、背景、格式的顺序提问，意图不容易偏离", "加一个示例，输出的格式和语气就会稳定", "总结和整理时分项请求，结果更好用", "把AI的回答当作草稿，最后自己确认"],
            ["先写目的，回答的方向就确定了", "先决定想要的形式（条目、字数）", "加一个示例，格式就会统一"],
            ["让AI把会议记录总结成「要点、决定事项、待办」", "查资料前先让AI梳理论点", "把固定步骤做成模板，可以节省时间"],
            ["睡前90分钟泡澡，有助于入睡和深睡", "比起周末补觉，更重要的是每天固定入睡和起床时间", "睡前的强光会推迟困意"],
            ["先从固定支出（通信、保险、订阅）检视", "定投选择生活无负担的金额坚持下去", "记账比起详细，更要优先考虑能否坚持"],
            ["周末30分钟备菜，工作日做饭更快", "用海带和蘑菇的鲜味，减盐也有满足感", "以可冷冻的备餐为主来安排"],
        ],
        tags: ["AI", "工作方法", "睡眠", "家庭开支", "烹饪"],
        question: "怎样才能向AI提出好问题？",
        answer: "按目的、背景、想要的格式的顺序告诉AI，回答就不容易跑偏{A}。再加上一个示例，输出的格式和语气会更稳定{B}。"
    )

    // MARK: - zh-Hant

    static let zhHant = DemoText(
        titles: [
            "如何向AI提問：先說明目的、背景與格式",
            "為什麼在提示詞中加入一個範例，回答會更穩定",
            "用AI整理會議記錄：不會出錯的三個步驟",
            "讓AI查資料時間減半的小習慣",
            "睡前90分鐘泡澡，睡得更深",
            "睡眠不足，週末補眠並無法完全補回來",
            "從固定支出著手，輕鬆管好家庭開銷",
            "定期定額投資入門：如何決定能長期堅持的金額",
            "週末花30分鐘備菜，平日晚餐更輕鬆",
            "少鹽也不乏味：善用鮮味",
        ],
        essences: [
            "依目的、背景、格式的順序告訴AI，回答不容易偏離。",
            "只要加入一個範例，輸出的格式與語氣就會更穩定。",
            "將重點、決議事項與待辦分開請AI整理，結果更好用。",
            "搜尋之前先讓AI釐清論點，可以減少重複查資料。",
            "睡前90分鐘泡澡有助於體溫下降，更容易入睡並進入深層睡眠。",
            "睡眠不足很難靠週末補眠彌補，每天規律作息才重要。",
            "先從固定支出開始檢視，不必忍耐也能減少開銷。",
            "定期定額投資的關鍵是選擇生活無負擔的金額，並長期堅持。",
            "週末集中備菜，可以大幅縮短平日的煮飯時間。",
            "運用昆布與香菇的鮮味，減鹽後仍有滿足感。",
        ],
        a0Facts: [
            "提問依「目的→背景→格式」的順序寫",
            "含糊的指示補上條件後會更準確",
            "較長的請求用條列分開說明",
        ],
        a0Body: [
            "向AI提問時，首先要寫的是「為什麼想知道」這個目的。目的明確後，AI更容易縮小回答的方向。",
            "接著補充背景。讀者是初學者還是專家？可用的時間有多少？光是這些條件，就會改變回答的深度。",
            "最後指定想要的格式。例如「用三點條列」「200字以內」，先決定形式，可以省去反覆閱讀的麻煩。",
        ],
        topicNames: ["生成式AI", "提示詞技巧", "用AI提升工作效率", "睡眠與休息", "家庭開銷與理財", "家常菜"],
        topicSummaries: [
            "能生成文字與圖像的AI的統稱。用法不同，查資料與工作方式也會大不相同。",
            "讓AI準確理解意圖的寫法：說明目的、背景與格式，並附上範例。",
            "把AI融入日常工作的方法，例如整理會議記錄、歸納資料。",
            "從泡澡到作息規律，提升每天睡眠品質的小方法。",
            "透過檢視固定支出與無負擔的定期定額投資，把家庭開銷理順。",
            "透過備菜與減鹽的小技巧，輕鬆安排平日的飲食。",
        ],
        topicInsights: [
            ["依目的、背景、格式的順序提問，意圖不容易偏離", "加入一個範例，輸出的格式與語氣就會穩定", "整理與歸納時分項請求，結果更好用", "把AI的回答當作草稿，最後自己確認"],
            ["先寫目的，回答的方向就確定了", "先決定想要的形式（條列、字數）", "加入一個範例，格式就會一致"],
            ["讓AI把會議記錄整理成「重點、決議事項、待辦」", "查資料前先讓AI釐清論點", "把固定步驟做成範本，可以節省時間"],
            ["睡前90分鐘泡澡，有助於入睡與深層睡眠", "比起週末補眠，更重要的是每天固定就寢與起床時間", "睡前的強光會延後睏意"],
            ["先從固定支出（通訊、保險、訂閱）檢視", "定期定額選擇生活無負擔的金額持續下去", "記帳比起詳細，更要優先考慮能否堅持"],
            ["週末30分鐘備菜，平日煮飯更快", "用昆布與香菇的鮮味，減鹽也有滿足感", "以可冷凍的備餐為主來安排"],
        ],
        tags: ["AI", "工作方法", "睡眠", "家庭開銷", "料理"],
        question: "怎樣才能向AI提出好問題？",
        answer: "依目的、背景、想要的格式的順序告訴AI，回答就不容易偏離{A}。再加上一個範例，輸出的格式與語氣會更穩定{B}。"
    )

    // MARK: - ko

    static let ko = DemoText(
        titles: [
            "AI에게 잘 묻는 법: 목적, 배경, 형식을 먼저 쓰기",
            "프롬프트에 예시를 하나 더하면 답변이 안정되는 이유",
            "회의 메모를 AI로 요약하기: 실패하지 않는 3단계",
            "AI로 조사 시간을 절반으로 줄이는 습관",
            "잠들기 90분 전 목욕이 숙면을 돕는다",
            "수면 부족은 주말 몰아 자기로 채우기 어렵다",
            "고정비 점검부터 시작하는 무리 없는 가계 관리",
            "적립식 투자의 기본: 꾸준히 할 수 있는 금액 정하기",
            "주말 30분 밑반찬 준비로 평일 저녁이 편해진다",
            "싱겁지 않게 줄이는 소금: 감칠맛 활용법",
        ],
        essences: [
            "목적, 배경, 원하는 형식 순으로 알려 주면 AI의 답이 의도에서 벗어나지 않는다.",
            "예시를 하나만 더해도 출력의 형식과 말투가 안정된다.",
            "요점, 결정 사항, 할 일로 나눠 요청하면 요약이 훨씬 쓸모 있다.",
            "검색 전에 AI로 논점을 정리하면 다시 찾아보는 일이 줄어든다.",
            "잠들기 90분 전 목욕은 체온이 내려가는 것을 도와 숙면으로 이어진다.",
            "부족한 잠은 주말에 몰아 자도 회복하기 어렵고, 매일의 규칙성이 중요하다.",
            "가계는 고정비부터 점검하면 참지 않고도 지출을 줄이기 쉽다.",
            "적립식 투자는 생활에 무리가 없는 금액을 오래 이어 가는 것이 기본이다.",
            "주말에 밑준비를 모아 두면 평일 조리 시간이 크게 줄어든다.",
            "다시마와 버섯의 감칠맛을 쓰면 소금을 줄여도 만족감이 유지된다.",
        ],
        a0Facts: [
            "질문은 「목적→배경→형식」 순으로 쓴다",
            "애매한 지시는 조건을 더하면 정확해진다",
            "긴 요청은 글머리 기호로 나눠 전달한다",
        ],
        a0Body: [
            "AI에게 질문할 때 가장 먼저 쓸 것은 「무엇을 위해 알고 싶은가」라는 목적입니다. 목적이 분명하면 AI가 답변의 방향을 좁히기 쉬워집니다.",
            "다음으로 배경을 덧붙입니다. 읽는 사람이 초보자인지 전문가인지, 쓸 수 있는 시간은 얼마나 되는지. 이런 조건만으로도 답변의 깊이가 달라집니다.",
            "마지막으로 원하는 형식을 지정합니다. 「세 가지 글머리 기호로」 「200자 이내로」처럼 형태를 먼저 정해 두면 다시 읽는 수고가 줄어듭니다.",
        ],
        topicNames: ["생성형 AI", "프롬프트 요령", "AI로 일 효율 높이기", "수면과 휴식", "가계와 투자", "집밥"],
        topicSummaries: [
            "글과 이미지를 만들어 내는 AI의 총칭. 쓰는 방법에 따라 조사와 업무 방식이 크게 달라진다.",
            "AI에게 의도를 정확히 전하는 글쓰기. 목적, 배경, 형식을 밝히고 예시를 더하는 것이 기본.",
            "회의 메모 요약이나 조사 정리 등 일상 업무에 AI를 녹여 넣는 방법.",
            "목욕과 생활 리듬 등 매일의 수면의 질을 높이는 방법.",
            "고정비 점검과 무리 없는 적립식 투자로 가계를 다듬는 생각.",
            "밑반찬과 저염 요령으로 평일 식사를 무리 없이 챙긴다.",
        ],
        topicInsights: [
            ["목적, 배경, 형식 순으로 전하면 의도가 어긋나지 않는다", "예시를 하나만 더해도 출력의 형식과 말투가 안정된다", "요약과 정리는 항목을 나눠 요청하면 쓰기 좋다", "AI의 답은 초안으로 쓰고 마지막은 직접 확인한다"],
            ["목적을 먼저 쓰면 답변의 방향이 정해진다", "원하는 형태(글머리 기호, 글자 수)를 먼저 정한다", "예시를 하나 더하면 형식이 맞춰진다"],
            ["회의 메모는 「요점, 결정 사항, 할 일」로 나눠 요약시킨다", "조사는 검색 전에 AI로 논점을 정리한다", "매번 하는 절차를 템플릿으로 만들면 시간이 줄어든다"],
            ["잠들기 90분 전 목욕이 잠들기와 숙면을 돕는다", "주말 몰아 자기보다 매일 취침·기상 시각을 맞춘다", "자기 전의 강한 빛은 졸음을 늦춘다"],
            ["먼저 고정비(통신·보험·구독)부터 점검한다", "적립식은 생활에 무리 없는 금액으로 이어 간다", "가계부는 꼼꼼함보다 지속 가능성을 우선한다"],
            ["주말 30분 밑준비로 평일 조리가 짧아진다", "다시마·버섯의 감칠맛으로 저염식도 만족스럽다", "냉동할 수 있는 밑반찬을 중심으로 짠다"],
        ],
        tags: ["AI", "업무 요령", "수면", "가계", "요리"],
        question: "AI에게 질문을 잘하는 요령은?",
        answer: "목적, 배경, 원하는 형식 순으로 알려 주면 답변이 의도에서 벗어나지 않습니다{A}. 예시를 하나 더하면 출력의 형식과 말투도 안정됩니다{B}."
    )

    // MARK: - es

    static let es = DemoText(
        titles: [
            "Cómo preguntar mejor a la IA: primero objetivo, contexto y formato",
            "Por qué un solo ejemplo hace más estables las respuestas de la IA",
            "Resumir notas de reuniones con IA: tres pasos que funcionan",
            "Un hábito que reduce a la mitad el tiempo de investigar con IA",
            "Un baño 90 minutos antes de dormir profundiza el sueño",
            "Recuperar el sueño perdido el fin de semana no basta",
            "Empieza por los gastos fijos para un presupuesto sostenible",
            "Inversión periódica: elige una cantidad que puedas mantener",
            "30 minutos de preparación el fin de semana facilitan las cenas",
            "Cocinar con menos sal sin perder sabor: usa el umami",
        ],
        essences: [
            "Si le indicas a la IA objetivo, contexto y formato, en ese orden, sus respuestas se ajustan mejor.",
            "Con solo añadir un ejemplo, el formato y el tono de la respuesta son más estables.",
            "Pedir por separado puntos clave, decisiones y tareas hace los resúmenes más útiles.",
            "Ordenar las preguntas con la IA antes de buscar reduce las búsquedas repetidas.",
            "Un baño 90 minutos antes de dormir ayuda a bajar la temperatura corporal y a dormir más profundo.",
            "El sueño perdido cuesta recuperarlo en el fin de semana; importa más la regularidad diaria.",
            "Revisar primero los gastos fijos permite gastar menos sin sentirse privado.",
            "La inversión periódica funciona mejor con una cantidad cómoda mantenida durante años.",
            "Preparar todo junto el fin de semana reduce mucho el tiempo de cocina entre semana.",
            "El umami del alga kombu y los champiñones mantiene la comida sabrosa con menos sal.",
        ],
        a0Facts: [
            "Escribe la pregunta en este orden: objetivo, contexto, formato",
            "Las peticiones vagas mejoran al añadir condiciones",
            "Divide las peticiones largas en una lista",
        ],
        a0Body: [
            "Al preguntar a la IA, lo primero que debes escribir es para qué quieres saberlo. Con el objetivo claro, la IA puede acotar mejor la dirección de su respuesta.",
            "Después, añade el contexto. ¿El lector es principiante o experto? ¿De cuánto tiempo dispones? Solo con estas condiciones cambia la profundidad de la respuesta.",
            "Por último, indica el formato que quieres. Decidir la forma de antemano, por ejemplo tres viñetas o menos de 200 palabras, evita releer y reescribir.",
        ],
        topicNames: ["IA generativa", "Mejores prompts", "IA para el trabajo diario", "Sueño y descanso", "Presupuesto e inversión", "Cocina casera"],
        topicSummaries: [
            "IA que crea texto e imágenes. Según cómo la uses, cambia tu forma de investigar y trabajar.",
            "Formas de escribir para que la IA entienda tu intención: objetivo, contexto, formato y un ejemplo.",
            "Cómo integrar la IA en tareas diarias, desde resumir reuniones hasta ordenar investigaciones.",
            "Hábitos diarios, del baño a las rutinas, que mejoran la calidad del sueño.",
            "Ordenar el presupuesto familiar revisando gastos fijos e invirtiendo con constancia.",
            "Facilitar las comidas entre semana con preparación previa y menos sal.",
        ],
        topicInsights: [
            ["Objetivo, contexto y formato, en ese orden, evitan que se pierda la intención", "Un solo ejemplo estabiliza el formato y el tono de la respuesta", "Pide los resúmenes por partes para que resulten más útiles", "Trata las respuestas de la IA como borradores y revisa tú el resultado"],
            ["Escribir primero el objetivo marca la dirección de la respuesta", "Decide de antemano la forma (viñetas, longitud)", "Un ejemplo hace que el formato sea coherente"],
            ["Pide que las notas de reunión se resuman en puntos clave, decisiones y tareas", "Ordena las preguntas con la IA antes de buscar", "Convierte tus pasos habituales en una plantilla para ahorrar tiempo"],
            ["Un baño 90 minutos antes de dormir ayuda a dormir más profundo", "Mantén horarios regulares en lugar de recuperar el fin de semana", "La luz intensa antes de dormir retrasa el sueño"],
            ["Empieza revisando los gastos fijos: móvil, seguros, suscripciones", "Mantén la inversión periódica en una cantidad cómoda", "Prefiere un presupuesto que puedas sostener a uno muy detallado"],
            ["30 minutos de preparación el fin de semana acortan la cocina diaria", "El umami del kombu y los champiñones satisface con menos sal", "Organiza todo en torno a platos que se pueden congelar"],
        ],
        tags: ["IA", "Productividad", "Sueño", "Presupuesto", "Cocina"],
        question: "¿Cuál es la mejor forma de hacer buenas preguntas a la IA?",
        answer: "Indica el objetivo, el contexto y el formato que quieres, en ese orden, y la respuesta se ajustará mejor{A}. Añadir un solo ejemplo también estabiliza el formato y el tono{B}."
    )

    // MARK: - de

    static let de = DemoText(
        titles: [
            "Besser fragen: Ziel, Kontext und Format zuerst nennen",
            "Warum ein einziges Beispiel KI-Antworten stabiler macht",
            "Besprechungsnotizen mit KI zusammenfassen: drei Schritte",
            "Eine Gewohnheit, die die Recherchezeit mit KI halbiert",
            "Ein Bad 90 Minuten vor dem Schlafen vertieft den Schlaf",
            "Schlafmangel lässt sich am Wochenende kaum aufholen",
            "Mit den Fixkosten beginnen: Haushaltsplanung, die hält",
            "Sparplan-Grundlagen: einen durchhaltbaren Betrag wählen",
            "30 Minuten Vorkochen am Wochenende erleichtern die Abende",
            "Weniger Salz, trotzdem Geschmack: Umami nutzen",
        ],
        essences: [
            "Wer der KI Ziel, Kontext und Format in dieser Reihenfolge nennt, bekommt treffendere Antworten.",
            "Schon ein einziges Beispiel macht Format und Tonfall der Antwort stabiler.",
            "Wichtige Punkte, Beschlüsse und Aufgaben getrennt anzufordern, macht Zusammenfassungen nützlicher.",
            "Wer vor der Suche die Fragen mit KI ordnet, muss seltener neu recherchieren.",
            "Ein Bad 90 Minuten vor dem Schlafen unterstützt das Absinken der Körpertemperatur und vertieft den Schlaf.",
            "Verlorener Schlaf lässt sich am Wochenende schwer aufholen; ein regelmäßiger Rhythmus zählt mehr.",
            "Wer zuerst die Fixkosten prüft, kann ohne Verzicht Ausgaben senken.",
            "Ein Sparplan funktioniert am besten mit einem Betrag, der zum Leben passt und lange durchgehalten wird.",
            "Wer am Wochenende gebündelt vorbereitet, spart unter der Woche viel Kochzeit.",
            "Umami aus Kombu und Pilzen hält Gerichte auch mit weniger Salz befriedigend.",
        ],
        a0Facts: [
            "Fragen in der Reihenfolge Ziel, Kontext, Format schreiben",
            "Vage Anfragen werden mit Bedingungen präziser",
            "Lange Anfragen in einer Aufzählung gliedern",
        ],
        a0Body: [
            "Wenn Sie einer KI eine Frage stellen, schreiben Sie zuerst, wozu Sie etwas wissen möchten. Ist das Ziel klar, kann die KI die Richtung ihrer Antwort leichter eingrenzen.",
            "Danach ergänzen Sie den Kontext. Ist der Leser Anfänger oder Experte? Wie viel Zeit steht zur Verfügung? Schon solche Angaben verändern die Tiefe der Antwort.",
            "Zuletzt legen Sie das gewünschte Format fest. Wer die Form vorab bestimmt, etwa drei Stichpunkte oder unter 200 Wörter, spart sich erneutes Lesen und Umschreiben.",
        ],
        topicNames: ["Generative KI", "Bessere Prompts", "KI im Arbeitsalltag", "Schlaf und Erholung", "Haushalt und Geldanlage", "Hausmannskost"],
        topicSummaries: [
            "KI, die Texte und Bilder erzeugt. Je nach Nutzung verändert sie Recherche und Arbeitsweise.",
            "Schreibweisen, damit die KI Ihre Absicht versteht: Ziel, Kontext und Format nennen und ein Beispiel beifügen.",
            "Wege, KI in tägliche Aufgaben einzubauen, von Besprechungsnotizen bis zur Recherche.",
            "Alltagsgewohnheiten, vom Bad bis zur Routine, die die Schlafqualität verbessern.",
            "Den Haushalt ordnen durch Fixkostenprüfung und einen gleichmäßigen, maßvollen Sparplan.",
            "Mahlzeiten unter der Woche mit Vorkochen und weniger Salz erleichtern.",
        ],
        topicInsights: [
            ["Ziel, Kontext, Format in dieser Reihenfolge verhindern, dass die Absicht abdriftet", "Ein einziges Beispiel stabilisiert Format und Tonfall der Antwort", "Zusammenfassungen in Teilen anfordern, dann sind sie besser nutzbar", "KI-Antworten als Entwurf nehmen und das Ergebnis selbst prüfen"],
            ["Das Ziel zuerst zu schreiben legt die Richtung der Antwort fest", "Die gewünschte Form (Stichpunkte, Länge) vorab festlegen", "Ein Beispiel macht das Format einheitlich"],
            ["Besprechungsnotizen als Kernpunkte, Beschlüsse und Aufgaben zusammenfassen lassen", "Vor der Suche die Fragen mit KI ordnen", "Wiederkehrende Schritte als Vorlage anlegen spart Zeit"],
            ["Ein Bad 90 Minuten vor dem Schlafen unterstützt tiefen Schlaf", "Feste Schlaf- und Aufstehzeiten sind besser als Aufholen am Wochenende", "Helles Licht vor dem Schlafen verzögert die Müdigkeit"],
            ["Zuerst die Fixkosten prüfen: Mobilfunk, Versicherungen, Abos", "Den Sparplan auf einen Betrag setzen, der zum Leben passt", "Ein durchhaltbares Haushaltsbuch ist besser als ein detailliertes"],
            ["30 Minuten Vorbereiten am Wochenende verkürzen das Kochen unter der Woche", "Umami aus Kombu und Pilzen macht auch salzarme Gerichte sättigend", "Auf einfrierbare Gerichte zum Vorkochen setzen"],
        ],
        tags: ["KI", "Arbeitsweise", "Schlaf", "Haushalt", "Kochen"],
        question: "Wie stelle ich der KI am besten gute Fragen?",
        answer: "Nennen Sie Ziel, Kontext und gewünschtes Format in dieser Reihenfolge, dann bleibt die Antwort treffend{A}. Ein einziges Beispiel macht Format und Tonfall zusätzlich stabiler{B}."
    )
}
#endif
