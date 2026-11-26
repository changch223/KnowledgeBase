# App Store Connect メタデータ 一括コピペ表 — v2.0（7 ロケール）

対象バージョン: **2.0** / build **4**（`MARKETING_VERSION = 2.0` / `CURRENT_PROJECT_VERSION = 4`、全 target 設定済み）

前提: App Store で公開中なのは **v1.0（日本語のみ）**。v1.1 は提出せず、その内容をすべて含めて 2.0 として出す。
したがって「このバージョンの最新情報」は **v1.0 からの差分**で書いてある（7 言語対応・画面刷新・直読み等）。

v1.1 版（`APP-STORE-METADATA-v1.1.md`）からの主な修正:
- 用語を現在のアプリ表示に合わせた: 概念ページ → **トピック** / AI チャット → **「検索」タブで AI に聞く** /
  記事詳細の「訂正」→ **「本文の表現を見直す」**
- 生成言語が日本語以外のとき、記事を翻訳せず原文のまま読む（spec 106）ことを反映
- en 説明文の「4 interface languages」→ 7 言語に修正

ロケール順序: ja → en → zh-Hans → zh-Hant → ko → es → de。文字数は python3 `len()` の実測。

---

## 共通（ロケール非依存）

| フィールド | 値 |
|---|---|
| バージョン | `2.0` |
| 著作権 | `© 2026 Chia-Wei Chang` |
| サポート URL | `https://github.com/changch223/KnowledgeBase/blob/main/docs/support.md` |
| マーケティング URL | `https://note.com/wayne_chang/n/n8a47122ebe63` |
| プライバシーポリシー URL | `https://github.com/changch223/KnowledgeBase/blob/main/docs/privacy-policy.md` |
| ユーザプライバシー選択 URL | 空欄（任意。トラッキング・データ収集がないため不要） |
| App のプライバシー（データの収集） | 「データを収集していません」のまま（v1.0 と同じ。`PrivacyInfo.xcprivacy` とも一致） |
| 暗号化の申告 | 不要（`ITSAppUsesNonExemptEncryption = false` を Info.plist に設定済み） |

---

## 日本語 (ja)

### 1. 名前

```
まとメモ：AIが読んだ記事を自動まとめ
```
(実測 19 / 上限 30)

### 2. サブタイトル

```
読んだ知識を、AIが自動で整理・蓄積、そしてAI自身を育てる
```
(実測 30 / 上限 30)

> 注意: 「AI 自身を育てる」は、アプリが AI モデルを学習・更新するようにも読める（実際は端末の Apple Intelligence を
> 使うだけで、モデル自体は変わらない）。誤解を避けたい場合は前半だけの `読んだ知識を、AIが自動で整理・蓄積`
> （17 字）も使える。

### 3. プロモーションテキスト

```
「あとで読む」で終わっていませんか？保存するだけで、あなたのiPhoneのAIがあなた専用の百科事典にまとめ続けます。要点は一目、深掘りはAIに聞けば根拠付きで。処理はすべて端末内で完結、データは外に出ません。
```
(実測 105 / 上限 170)

### 4. 概要

```
■ 「あとで読む」で、終わらせない。

保存した記事、読み返せていますか？ためるだけで満足していませんか？
まとメモは、保存した記事を AI が裏側で自動的に整理し、あなただけの百科事典に育て続けるアプリです。
「あとで読む」を、ちゃんと「知識」に変えていきましょう。

■ どこからでも、ひと手間で保存

・Safari やアプリの共有シートから、記事をそのまま保存
・右上の＋から、URL を貼るだけで保存。テキスト・PDF・写真（文字認識）・音声（文字起こし）も取り込み
・英語や中国語などの記事も、自動で日本語に翻訳して整理

保存はすぐ完了。重い処理はすべて裏側で進むので、あなたを待たせません。

■ AI が、トピックごとに要点をまとめる

複数の記事をまたいで、AI が「トピック（あなた専用の Wiki）」を自動で作り、記事が増えるたびに更新します。
「ナレッジ」タブを開けば、最近保存したものと、トピックごとの要点が並んでいます。
・最重要ポイントが、開かなくても先に読める
・トピックは「定義 → 要点 → 新しく増えた記事」の順で、さっと読める
・記事がたまった大きなトピックは、詳しいトピックに分けて本棚のように整理
・関連するトピックどうしが自動でリンクし、知識がつながっていく
・どの要点も、必ず元の記事にさかのぼって確認できる
・まだ開いていない記事には、さりげなく印を表示

■ 探すのも、聞くのも、「検索」タブひとつで

「あの記事、何て書いてあったっけ？」は、「検索」タブで AI に聞くだけ。
・回答はあなたが保存した記事だけを根拠に生成
・引用番号をタップすると、まず出典をプレビュー。そのまま元記事へ
・一般知識で補うときは、はっきり明示
・キーワードで記事やトピックを探すのも同じ画面で

■ AI の間違いは、ひとことで直せる

・記事詳細の「本文の表現を見直す」から、直したい点を言葉で伝えるだけ（例:「Claude Code を誤認識しています」）
・要らないトピックやタグは、いつでも編集・統合・非表示に
最終的な主導権は、いつもあなたの手に。

■ プライバシーは、設計の中心

・AI 処理は Apple Intelligence によりすべて端末内で完結
・広告なし・トラッキングなし・外部サーバーへの送信ゼロ
・iCloud 同期はあなたのプライベートデータベースのみ

■ 7 つの言語に対応

日本語・English・简体中文・繁體中文・한국어・Español・Deutsch。画面の表示も、AI が作る要約・トピック・回答も、設定で選んだ言語で届きます。

■ 日本語ファースト、和の佇まい

明朝体の見出しと墨色、青海波の余白。開くたびに静かで心地よい、日本語のために作られた画面です。

■ 動作環境（重要）

・AI 機能（トピックの自動生成・AI への質問・要約・翻訳・自動タグ）には、Apple Intelligence が利用できる iPhone が必要です
・お使いの iPhone の設定で Apple Intelligence を有効にしてご利用ください
・Apple Intelligence が利用できない環境でも、記事の保存・検索・閲覧・タグ整理はご利用いただけます（使えない理由と対処法はアプリ内でお知らせします）

さあ、あなたの iPhone の AI を最大限に活かして、読んだものを「自分だけの知識」に変えていきましょう。
```
(実測 1462 / 上限 4000)

