# App Store Connect メタデータ 一括コピペ表 — v1.1（7 ロケール）

対象バージョン: **1.1** / build **2**

出典: `docs/app-store/RELEASE-MATERIALS.md` §1-J（zh-Hans / zh-Hant / en）・
§1-K（ko / es / de）・§1-L（ja リブランド版、名前・サブタイトル・プロモ・キーワード・説明文冒頭）・
§1-M（What's New 最終版、7 ロケール）。値はすべて出典からの転記であり、本ファイルでの創作・修正は行っていない。

> **注意**: **ja ロケールのみ**アプリ名が「まとメモ」（旧 Knowledge Base からのリブランド）。
> 他 6 ロケール（en / zh-Hans / zh-Hant / ko / es / de）は引き続き "Knowledge Base" 系の名前のまま。

審査メモ（App Review Information > Notes）は本ファイルの対象外。`RELEASE-MATERIALS.md` §1-L L-8
（§1-J J-5 の審査メモ本体に追記する日英併記の 1 文）を参照。

ロケール順序: ja → en → zh-Hans → zh-Hant → ko → es → de。各ロケール 6 フィールド
（名前 / サブタイトル / プロモーションテキスト / 概要 / このバージョンの最新情報 / キーワード）を
コードブロックでそのままコピペできる形にしてある。文字数は各コードブロック直後に
「(実測 N / 上限 M)」で併記（python3 の `len()` で実測）。

---

## 日本語 (ja)

出典: L-1〜L-5 + M-1
　/　**アプリ名は「まとメモ」（他ロケールと異なる）**

### 1. 名前

```
まとメモ：AIが読んだ記事を自動まとめ
```
(実測 19 / 上限 30)

### 2. サブタイトル

```
あとで読むを、第二の脳に
```
(実測 12 / 上限 30)

### 3. プロモーションテキスト

```
「あとで読む」で終わっていませんか？保存するだけで、あなたのiPhoneのAIがあなた専用の百科事典にまとめ続けます。要点は一目、深掘りはチャットで根拠付きに。処理はすべて端末内で完結、データは外に出ません。
```
(実測 104 / 上限 170)

### 4. 概要

```
■ 「あとで読む」で、終わらせない。

保存した記事、読み返せていますか？ためるだけで満足していませんか？
まとメモは、保存した記事を AI が裏側で自動的に整理し、あなただけの百科事典に育て続けるアプリです。
「あとで読む」を、ちゃんと「知識」に変えていきましょう。

■ どこからでも、ひと手間で保存

・Safari やアプリの共有シートから、記事をそのまま保存
・＋ボタンで URL・テキスト・PDF・写真（文字認識）・音声（文字起こし）も取り込み
・英語や中国語のコンテンツは、自動で日本語に翻訳して整理

保存はすぐ完了。重い処理はすべて裏側で進むので、あなたを待たせません。

■ AI が、テーマごとに要点をまとめる

複数の記事をまたいで、AI が「概念ページ（あなた専用の Wiki）」を自動で生成・更新します。
「ナレッジ」タブを開けば、テーマごとの要点まとめが常に最新の状態で並んでいます。
・最重要ポイントが、クリック不要で先に読める
・関連する概念どうしが自動でリンクし、知識がつながっていく
・どのページも、必ず元の記事にさかのぼって確認できる

■ あなたの知識に、根拠付きで答えるチャット

「あの記事、何て書いてあったっけ？」に、AI チャットが答えます。
・回答はあなたが保存した記事だけを根拠に生成
・引用番号をタップすれば、元記事にすぐ移動
・一般知識で補うときは、はっきり明示

■ AI の間違いは、ひとことで直せる

・記事詳細の「訂正」から自然言語で指示するだけ（例:「Claude Code を誤認識しています」）
・要らない概念やタグは、いつでも編集・統合・非表示に
最終的な主導権は、いつもあなたの手に。

■ プライバシーは、設計の中心

・AI 処理は Apple Intelligence によりすべて端末内で完結
・広告なし・トラッキングなし・外部サーバーへの送信ゼロ
・iCloud 同期はあなたのプライベートデータベースのみ

■ 日本語ファースト、和の佇まい

明朝体の見出しと墨色、青海波の余白。開くたびに静かで心地よい、日本語のために作られた画面です。

■ 動作環境（重要）

・AI 機能（概念ページの自動生成・AI チャット・要約・翻訳・自動タグ）には、Apple Intelligence が利用できる iPhone が必要です
・お使いの iPhone の設定で Apple Intelligence を有効にしてご利用ください
・Apple Intelligence が利用できない環境でも、記事の保存・検索・閲覧・タグ整理はご利用いただけます

さあ、あなたの iPhone の AI を最大限に活かして、読んだものを「自分だけの知識」に変えていきましょう。
```
(実測 1173 / 上限 4000)

