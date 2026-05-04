# Spec 005 — 詳細画面統合 + 下部ステータスバー + 表示品質改善

**Status**: Draft
**Branch**: `005-detail-status-ui`
**Created**: 2026-05-04
**Authors**: Chia-Wei

## なぜ (Why)

spec 001-004 が動き出した結果、いくつかの摩擦が顕在化した。

1. **タップ後の遷移が分裂している**
   本文抽出に成功した記事はアプリ内 Reader View に行く一方、それ以外は外部 Safari View Controller に直行する。同じ「保存した記事をタップする」操作で、得られる体験が記事ごとに違う。
   ユーザーは記事を追加した直後にタップすることが多く、その時点では body 抽出も knowledge 抽出も完了していないため、ほぼ毎回 SVC に飛ばされ、せっかく抽出した知識サマリを見る導線が無い。

2. **記事を保存した後、何が動いているのか分からない**
   保存直後は enrichment → body → knowledge の 3 段階が裏で走るが、UI 上は何も表示されない。
   「保存した直後にすぐ knowledge を見たいのに、いつ抽出が終わるか分からない」「失敗してるのか、まだ走ってるのか分からない」という体験になっている。

3. **日本語サイトで文字化けする (mojibake)**
   atmarkit のような Shift-JIS 配信のサイトを共有すると、enrichment 後に表示される canonical title / summary が完全に化ける。
   UTF-8 → ISO-Latin1 のフォールバックしかしていなかった。

4. **タイトルが意図せず差し替わる**
   KFC のクーポンページを保存すると、最初は「クーポン...」と長いタイトルだったのに、enrichment 完了後に `<title>KFC` だけに上書きされ、何のクーポンだったか分からなくなった。
   保存時にユーザーが見たタイトルの方が、保存意図に近いはず。

これらは個別の bug fix で済むサイズだが、3 つ合わせて「保存後の体験」を作り直す価値があるので 1 つの spec として扱う。

## ゴール

- 記事一覧で記事をタップしたら、必ず**アプリ内詳細画面**が開く。SVC は詳細画面内の「元記事を開く」ボタンからのみ起動する。
- 詳細画面では、抽出済の知識・本文・サムネ・元記事リンクが 1 画面に並ぶ。抽出未完了の要素は「取得中」プレースホルダで明示する。
- 一覧画面の下部に、現在裏で走っている処理 (enrichment / body / knowledge) を恒常的に表示する。何も走っていないときは非表示。
- Shift-JIS / EUC-JP / ISO-2022-JP の HTML を正しく decode する。
- ユーザーが共有したときのタイトルを優先表示する。`<title>` で上書きしない。

## 非ゴール

- 詳細画面に編集機能を持たせること (タグ付け、メモ追加 etc) — 将来 spec
- 通知や集計画面、ダッシュボード — 将来 spec
- macOS / iPad 専用レイアウト最適化 — iPhone 縦持ちで問題なく使えれば足りる

## ユーザストーリー

### US1 (P1) — 保存した記事をタップして知識・本文・元記事を 1 画面で見る

**As a** 記事を共有から保存したユーザー
**I want** 保存した記事をタップしたときに、アプリ内で全部見たい
**So that** SVC で外部に飛ばずに、抽出された知識サマリ・本文を即読める

#### 受け入れ基準

- 一覧で記事をタップする → アプリ内 ArticleDetailView が sheet で開く
- ArticleDetailView 内では:
  - サムネイル (enrichment.ogImageURL) が取得済なら表示
  - タイトル (Article.title 優先、空なら canonicalTitle)
  - 知識サマリ (essence / summary / keyFacts / entities) が取得済なら表示。未取得なら「AI が記事を解析中...」プレースホルダ
  - 本文段落が取得済なら表示。未取得なら「本文を取得中...」プレースホルダ
  - 「元記事を開く」ボタンを画面下部に固定
- 「元記事を開く」を押すと SVC が開く
- 「完了」を押すと sheet が閉じる
- ArticleListView から SVC へ直接遷移する経路は廃止する

### US2 (P1) — 裏で何が走っているか一目で分かる