### 5. このバージョンの最新情報

```
まとメモ 2.0 をリリースしました。
・画面を一新。ホームは「最近保存したもの」とトピック。「検索」タブで記事を探すこともAIに聞くことも1か所で。出典はタップでまずプレビュー
・記事がたまった大きなトピックは、詳しいトピックに分けて本棚のように表示。トピックは「定義→要点→新しく増えた記事」の順で読みやすく
・まだ開いていない記事に印を表示
・記事の追加は入力欄ひとつに。URLを貼るだけで保存、写真・PDF・音声は添付で
・日本語・简体中文・繁體中文・English・한국어・Español・Deutschの7言語に対応。画面もAIが作る要約・トピック・回答も、選んだ言語で
・日本語以外の言語では、記事を翻訳せずそのまま読んで整理するので、より速く自然に
・Apple Intelligenceが使えないときや、端末の言語と生成言語がズレているときは、理由と対処法をバナーでお知らせ
・AIが使えるようになったら、止まっていた整理を自動で再開
・AIのまとめ作成がうまくいかなかったときの立て直しを強化
・アプリ名が「まとメモ」になりました（旧 Knowledge Base）
ご意見・不具合はGitHub Issuesまでお寄せください。
```
(実測 525 / 上限 4000)

### 6. キーワード

```
あとで読む,記事保存,AI要約,まとめ,ノート,クリップ,スクラップ,知識整理,ブックマーク,オフライン,ウィキ,百科事典,PKM,翻訳,学習
```
(実測 71 / 上限 100)

---

## English (en-US)

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
- Tap + in the top corner and just paste a URL to save it. Text, PDFs, photos (OCR), and audio (transcription) work too
- Articles in other languages are read as they are and organized in your chosen language — translated first only when needed

Saving finishes instantly — the heavy lifting happens in the background, so you're never kept waiting.

■ AI organizes key points by topic

AI automatically creates "topics" — your own personal wiki — across multiple articles, and updates them as you save more.
Open the Knowledge tab to see what you saved recently and the key points of each topic.
- The most important points come first, no tapping required
- Each topic reads in order: definition, key points, then what's new since you last looked
- Big topics with many articles are split into detailed subtopics, like a bookshelf
- Related topics link to each other automatically, so your knowledge connects
- Every key point can always be traced back to its original article
- Articles you haven't opened yet get a subtle dot

■ Search and ask in one place

"What did that article actually say again?" Just ask the AI from the Search tab.
- Answers are generated only from the articles you've saved
- Tap a citation number to preview the source first, then open the full article
- When general knowledge is used to fill a gap, it's always labeled clearly
- Keyword search for articles and topics lives on the same screen

■ Fix AI's mistakes in one sentence

- Tap "Review the Article Wording" on any article's detail page and describe the fix in plain language (e.g. "Claude Code is being misread as something else")
- Unwanted topics or tags can be edited, merged, or hidden anytime
You always stay in control.

■ Privacy by design

- All AI processing runs entirely on-device via Apple Intelligence
- No ads, no tracking, zero data sent to external servers
- iCloud sync uses only your own private database

■ 7 languages

English, Japanese, Simplified Chinese, Traditional Chinese, Korean, Spanish, and German. The interface and everything the AI writes — summaries, topics, and answers — follow the language you choose in Settings.

■ A calm, considered aesthetic

A palette of sumi ink and washi paper, elegant Mincho headlines, and breathing negative space inspired by seigaiha waves. Every time you open it, it feels quiet and refined.

■ Requirements (important)