### 5. このバージョンの最新情報

```
まとメモ（旧 Knowledge Base）v1.1 をリリースしました。
・日本語・简体中文・繁體中文・English・한국어・Español・Deutschの7言語に対応。UIもAIが生成する要約・概念ページ・チャット回答も、選んだ言語で
・Apple Intelligenceが使えないときは、理由と対処法をバナーでお知らせ
・端末の言語設定と生成言語がズレているときも、バナーでお知らせ
・AIが使えるようになったら、止まっていた整理を自動で再開
・アプリ名が「まとメモ」になりました
ご意見・不具合はGitHub Issuesまでお寄せください。
```
(実測 278 / 上限 4000)

### 6. キーワード

```
あとで読む,記事保存,AI要約,まとめ,ノート,クリップ,スクラップ,知識整理,ブックマーク,オフライン,ウィキ,百科事典,PKM,翻訳,学習
```
(実測 71 / 上限 100)

---

## English (en-US)

出典: J-3 + M-4

### 1. 名前

```
Knowledge Base: Second Brain
```
(実測 28 / 上限 30)

### 2. サブタイトル

```
AI grows your second brain
```
(実測 26 / 上限 30)

### 3. プロモーションテキスト

```
Stop reading and forgetting. Save an article and AI keeps weaving it into your own evolving encyclopedia — key points up front, answers with citations, all on-device.
```
(実測 166 / 上限 170)

### 4. 概要

