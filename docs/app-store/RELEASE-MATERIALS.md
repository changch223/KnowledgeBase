# Knowledge Base — App Store リリース素材一式

作成日: 2026-07-04 / 対象バージョン: **v1.0** / 主要プラットフォーム: iPhone (iOS 26+, Apple Intelligence)
> **v1.1 追記**: 多言語対応（简体中文 / 繁體中文 / English）+ Apple Intelligence 可用性ガイド + AI 復旧機能の
> 提出素材は本ドキュメント末尾の **§1-J** に追加した（作成日 2026-07-11、PR #66〜#70 対応）。v1.0 の内容（§1-A〜§1-I）は
> 提出時の記録としてそのまま残し、変更していない。
> **v1.1 追加ロケール追記**: さらに 韓国語 (ko) / スペイン語 (es) / ドイツ語 (de) の提出素材を **§1-K** に追加した
> （作成日 2026-07-11、PR #73 `i18n-ko-es-de` 対応）。これで v1.1 の対応言語は 日本語・简体中文・繁體中文・
> English・한국어・Español・Deutsch の **7 言語**になる。§1-J（zh/en 追加時点の記録）は変更していない
> （審査メモ §1-I 相当の言語リストのみ J-5 内を 7 言語に更新済み）。

このドキュメントは以下 4 部構成:
1. App Store Connect メタデータ（日本語 primary / 英語 secondary）
2. アプリ内文言の修正・整合（在庫監査）
3. スクリーンショット撮影指示（画面・順序・キャプション・仕様）
4. クリエイティブ指示 prompt（キービジュアル・スクショ枠・アイコンの生成 prompt）

> **一文ビジョン（全コピーの North Star）**
> 「読んだ記事を AI が裏で 1 つの百科事典に編さんし続け、美しいフィードを開くだけで“自分だけの知識”が育っていくのが見える、優しい第二の脳」

---

## 1. App Store Connect メタデータ

### 1-A. 基本情報

| 項目 | 値 | 備考 |
|---|---|---|
| プライマリ言語 | 日本語 (ja) | 英語 (en-US) は任意で追加 |
| Primary Category | **仕事効率化 (Productivity)** | |
| Secondary Category | **辞書/参考書 (Reference)** | 教育 (Education) でも可 |
| 価格 | 無料（App 内課金の予定があれば別途） | |
| 年齢制限 | **4+** | UGC なし・トラッキングなし・外部通信なし |
| Support URL | `https://github.com/changch223/KnowledgeBase`（Issues 受付） | `docs/support.md` を GitHub Pages 公開推奨 |
| Privacy Policy URL | `docs/privacy-policy.md` を公開した URL | 提出前に GitHub Pages 等で hosting |
| Marketing URL | 任意（LP があれば） | |
| 暗号輸出 | `ITSAppUsesNonExemptEncryption = false`（Info.plist 設定済） | 標準 HTTPS のみ = exempt |

### 1-B. App 名（最大 30 文字）— 最新確定版

- **推奨（ASO 強化）**: `Knowledge Base：AI第二の脳`（21）
  - 「Knowledge Base」単体は汎用語で検索埋没しやすい。名前に差別化ワードを含めるのが最新の推奨。
- 代替（純ブランド）: `Knowledge Base`（14）

### 1-C. サブタイトル（最大 30 文字）— 最新確定版

- **推奨 A**: `iPhoneのAIが育てる、第二の脳`（18）
  - 「あなたの iPhone の AI（Apple Intelligence）が働く」= オンデバイスの差別化を名前直下で即伝える。
- 代替 B: `AIが読んだ記事を整理する第二の脳`（17）
- 代替 C: `保存するだけ。AIが知識を編さん`（15）

### 1-D. プロモーションテキスト（最大 170 文字・審査なしで随時更新可）— 最新確定版

```
読んで終わり、を卒業。保存するだけで、AIがあなた専用の百科事典を編さんし続けます。要点は一目、深掘りはチャットで根拠付きに。あなたのiPhoneに搭載されたAI（Apple Intelligence）の力を最大限に引き出し、処理はすべて端末内で完結。データは外に出ません。
```
（約 130 文字）

> 訴求の核: 「**あなたの iPhone の AI を最大限に活かす**」— クラウド AI 依存の競合と真逆の立ち位置を明示。

### 1-E. キーワード（最大 100 文字・カンマ区切り・スペース禁止）— 最新確定版

```
ノート,メモ,AI,知識管理,ブックマーク,あとで読む,要約,ウィキ,百科事典,PKM,学習,整理,オフライン,記事保存,チャット,翻訳,ナレッジ
```
（約 73 文字。英語ロケール用: `note,AI,second brain,knowledge,bookmark,read later,summary,wiki,PKM,offline,save article,on-device`）