- AI features (automatic topics, asking the AI, summaries, translation, auto-tagging) require an iPhone that supports Apple Intelligence
- Please turn on Apple Intelligence in Settings before use
- Even without Apple Intelligence, you can still save, search, browse, and organize tags for your articles (the app tells you why AI is unavailable and how to fix it)

Now, put your iPhone's AI to full use and turn everything you read into knowledge that's truly your own.
```
(実測 3193 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base 2.0 is here.
・Redesigned: Home shows what you saved recently and your topics. Find articles and ask the AI from one Search tab. Tap a citation to preview its source first
・Big topics with many articles are split into detailed subtopics, shown like a bookshelf. Topics now read in order: definition, key points, then new articles
・Articles you haven't opened yet are marked with a dot
・Adding is now one input field: paste a URL to save, or attach a photo, PDF, or audio file
・Now in 7 languages: Japanese, Simplified Chinese, Traditional Chinese, English, Korean, Spanish, and German. The interface and AI-generated summaries, topics, and answers follow your chosen language
・In languages other than Japanese, articles are read as they are instead of being translated first — faster and more natural
・A banner explains why and how to fix it when Apple Intelligence isn't available, or when your device language and generation language don't match
・When AI becomes available again, paused organizing resumes automatically
・Better recovery when the AI fails to write a topic summary
Feedback and bug reports are welcome via GitHub Issues.
```
(実測 1151 / 上限 4000)

### 6. キーワード

```
note,AI,knowledge,bookmark,read later,summary,wiki,PKM,offline,save article,on-device,translate
```
(実測 95 / 上限 100)

---

## 简体中文 (zh-Hans)

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
读完就忘？不再需要。只需保存文章，AI 就会持续为你编纂专属百科全书。要点一目了然，深入了解就问 AI，回答有据可查。充分释放 iPhone 内置 AI（Apple Intelligence）的能力，所有处理都在设备本机完成，数据绝不外传。
```
(実測 120 / 上限 170)

### 4. 概要

```
■ 读过的知识，自动生长

只需保存你感兴趣的文章，剩下的交给 AI——它会在背后持续为你编纂专属的百科全书。
Knowledge Base 是让你从「读完就忘」毕业的、温柔的第二大脑。

■ 随时随地，轻松保存

・从 Safari 或任意 App 的共享面板，直接保存文章
・点击右上角的「+」，只需粘贴 URL 即可保存。文字・PDF・照片（文字识别）・语音（语音转文字）也能导入
・其他语言的文章会原样阅读，并以你选择的语言整理（只在需要时才先翻译）

保存立即完成。繁重的处理都在背后进行，不会让你等待。

■ AI 按主题为你梳理要点

AI 会跨越多篇文章，自动创建「主题（专属于你的 Wiki）」，并随着文章增加不断更新。
打开「知识」标签页，就能看到最近保存的内容和各主题的要点。
・最重要的要点，无需点击即可先看到
・每个主题按「定义 → 要点 → 新增的文章」的顺序，轻松读完
・文章较多的大主题，会拆分成更细的主题，像书架一样整齐
・相关主题会自动互相链接，让知识彼此串联
・每个要点都能一路追溯回原始文章
・尚未打开的文章会有一个不显眼的标记

■ 搜索与提问，「搜索」标签页一站搞定

「那篇文章到底写了什么来着？」直接在「搜索」标签页问 AI 就好。
・回答只依据你保存的文章生成
・点按引用编号，先预览出处，再跳转到原文章
・需要补充一般常识时，会明确标示
・用关键词查找文章和主题，也在同一个画面

■ AI 的错误，一句话就能更正

・在文章详情的「重新检视正文表达」中，用自然语言说出想修正的地方即可（例如：「Claude Code 被误认成了别的名字」）
・不需要的主题或标签，随时可以编辑、合并、隐藏
最终的主导权，永远握在你手中。

■ 隐私，是设计的核心

・AI 处理全部由 Apple Intelligence 在设备本机完成
・无广告、无跟踪、零外部服务器数据传输
・iCloud 同步仅使用你自己的私有数据库

■ 支持 7 种语言

日本語・English・简体中文・繁體中文・한국어・Español・Deutsch。界面显示，以及 AI 生成的摘要、主题和回答，都会使用你在设置中选择的语言。

■ 日式静谧美学

墨与和纸交织的配色，明朝体标题，青海波留白的呼吸感。每次打开，都是一次静谧优雅的阅读体验。

■ 使用环境（重要）

・AI 功能（主题自动生成・向 AI 提问・摘要・翻译・自动标签）需要支持 Apple Intelligence 的 iPhone
・请在「设置」中开启 Apple Intelligence 后使用
・即使 Apple Intelligence 不可用，你仍然可以保存、搜索、浏览文章与整理标签（无法使用的原因与解决方法会在 App 内告知）

