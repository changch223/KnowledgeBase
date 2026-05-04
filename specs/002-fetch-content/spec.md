# Feature Specification: 本文取得・メタデータエンリッチメント

**Feature Branch**: `002-fetch-content` *(計画中。Round 1 of spec 001 の未コミット状態が解消されてから実ブランチを切る)*
**Created**: 2026-05-04
**Status**: Draft
**Input**: ユーザー説明: "spec 001 で保存された記事ごとに、URL を 1 回 HTTP fetch してページ HTML から canonical title / meta description / OG image を抽出し、Article に紐づけて保存する。一覧画面はサムネイル付きの enriched カードで表示できるようにする。本文 (article body) の抽出は spec 003 に分離 (HTML キャッシュは本 spec で行うので spec 003 は再 fetch 不要)。"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 保存後に自動でメタデータが取得され一覧が enriched になる (Priority: P1)

ユーザーが Share Sheet 経由で記事を保存した直後、KnowledgeTree がバックグラウンドで URL を 1 回 fetch し、HTML から canonical title・meta description・OG image を抽出する。アプリの一覧画面は、それまで「URL ホスト名 + URL」だけだったカードが、サムネイル + canonical タイトル + 説明文の付いた enriched カードに変わる。ユーザーは「これは何の記事か」をリスト上で一目で判断できる。

**Why this priority**: spec 001 の素朴な一覧 (タイトル + URL のみ) は機能としては成立するが、見返したときに「どんな内容だったか」を思い出すのに記事を開く必要があり摩擦が大きい。enrichment があるとリストを眺めるだけで内容を思い出せ、Constitution Principle V「シンプルで落ち着いた UX」と Principle II「軽快な検証ループ」の両方に直接効く。

**Independent Test**: 1 件の記事を Share Sheet で保存 → 数秒待つ → アプリを開く → 一覧の最上段にサムネイル + canonical タイトル + description が表示されている。元の保存時タイトル (URL ホスト等のフォールバック) は使われていない。

**Acceptance Scenarios**:

1. **Given** ユーザーが新規記事を保存し、Wi-Fi 接続済みである、**When** バックグラウンドの enrichment ジョブが完了する (5 秒以内目安)、**Then** 一覧の該当行が canonical title + description + サムネイルで表示される。
2. **Given** Article の保存時 title が「URL ホスト名」のフォールバック値だった、**When** enrichment が成功した、**Then** 一覧に表示される title は HTML の `<title>` 値 (canonical) に置き換わる。元の savedAt は変更されない。
3. **Given** OG image が見つかった、**When** 一覧を表示する、**Then** 行先頭にサムネイル (角丸正方形、72×72pt 程度) が表示される。OG image が無い場合はサムネイル領域は表示しない (空白を残さず行高を縮める)。

---

### User Story 2 - 取得失敗時のフォールバック (Priority: P2)

ネットワーク接続がない・サーバーが応答しない・HTML が壊れている等で enrichment に失敗した場合、ユーザーには静かに spec 001 の元情報 (Article.title + URL) で表示が継続される。失敗状態はリスト行に小さなインジケータ (例: 雲に斜線のアイコン) で表示され、タップ可能な情報源として残る。再試行は自動 (バックオフ) で行われる。

**Why this priority**: 「ネットワーク失敗するとリストが空白になる」「保存ボタンが無反応」のような体験は、Constitution Principle V (落ち着いた UX) と Principle I (ローカルファースト) を最も損なう。Enrichment はあくまで上乗せ機能であり、失敗しても spec 001 の最低保証は崩れない設計を明示的に保つ必要がある。

**Independent Test**: 機内モードで 1 件保存 → アプリを開く → 一覧に Article.title + URL がフォールバック表示され、行先頭に小さな「未取得」アイコンが表示される。機内モードを解除して数分待つ → 自動再試行で enrichment が完了し、表示が enriched カードに置き換わる。

**Acceptance Scenarios**:

1. **Given** ネットワークが切断されている、**When** 新規記事を保存する、**Then** 一覧に Article.title + URL の最低表示で行が表示され、「未取得」インジケータが付く。アプリ全体はクラッシュ・スピナー固着・空白等の不安喚起 UX を起こさない。
2. **Given** 失敗状態の記事がある、**When** ネットワーク復帰後に backoff 再試行が成功する、**Then** 「未取得」インジケータが消え、enriched カードに更新される。
3. **Given** 連続で失敗した記事がある (例: 404 / DNS NXDOMAIN / 30 秒タイムアウト)、**When** 既定の最大再試行回数 (3 回) を超えた、**Then** 自動再試行は停止し、行は「取得失敗」インジケータで表示される。ユーザーが手動で再試行するための導線は spec 003 以降で扱う (本 spec では未実装)。

---

### Edge Cases

- **HTTP 200 だが HTML ではない (PDF / 画像 / JSON 等)**: enrichment 失敗扱い。Article.title + URL のフォールバック表示。「取得失敗」インジケータ付き。
- **HTTPS 証明書エラー**: enrichment 失敗扱い (ATS エラー)。Apple 推奨に従い HTTP / 信頼できない HTTPS には接続しない。
- **リダイレクトループ / 過度なリダイレクト**: URLSession 既定 (10 リダイレクト) を超えたら失敗。
- **巨大 HTML (5 MB 超)**: ダウンロードを途中で中止し失敗扱い (帯域・メモリ保護)。実用上のページはこの上限を超えない。
- **`<title>` が空 / 異常に長い (1000 文字超)**: 既存の Article.title フォールバックを使う。長すぎる場合は 200 文字で切り詰めて保存。
- **OG image URL が相対パス**: ベース URL を使って絶対 URL に解決する。解決できない場合はサムネイルなし。
- **OG image URL の HTTPS 化**: schema 不一致 (`http:` の og:image を `https:` ページから読む等) は ATS で失敗するため、その場合はサムネイルなし。
- **同一 URL を spec 001 で重複拒否されたケース**: enrichment ジョブは新規 Article 挿入時にのみキューイングされるため、重複拒否されたケースでは enrichment は走らない (既存 Article に対する手動再取得は spec 003 以降)。
- **Share Extension 経由の保存後すぐにアプリ強制終了**: enrichment ジョブはアプリ本体プロセスでのみ実行される。Share Extension は保存だけ行い、enrichment は次回アプリ起動時にキューが処理される (Principle V — 共有が止まらない)。
- **`Localizable.xcstrings` の未取得 / 失敗ラベル**: 「取得中」「未取得」「取得失敗」を新規キーで日本語登録 (Principle VII)。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: アプリは新規 `Article` 挿入時に、その URL に対する HTML fetch ジョブをバックグラウンドキューに登録する。
- **FR-002**: HTML fetch は HTTPS のみを許可し、HTTP / 信頼できない証明書は失敗扱いとする (App Transport Security 既定遵守)。
- **FR-003**: HTTP リクエストには KnowledgeTree 専用の固定 User-Agent (例: `KnowledgeTree/1.0 (iOS)`) のみを付与する。Cookie・Authorization ヘッダ・カスタムトラッキングパラメータは送信しない。
- **FR-004**: HTML から以下を抽出する: `<title>` の文字列、`<meta name="description" content="...">`、`<meta property="og:image" content="...">`。失敗した個別フィールドは nil として保存。
- **FR-005**: 抽出結果は新規エンティティ `ArticleEnrichment` として保存し、対応する `Article` への non-optional 参照を持つ (Constitution Principle III)。
- **FR-006**: 一覧 View は Article ごとに ArticleEnrichment があれば enriched カード (canonical title + description + サムネイル) を、無ければ spec 001 の最低表示 (Article.title + URL) を表示する。
- **FR-007**: enrichment 取得中はリスト行に小さな「取得中」インジケータ (例: 微小スピナー、控えめなトーン) を表示する。Principle V に従い、画面全体を覆うスピナーや進捗バーは禁止。
- **FR-008**: enrichment 失敗かつ最大再試行回数未満の場合は「未取得」インジケータを、最大再試行を超えた場合は「取得失敗」インジケータを表示する。文言は `Localizable.xcstrings` から日本語で取得。
- **FR-009**: 失敗時の再試行は exponential backoff (例: 30 s → 2 min → 10 min) で最大 3 回。再試行は端末がオンラインのときのみ実行する。
- **FR-010**: 1 リクエストあたりのタイムアウトは 30 秒、ダウンロード上限は 5 MB。超えたら失敗扱い。
- **FR-011**: enrichment ジョブは `URLSession` の background configuration を使用し、アプリが foreground でないときも OS が許す範囲で進行する。
- **FR-012**: HTML 全文 (取得した raw HTML 文字列) は ArticleEnrichment.rawHTML フィールドに保存する。spec 003 (本文抽出) で再 fetch 不要にするため。サイズ上限 (例: 2 MB) を超える場合は raw を保存しない (メタデータだけ保存)。
- **FR-013**: ユーザーがアプリの設定で enrichment を無効化する手段は本 spec では提供しない (将来 spec)。ただし spec.md に「ネットワークアクセスを行う」旨を明記し、ユーザーが App Store description / Privacy Policy で事前確認できる前提とする。
- **FR-014**: enrichment 取得・再試行・失敗のログは標準 OS Logger (`Logger`) に記録するが、URL や記事タイトル等の機微情報は出力しない (Principle I)。