> ASO メモ: 名前に含む語（Knowledge Base / 第二の脳）はキーワードに入れない（重複無駄）。競合商標（Notion/Readwise 等）・「Apple」を含む語も入れない（審査リスク）。Apple Intelligence の訴求は名前/サブタイトル/説明文/審査メモ側で行う。

### 1-F. 説明文（最大 4000 文字・日本語）

```
■ 読んだ知識が、勝手に育つ。

気になった記事を保存するだけ。あとは AI が裏側で、あなただけの百科事典を編さんし続けます。
Knowledge Base は「読んで終わり」を卒業するための、優しい第二の脳です。

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

### 1-G. 「このバージョンの新機能」（What's New / v1.0）

```
Knowledge Base v1.0 をリリースしました。
・共有シート/＋ボタンから、URL・テキスト・PDF・写真・音声を保存
・AI が記事をまたいで概念ページ（Wiki）を自動編さん
・保存した知識に根拠付きで答える AI チャット
・すべて端末内で完結、プライバシーファースト
ご意見・不具合は GitHub Issues までお寄せください。
```

### 1-H. 英語版（en-US、任意で追加する場合）

- **Subtitle**: `Your AI-organized second brain`
- **Promotional Text**:
  `Stop reading and forgetting. Just save an article and AI keeps weaving it into an evolving encyclopedia of your own — key points up front, answers with citations, all on-device.`
- **Description（要約版）**:
  ```
  Save anything you read — AI quietly compiles it into your personal encyclopedia.

  • Save from the share sheet, or add URLs, text, PDFs, photos (OCR) and audio (transcription). Non-Japanese content is auto-translated.
  • AI generates and updates "concept pages" (your own wiki) across articles. Key points are shown first; related concepts link automatically.
  • Ask your knowledge base anything — answers are grounded only in your saved articles, with tappable citations.
  • Correct AI mistakes in plain language; merge, edit or hide anything.
  • Privacy by design: all AI runs on-device via Apple Intelligence. No ads, no tracking, no external servers. iCloud sync uses your private database only.
  ```

### 1-I. App Review 審査メモ（App Review Information > Notes 欄に記入）

App Store Connect の「App Review に関する情報」の Notes にそのまま貼れる文面:

```
【テスト環境について】
本アプリは iPhone 17（iOS 26）の実機で全機能のテストを完了しています。

【動作要件（重要）】
本アプリの AI 機能（概念ページの自動生成 / AI チャット / 要約 / 翻訳 / 自動タグ付け）は、
Apple の Foundation Models framework（Apple Intelligence）を使用し、すべて端末内で実行されます。
そのため AI 機能の動作確認には以下が必要です:
- Apple Intelligence 対応の iPhone（iPhone 15 Pro 以降 / iPhone 16・17 シリーズ）
- 設定 > Apple Intelligence と Siri で Apple Intelligence が有効であること
- 日本語の言語モデルがダウンロード済みであること

【Apple Intelligence 非対応環境での挙動】
非対応端末・無効時でもアプリはクラッシュせず、記事の保存・検索・閲覧・タグ整理などの
基本機能はすべて動作します（AI 生成部分は自動的にスキップ / 簡易表示にフォールバックします）。

【レビュー手順のご案内】
1. Safari で任意の記事を開き、共有シートから「Knowledge Base」で保存
2. アプリを起動すると数十秒で AI が要約・タグ・概念ページを自動生成します
3. 「ナレッジ」タブで概念ページ、「AI チャット」タブで根拠付き回答をご確認いただけます