**As a** 記事を保存した直後のユーザー
**I want** 何が処理されているのか、どの記事が処理中か、画面下に常に見えてほしい
**So that** いつ knowledge が見られるようになるか予測がつく

#### 受け入れ基準

- 一覧画面の下部に固定 `BottomStatusBar` を表示
- 何も走っていないとき (`monitor.isIdle`) は非表示
- 1 件以上走っているとき:
  - スピナー
  - フェーズ名 (取得中 / 本文抽出中 / 知識抽出中)
  - 対象記事のタイトル (1 行 truncate middle)
  - 並列で複数走っているときは `+N` バッジで残件数
- 表示優先度: knowledge > body > enrichment > 同 phase 内は最新開始
- 進捗表示の追加・除去はアニメーション (0.2s easeInOut) で滑らかに
- 詳細画面が開いていても下部バーは表示し続ける必要はない (一覧画面のみで OK)

### US3 (P2) — 日本語サイトの文字化け解消

**As a** atmarkit / @IT / Yahoo!ニュース など Shift-JIS 配信のサイトを保存するユーザー
**I want** タイトル・要約が文字化けせず日本語で読めること
**So that** 古い日本語サイトでも信頼して保存できる

#### 受け入れ基準

- HTTP `Content-Type: charset=...` ヘッダから encoding を検出する
- ヘッダに無ければ HTML 先頭の `<meta charset="...">` または `<meta http-equiv="Content-Type" content="...; charset=...">` から検出する
- どちらも無ければ UTF-8 → Shift-JIS → EUC-JP の順でフォールバック
- 対応 encoding: UTF-8 / Shift-JIS (CP932 / Windows-31J / sjis) / EUC-JP / ISO-2022-JP / ISO-8859-1 / Windows-1252 / US-ASCII
- atmarkit (`https://atmarkit.itmedia.co.jp/`) を保存して enrichment 完了後、canonical title が日本語で読める
- 既に文字化けして保存された記事の修復は対象外 (新規保存からのみ正しく動く)

### US4 (P2) — 共有時タイトルを尊重

**As a** Web 記事を共有から保存するユーザー
**I want** 保存時に見たタイトルがそのまま残ってほしい
**So that** 「KFC」みたいな短いタイトルに勝手に上書きされない

#### 受け入れ基準

- ArticleRow / ArticleDetailView の表示タイトルは:
  1. Article.title (Share-time に NSExtensionItem.attributedTitle から取得した値)。trim 済が空でない、かつ URL 文字列そのものでなければ採用
  2. 1 が条件を満たさない場合のみ enrichment.canonicalTitle にフォールバック
  3. それも無ければ Article.title を生のまま
- 既存の挙動 (canonicalTitle 優先) は廃止
- enrichment.canonicalTitle 自体は引き続き保存する (将来の検索や表示の選択肢として残す)

## 機能要件

| ID | 要件 | 由来 |
|---|---|---|
| FR-001 | 一覧の記事行タップは `ArticleDetailView` を sheet で開く。SVC への直接遷移は行わない | US1 |
| FR-002 | `ArticleDetailView` は thumbnail / title / 知識サマリ / 本文 / 「元記事を開く」を縦に並べる | US1 |
| FR-003 | 知識・本文が未取得の場合、`ArticleDetailView` は ProgressView + プレースホルダ文字列を表示 | US1 |
| FR-004 | `ProcessingMonitor` (`@Observable`) が enrichment / body / knowledge の active task を集約する | US2 |
| FR-005 | 各 Service は処理開始時に `monitor.start(phase, articleID:title:)`、終了時に `monitor.finish(articleID:)` を呼ぶ | US2 |
| FR-006 | `BottomStatusBar` は `monitor.current` の有無で表示 / 非表示を切り替え、phase に応じて localized 文字列を出す | US2 |
| FR-007 | `MetadataParser.decodeHTML(data:contentType:)` が HTTP / HTML meta / fallback の順に encoding を検出する | US3 |
| FR-008 | `ArticleEnrichmentService.fetchAndParse` は `decodeHTML` 経由で HTML を取得する | US3 |
| FR-009 | `ArticleRow` / `ArticleDetailView` の `displayTitle` は Article.title を最優先する | US4 |
| FR-010 | spec 003 の `ReaderView` は廃止しない (互換のため残す) が、routing からは外す | US1 |
| FR-011 | main app と Share Extension は **同一の Schema 定義** (`SharedSchema.all`) を使用する | live-update |
| FR-012 | `ArticleListView` / `ArticleDetailView` は **5 つの並列メカニズム** で UI 更新を保証: (a) `RefreshTrigger` Observable、(b) `ModelContext.didSave`、(c) `NSManagedObjectContextObjectsDidChange`、(d) `NSPersistentStoreRemoteChange`、(e) Detail 画面のみ Timer 1秒ポーリング (完了状態でないときのみ) | live-update |
| FR-013 | scenePhase が `.active` に遷移したら `refreshTick` を increment する (前景復帰時の保険) | live-update |
| FR-014 | `KnowledgeExtractionService` / `ArticleEnrichmentService` / `BodyExtractionService` は同一 article への重複呼び出しを抑止 (existing task の値を待つだけ) | duplication |
| FR-015 | `KnowledgeTreeApp.bootstrap()` は二重実行を防止 (`serviceContainer.knowledgeService != nil` で guard) | duplication |

