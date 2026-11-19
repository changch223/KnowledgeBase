# spec 104 — 入口の再構成（UI/UX 再設計 v2・第 2 段階）

> 先に `specs/REDESIGN-v2.md`（共通ルール）を読むこと。spec 103 が main にマージ済みであること。
> ブランチ: `104-navigation-search`（main から）/ リスク: 中 / 新 AI 呼び出し: なし / @Model 変更: `Article.lastOpenedAt` 追加のみ

## 目的
- 「探す」と「聞く」を 1 か所にまとめる（今は検索がライブラリに、質問が別タブにあり、ユーザーが先にどちらを使うか決めさせられている）。
- ホーム「ナレッジ」を **保存したものの置き場** として整える。日付で語らず、「最近保存したもの」と「AI が整理したトピック」を見せる。
- ＋と設定を、どのタブからも同じ場所（右上）で押せるようにする。

## 完成形のタブ

| タブ | key | ja | en | zh-Hans | zh-Hant | ko | es | de | 中身 |
|---|---|---|---|---|---|---|---|---|---|
| ナレッジ | `clip.tab.title`（**値は変えない**） | ナレッジ | Knowledge | 知识 | 知識 | 지식 | Conocimiento | Wissen | 最近保存したもの + トピック |
| ライブラリ | `library.tab.title`（値は変えない） | ライブラリ | Library | 资料库 | 資料庫 | 라이브러리 | Biblioteca | Bibliothek | 全記事の一覧 |
| 検索 | `search.tab.title`（新規） | 検索 | Search | 搜索 | 搜尋 | 검색 | Buscar | Suche | 検索 + AI に聞く + 最近聞いたこと |

「AI チャット β」タブは廃止。チャット機能（`ChatService`、会話画面、履歴、再生成）は検索タブの中に移す。**機能は削らない。**

---

## タスク

### T1. `Article.lastOpenedAt` 追加と記録
- `KnowledgeBase/Models/Article.swift` に `var lastOpenedAt: Date? = nil` を追加（コメントに spec 104 と「CloudKit lightweight 安全」）。
- `ArticleDetailView` の `.task`（無ければ追加）で `article.lastOpenedAt = .now` → `try context.save()`。失敗は `AppErrorReporter.shared` でログのみ（alert 不要）。
- **既存記事の一括補完**（全記事が「未開封」に見えるのを防ぐ）: `KnowledgeBaseApp` の起動処理（bootstrap、他の one-time migration と同じ場所）で、`UserDefaults` キー `spec104_lastOpenedBackfilled` が false のとき、`lastOpenedAt == nil` の全 Article に `lastOpenedAt = savedAt` を入れて保存し、フラグを true にする。fetch は `#Predicate { $0.lastOpenedAt == nil }`。
- 純関数: `FeedBuilder.isUnopened(_ article: Article) -> Bool`（`lastOpenedAt == nil`）。
- テスト: `FeedBuilderTests` に `isUnopened` 1 件。

### T2. タブ構成の変更
ファイル: `KnowledgeBase/KnowledgeBaseApp.swift`
- `enum AppTab`: `case chat` を `case search` に置き換える（`knowledgeClip`, `library` はそのまま）。
- `TabView(selection:)` を iOS 18+ の `Tab` API に書き換える:
  ```swift
  TabView(selection: $selectedTab) {
      Tab("clip.tab.title", systemImage: "newspaper.fill", value: AppTab.knowledgeClip) { KnowledgeClipView() }
      Tab("library.tab.title", systemImage: "books.vertical", value: AppTab.library) { ArticleListView() }
      Tab("search.tab.title", systemImage: "magnifyingglass", value: AppTab.search, role: .search) { SearchTabView() }
  }
  ```
  （既存の各 View に付いている modifier・環境注入はそのまま引き継ぐ。`accessibilityIdentifier` は `tab.knowledgeClip` / `tab.library` / `tab.search`。）
- 181 行付近 `pendingRegenerateRequest` の監視: `selectedTab = .chat` → `selectedTab = .search`。
- `.chat` を参照している箇所を全部 grep して置き換える（`grep -rn "\.chat\b" KnowledgeBase --include=*.swift` で AppTab 由来のものだけ。`ChatMode` 等と混同しない）。