现在，就让你 iPhone 内的 AI 全力发挥，把读过的一切变成「专属于你的知识」吧。
```
(実測 1213 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base 2.0 发布了。
・全新界面：首页显示最近保存的内容和主题。在「搜索」标签页即可查找文章或向 AI 提问。点按出处可先预览
・文章较多的大主题会拆分成更细的主题，像书架一样展示。主题按「定义→要点→新增的文章」的顺序更易阅读
・尚未打开的文章会显示标记
・添加内容只需一个输入框：粘贴 URL 即可保存，照片、PDF、语音可作为附件添加
・现已支持日文、简体中文、繁體中文、英文、韩文、西班牙文、德文共 7 种语言。界面与 AI 生成的摘要、主题、回答都会使用你选择的语言
・在日文以外的语言下，文章不再先翻译，而是直接阅读并整理，更快也更自然
・Apple Intelligence 无法使用，或设备语言与生成语言不一致时，会用提示条告知原因与解决方法
・AI 恢复可用后，被中断的整理会自动继续
・AI 撰写主题摘要失败时的恢复能力更强了
欢迎通过 GitHub Issues 提出意见与问题反馈。
```
(実測 416 / 上限 4000)

### 6. キーワード

```
笔记,备忘录,AI,知识管理,书签,稍后阅读,摘要,百科全书,Wiki,PKM,学习,整理,离线,保存文章,AI聊天,翻译,知识库
```
(実測 65 / 上限 100)

---

## 繁體中文 (zh-Hant)

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
讀完就忘？不再需要。只需儲存文章，AI 就會持續為你編纂專屬百科全書。要點一目了然，深入了解就問 AI，回答有憑有據。充分釋放 iPhone 內建 AI（Apple Intelligence）的能力，所有處理都在裝置本機完成，資料絕不外流。
```
(実測 120 / 上限 170)

### 4. 概要

```
■ 讀過的知識，自動生長

只需儲存你感興趣的文章，剩下的交給 AI——它會在背後持續為你編纂專屬的百科全書。
Knowledge Base 是讓你從「讀完就忘」畢業的、溫柔的第二大腦。

■ 隨時隨地，輕鬆儲存

・從 Safari 或任何 App 的共享面板，直接儲存文章
・點擊右上角的「+」，只需貼上 URL 即可儲存。文字・PDF・照片（文字辨識）・語音（語音轉文字）也能匯入
・其他語言的文章會原樣閱讀，並以你選擇的語言整理（只在需要時才先翻譯）

儲存立即完成。繁重的處理都在背後進行，不會讓你等待。

■ AI 依主題為你梳理要點

AI 會跨越多篇文章，自動建立「主題（專屬於你的 Wiki）」，並隨著文章增加不斷更新。
開啟「知識」分頁，就能看到最近儲存的內容和各主題的要點。
・最重要的要點，不必點擊即可率先看到
・每個主題依「定義 → 要點 → 新增的文章」的順序，輕鬆讀完
・文章較多的大主題，會拆分成更細的主題，像書架一樣整齊
・相關主題會自動互相連結，讓知識彼此串連
・每個要點都能一路追溯回原始文章
・尚未開啟的文章會有一個不顯眼的標記

■ 搜尋與提問，「搜尋」分頁一站搞定

「那篇文章到底寫了什麼來著？」直接在「搜尋」分頁問 AI 就好。
・回答僅依據你儲存的文章產生
・點按引用編號，先預覽出處，再跳轉到原文章
・需要補充一般常識時，會明確標示
・用關鍵字查找文章和主題，也在同一個畫面

■ AI 的錯誤，一句話就能更正

・在文章詳情的「重新檢視正文表達」中，用自然語言說出想修正的地方即可（例如：「Claude Code 被誤認成了別的名字」）
・不需要的主題或標籤，隨時可以編輯、合併、隱藏
最終的主導權，永遠握在你手中。

■ 隱私，是設計的核心

・AI 處理全部由 Apple Intelligence 在裝置本機完成
・無廣告、無追蹤、零外部伺服器資料傳輸
・iCloud 同步僅使用你自己的私有資料庫

■ 支援 7 種語言

日本語・English・简体中文・繁體中文・한국어・Español・Deutsch。介面顯示，以及 AI 產生的摘要、主題和回答，都會使用你在設定中選擇的語言。

■ 日式靜謐美學

墨與和紙交織的色調，明朝體標題，青海波留白的呼吸感。每次開啟，都是一次靜謐優雅的閱讀體驗。

■ 使用環境（重要）

・AI 功能（主題自動產生・向 AI 提問・摘要・翻譯・自動標籤）需要支援 Apple Intelligence 的 iPhone
・請在「設定」中開啟 Apple Intelligence 後使用
・即使 Apple Intelligence 無法使用，你仍然可以儲存、搜尋、瀏覽文章與整理標籤（無法使用的原因與解決方法會在 App 內告知）