## 成功基準 (Success Criteria)

- SC-001: atmarkit の URL を共有保存して enrichment 完了後、文字化けせず日本語で title が読める
- SC-002: 任意の記事を保存して 0.5 秒以内に下部 BottomStatusBar に「メタデータ取得中: <タイトル>」が出る
- SC-003: 一覧で記事をタップして 0.5 秒以内に ArticleDetailView が開く (body / knowledge の状態に依存しない)
- SC-004: KFC ページを保存して enrichment 完了後も、最初に見えていたタイトルが維持されている
- SC-005: knowledge 抽出が succeeded の記事を ArticleDetailView で開くと、essence / summary / keyFacts / entities が全部見える
- SC-006: enrichment が走っていないときは BottomStatusBar が画面に存在しない (タブバーや tab indicator が干渉しない)
- SC-007: Chrome から共有した記事の Detail 画面を開きっぱなしにし、サムネ / 本文 / 知識サマリが **アプリを閉じずに** 順次表示される (Live update)
- SC-008: 同一 article への knowledge 抽出が複数経路から呼ばれても `truncating body` ログが 1 回しか出ない (重複抑止)

## 依存・前提

- spec 001-004 が稼働済 (Article / Enrichment / Body / Knowledge schema、3 service chain)
- iOS 26 SwiftUI 6 / SwiftData / `@Observable` (Observation framework)
- `LocalizedStringKey` での日本語 first ローカライズ (`Localizable.xcstrings`)

## アサンプション

- ProcessingMonitor は in-memory only (永続化しない)。アプリ再起動後は backfill が再開し、再びそこから報告する。
- 並列 active task の最大数は backfill 直後に最大 (記事数分) になる。`+N` バッジが大きい数字になっても許容 (3 桁を超えるユーザーは想定外)。
- BottomStatusBar 自体はタップに反応しない。詳細を見たい場合は対象記事を一覧でタップする。

## エッジケース

- 共有した直後に同じ記事をタップ → ArticleDetailView は開く。中身は全プレースホルダ → enrichment 進行に応じて埋まっていく
- knowledge が `.skipped` (Apple Intelligence 利用不可) → 「Apple Intelligence が利用できないためスキップしました」を表示
- body が `.failed` / `.permanentlyFailed` → 「本文を抽出できませんでした。元記事を開いてください。」 を表示
- enrichment が `.permanentlyFailed` → サムネ無し、canonical title 無し、本文も無し → ユーザーは「元記事を開く」のみで対応

## ロールアウト

- spec 005 は spec 001-004 と同じ commit / 同じビルドで一括投入する (個別 feature flag を立てない)
- 既存ユーザーがいないため migration 配慮は不要

## 非機能

- 一覧画面の再レンダリング負荷: BottomStatusBar の更新は monitor.current の id 変更時にだけ animation を走らせる
- メモリ: ProcessingMonitor は active task しか保持しない (履歴を残さない)