### T3. 会話画面の切り出し `ChatConversationView`
- `KnowledgeBase/Views/ChatTabView.swift` を `ChatConversationView.swift` にリネーム（型名も変更）し、以下に作り替える:
  - `init(sessionID: UUID, initialQuestion: String? = nil, onOpenArticle: @escaping (Article) -> Void)`
  - 自前の `NavigationStack` と `navigationPath` を削除（親の検索タブのスタックに push される）。`.navigationDestination` 群も削除（親に移す）。
  - `pinnedSessionID` / `currentSession` の算出を、渡された `sessionID` に固定する。`allSessions.first` へのフォールバックは削除。session が消えたら（全削除後など）`dismiss()`。
  - 履歴サイドバー（`showSidebar` / `ChatHistorySidebar` の sheet / 左上の `chat.toolbar.sidebar`）を削除。履歴は検索タブのトップに出す（T4）。
  - `initialQuestion` があり、session のメッセージが 0 件なら `.task` で 1 回だけ `inputText = initialQuestion` → `sendQuestion()`。二重送信しないよう `@State hasSentInitial` で守る。
  - `.navigationTitle` は session のタイトル（無ければ `chat.sidebar.untitled`）、`.inline`。
  - `ChatMessageRow(onArticleLinkTap:)` には受け取った `onOpenArticle` を渡す（T6 でプレビュー経由になる）。
  - clarification の `onReceive` 2 つ、`AppleIntelligenceBanner`、`isThinking` バナー、`ChatInputField`、擬似 streaming はそのまま残す。
  - `pendingRegenerateRequest` の `onChange` はここから削除（T4 の検索タブへ移す）。
- `ChatHistorySidebar.swift` は T4 で「最近聞いたこと」の行表示に流用できる部分があれば流用し、未使用になれば削除。

### T4. 検索タブ `SearchTabView`
- 新規: `KnowledgeBase/Views/SearchTabView.swift`
- 構造:
  ```
  NavigationStack(path: $path)
    List
      [query 空]  Section「最近聞いたこと」: ChatSession を lastMessageAt 降順で最大 20 件（タップで会話を開く、スワイプ削除は既存 ChatHistorySidebar と同じ）
      [query あり] 1 行目: 「“<query>” を AI に聞く」行（sparkles アイコン）
                   Section「トピック」: SearchService.searchConceptPages(query:in:) 上位 5 件
                   Section「記事」: SearchService.search(query:in:) 上位 30 件（ArticleRow(searchQuery:)）
    .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
    .onSubmit(of: .search) { ask(query) }
  ```
- `ask(_ q: String)`: `serviceContainer.chatService?.createSession()` で新規 session を作り、`path.append(ChatConversationDestination(sessionID: id, initialQuestion: q))`。
- 新規 `struct ChatConversationDestination: Hashable { let sessionID: UUID; let initialQuestion: String? }` を同ファイルに。
- `navigationDestination`: `ChatConversationDestination` → `ChatConversationView(sessionID:initialQuestion:onOpenArticle: { path.append($0) })` / `Article.self` → `ArticleDetailView(article:embedNavigationStack: false)` / `ConceptPageDetailDestination` → `ConceptPageDetailLoader` / `KnowledgeGraphFullScreenDestination` は不要なら付けない。
- AI が使えないとき（`serviceContainer.availabilityChecker?.unavailabilityReason != nil`）: 「AI に聞く」行を無効化し、副題に新キー `search.ask.unavailable` を表示。トピック・記事の検索結果はいつもどおり出す。
- `pendingRegenerateRequest` の監視をここへ移す: 値が来たら `ask(req.question)` 相当（新 session + 初回質問）→ `serviceContainer.pendingRegenerateRequest = nil`。
- 検索対象の @Query: 記事は `@Query(sort: \Article.savedAt, order: .reverse)`、トピックは `!isHidden`。`ArticleListView` の `filteredArticles` / `filteredConceptPages`（213〜240 行付近）と同じ呼び方に揃える。
- 新キー（7 ロケール）:

| key | ja | en | zh-Hans | zh-Hant | ko | es | de |
|---|---|---|---|---|---|---|---|
| `search.tab.title` | 検索 | Search | 搜索 | 搜尋 | 검색 | Buscar | Suche |
| `search.prompt` | 記事やトピックを探す・聞く | Search or ask | 搜索或提问 | 搜尋或提問 | 검색하거나 질문하기 | Busca o pregunta | Suchen oder fragen |
| `search.ask.row %@` | 「%@」を AI に聞く | Ask AI “%@” | 向 AI 提问“%@” | 向 AI 提問「%@」 | AI에게 “%@” 질문 | Preguntar a la IA “%@” | KI fragen: „%@“ |
| `search.ask.unavailable` | AI が使えないため、検索だけできます | AI is unavailable, so only search works | AI 不可用，只能搜索 | AI 無法使用，只能搜尋 | AI를 사용할 수 없어 검색만 가능합니다 | La IA no está disponible; solo puedes buscar | KI nicht verfügbar – nur Suche möglich |
| `search.section.recentQuestions` | 最近聞いたこと | Recent questions | 最近的提问 | 最近的提問 | 최근 질문 | Preguntas recientes | Letzte Fragen |
| `search.section.topics` | トピック | Topics | 主题 | 主題 | 주제 | Temas | Themen |
| `search.section.articles` | 記事 | Articles | 文章 | 文章 | 글 | Artículos | Artikel |
| `search.empty.recent` | 知りたいことを入力すると、保存した記事から答えます | Type a question and get answers from what you saved | 输入问题，从你保存的文章里找答案 | 輸入問題，從你儲存的文章裡找答案 | 질문을 입력하면 저장한 글에서 답합니다 | Escribe una pregunta y responderé con lo que guardaste | Stelle eine Frage – die Antwort kommt aus deinen gespeicherten Inhalten |