現在，就讓你 iPhone 內的 AI 全力發揮，把讀過的一切變成「專屬於你的知識」吧。
```
(実測 1212 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base 2.0 發布了。
・全新介面：首頁顯示最近儲存的內容和主題。在「搜尋」分頁即可查找文章或向 AI 提問。點按出處可先預覽
・文章較多的大主題會拆分成更細的主題，像書架一樣展示。主題依「定義→要點→新增的文章」的順序更易閱讀
・尚未開啟的文章會顯示標記
・新增內容只需一個輸入框：貼上 URL 即可儲存，照片、PDF、語音可作為附件加入
・現已支援日文、簡體中文、繁體中文、英文、韓文、西班牙文、德文共 7 種語言。介面與 AI 產生的摘要、主題、回答都會使用你選擇的語言
・在日文以外的語言下，文章不再先翻譯，而是直接閱讀並整理，更快也更自然
・Apple Intelligence 無法使用，或裝置語言與產生語言不一致時，會用提示條告知原因與解決方法
・AI 恢復可用後，被中斷的整理會自動繼續
・AI 撰寫主題摘要失敗時的復原能力更強了
歡迎透過 GitHub Issues 提出意見與問題回報。
```
(実測 415 / 上限 4000)

### 6. キーワード

```
筆記,備忘錄,AI,知識管理,書籤,稍後閱讀,摘要,百科全書,Wiki,PKM,學習,整理,離線,儲存文章,AI聊天,翻譯,知識庫
```
(実測 65 / 上限 100)

---

## 한국어 (ko)

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
읽고 잊어버리는 습관과는 이제 안녕. 저장만 하면 AI가 당신만의 백과사전을 계속 편집합니다. 요점은 한눈에, 깊이 알고 싶을 땐 AI에게 물어 근거와 함께. iPhone 내장 AI(Apple Intelligence)를 최대한 활용하며, 모든 처리는 기기 안에서 끝나 데이터는 외부로 나가지 않습니다.
```
(実測 168 / 上限 170)

### 4. 概要

```
■ 읽은 지식이, 저절로 자랍니다

관심 있는 기사를 저장하기만 하면 됩니다. 나머지는 AI가 뒤에서 당신만의 백과사전을 계속 편집합니다.
Knowledge Base는 「읽고 잊어버리는 습관」을 졸업하게 해주는, 다정한 제2의 뇌입니다.

■ 어디서든, 한 번의 동작으로 저장

・Safari나 다른 앱의 공유 시트에서 기사를 그대로 저장
・오른쪽 위의 +를 눌러 URL을 붙여넣기만 하면 저장됩니다. 텍스트・PDF・사진(문자 인식)・음성(텍스트 변환)도 가져올 수 있습니다
・다른 언어로 된 기사는 그대로 읽어 선택한 언어로 정리합니다(필요할 때만 먼저 번역)

저장은 즉시 완료됩니다. 무거운 처리는 모두 뒤에서 진행되므로 기다릴 필요가 없습니다.

■ AI가 주제별로 요점을 정리합니다

여러 기사를 아울러, AI가 「주제(당신만의 Wiki)」를 자동으로 만들고 기사가 늘어날 때마다 업데이트합니다.
「지식」탭을 열면 최근 저장한 글과 주제별 요점이 나열되어 있습니다.
・가장 중요한 포인트는 탭하지 않아도 먼저 읽을 수 있습니다
・주제는 「정의 → 요점 → 새로 늘어난 기사」 순서로 술술 읽힙니다
・기사가 많이 쌓인 큰 주제는 더 세부적인 주제로 나누어 책장처럼 정돈합니다
・관련 주제끼리 자동으로 연결되어 지식이 이어집니다
・모든 요점은 반드시 원본 기사로 거슬러 올라가 확인할 수 있습니다
・아직 열지 않은 기사에는 은은한 표시가 붙습니다

■ 찾기도, 묻기도, 「검색」탭 하나로

「그 기사에 뭐라고 쓰여 있었더라?」는 「검색」탭에서 AI에게 물어보세요.
・답변은 당신이 저장한 기사만을 근거로 생성됩니다
・인용 번호를 탭하면 먼저 출처를 미리 보고, 그대로 원본 기사로 이동합니다
・일반 지식으로 보충할 때는 명확히 표시됩니다
・키워드로 기사와 주제를 찾는 것도 같은 화면에서 할 수 있습니다

■ AI의 실수는 한마디로 고칠 수 있습니다

・기사 상세 화면의 「본문 표현 검토」에서 고치고 싶은 점을 말로 전하기만 하면 됩니다(예: 「Claude Code를 다른 이름으로 잘못 인식했어요」)
・필요 없는 주제나 태그는 언제든 편집・통합・숨기기가 가능합니다
최종 결정권은 언제나 당신에게 있습니다.

■ 프라이버시는 설계의 중심입니다

・AI 처리는 모두 Apple Intelligence를 통해 기기 안에서 완결됩니다
・광고 없음・추적 없음・외부 서버로의 전송 없음
・iCloud 동기화는 당신의 개인 데이터베이스만 사용합니다

■ 7개 언어 지원

日本語・English・简体中文・繁體中文・한국어・Español・Deutsch. 화면 표시는 물론 AI가 만드는 요약・주제・답변도 설정에서 선택한 언어로 제공됩니다.

■ 일본풍의 고요한 아름다움