### Key Entities *(include if feature involves data)*

- **ArticleEnrichment**: 1 件の `Article` に紐づく enriched メタデータ。
  - 必須属性: 一意識別子、対応する `Article` への non-optional 参照 (Principle III)、enrichment ステータス (`pending` / `succeeded` / `failed` / `permanentlyFailed`)。
  - オプション属性: canonicalTitle (String?)、description (String?)、ogImageURL (String?)、rawHTML (String?、サイズ制限あり)、最終更新日時 (lastFetchedAt)、リトライ回数 (retryCount)。
  - 関係: `Article` ↔ `ArticleEnrichment` は 1-to-1 (cascade delete: Article 削除時に Enrichment も削除)。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 新規記事を保存してから enriched カード (canonical title + description + サムネイル) が一覧で表示されるまで、平常 Wi-Fi 環境でメディアン **5 秒以内**。
- **SC-002**: ネットワーク切断状態でも、保存・一覧表示・削除・元記事閲覧 (spec 001 の全機能) は **100 % 利用可能** (enrichment が無くても fail しない)。
- **SC-003**: enrichment 成功率は典型的なニュースサイト 20 サイトのサンプルで **80 % 以上** (canonical title + description のうち少なくとも 1 つが取得できる比率)。
- **SC-004**: enrichment ジョブ中もアプリ本体の UI 応答性は ≤ 100 ms (Constitution パフォーマンスゲート)。バックグラウンド処理がメインスレッドをブロックしない。
- **SC-005**: 失敗インジケータ表示 → 自動再試行成功 → enriched 表示への遷移が、ネットワーク復帰後 **2 分以内** に完了する (バックオフ最初のリトライ間隔 30 s + 取得時間)。
- **SC-006**: 1 件の enrichment 取得で送信される HTTP リクエストは **正確に 1 回** (リダイレクト除く)。バッチや複数並列の冗長リクエストを行わない。
- **SC-007**: enrichment が無いまま 100 件の記事一覧を表示したときも、Constitution パフォーマンスゲートの 60 fps スクロールを維持する。

## Network Access Justification (Principle I)

Constitution Principle I「プライバシーファースト・ローカルファースト」は、外部送信が発生する場合は spec.md で送信先・データ種別・必要性を明記することを要求する。本 spec はその初の例外であるため、以下を明記する。

### 何が外部送信されるか

- **送信先**: ユーザーが保存した記事 URL のオリジン (例: `https://news.example.com/article-123` を保存したら `news.example.com` に GET)。
- **送信内容**:
  - HTTP GET リクエストライン (`GET /article-123 HTTP/1.1`)
  - 固定 User-Agent (例: `KnowledgeTree/1.0 (iOS)`)
  - `Accept: text/html, ...` 等の標準ヘッダ
- **送信されないもの**:
  - Cookie・Authorization ヘッダ・iOS デバイス識別子・IDFA・ユーザーアカウント情報
  - 他に保存している記事の URL リスト
  - リクエストタイミング以外のテレメトリー
  - 第三者サーバー (アプリ作者管理サーバー / 解析サービス等) への送信は **一切なし**