【プライバシー】
外部サーバーへのデータ送信はありません。ログインも不要です。
iCloud 同期はユーザー自身のプライベートデータベースのみを使用します。
```

> ポイント: 審査員が Apple Intelligence 非対応端末や無効状態でテストして「AI 機能が動かない」と
> リジェクトされるのを防ぐため、**要件とフォールバック挙動を先回りして明記**するのが重要。

---

## §1-J. v1.1 多言語リリース（简体中文 / 繁體中文 / English 追加）

作成日: 2026-07-11 / 対象: PR #66（zh Phase A）〜#70（en）/ ベースコミット `7c572ce`

v1.1 の柱は 3 つ。App Store Connect にはこの 3 つを軸に伝える。
1. **多言語対応**: UI（`Localizable.xcstrings`）と AI 生成知識（要約・概念ページ・チャット回答・カテゴリ）の両方が
   日本語 / 简体中文 / 繁體中文 / English の 4 言語に対応。生成言語は初回起動時の端末言語で自動的に決まり、
   設定からいつでも変更できる（`PipelineLanguage`、`docs/HANDOFF.md` §2-2 の設計）
2. **Apple Intelligence 可用性ガイド**: AI が使えない/使えなくなった時に理由別バナー + 手順ガイドで気づかせる
3. **AI 復旧**: AI が再び使えるようになった時、止まっていた整理（要約・概念ページ・タグ）を自動で再開する

用語は各言語の `Localizable.xcstrings` 実訳（needs_review 済み・PR #66/#67/#70 で導入）に合わせてある
（简体中文の「知识/资料库/生成语言/保存/更正」、繁體中文の「知識/資料庫/產生語言/儲存/更正」、
English の "Knowledge/Library/Generation Language" 等）。

### J-1. zh-Hans（简体中文）ロケール

| 項目 | 値 | 文字数 |
|---|---|---|
| App 名（30字以内） | `Knowledge Base：AI第二大脑` | 21 / 30 |
| サブタイトル（30字以内） | `iPhone的AI，养出你的第二大脑` | 18 / 30 |
| プロモーションテキスト（170字以内） | 下記 | 123 / 170 |
| キーワード（100字以内・カンマ区切り・スペース禁止） | 下記 | 65 / 100 |

プロモーションテキスト:
```
读完就忘？不再需要。只需保存文章，AI 就会持续为你编纂专属百科全书。要点一目了然，深入了解就问 AI 聊天，回答有据可查。充分释放 iPhone 内置 AI（Apple Intelligence）的能力，所有处理都在设备本机完成，数据绝不外传。
```

キーワード:
```
笔记,备忘录,AI,知识管理,书签,稍后阅读,摘要,百科全书,Wiki,PKM,学习,整理,离线,保存文章,AI聊天,翻译,知识库
```
> ASO メモ: App 名に含む語（Knowledge Base / 第二大脑）と重複する語はキーワードに入れていない。「Wiki」は
> アプリ内訳語（`search.concepts.header` = "Wiki 页面"）に合わせ翻訳せず英語表記のまま採用。

説明文（简体中文フル版、ja §1-F の構成を踏襲）:
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
（1064 / 4000 字）

What's New（v1.1）:
```
Knowledge Base v1.1 发布了。
・新增简体中文、繁體中文、英文支持。界面与 AI 生成的摘要、概念页面、聊天回答都会使用你选择的语言
・Apple Intelligence 无法使用时，会用提示条告知原因与解决方法
・AI 恢复可用后，被中断的整理会自动继续
欢迎通过 GitHub Issues 提出意见与问题反馈。
```

### J-2. zh-Hant（繁體中文）ロケール

台湾語彙（儲存・檔案・新增・辨識・設定・產生語言 等）で書き分け。単純な字体変換ではない。

| 項目 | 値 | 文字数 |
|---|---|---|
| App 名（30字以内） | `Knowledge Base：AI第二大腦` | 21 / 30 |
| サブタイトル（30字以内） | `iPhone的AI，養出你的第二大腦` | 18 / 30 |
| プロモーションテキスト（170字以内） | 下記 | 123 / 170 |
| キーワード（100字以内） | 下記 | 65 / 100 |

プロモーションテキスト:
```
讀完就忘？不再需要。只需儲存文章，AI 就會持續為你編纂專屬百科全書。要點一目了然，深入了解就問 AI 聊天，回答有憑有據。充分釋放 iPhone 內建 AI（Apple Intelligence）的能力，所有處理都在裝置本機完成，資料絕不外流。
```

キーワード:
```
筆記,備忘錄,AI,知識管理,書籤,稍後閱讀,摘要,百科全書,Wiki,PKM,學習,整理,離線,儲存文章,AI聊天,翻譯,知識庫
```

説明文（繁體中文フル版）:
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
（1062 / 4000 字）

What's New（v1.1）:
```
Knowledge Base v1.1 發布了。
・新增簡體中文、繁體中文、英文支援。介面與 AI 產生的摘要、概念頁面、聊天回答都會使用你選擇的語言
・Apple Intelligence 無法使用時，會用提示條告知原因與解決方法
・AI 復原可用後，被中斷的整理會自動繼續
歡迎透過 GitHub Issues 提出意見與問題回報。
```

### J-3. en-US ロケール（§1-H のフル版）

| 項目 | 値 | 文字数 |
|---|---|---|
| App Name（30 chars max） | `Knowledge Base: Second Brain` | 28 / 30 |
| Subtitle（30 chars max、§1-H から変更なし） | `Your AI-organized second brain` → **31 は超過のため短縮**: `AI grows your second brain` | 26 / 30 |
| Promotional Text（170 chars max） | 下記 | 166 / 170 |
| Keywords（100 chars max） | 下記 | 95 / 100 |

> 注: §1-H の Subtitle 案 `Your AI-organized second brain` は実測 31 文字で **上限超過**（過去の下書き未検証だった）。
> v1.1 では `AI grows your second brain`（26字）に短縮して確定した。

Promotional Text:
```
Stop reading and forgetting. Save an article and AI keeps weaving it into your own evolving encyclopedia — key points up front, answers with citations, all on-device.
```

Keywords:
```
note,AI,knowledge,bookmark,read later,summary,wiki,PKM,offline,save article,on-device,translate
```
> ASO note: removed "second brain" from keywords (now duplicated in App Name) versus the §1-H draft; added "translate" to reflect the multilingual pipeline.

Description（full version、structure mirrors ja §1-F / zh-Hans J-1）:
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
（2836 / 4000 字）

What's New（v1.1）:
```
Knowledge Base v1.1 is here.
・Added Simplified Chinese, Traditional Chinese, and English. Both the UI and AI-generated summaries, concept pages, and chat replies now follow your chosen language
・A banner now explains why and how to fix it when Apple Intelligence isn't available
・When AI becomes available again, any paused organizing automatically resumes
Feedback and bug reports are welcome via GitHub Issues.
```

### J-4. ja — What's New（v1.1）

§1-G の v1.0 What's New はそのまま履歴として残し、v1.1 提出時は以下に差し替える:
```
Knowledge Base v1.1 をリリースしました。
・簡体字・繁体字・英語に対応。UI も AI が生成する要約・概念ページ・チャット回答も、選んだ言語で
・Apple Intelligence が使えないときは、理由と対処法をバナーでお知らせ
・AI が使えるようになったら、止まっていた整理を自動で再開
ご意見・不具合は GitHub Issues までお寄せください。
```

### J-5. App Review 審査メモ（更新版・v1.1、§1-I を差し替え）

App Store Connect の「App Review に関する情報」の Notes に、v1.1 提出時はこちらを貼る（§1-I の v1.0 版から
対応言語・生成言語・AI 復旧の 3 点を追記）:

```
【テスト環境について】
本アプリは iPhone 17（iOS 26）の実機で全機能のテストを完了しています。