```
■ Knowledge that grows on its own

Just save the articles you find interesting — AI quietly compiles them into your own encyclopedia in the background.
Knowledge Base is the gentle second brain that helps you graduate from "read once, forget forever."

■ Save from anywhere, in one step

- Save articles directly from Safari or any app's Share Sheet
- The + button also lets you add URLs, text, PDFs, photos (OCR), and audio (transcription)
- Non-English or non-Japanese content is automatically translated into your chosen language before it's organized

Saving finishes instantly — the heavy lifting happens in the background, so you're never kept waiting.

■ AI organizes key points by topic

AI automatically creates and updates "concept pages" — your own personal wiki — across multiple articles.
Open the Knowledge tab and topic summaries are always shown up to date.
- The most important points come first, no tapping required
- Related concepts link to each other automatically, so your knowledge connects
- Every page can always be traced back to its original article

■ Chat that answers with citations

"What did that article actually say again?" Ask the AI Chat.
- Answers are generated only from the articles you've saved
- Tap a citation number to jump straight to the source article
- When general knowledge is used to fill a gap, it's always labeled clearly

■ Fix AI's mistakes in one sentence

- Tap "Correct" on any article's detail page and describe the fix in plain language (e.g. "Claude Code is being misread as something else")
- Unwanted concepts or tags can be edited, merged, or hidden anytime
You always stay in control.

■ Privacy by design

- All AI processing runs entirely on-device via Apple Intelligence
- No ads, no tracking, zero data sent to external servers
- iCloud sync uses only your own private database

■ A calm, considered aesthetic

A palette of sumi ink and washi paper, elegant Mincho headlines, and breathing negative space inspired by seigaiha waves. Every time you open it, it feels quiet and refined.

■ Languages

Knowledge Base supports 4 interface languages: English, Japanese, Simplified Chinese, and Traditional Chinese. AI-generated summaries, concept pages, and chat replies follow the same language, chosen automatically from your device's language on first launch (you can change it anytime in Settings > Generation Language).

■ Requirements (important)

- AI features (automatic concept-page generation, AI Chat, summaries, translation, auto-tagging) require an iPhone that supports Apple Intelligence
- Please turn on Apple Intelligence in Settings before use
- Even without Apple Intelligence, you can still save, search, browse, and organize tags for your articles

Now, put your iPhone's AI to full use and turn everything you read into knowledge that's truly your own.
```
(実測 2836 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base v1.1 is here.
・Now supports 7 languages: Japanese, Simplified Chinese, Traditional Chinese, English, Korean, Spanish, and German. Both the UI and AI-generated summaries, concept pages, and chat replies follow your chosen language
・A banner now explains why and how to fix it when Apple Intelligence isn't available
・A banner also lets you know if your device language and generation language don't match
・When AI becomes available again, any paused organizing automatically resumes
Feedback and bug reports are welcome via GitHub Issues.
```
(実測 552 / 上限 4000)

### 6. キーワード

```
note,AI,knowledge,bookmark,read later,summary,wiki,PKM,offline,save article,on-device,translate
```
(実測 95 / 上限 100)

---

## 简体中文 (zh-Hans)

出典: J-1 + M-2

### 1. 名前

```
Knowledge Base：AI第二大脑
```
(実測 21 / 上限 30)

### 2. サブタイトル

```
iPhone的AI，养出你的第二大脑
```
(実測 18 / 上限 30)

### 3. プロモーションテキスト

```
读完就忘？不再需要。只需保存文章，AI 就会持续为你编纂专属百科全书。要点一目了然，深入了解就问 AI 聊天，回答有据可查。充分释放 iPhone 内置 AI（Apple Intelligence）的能力，所有处理都在设备本机完成，数据绝不外传。
```
(実測 123 / 上限 170)

### 4. 概要

```
■ 读过的知识，自动生长

只需保存你感兴趣的文章，剩下的交给 AI——它会在背后持续为你编纂专属的百科全书。
Knowledge Base 是让你从「读完就忘」毕业的、温柔的第二大脑。

■ 随时随地，轻松保存

・从 Safari 或任意 App 的共享面板，直接保存文章
・点击「+」还可以导入 URL・文字・PDF・照片（文字识别）・语音（语音转文字）
・英文、日文等外语内容会自动翻译成中文后再整理

保存立即完成。繁重的处理都在背后进行，不会让你等待。

■ AI 按主题为你梳理要点

AI 会跨越多篇文章，自动生成并更新「概念页面（专属于你的 Wiki）」。
打开「知识」标签页，按主题整理的要点摘要会始终保持最新。
・最重要的要点，无需点击即可先看到
・相关概念会自动互相链接，让知识彼此串联
・每个页面都能一路追溯回原始文章

■ 有据可查地回答你的问题

「那篇文章到底写了什么来着？」交给 AI 聊天来回答你。
・回答只依据你保存的文章生成
・点按引用编号即可立即跳转到原文章
・需要补充一般常识时，会明确标示

■ AI 的错误，一句话就能更正

・在文章详情的「更正」按钮中，用自然语言下达指示即可（例如：「Claude Code 被误认成了别的名字」）
・不需要的概念或标签，随时可以编辑、合并、隐藏
最终的主导权，永远握在你手中。

■ 隐私，是设计的核心

・AI 处理全部由 Apple Intelligence 在设备本机完成
・无广告、无跟踪、零外部服务器数据传输
・iCloud 同步仅使用你自己的私有数据库

■ 日式静谧美学

墨与和纸交织的配色，明朝体标题，青海波留白的呼吸感。每次打开，都是一次静谧优雅的阅读体验。

■ 支持的语言

Knowledge Base 支持简体中文、繁體中文、日文、English 4 种界面语言。AI 生成的摘要、概念页面、聊天回答也会使用相同的语言，并在首次启动时根据设备语言自动选择（之后可在「设置 > 生成语言」中随时更改）。

■ 使用环境（重要）

・AI 功能（概念页面自动生成・AI 聊天・摘要・翻译・自动标签）需要支持 Apple Intelligence 的 iPhone
・请在「设置」中开启 Apple Intelligence 后使用
・即使 Apple Intelligence 不可用，你仍然可以保存、搜索、浏览文章与整理标签

现在，就让你 iPhone 内的 AI 全力发挥，把读过的一切变成「专属于你的知识」吧。
```
(実測 1064 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base v1.1 发布了。
・现已支持日文、简体中文、繁體中文、英文、韩文、西班牙文、德文共 7 种语言。界面与 AI 生成的摘要、概念页面、聊天回答都会使用你选择的语言
・Apple Intelligence 无法使用时，会用提示条告知原因与解决方法
・设备语言与生成语言不一致时，也会用提示条提醒你
・AI 恢复可用后，被中断的整理会自动继续
欢迎通过 GitHub Issues 提出意见与问题反馈。
```
(実測 214 / 上限 4000)

### 6. キーワード

```
笔记,备忘录,AI,知识管理,书签,稍后阅读,摘要,百科全书,Wiki,PKM,学习,整理,离线,保存文章,AI聊天,翻译,知识库
```
(実測 65 / 上限 100)

---

## 繁體中文 (zh-Hant)

出典: J-2 + M-3

### 1. 名前

```
Knowledge Base：AI第二大腦
```
(実測 21 / 上限 30)

### 2. サブタイトル

```
iPhone的AI，養出你的第二大腦
```
(実測 18 / 上限 30)

### 3. プロモーションテキスト

```
讀完就忘？不再需要。只需儲存文章，AI 就會持續為你編纂專屬百科全書。要點一目了然，深入了解就問 AI 聊天，回答有憑有據。充分釋放 iPhone 內建 AI（Apple Intelligence）的能力，所有處理都在裝置本機完成，資料絕不外流。
```
(実測 123 / 上限 170)

### 4. 概要

```
■ 讀過的知識，自動生長

只需儲存你感興趣的文章，剩下的交給 AI——它會在背後持續為你編纂專屬的百科全書。
Knowledge Base 是讓你從「讀完就忘」畢業的、溫柔的第二大腦。

■ 隨時隨地，輕鬆儲存

・從 Safari 或任何 App 的共享面板，直接儲存文章
・點擊「+」還能匯入 URL・文字・PDF・照片（文字辨識）・語音（語音轉文字）
・英文、日文等外語內容會自動翻譯成中文後再整理

儲存立即完成。繁重的處理都在背後進行，不會讓你等待。

■ AI 依主題為你梳理要點

AI 會跨越多篇文章，自動產生並更新「概念頁面（專屬於你的 Wiki）」。
開啟「知識」分頁，依主題整理的要點摘要會始終保持最新。
・最重要的要點，不必點擊即可率先看到
・相關概念會自動互相連結，讓知識彼此串連
・每個頁面都能一路追溯回原始文章

■ 有憑有據回答你的問題

「那篇文章到底寫了什麼來著？」交給 AI 聊天來回答你。
・回答僅依據你儲存的文章產生
・點按引用編號即可立即跳轉到原文章
・需要補充一般常識時，會明確標示

■ AI 的錯誤，一句話就能更正

・在文章詳情的「更正」按鈕中，用自然語言下達指示即可（例如：「Claude Code 被誤認成了別的名字」）
・不需要的概念或標籤，隨時可以編輯、合併、隱藏
最終的主導權，永遠握在你手中。

■ 隱私，是設計的核心

・AI 處理全部由 Apple Intelligence 在裝置本機完成
・無廣告、無追蹤、零外部伺服器資料傳輸
・iCloud 同步僅使用你自己的私有資料庫

■ 日式靜謐美學

墨與和紙交織的色調，明朝體標題，青海波留白的呼吸感。每次開啟，都是一次靜謐優雅的閱讀體驗。

■ 支援的語言

Knowledge Base 支援繁體中文、簡體中文、日文、English 4 種介面語言。AI 產生的摘要、概念頁面、聊天回答也會使用相同的語言，並在首次啟動時依裝置語言自動選擇（之後可在「設定 > 產生語言」中隨時變更）。

■ 使用環境（重要）

・AI 功能（概念頁面自動產生・AI 聊天・摘要・翻譯・自動標籤）需要支援 Apple Intelligence 的 iPhone
・請在「設定」中開啟 Apple Intelligence 後使用
・即使 Apple Intelligence 無法使用，你仍然可以儲存、搜尋、瀏覽文章與整理標籤

現在，就讓你 iPhone 內的 AI 全力發揮，把讀過的一切變成「專屬於你的知識」吧。
```
(実測 1062 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base v1.1 發布了。
・現已支援日文、簡體中文、繁體中文、英文、韓文、西班牙文、德文共 7 種語言。介面與 AI 產生的摘要、概念頁面、聊天回答都會使用你選擇的語言
・Apple Intelligence 無法使用時，會用提示條告知原因與解決方法
・裝置語言與產生語言不一致時，也會用提示條提醒你
・AI 復原可用後，被中斷的整理會自動繼續
歡迎透過 GitHub Issues 提出意見與問題回報。
```
(実測 214 / 上限 4000)

### 6. キーワード

```
筆記,備忘錄,AI,知識管理,書籤,稍後閱讀,摘要,百科全書,Wiki,PKM,學習,整理,離線,儲存文章,AI聊天,翻譯,知識庫
```
(実測 65 / 上限 100)

---

## 한국어 (ko)

出典: K-1 + M-5

### 1. 名前

```
Knowledge Base: AI 두 번째 뇌
```
(実測 25 / 上限 30)

### 2. サブタイトル

```
iPhone의 AI가 키우는 제2의 뇌
```
(実測 21 / 上限 30)

### 3. プロモーションテキスト

```
읽고 잊어버리는 습관과는 이제 안녕. 저장만 하면 AI가 당신만의 백과사전을 계속 편집합니다. 요점은 한눈에, 깊이 알고 싶을 땐 채팅으로 근거와 함께. iPhone에 탑재된 AI(Apple Intelligence)의 힘을 최대한 활용하며, 모든 처리는 기기 안에서 끝나 데이터는 외부로 나가지 않습니다.
```
(実測 170 / 上限 170)

### 4. 概要

```
■ 읽은 지식이, 저절로 자랍니다

관심 있는 기사를 저장하기만 하면 됩니다. 나머지는 AI가 뒤에서 당신만의 백과사전을 계속 편집합니다.
Knowledge Base는 「읽고 잊어버리는 습관」을 졸업하게 해주는, 다정한 제2의 뇌입니다.

■ 어디서든, 한 번의 동작으로 저장

・Safari나 다른 앱의 공유 시트에서 기사를 그대로 저장
・+ 버튼으로 URL・텍스트・PDF・사진(문자 인식)・음성(텍스트 변환)도 가져올 수 있습니다
・설정한 언어가 아닌 콘텐츠는 자동으로 번역되어 정리됩니다

저장은 즉시 완료됩니다. 무거운 처리는 모두 뒤에서 진행되므로 기다릴 필요가 없습니다.

■ AI가 주제별로 요점을 정리합니다

여러 기사를 아울러, AI가 「개념 페이지(당신만의 Wiki)」를 자동으로 생성・업데이트합니다.
「지식」탭을 열면 주제별 요점 정리가 항상 최신 상태로 나열되어 있습니다.
・가장 중요한 포인트는 탭하지 않아도 먼저 읽을 수 있습니다
・관련 개념끼리 자동으로 연결되어 지식이 이어집니다
・모든 페이지는 반드시 원본 기사로 거슬러 올라가 확인할 수 있습니다

■ 근거와 함께 답하는 AI 채팅

「그 기사에 뭐라고 쓰여 있었더라?」 AI 채팅이 답합니다.
・답변은 당신이 저장한 기사만을 근거로 생성됩니다
・인용 번호를 탭하면 바로 원본 기사로 이동합니다
・일반 지식으로 보충할 때는 명확히 표시됩니다

■ AI의 실수는 한마디로 고칠 수 있습니다

・기사 상세 화면의 「수정」 버튼에서 자연어로 지시하기만 하면 됩니다(예: 「Claude Code를 다른 이름으로 잘못 인식했어요」)
・필요 없는 개념이나 태그는 언제든 편집・통합・숨기기가 가능합니다
최종 결정권은 언제나 당신에게 있습니다.

■ 프라이버시는 설계의 중심입니다

・AI 처리는 모두 Apple Intelligence를 통해 기기 안에서 완결됩니다
・광고 없음・추적 없음・외부 서버로의 전송 없음
・iCloud 동기화는 당신의 개인 데이터베이스만 사용합니다

■ 일본풍의 고요한 아름다움

먹빛과 화지가 어우러진 색감, 명조체 표제, 세이가이하 문양이 만들어내는 여백의 호흡. 열 때마다 고요하고 우아한 독서 경험을 선사합니다.

■ 지원 언어

Knowledge Base는 한국어・日本語・简体中文・繁體中文・English・Español・Deutsch 총 7개 언어의 인터페이스를 지원합니다. AI가 생성하는 요약・개념 페이지・채팅 답변도 같은 언어를 사용하며, 최초 실행 시 기기 언어에 따라 자동으로 선택됩니다(이후 「설정 > 생성 언어」에서 언제든 변경할 수 있습니다).

■ 사용 환경(중요)

・AI 기능(개념 페이지 자동 생성・AI 채팅・요약・번역・자동 태그)에는 Apple Intelligence를 지원하는 iPhone이 필요합니다
・「설정」에서 Apple Intelligence를 켠 후 이용해 주세요
・Apple Intelligence를 사용할 수 없는 환경에서도 기사 저장・검색・열람・태그 정리는 이용하실 수 있습니다

이제, 당신의 iPhone에 담긴 AI를 최대한 활용해 읽은 모든 것을 「나만의 지식」으로 바꿔보세요.
```
(実測 1524 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base v1.1을 출시했습니다.
・일본어・简体中文・繁體中文・English・한국어・Español・Deutsch 총 7개 언어를 지원합니다. UI는 물론 AI가 생성하는 요약・개념 페이지・채팅 답변도 선택한 언어로 제공됩니다
・Apple Intelligence를 사용할 수 없을 때는 이유와 해결 방법을 배너로 안내합니다
・기기 언어와 생성 언어가 다를 때도 배너로 알려드립니다
・AI를 다시 사용할 수 있게 되면, 중단되었던 정리 작업이 자동으로 재개됩니다
의견이나 문제는 GitHub Issues로 알려주세요.
```
(実測 296 / 上限 4000)

### 6. キーワード

```
노트,메모,AI,지식관리,북마크,나중에읽기,요약,위키,백과사전,PKM,학습,정리,오프라인,기사저장,AI채팅,번역,지식
```
(実測 65 / 上限 100)

---

## Español (es)

出典: K-2 + M-6

### 1. 名前

```
Knowledge Base: IA 2º Cerebro
```
(実測 29 / 上限 30)

### 2. サブタイトル

```
IA de tu iPhone, tu 2º cerebro
```
(実測 30 / 上限 30)

### 3. プロモーションテキスト

```
Deja de leer y olvidar. Guarda un artículo y la IA arma tu enciclopedia. Puntos clave al instante, respuestas citadas en el chat. Todo en tu iPhone, sin salir de él.
```
(実測 165 / 上限 170)

### 4. 概要

```
■ El conocimiento que lees crece por sí solo

Basta con guardar los artículos que te interesan. El resto se lo dejas a la IA, que teje en segundo plano tu propia enciclopedia.
Knowledge Base es el segundo cerebro que te ayuda a dejar de «leer y olvidar».

■ Guarda desde cualquier lugar, en un solo paso

・Guarda artículos directamente desde Safari o la hoja de compartir de cualquier app
・El botón + también permite añadir URL, texto, PDF, fotos (reconocimiento de texto) y audio (transcripción)
・El contenido en un idioma distinto al elegido se traduce automáticamente antes de organizarse

Guardar es instantáneo. El trabajo pesado ocurre en segundo plano, así que nunca tienes que esperar.

■ La IA organiza los puntos clave por tema

La IA crea y actualiza automáticamente «páginas de concepto» (tu propia wiki) a partir de varios artículos.
Abre la pestaña Conocimiento y encontrarás resúmenes por tema siempre actualizados.
・Los puntos más importantes aparecen primero, sin necesidad de tocar nada
・Los conceptos relacionados se enlazan automáticamente, conectando tu conocimiento
・Cada página siempre puede rastrearse hasta el artículo original

■ Un chat que responde con pruebas

«¿Qué decía exactamente ese artículo?» Pregúntaselo al chat de IA.
・Las respuestas se generan solo a partir de los artículos que has guardado
・Toca el número de cita para ir directo al artículo original
・Cuando se usa conocimiento general para completar la respuesta, se indica claramente

■ Corrige los errores de la IA con una frase

・Toca «Corregir» en la página de detalle del artículo y describe el error en lenguaje natural (p. ej.: «Claude Code se reconoce mal como otro nombre»)
・Los conceptos o etiquetas que no necesites se pueden editar, combinar u ocultar en cualquier momento
El control final siempre está en tus manos.

■ La privacidad, en el centro del diseño

・Todo el procesamiento de IA ocurre en el dispositivo gracias a Apple Intelligence
・Sin anuncios, sin rastreo, cero datos enviados a servidores externos
・La sincronización con iCloud usa solo tu base de datos privada

■ Una estética japonesa serena

Una paleta de tinta sumi y papel washi, títulos en elegante Mincho y el respiro del patrón seigaiha en el espacio negativo. Cada vez que la abres, es una experiencia de lectura serena y refinada.

■ Idiomas compatibles

Knowledge Base admite 7 idiomas de interfaz: español, 日本語, 简体中文, 繁體中文, English, 한국어 y Deutsch. Los resúmenes, páginas de concepto y respuestas del chat generados por la IA siguen el mismo idioma, elegido automáticamente según el idioma del dispositivo en el primer inicio (puedes cambiarlo cuando quieras en Ajustes > Idioma de generación).

■ Requisitos (importante)

・Las funciones de IA (generación automática de páginas de concepto, chat de IA, resúmenes, traducción, etiquetado automático) requieren un iPhone compatible con Apple Intelligence
・Activa Apple Intelligence en Ajustes antes de usarlas
・Aunque Apple Intelligence no esté disponible, puedes seguir guardando, buscando, explorando artículos y organizando etiquetas

Ahora, aprovecha al máximo la IA de tu iPhone y convierte todo lo que lees en un conocimiento verdaderamente tuyo.
```
(実測 3182 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base v1.1 ya está disponible.
・Ahora con 7 idiomas: japonés, chino simplificado, chino tradicional, inglés, coreano, español y alemán. Los resúmenes, páginas de concepto y respuestas del chat generados por IA también siguen el idioma elegido
・Cuando Apple Intelligence no está disponible, un aviso explica el motivo y cómo solucionarlo
・Un aviso también te avisa si el idioma del dispositivo y el idioma de generación no coinciden
・Cuando la IA vuelve a estar disponible, el trabajo de organización pendiente se reanuda automáticamente
Tus comentarios y reportes de errores son bienvenidos a través de GitHub Issues.
```
(実測 626 / 上限 4000)

### 6. キーワード

```
nota,IA,conocimiento,marcador,resumen,wiki,PKM,offline,artículo,chat,traducir,enciclopedia
```
(実測 90 / 上限 100)

---

## Deutsch (de)

出典: K-3 + M-7

### 1. 名前

```
Knowledge Base: KI, 2. Gehirn
```
(実測 29 / 上限 30)

### 2. サブタイトル

```
iPhone-KI formt Ihr 2. Gehirn
```
(実測 29 / 上限 30)

### 3. プロモーションテキスト

```
Schluss mit Lesen und Vergessen. Speichern genügt – die KI baut Ihre Enzyklopädie. Kernpunkte sofort, Antworten mit Quellen im Chat. Alles läuft auf Ihrem iPhone.
```
(実測 162 / 上限 170)

### 4. 概要

```
■ Wissen, das von selbst wächst

Sichern Sie einfach die Artikel, die Sie interessieren. Den Rest übernimmt die KI und webt sie im Hintergrund zu Ihrer eigenen Enzyklopädie zusammen.
Knowledge Base ist das sanfte zweite Gehirn, das Ihnen hilft, dem „Lesen und Vergessen" zu entkommen.

■ Von überall sichern, in einem Schritt

・Sichern Sie Artikel direkt aus Safari oder dem Teilen-Menü jeder App
・Über die Plus-Schaltfläche können Sie auch URLs, Text, PDFs, Fotos (Texterkennung) und Audio (Transkription) hinzufügen
・Inhalte in einer anderen als Ihrer gewählten Sprache werden automatisch übersetzt, bevor sie organisiert werden

Das Sichern ist sofort abgeschlossen. Die aufwendige Verarbeitung läuft im Hintergrund, sodass Sie nie warten müssen.

■ Die KI ordnet Kernpunkte nach Thema

Die KI erstellt und aktualisiert automatisch „Konzeptseiten" (Ihr persönliches Wiki) über mehrere Artikel hinweg.
Öffnen Sie den Tab Wissen, und Sie finden immer aktuelle, nach Thema geordnete Zusammenfassungen.
・Die wichtigsten Punkte erscheinen zuerst, ganz ohne Tippen
・Verwandte Konzepte verknüpfen sich automatisch, sodass Ihr Wissen zusammenwächst
・Jede Seite lässt sich stets bis zum Originalartikel zurückverfolgen

■ Ein Chat, der mit Belegen antwortet

„Was stand noch mal in diesem Artikel?" Fragen Sie den KI-Chat.
・Antworten entstehen ausschließlich aus Ihren gesicherten Artikeln
・Tippen Sie auf eine Zitatnummer, um direkt zum Quellartikel zu springen
・Wird zur Ergänzung Allgemeinwissen verwendet, wird das klar gekennzeichnet

■ KI-Fehler mit einem Satz korrigieren

・Tippen Sie auf „Korrigieren" auf der Artikeldetailseite und beschreiben Sie die Korrektur in einfachen Worten (z. B. „Claude Code wird fälschlicherweise als anderer Name erkannt")
・Unnötige Konzepte oder Tags können Sie jederzeit bearbeiten, zusammenführen oder ausblenden
Die letzte Entscheidung liegt immer bei Ihnen.

■ Datenschutz im Zentrum des Designs

・Die gesamte KI-Verarbeitung läuft vollständig auf dem Gerät über Apple Intelligence
・Keine Werbung, kein Tracking, keine Datenübertragung an externe Server
・Die iCloud-Synchronisierung nutzt ausschließlich Ihre private Datenbank

■ Eine ruhige, japanisch geprägte Ästhetik

Eine Palette aus Sumi-Tinte und Washi-Papier, elegante Mincho-Überschriften und der ruhige Atem des Seigaiha-Musters im Weißraum. Jedes Öffnen fühlt sich still und stilvoll an.

■ Sprachen

Knowledge Base unterstützt 7 Oberflächensprachen: Deutsch, 日本語, 简体中文, 繁體中文, English, 한국어 und Español. Von der KI erzeugte Zusammenfassungen, Konzeptseiten und Chat-Antworten folgen derselben Sprache, die beim ersten Start automatisch anhand der Gerätesprache gewählt wird (später jederzeit änderbar unter Einstellungen > Generierungssprache).

■ Voraussetzungen (wichtig)

・Die KI-Funktionen (automatische Konzeptseiten, KI-Chat, Zusammenfassungen, Übersetzung, automatische Tags) benötigen ein iPhone mit Apple-Intelligence-Unterstützung
・Bitte aktivieren Sie Apple Intelligence in den Einstellungen, bevor Sie diese Funktionen nutzen
・Auch ohne Apple Intelligence können Sie weiterhin Artikel sichern, suchen, durchsuchen und Tags organisieren

Nutzen Sie jetzt die KI Ihres iPhones voll aus und verwandeln Sie alles, was Sie lesen, in Wissen, das wirklich Ihnen gehört.
```
(実測 3271 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base v1.1 ist da.
・Jetzt mit 7 Sprachen: Japanisch, vereinfachtes Chinesisch, traditionelles Chinesisch, Englisch, Koreanisch, Spanisch und Deutsch. Auch die von der KI erzeugten Zusammenfassungen, Konzeptseiten und Chat-Antworten folgen der gewählten Sprache
・Wenn Apple Intelligence nicht verfügbar ist, erklärt ein Banner den Grund und die Lösung
・Ein Banner informiert Sie auch, wenn Gerätesprache und Generierungssprache nicht übereinstimmen
・Sobald die KI wieder verfügbar ist, wird unterbrochene Organisation automatisch fortgesetzt
Feedback und Fehlermeldungen sind über GitHub Issues willkommen.
```
(実測 614 / 上限 4000)

### 6. キーワード

```
notiz,KI,wissen,lesezeichen,zusammenfassung,wiki,PKM,offline,artikel,chat,übersetzen,enzyklopädie
```
(実測 97 / 上限 100)

---