먹빛과 화지가 어우러진 색감, 명조체 표제, 세이가이하 문양이 만들어내는 여백의 호흡. 열 때마다 고요하고 우아한 독서 경험을 선사합니다.

■ 사용 환경(중요)

・AI 기능(주제 자동 생성・AI에게 질문・요약・번역・자동 태그)에는 Apple Intelligence를 지원하는 iPhone이 필요합니다
・「설정」에서 Apple Intelligence를 켠 후 이용해 주세요
・Apple Intelligence를 사용할 수 없는 환경에서도 기사 저장・검색・열람・태그 정리는 이용하실 수 있습니다(사용할 수 없는 이유와 해결 방법은 앱 안에서 안내합니다)

이제, 당신의 iPhone에 담긴 AI를 최대한 활용해 읽은 모든 것을 「나만의 지식」으로 바꿔보세요.
```
(実測 1691 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base 2.0을 출시했습니다.
・새로운 화면: 홈에서 최근 저장한 글과 주제를 확인하고, 검색 탭 하나에서 글 찾기와 AI 질문을 모두 할 수 있습니다. 출처를 탭하면 먼저 미리보기가 열립니다
・기사가 많이 쌓인 큰 주제는 세부 주제로 나누어 책장처럼 보여 줍니다. 주제는 「정의→요점→새로 늘어난 기사」 순서로 더 읽기 쉬워졌습니다
・아직 열지 않은 기사에 표시가 붙습니다
・추가는 입력란 하나로: URL을 붙여넣기만 하면 저장되고, 사진・PDF・음성은 첨부로 추가합니다
・일본어・简体中文・繁體中文・English・한국어・Español・Deutsch 총 7개 언어를 지원합니다. UI는 물론 AI가 생성하는 요약・주제・답변도 선택한 언어로 제공됩니다
・일본어 이외의 언어에서는 기사를 먼저 번역하지 않고 그대로 읽어 정리하므로 더 빠르고 자연스럽습니다
・Apple Intelligence를 사용할 수 없거나 기기 언어와 생성 언어가 다를 때는 이유와 해결 방법을 배너로 안내합니다
・AI를 다시 사용할 수 있게 되면, 중단되었던 정리 작업이 자동으로 재개됩니다
・AI가 주제 요약 작성에 실패했을 때의 복구를 강화했습니다
의견이나 문제는 GitHub Issues로 알려주세요.
```
(実測 613 / 上限 4000)

### 6. キーワード

```
노트,메모,AI,지식관리,북마크,나중에읽기,요약,위키,백과사전,PKM,학습,정리,오프라인,기사저장,AI채팅,번역,지식
```
(実測 65 / 上限 100)

---

## Español (es)

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
Deja de leer y olvidar. Guarda un artículo y la IA arma tu enciclopedia. Puntos clave al instante, respuestas citadas al preguntar a la IA. Todo en tu iPhone.
```
(実測 158 / 上限 170)

### 4. 概要

```
■ El conocimiento que lees crece por sí solo

Basta con guardar los artículos que te interesan. El resto se lo dejas a la IA, que teje en segundo plano tu propia enciclopedia.
Knowledge Base es el segundo cerebro que te ayuda a dejar de «leer y olvidar».

■ Guarda desde cualquier lugar, en un solo paso

・Guarda artículos directamente desde Safari o la hoja de compartir de cualquier app
・Toca + en la esquina superior derecha y pega una URL para guardarla. También puedes añadir texto, PDF, fotos (reconocimiento de texto) y audio (transcripción)
・Los artículos en otros idiomas se leen tal cual y se organizan en el idioma que elijas (solo se traducen antes cuando hace falta)

Guardar es instantáneo. El trabajo pesado ocurre en segundo plano, así que nunca tienes que esperar.

■ La IA organiza los puntos clave por tema

La IA crea automáticamente «temas» (tu propia wiki) a partir de varios artículos y los actualiza a medida que guardas más.
Abre la pestaña Conocimiento para ver lo que guardaste recientemente y los puntos clave de cada tema.
・Los puntos más importantes aparecen primero, sin necesidad de tocar nada
・Cada tema se lee en orden: definición, puntos clave y artículos nuevos desde la última vez
・Los temas grandes con muchos artículos se dividen en temas más detallados, como una estantería
・Los temas relacionados se enlazan automáticamente, conectando tu conocimiento
・Cada punto clave siempre puede rastrearse hasta el artículo original
・Los artículos que aún no has abierto llevan una marca discreta

■ Buscar y preguntar, en la pestaña Buscar

«¿Qué decía exactamente ese artículo?» Pregúntaselo a la IA desde la pestaña Buscar.
・Las respuestas se generan solo a partir de los artículos que has guardado
・Toca el número de cita para ver primero una vista previa de la fuente y luego abrir el artículo original
・Cuando se usa conocimiento general para completar la respuesta, se indica claramente
・La búsqueda por palabras clave de artículos y temas está en la misma pantalla

■ Corrige los errores de la IA con una frase