### なぜ必要か

- spec 001 で保存される `Article.title` は Share payload 由来でしばしば貧弱 (URL ホスト名フォールバックなど)。一覧で記事を見返す体験が「この URL 何だっけ」状態になり、Principle V「シンプルで落ち着いた UX」を実質的に達成できない。
- Apple Foundation Models (将来 spec) の要約・分類入力には HTML から抽出した本文が必須。本 spec での 1 fetch + raw HTML キャッシュにより、後続 spec が再 fetch なく動作する設計上の前提を作る。
- ユーザー視点では「自分が共有した URL を、自分の端末がブラウザのように 1 回開く」だけの動作。第三者にデータが渡る経路はない。

### ユーザー控制 (本 spec では未実装、将来 spec で予定)

- 設定画面で enrichment を OFF にする trigger は spec 002 ではスコープ外。On/Off 設定が無い間も、機内モードで起動すれば enrichment は自動的に skip され、spec 001 の最低体験で動作する (FR-002 / SC-002)。
- App Store の Privacy Manifest / Privacy Policy には「ユーザーが保存した URL に対し、メタデータ取得目的でアプリ本体が HTTPS GET を行う。データは端末内に保存され、第三者に送信されない」と明記する (実装責任は app submission 段階)。

## Assumptions

- **対象 OS / 端末**: spec 001 と同じ (iOS 26+ / iPadOS 26+、Apple Intelligence 対応端末)。本 spec も Foundation Models 不使用。
- **HTML パーサ**: サードパーティ依存禁止 (Constitution Additional Constraints) のため、`<title>` / `<meta>` の抽出は Foundation の `NSAttributedString(data:options:documentAttributes:)` または Swift の正規表現で行う。WebKit (`WKWebView`) を使う場合は重量級でメモリコストが高いため避ける。
- **URLSession 構成**: background configuration を使用するため、アプリが backgrounded でも OS が許可する範囲で fetch が継続する。バックグラウンド実行時間制限は OS の制約に従う。
- **ATS (App Transport Security)**: Apple 既定の制約に従う。`NSAllowsArbitraryLoads` は使用しない。HTTP-only サイトの記事は enrichment 失敗扱い (本文表示は SVC で外部 Safari に委ねる)。
- **重複処理**: spec 001 で URL 完全一致による重複拒否がされるため、enrichment ジョブは Article 新規挿入時のみキューイングされる。既存 Article への手動 enrichment 再取得は spec 003 以降。
- **データモデルマイグレーション**: spec 001 が production リリース前のため、SwiftData schema に `ArticleEnrichment` を追加する際の SwiftData 自動マイグレーションが想定通りに動かない場合、開発中は dev データを 1 回 wipe して対応する。Production リリース後の真のマイグレーションは spec 002 リリース時の別タスクで扱う。

## Out of Scope

本 spec では以下を **明示的に扱わない**。すべて将来 spec で扱う想定。

- **本文抽出 (article body の本格的な抽出)**: spec 003 で扱う。本 spec では raw HTML をキャッシュするまでで、Readability 風の処理は含めない。
- **要約 (Apple Foundation Models)**: spec 004 (現 spec 003 候補) で扱う。本 spec の rawHTML を入力に取る。
- **カテゴリ分類 (Apple Foundation Models)**: spec 005 候補で扱う。
- **ユーザー設定画面 (enrichment ON/OFF、再取得頻度等)**: 別 spec で扱う。
- **手動再取得 UI** (個別記事を pull-to-refresh で再 fetch): 別 spec。
- **ローカル画像キャッシュ** (OG image を端末にダウンロードしてオフライン表示する): 本 spec では URL のみ保存し、表示時に SwiftUI の AsyncImage で都度ロード。完全オフライン化は将来 spec。
- **URL 正規化 / トラッキングパラメータ除去** (重複検出と enrichment URL の両方に影響): 本 spec では未対応。
- **第三者 readability API** (Mercury / Diffbot 等): Principle I + Additional Constraints により禁止。