【対応言語（v1.1 で追加）】
UI は 日本語 / 简体中文（Simplified Chinese）/ 繁體中文（Traditional Chinese）/ English / 한국어（Korean）/
Español（Spanish）/ Deutsch（German）の 7 言語に対応しています。
AI が生成する要約・概念ページ・チャット回答などの「知識」の言語（生成言語）は、初回起動時の端末の言語設定
から自動的に決まります。ユーザーは 設定 > 生成言語 からいつでも変更できます（変更後はアプリの再起動が
必要です）。

【動作要件（重要）】
本アプリの AI 機能（概念ページの自動生成 / AI チャット / 要約 / 翻訳 / 自動タグ付け）は、
Apple の Foundation Models framework（Apple Intelligence）を使用し、すべて端末内で実行されます。
そのため AI 機能の動作確認には以下が必要です:
- Apple Intelligence 対応の iPhone（iPhone 15 Pro 以降 / iPhone 16・17 シリーズ）
- 設定 > Apple Intelligence と Siri で Apple Intelligence が有効であること
- 使用する言語（生成言語）に応じた言語モデルがダウンロード済みであること

【Apple Intelligence 非対応環境での挙動（v1.1 で強化）】
非対応端末・無効時でもアプリはクラッシュせず、記事の保存・検索・閲覧・タグ整理などの
基本機能はすべて動作します（AI 生成部分は自動的にスキップ / 簡易表示にフォールバックします）。
AI が利用できない/無効な間は、画面上部のバナーで理由（端末非対応 / 未有効化 / モデル準備中 / 不明）を
お知らせし、対処方法を案内します。AI が利用可能になると、保留されていた要約・概念ページ・タグ付けなどの
処理は自動的に再開されます（AI 復旧機能）。

【レビュー手順のご案内】
1. Safari で任意の記事を開き、共有シートから「Knowledge Base」で保存
2. アプリを起動すると数十秒で AI が要約・タグ・概念ページを自動生成します
3. 「ナレッジ」タブで概念ページ、「AI チャット」タブで根拠付き回答をご確認いただけます

【言語別の確認方法（任意）】
テスト端末の「設定 > 一般 > 言語と地域」で言語を 简体中文 / 繁體中文 / English / 한국어 / Español / Deutsch
に切り替えてからアプリを完全終了→再起動すると、UI とアプリ初回起動時の生成言語の両方がその言語になります
（生成言語はアプリ内の 設定 > 生成言語 からも個別に確認・変更できます）。