・Toca «Revisar la redacción del artículo» en la página de detalle y describe el cambio en lenguaje natural (p. ej.: «Claude Code se reconoce mal como otro nombre»)
・Los temas o etiquetas que no necesites se pueden editar, combinar u ocultar en cualquier momento
El control final siempre está en tus manos.

■ La privacidad, en el centro del diseño

・Todo el procesamiento de IA ocurre en el dispositivo gracias a Apple Intelligence
・Sin anuncios, sin rastreo, cero datos enviados a servidores externos
・La sincronización con iCloud usa solo tu base de datos privada

■ 7 idiomas

Español, 日本語, 简体中文, 繁體中文, English, 한국어 y Deutsch. La interfaz y todo lo que escribe la IA (resúmenes, temas y respuestas) siguen el idioma que elijas en Ajustes.

■ Una estética japonesa serena

Una paleta de tinta sumi y papel washi, títulos en elegante Mincho y el respiro del patrón seigaiha en el espacio negativo. Cada vez que la abres, es una experiencia de lectura serena y refinada.

■ Requisitos (importante)

・Las funciones de IA (temas automáticos, preguntas a la IA, resúmenes, traducción, etiquetado automático) requieren un iPhone compatible con Apple Intelligence
・Activa Apple Intelligence en Ajustes antes de usarlas
・Aunque Apple Intelligence no esté disponible, puedes seguir guardando, buscando, explorando artículos y organizando etiquetas (la app te explica por qué no está disponible y cómo solucionarlo)

Ahora, aprovecha al máximo la IA de tu iPhone y convierte todo lo que lees en un conocimiento verdaderamente tuyo.
```
(実測 3573 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base 2.0 ya está disponible.
・Nuevo diseño: el inicio muestra lo guardado recientemente y tus temas. Busca artículos y pregunta a la IA desde una sola pestaña Buscar. Toca una cita para ver primero una vista previa de la fuente
・Los temas grandes con muchos artículos se dividen en temas más detallados, como una estantería. Ahora los temas se leen en orden: definición, puntos clave y artículos nuevos
・Los artículos que aún no has abierto llevan una marca
・Añadir ahora es un solo campo: pega una URL para guardar o adjunta una foto, un PDF o un audio
・Ahora con 7 idiomas: japonés, chino simplificado, chino tradicional, inglés, coreano, español y alemán. La interfaz y los resúmenes, temas y respuestas generados por IA siguen el idioma elegido
・En idiomas distintos del japonés, los artículos se leen tal cual en lugar de traducirse antes: más rápido y más natural
・Cuando Apple Intelligence no está disponible, o el idioma del dispositivo y el de generación no coinciden, un aviso explica el motivo y cómo solucionarlo
・Cuando la IA vuelve a estar disponible, el trabajo de organización pendiente se reanuda automáticamente
・Mejor recuperación cuando la IA falla al escribir el resumen de un tema
Tus comentarios y reportes de errores son bienvenidos a través de GitHub Issues.
```
(実測 1293 / 上限 4000)

### 6. キーワード

```
nota,IA,conocimiento,marcador,resumen,wiki,PKM,offline,artículo,chat,traducir,enciclopedia
```
(実測 90 / 上限 100)

---

## Deutsch (de)

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
Schluss mit Lesen und Vergessen. Speichern genügt – die KI baut Ihre Enzyklopädie. Kernpunkte sofort, KI-Antworten mit Quellen. Alles läuft auf Ihrem iPhone.
```
(実測 157 / 上限 170)

### 4. 概要

```
■ Wissen, das von selbst wächst

Sichern Sie einfach die Artikel, die Sie interessieren. Den Rest übernimmt die KI und webt sie im Hintergrund zu Ihrer eigenen Enzyklopädie zusammen.
Knowledge Base ist das sanfte zweite Gehirn, das Ihnen hilft, dem „Lesen und Vergessen" zu entkommen.

■ Von überall sichern, in einem Schritt

・Sichern Sie Artikel direkt aus Safari oder dem Teilen-Menü jeder App
・Tippen Sie oben rechts auf das Plus und fügen Sie einfach eine URL ein, um sie zu sichern. Auch Text, PDFs, Fotos (Texterkennung) und Audio (Transkription) lassen sich hinzufügen
・Artikel in anderen Sprachen werden unverändert gelesen und in Ihrer gewählten Sprache organisiert (nur bei Bedarf zuerst übersetzt)

Das Sichern ist sofort abgeschlossen. Die aufwendige Verarbeitung läuft im Hintergrund, sodass Sie nie warten müssen.

■ Die KI ordnet Kernpunkte nach Thema

Die KI erstellt automatisch „Themen" (Ihr persönliches Wiki) über mehrere Artikel hinweg und aktualisiert sie, sobald Sie mehr sichern.
Öffnen Sie den Tab Wissen, um zuletzt Gesichertes und die Kernpunkte jedes Themas zu sehen.
・Die wichtigsten Punkte erscheinen zuerst, ganz ohne Tippen
・Jedes Thema liest sich der Reihe nach: Definition, Kernpunkte, dann neu hinzugekommene Artikel
・Große Themen mit vielen Artikeln werden in Detailthemen aufgeteilt, wie in einem Bücherregal
・Verwandte Themen verknüpfen sich automatisch, sodass Ihr Wissen zusammenwächst
・Jeder Kernpunkt lässt sich stets bis zum Originalartikel zurückverfolgen
・Artikel, die Sie noch nicht geöffnet haben, tragen eine dezente Markierung