### T5. ライブラリの整理
ファイル: `KnowledgeBase/Views/ArticleListView.swift`
- `.searchable`（100 行付近）と検索結果モードの分岐を削除。検索は検索タブに一本化。`filteredConceptPages` 等、検索専用になったコードは削除。
- 分野チップ: 新規純関数 `FeedBuilder.shouldShowCategoryChips(counts: [Int]) -> Bool`（最多分野の記事数 ÷ 全体 ≥ 0.7 なら false。チップが 1 個以下なら false）。false のとき分野チップ行を出さない（現状「テクノロジー 341 / 次点 21」で絞り込みとして機能していない）。タグチップはそのまま。テスト 3 件（[341,21]→false / [40,30,30]→true / [10]→false）。
- 先頭に「未開封のみ」トグルチップ（新キー `library.filter.unopened` ja「未開封」/ en「Unopened」/ zh-Hans「未打开」/ zh-Hant「未開啟」/ ko「안 연 글」/ es「Sin abrir」/ de「Ungeöffnet」）。ON で `FeedBuilder.isUnopened` の記事だけ。件数は出さない。
- 右下 `FABButton`（92 行付近）を削除し、T7 のツールバーに置き換え。

### T6. 出典プレビュー
- 新規: `KnowledgeBase/Views/CitationPreviewSheet.swift`
  - `CitationPreviewSheet(article: Article, onOpen: () -> Void)`
  - 表示: タイトル（`TitleCleaner`）/ 保存元・日時（`ArticleSourceLabel` + `SavedAtFormatter`）/ `essence`（無ければ `enrichment.summary`）/ ボタン「記事を開く」（新キー `citation.preview.open` ja「記事を開く」/ en「Open article」/ zh-Hans「打开文章」/ zh-Hant「開啟文章」/ ko「글 열기」/ es「Abrir artículo」/ de「Artikel öffnen」）
  - `.presentationDetents([.height(280), .medium])`、`.presentationDragIndicator(.visible)`
- `ChatMessageRow`: 番号リンク（71〜75 行の `OpenURLAction`）と `CitationSourcesSection` の行タップで、直接 `onArticleLinkTap` を呼ばず `@State previewArticle: Article?` に入れて `.sheet(item:)` でプレビュー。「記事を開く」で sheet を閉じてから `onArticleLinkTap?(article)`。
- `ConceptPageDetailView`: 要点の出典（366 行付近の `NavigationLink(value: article)`、spec 089）を Button に変えて同じプレビューを出す。「記事を開く」は `@State openedArticle: Article?` + `.navigationDestination(item: $openedArticle)` で push。

### T7. ホーム「ナレッジ」の再構成とツールバー統一
ファイル: `KnowledgeBase/Views/KnowledgeClipView.swift`、`KnowledgeBase/Services/FeedBuilder.swift`、`KnowledgeBase/Views/ArticleListView.swift`
- 構成（上から）:
  1. `ProcessingInlineStatus`（spec 103）
  2. 「最近保存したもの」横棚: 新規 `FeedBuilder.recentSaves(articles:limit: 8)`（savedAt 降順、`isObsolete` を除く、処理中も含む）。既存 `newArticleShelf`（未概念化のみ）の代わりに使う。カードは既存 `ArticleShelfCard` に、未開封なら左上に小さな藍の点（`DS.Color` のアクセント、直径 7pt、`accessibilityLabel` は `library.filter.unopened`）を追加。見出しは既存キー `feed.new.title` の値を変更（下表）。
  3. 「トピック」縦カード: 現行どおり（`clip.section.concepts` は spec 103 で「トピック」に変更済み）。
- 初回（記事 0 件）: 新規 `FirstSaveGuide` を表示し、トピックの空表示（`SeigaihaEmptyState(message: "clip.empty.concepts")`）は出さない。内容: 見出し + 保存方法 3 つ（① 他のアプリの共有ボタン →「Knowledge Base」② 右上の ＋ ③ Safari 拡張 → 既存 `SafariSetupView` への NavigationLink）。未使用の `feedEmptyState`（241 行付近、参照ゼロ）は削除。
- ツールバー（ナレッジ・ライブラリ共通）: `topBarTrailing` に ＋（`plus`、`accessibilityIdentifier("toolbar.addArticle")`、`AddArticleSheet` を開く）と既存 `AvatarMenu()`。ナレッジの右下 `FABButton`（181 行付近の overlay）を削除。
- `V3MigrationTooltip`（「知識 Clip / ライブラリ / AI チャット の 3 つにまとめました」）は表示をやめる（コードごと削除してよい）。
- 文言（値の変更・新規）:

| key | ja | en | zh-Hans | zh-Hant | ko | es | de |
|---|---|---|---|---|---|---|---|
| `feed.new.title`（値変更） | 最近保存したもの | Recently saved | 最近保存 | 最近儲存 | 최근 저장 | Guardado recientemente | Zuletzt gespeichert |
| `firstSave.title` | 保存したものが、ここで整理されます | What you save gets organized here | 你保存的内容会在这里整理 | 你儲存的內容會在這裡整理 | 저장한 것이 여기서 정리됩니다 | Lo que guardes se organiza aquí | Was du speicherst, wird hier geordnet |
| `firstSave.share` | 他のアプリの共有ボタンから「Knowledge Base」を選ぶ | Tap Share in any app and choose Knowledge Base | 在任意应用点“分享”，选择 Knowledge Base | 在任何 App 點「分享」，選擇 Knowledge Base | 다른 앱의 공유 버튼에서 Knowledge Base 선택 | Toca Compartir en cualquier app y elige Knowledge Base | In jeder App auf Teilen tippen und Knowledge Base wählen |
| `firstSave.plus` | 右上の ＋ から URL やメモを追加 | Add a URL or note with + at the top right | 点右上角 + 添加网址或笔记 | 點右上角 + 新增網址或筆記 | 오른쪽 위 +로 URL이나 메모 추가 | Añade una URL o nota con + arriba a la derecha | Mit + oben rechts URL oder Notiz hinzufügen |
| `firstSave.safari` | Safari 拡張で、見ているページをそのまま保存 | Save the page you're reading with the Safari extension | 用 Safari 扩展保存正在看的网页 | 用 Safari 延伸功能儲存正在看的網頁 | Safari 확장으로 보고 있는 페이지 저장 | Guarda la página que lees con la extensión de Safari | Aktuelle Seite mit der Safari-Erweiterung sichern |

### T8. 旧文言の整理
- `onboarding.page5.body`（「AI チャットタブで…」）を検索タブ前提に書き換え（ja「検索タブで質問すると、保存した記事だけを根拠に答えます。答えには番号付きの出典が付き、元記事へすぐ戻れます。」）。他 6 言語も同じ意味に更新。
- `chat.tab.title` は会話画面の汎用タイトルとして使わないなら参照ゼロを確認して削除。残すなら値から「β」を外す。
- `chat.sidebar.section.general`「AI チャット」等、画面に残る文言で「タブ」を前提にしたものが無いか grep（`タブ` `チャット`）して報告。

### T9. UI テスト更新
ファイル: `KnowledgeBaseUITests/V3RedesignUITests.swift`
- `tab.chat` → `tab.search`。チャット空状態のテストは「検索タブを開くと検索欄と『最近聞いたこと』が出る」に書き換え。
- `fab.addArticle` → `toolbar.addArticle`。
- 3 タブ表示テストの期待値を新タブに。

---

## 受け入れ基準
- [ ] タブが「ナレッジ / ライブラリ / 検索」。検索は分頁列の右端に独立して表示される（iOS 26 の search role）
- [ ] 検索欄に入力すると、トピックと記事がその場で出る。Return か「AI に聞く」行で会話画面に進み、従来どおり番号付き出典で回答される
- [ ] 検索タブのトップに過去の会話が並び、開くと続きから話せる。スワイプで削除できる
- [ ] 保存済み回答の「再生成」から、検索タブの新しい会話に移って自動で質問される（spec 045 の動線維持）
- [ ] 出典番号・出典リスト・トピックの要点の出典をタップすると、まず下からプレビューが出る。「記事を開く」で記事詳細へ
- [ ] ホームが「最近保存したもの」→「トピック」の順。未開封の記事に点が付き、開くと消える。アップデート直後に既存記事へ点が付かない
- [ ] 記事 0 件のとき保存方法の案内が出る
- [ ] ＋と設定がナレッジ・ライブラリの右上にある。右下の浮動ボタンが無い
- [ ] AI が使えない端末で、検索は動き「AI に聞く」は理由付きで無効
- [ ] 新規・変更キーが 7 ロケールすべてで値を持つ
- [ ] ビルド成功・ユニットテスト全件成功・新規 warning なし。UI テストは更新済み（実行結果を報告）

## 実機で確認（ユーザー）
- CloudKit 同期後も `lastOpenedAt` が端末間で崩れない（別端末で開いた記事の点が消える）
- 長い会話を開いたときのスクロール・キーボード（会話画面が検索タブのスタック内に入ったため）