【プライバシー】
外部サーバーへのデータ送信はありません。ログインも不要です。
iCloud 同期はユーザー自身のプライベートデータベースのみを使用します。
```

---

## §1-K. v1.1 追加ロケール（韓国語 / スペイン語 / ドイツ語 追加）

作成日: 2026-07-11 / 対象: PR #73（`i18n-ko-es-de`）/ ベースコミット `df99984`

§1-J（简体中文 / 繁體中文 / English）に続けて、v1.1 の対応言語を **韓国語 (ko) / スペイン語 (es) / ドイツ語 (de)**
の 3 ロケールぶん追加する。機能面の柱（多言語対応・Apple Intelligence 可用性ガイド・AI 復旧）は §1-J と同一で、
今回はそこに対応言語を積み増すだけ（App Store Connect のロケール登録は「スペイン語 (スペイン)」「スペイン語
(メキシコ)」のどちらにも同じ es 原稿を流用できるよう、地域色を出さない中立スペイン語で書いてある）。

これで v1.1 の対応言語は 日本語 / 简体中文 / 繁體中文 / English / 한국어 / Español / Deutsch の **7 言語**になる。

用語は各言語の `Localizable.xcstrings` 実訳（needs_review 済み・PR #73 で導入）に合わせてある
（한국어の「지식/라이브러리/생성 언어/저장/수정」、español の「Conocimiento/Biblioteca/Idioma de generación/
Guardar/Corregir」、Deutsch の „Wissen/Bibliothek/Generierungssprache/Sichern/Korrigieren" 等）。

> **de（ドイツ語）のトーンについて**: アプリ内 UI（`Localizable.xcstrings`）は一貫して親称の **du** 調で
> 訳されている（例: `onboarding.page2.body` の "kannst du auch..."）。本 §1-K の App Store 提出コピー
> （App 名・サブタイトル・プロモーションテキスト・説明文・What's New）は依頼どおり **敬称の Sie 調**で
> 統一してある（マーケティング文面として硬めの丁寧語を採用する一般的なドイツ語ストア表記に合わせた判断）。
> アプリ内 UI のトーンとは意図的に異なる点に留意（アプリ内訴求文言を Sie 調に統一するかどうかは別途判断）。

### K-1. ko（韓国語）ロケール

| 項目 | 値 | 文字数 |
|---|---|---|
| App 名（30字以内） | `Knowledge Base: AI 두 번째 뇌` | 25 / 30 |
| サブタイトル（30字以内） | `iPhone의 AI가 키우는 제2의 뇌` | 21 / 30 |
| プロモーションテキスト（170字以内） | 下記 | 170 / 170 |
| キーワード（100字以内・カンマ区切り・スペース禁止） | 下記 | 65 / 100 |

プロモーションテキスト:
```
읽고 잊어버리는 습관과는 이제 안녕. 저장만 하면 AI가 당신만의 백과사전을 계속 편집합니다. 요점은 한눈에, 깊이 알고 싶을 땐 채팅으로 근거와 함께. iPhone에 탑재된 AI(Apple Intelligence)의 힘을 최대한 활용하며, 모든 처리는 기기 안에서 끝나 데이터는 외부로 나가지 않습니다.
```

キーワード:
```
노트,메모,AI,지식관리,북마크,나중에읽기,요약,위키,백과사전,PKM,학습,정리,오프라인,기사저장,AI채팅,번역,지식
```
> ASO メモ: App 名に含む語（Knowledge Base / 두 번째 뇌）と重複する語はキーワードに入れていない。「AI」は
> zh-Hans/zh-Hant の前例（App 名に「AI」を含みつつキーワードにも残した）に合わせ、検索価値の高い単独語として
> 残してある。

説明文（한국어フル版、ja §1-F / zh-Hans J-1 の構成を踏襲）:
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
（1524 / 4000 字）

What's New（v1.1）:
```
Knowledge Base v1.1을 출시했습니다.
・한국어・Español・Deutsch를 포함해 총 7개 언어를 지원합니다. UI는 물론 AI가 생성하는 요약・개념 페이지・채팅 답변도 선택한 언어로 제공됩니다
・Apple Intelligence를 사용할 수 없을 때는 이유와 해결 방법을 배너로 안내합니다
・AI를 다시 사용할 수 있게 되면, 중단되었던 정리 작업이 자동으로 재개됩니다
의견이나 문제는 GitHub Issues로 알려주세요.
```

### K-2. es（スペイン語・中立）ロケール

App Store Connect の「スペイン語 (スペイン)」「スペイン語 (メキシコ)」いずれのロケールにも同じ原稿を登録できるよう、
地域限定語（vosotros・vos 等）を避けた中立スペイン語（tú 調、ラテンアメリカでも自然な語彙）で統一している。

| 項目 | 値 | 文字数 |
|---|---|---|
| App 名（30字以内） | `Knowledge Base: IA 2º Cerebro` | 29 / 30 |
| サブタイトル（30字以内） | `IA de tu iPhone, tu 2º cerebro` | 30 / 30 |
| プロモーションテキスト（170字以内） | 下記 | 165 / 170 |
| キーワード（100字以内・カンマ区切り・スペース禁止） | 下記 | 90 / 100 |

プロモーションテキスト:
```
Deja de leer y olvidar. Guarda un artículo y la IA arma tu enciclopedia. Puntos clave al instante, respuestas citadas en el chat. Todo en tu iPhone, sin salir de él.
```

キーワード:
```
nota,IA,conocimiento,marcador,resumen,wiki,PKM,offline,artículo,chat,traducir,enciclopedia
```
> ASO メモ: App 名に含む語（Knowledge Base / cerebro）と重複する語はキーワードに入れていない。「IA」は
> zh-Hans/zh-Hant の前例（App 名に「AI」を含みつつキーワードにも残した）に合わせ、検索価値の高い単独語として
> 残してある。ドイツ語・韓国語版と異なり文字数の制約が厳しいため（1 語あたりの文字数が長い）、en 版と同様に
> 12 語程度に絞ってある。

説明文（español フル版、ja §1-F / en J-3 の構成を踏襲、tú 調で統一）:
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
（3182 / 4000 字）

What's New（v1.1）:
```
Knowledge Base v1.1 ya está disponible.
・Ahora con 7 idiomas de interfaz, incluidos español, coreano y alemán. Los resúmenes, páginas de concepto y respuestas del chat generados por IA también siguen el idioma elegido
・Cuando Apple Intelligence no está disponible, un aviso explica el motivo y cómo solucionarlo
・Cuando la IA vuelve a estar disponible, el trabajo de organización pendiente se reanuda automáticamente
Tus comentarios y reportes de errores son bienvenidos a través de GitHub Issues.
```

### K-3. de（ドイツ語）ロケール

Sie 調（敬称）で統一。§1-K 冒頭の注記のとおり、アプリ内 UI の du 調とは意図的にトーンを分けている。

| 項目 | 値 | 文字数 |
|---|---|---|
| App 名（30字以内） | `Knowledge Base: KI, 2. Gehirn` | 29 / 30 |
| サブタイトル（30字以内） | `iPhone-KI formt Ihr 2. Gehirn` | 29 / 30 |
| プロモーションテキスト（170字以内） | 下記 | 162 / 170 |
| キーワード（100字以内・カンマ区切り・スペース禁止） | 下記 | 97 / 100 |

プロモーションテキスト:
```
Schluss mit Lesen und Vergessen. Speichern genügt – die KI baut Ihre Enzyklopädie. Kernpunkte sofort, Antworten mit Quellen im Chat. Alles läuft auf Ihrem iPhone.
```

キーワード:
```
notiz,KI,wissen,lesezeichen,zusammenfassung,wiki,PKM,offline,artikel,chat,übersetzen,enzyklopädie
```
> ASO メモ: App 名に含む語（Knowledge Base / Gehirn）と重複する語はキーワードに入れていない。「KI」は
> zh-Hans/zh-Hant の前例（App 名に「AI」を含みつつキーワードにも残した）に合わせ、検索価値の高い単独語として
> 残してある。ドイツ語は複合語が長いため、es 版と同様に 12 語程度に絞ってある。

説明文（Deutsch フル版、ja §1-F / en J-3 の構成を踏襲、Sie 調で統一）:
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
（3271 / 4000 字）

What's New（v1.1）:
```
Knowledge Base v1.1 ist da.
・Jetzt mit 7 Oberflächensprachen, darunter Deutsch, Koreanisch und Spanisch. Auch die von der KI erzeugten Zusammenfassungen, Konzeptseiten und Chat-Antworten folgen der gewählten Sprache
・Wenn Apple Intelligence nicht verfügbar ist, erklärt ein Banner den Grund und die Lösung
・Sobald die KI wieder verfügbar ist, wird unterbrochene Organisation automatisch fortgesetzt
Feedback und Fehlermeldungen sind über GitHub Issues willkommen.
```

---

## 2. アプリ内文言の修正・整合（監査結果）

リリース前に UI 文言と App Store コピーの用語を揃えるための監査。

### 2-A. 対応済み（本ブランチ）
- ✅ オンボーディング旧ブランド名「iKnow タブ」→「ナレッジタブ」に修正（唯一のリブランド漏れ）
- ✅ 本文常時表示化に伴う不要文言「タップして本文を展開」削除

### 2-B. 確認済み・良好
- アプリ内 UI 文言は全て `Localizable.xcstrings` キー経由でローカライズ済み。ハードコードされた英語表示文字列の漏れなし。
- タブ名: `ナレッジ` / `ライブラリ` / `AI チャット`。App Store コピーでも「ナレッジ」タブと表記を統一（本ドキュメント準拠）。

### 2-C. 任意の磨き込み候補（リリースブロッカーではない）
- **用語の統一**: 画面によって「概念ページ」「Wiki」「まとめ」「超まとめ」が混在。App Store では「概念ページ（Wiki）」に寄せた。アプリ内も主表記を1つに寄せると初見ユーザーに親切（例: 主=「まとめ」、補足=「概念ページ」）。
- **空状態コピー**: 初回起動直後（記事ゼロ）の各タブ空状態が、スクショ撮影・初見体験に直結。「保存するとここに知識が育ちます」等、行動を促す一文に統一すると良い。
- **オンボーディング**: 4 ページの本文は現行のままで App Store 説明文とトーンが揃っている。変更不要。

---

## 3. スクリーンショット撮影指示

### 3-A. 必要サイズ・仕様
| 項目 | 指定 |
|---|---|
| デバイス | **iPhone 6.9″（iPhone 17 Pro Max / 16 Pro Max）**: 1320 × 2868 px（縦） |
| 補助（任意） | 6.5″ 1284 × 2778 も用意すると古い機種の見栄えが安定 |
| 枚数 | 最小 3・最大 10。**下記 8 枚**を推奨、上位 3 枚で価値が伝わる順に |
| 形式 | PNG または JPEG、sRGB、アルファなし |
| 向き | 縦（Portrait）固定 |
| 文字 | 端末画像の上に**日本語キャプション帯**を重ねる（実機 UI だけでは訴求不足） |

### 3-B. 撮影前の準備（重要）
- **デモデータを仕込む**: 実際の英語/日本語記事を 15〜20 本保存し、AI 整理を完走させてから撮る（概念ページ・カテゴリ・チャット引用が“中身のある”状態に）。空の画面は撮らない。
- **Light モード**で撮影（和紙背景が最も映える）。1 枚だけ Dark を混ぜても良い。
- ステータスバー: 時刻 9:41、フル電波・フル充電に整える（クリーンな見栄え）。
- 個人情報・実在の固有名詞が不都合な場合はダミー記事に差し替え。

### 3-C. 8 枚の構成（順序 = 訴求の強い順）

| # | 画面 | 撮り方 | キャプション（帯・日本語） | サブ（任意・小さめ） |
|---|---|---|---|---|
| 1 | **ナレッジ フィード**（概念カード + 要点先出し） | 概念カードが 3〜4 枚見える位置。要点の箇条書きが読める状態 | **読んだことが、勝手にまとまる。** | AIがテーマごとに要点を先出し |
| 2 | **概念ページ（Wiki）詳細** | 大見出し + 要点 + 子トピック + 記事数が見える | **AIが、あなただけの百科事典を編さん。** | 関連ページへ自動リンク |
| 3 | **AI チャット（引用付き回答）** | 回答本文に番号引用 `[1]` + 下部に出典リスト | **あなたの知識に、根拠付きで答える。** | 引用をタップで元記事へ |
| 4 | **取り込み（共有シート / ＋メニュー）** | 共有シートに Knowledge Base、または＋の 5 モード | **URL・写真・PDF・音声。どこからでも。** | 保存はすぐ完了、整理は裏側で |
| 5 | **自動翻訳**（英語記事 → 日本語の概念ページ） | 英語ソース名 + 日本語の要点が並ぶ | **英語も中国語も、日本語で整理。** | 読める言語に、自動で |
| 6 | **カテゴリ/タグ自動整理**（ライブラリ or 分野カード） | 分野・タグが並ぶ一覧 | **分野もタグも、AIが自動で。** | 間違いはひとことで訂正 |
| 7 | **プライバシー（設定 or 説明画面）** | 「すべて端末内」を示す設定 or オンボーディング | **すべて端末内。データは外に出ない。** | 広告なし・トラッキングなし |
| 8 | **訂正/主導権**（記事詳細の「訂正」） | 訂正シート or 訂正バナー | **AIの間違いは、ひとことで直せる。** | 最終的な主導権はあなたに |

> 最低 3 枚に絞る場合は **#1・#3・#2** の順。App Store は最初の 1〜3 枚しか多くのユーザーが見ないため、#1 に最も強い価値（自動でまとまる）を置く。

### 3-D. キャプション帯のデザイン規則（全 8 枚共通）
- 位置: 端末画像の**上部 22%**に帯。帯の下に端末スクショ。
- 背景: 和紙色 `#F4EFE6` 系（`washiBackground`）。
- 見出し: **明朝体（serif）太字**、墨色 `#1C1B19`（`sumiInk`）、28〜34pt 相当。
- サブ: ゴシック細字、`sumiMid`、14〜16pt 相当。
- 装飾: 帯下端に 0.5px の墨罫線 or 青海波（`seigaiha`）の薄い連続文様を 1 本。過剰にしない。