■ Suchen und Fragen im Tab Suche

„Was stand noch mal in diesem Artikel?" Fragen Sie einfach im Tab Suche die KI.
・Antworten entstehen ausschließlich aus Ihren gesicherten Artikeln
・Tippen Sie auf eine Zitatnummer, um zuerst die Quelle in der Vorschau zu sehen und dann den Originalartikel zu öffnen
・Wird zur Ergänzung Allgemeinwissen verwendet, wird das klar gekennzeichnet
・Die Stichwortsuche nach Artikeln und Themen finden Sie auf demselben Bildschirm

■ KI-Fehler mit einem Satz korrigieren

・Tippen Sie auf der Artikeldetailseite auf „Formulierung des Artikels überprüfen" und beschreiben Sie die Korrektur in einfachen Worten (z. B. „Claude Code wird fälschlicherweise als anderer Name erkannt")
・Unnötige Themen oder Tags können Sie jederzeit bearbeiten, zusammenführen oder ausblenden
Die letzte Entscheidung liegt immer bei Ihnen.

■ Datenschutz im Zentrum des Designs

・Die gesamte KI-Verarbeitung läuft vollständig auf dem Gerät über Apple Intelligence
・Keine Werbung, kein Tracking, keine Datenübertragung an externe Server
・Die iCloud-Synchronisierung nutzt ausschließlich Ihre private Datenbank

■ 7 Sprachen

Deutsch, 日本語, 简体中文, 繁體中文, English, 한국어 und Español. Die Oberfläche und alles, was die KI schreibt – Zusammenfassungen, Themen und Antworten – folgen der Sprache, die Sie in den Einstellungen wählen.

■ Eine ruhige, japanisch geprägte Ästhetik

Eine Palette aus Sumi-Tinte und Washi-Papier, elegante Mincho-Überschriften und der ruhige Atem des Seigaiha-Musters im Weißraum. Jedes Öffnen fühlt sich still und stilvoll an.

■ Voraussetzungen (wichtig)

・Die KI-Funktionen (automatische Themen, Fragen an die KI, Zusammenfassungen, Übersetzung, automatische Tags) benötigen ein iPhone mit Apple-Intelligence-Unterstützung
・Bitte aktivieren Sie Apple Intelligence in den Einstellungen, bevor Sie diese Funktionen nutzen
・Auch ohne Apple Intelligence können Sie weiterhin Artikel sichern, suchen, durchsuchen und Tags organisieren (die App erklärt, warum die KI nicht verfügbar ist und wie Sie das beheben)

Nutzen Sie jetzt die KI Ihres iPhones voll aus und verwandeln Sie alles, was Sie lesen, in Wissen, das wirklich Ihnen gehört.
```
(実測 3732 / 上限 4000)

### 5. このバージョンの最新情報

```
Knowledge Base 2.0 ist da.
・Neues Design: Die Startseite zeigt zuletzt Gespeichertes und Ihre Themen. Artikel suchen und die KI fragen in einem Tab Suche. Quellen per Tippen zuerst in der Vorschau ansehen
・Große Themen mit vielen Artikeln werden in Detailthemen aufgeteilt und wie ein Bücherregal dargestellt. Themen lesen sich jetzt der Reihe nach: Definition, Kernpunkte, neue Artikel
・Artikel, die Sie noch nicht geöffnet haben, sind markiert
・Hinzufügen geht jetzt über ein einziges Eingabefeld: URL einfügen und sichern oder Foto, PDF oder Audio anhängen
・Jetzt mit 7 Sprachen: Japanisch, vereinfachtes Chinesisch, traditionelles Chinesisch, Englisch, Koreanisch, Spanisch und Deutsch. Oberfläche sowie von der KI erzeugte Zusammenfassungen, Themen und Antworten folgen der gewählten Sprache
・In anderen Sprachen als Japanisch werden Artikel unverändert gelesen statt vorher übersetzt – schneller und natürlicher
・Wenn Apple Intelligence nicht verfügbar ist oder Gerätesprache und Generierungssprache nicht übereinstimmen, erklärt ein Banner den Grund und die Lösung
・Sobald die KI wieder verfügbar ist, wird unterbrochene Organisation automatisch fortgesetzt
・Bessere Wiederherstellung, wenn die KI eine Themen-Zusammenfassung nicht schreiben kann
Feedback und Fehlermeldungen sind über GitHub Issues willkommen.
```
(実測 1318 / 上限 4000)

### 6. キーワード

```
notiz,KI,wissen,lesezeichen,zusammenfassung,wiki,PKM,offline,artikel,chat,übersetzen,enzyklopädie
```
(実測 97 / 上限 100)

---