---

## 4. クリエイティブ指示 prompt

生成AI（Midjourney / DALL·E / Firefly / Nano-Banana / Figma AI 等）に渡す prompt 集。**アートディレクションの一貫キーワード**を各 prompt に必ず含める。

### 4-0. アートディレクション（共通・全 prompt に前置き）
```
Art direction: refined Japanese "washi + sumi-e" aesthetic, ukiyo-e restraint.
Palette: warm off-white washi paper (#F4EFE6), sumi ink black (#1C1B19),
soft indigo accent (#3A4A63), muted stone grey. No neon, no gradients-heavy.
Typography feel: elegant Mincho (serif) headings. Motifs: seigaiha (青海波) waves,
thin hairline rules, generous negative space (ma / 間). Calm, premium, quiet,
literary. NOT flashy, NOT corporate-tech-blue, NOT cluttered.
```

### 4-1. App Store キービジュアル / フィーチャーグラフィック
```
[Art direction above]
A serene hero key visual for a personal-knowledge iPhone app called "Knowledge Base".
Concept: scattered paper articles gently flowing and being woven into a single,
glowing open book / encyclopedia — a "second brain". Ink-wash strokes suggest
connections between floating cards. Seigaiha wave pattern subtly in the lower third.
Vast washi negative space at top for a Mincho headline. Muted, meditative, premium.
16:9 and 1:1 crops. No text in the image. --style raw --ar 16:9
```

### 4-2. スクリーンショットの背景 / 枠テンプレート（8 枚共通の下地）
```
[Art direction above]
A minimal App Store screenshot BACKGROUND template (portrait 1320x2868).
Top 22%: solid warm washi band for a Japanese Mincho headline (leave empty).
Below: soft washi paper texture with a single thin sumi hairline separating the
caption band from the device area. A faint seigaiha wave motif along the very
bottom edge, low opacity. Nothing else — this is a clean stage for a device mockup.
No device, no UI, no text. --ar 1320:2868
```
> 実運用: この下地に、実機スクショ（3-C の各画面）を端末フレーム込みで合成し、上帯に 3-C のキャプションを Mincho で載せる。Figma/Sketch のテンプレ 1 枚を作り 8 枚展開が最速。

### 4-3. キャプション・タイポグラフィ指定（デザイナー/Figma AI 向け）
```
Design an 8-slide App Store screenshot caption system, Japanese-first.
Heading: bold Mincho serif, sumi ink (#1C1B19), 2 lines max, punchy.
Subhead: light sans, sumiMid grey, 1 line.
Background band: washi (#F4EFE6). One 0.5px sumi rule under the band.
Keep 60% of each slide for the device screenshot. Consistent baseline grid
across all 8. Provide the 8 headline/subhead pairs from RELEASE-MATERIALS §3-C.
Aesthetic: calm, literary, premium — like a quiet Japanese stationery brand.
```

### 4-4. アプリアイコン ブラッシュアップ（任意）
```
[Art direction above]
An iOS app icon for "Knowledge Base". A single elegant sumi-ink brushstroke forming
an open book or the kanji "知" (knowledge) abstractly, on warm washi paper.
Centered, balanced, works at small sizes. One indigo accent stroke max.
Timeless, premium, unmistakably Japanese-craft. Flat, no bevels, no gradients.
1024x1024, safe margins. --style raw
```

### 4-5. プロモーション動画（App Preview, 15–30秒・任意）絵コンテ prompt
```
Storyboard a 20s vertical App Preview for "Knowledge Base" (washi/sumi aesthetic):
0-3s  Share sheet → tap "Knowledge Base" (saving from Safari). Caption: 保存するだけ。
3-8s  Feed assembles: article cards flow into concept cards. Caption: AIが自動でまとめる。
8-13s Open a concept page: key points appear first, related links glow. Caption: 要点が、先に読める。
13-18s AI chat answers with a tappable [1] citation → jumps to source. Caption: 根拠付きで答える。
18-20s Logo on washi + seigaiha. Caption: あなただけの、第二の脳。
Transitions: soft ink-bleed dissolves. Music: quiet koto / ambient. No hard cuts.
```

### 4-6. 禁止事項（全生成物・negative prompt）
```
Avoid: neon colors, heavy 3D glass, generic blue SaaS gradients, stock-photo people,
cluttered UI dumps, emoji, drop shadows everywhere, AI-brain-with-circuits cliché,
English-only text, busy backgrounds competing with the device.
```

---

## 5. 提出前チェックリスト（抜粋）
- [ ] Privacy Policy / Support URL を実際に公開して疎通確認
- [ ] `PrivacyInfo.xcprivacy`（同梱済）と App Privacy 質問票の内容を一致させる（データ収集=なし / トラッキング=なし）
- [ ] スクショはデモデータ完走後・9:41・Light で撮影
- [ ] App 名/サブタイトル/キーワードの文字数が上限内
- [ ] 年齢制限 4+、暗号輸出 `ITSAppUsesNonExemptEncryption=false` を確認
- [ ] Apple Intelligence 非対応端末での挙動（fallback）を審査ノートに一言添える
