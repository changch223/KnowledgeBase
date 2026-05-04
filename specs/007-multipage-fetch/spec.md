# Feature Specification: マルチページ記事の自動追跡 + 本文統合

**Feature Branch**: `007-multipage-fetch`
**Created**: 2026-05-05
**Status**: Draft
**Input**: User description: "マルチページ記事の自動追跡 + 本文統合。連載記事や長文の分割ページ (例: news サイトの「次のページ」リンク、Wikipedia の section 跨ぎ、技術ブログの 「continued on page 2」 等) を自動的にたどり、全ページの HTML を結合してから本文抽出 + 知識抽出に渡す。検出ルール: HTML の `<link rel=next>`, `<a rel=next>`, `<a class=next>`, pagination 系 a タグ (例: ?page=2 / /page/2 / /?p=2 のような URL パターン)。最大 5 ページまで自動取得 (N=5)、それ以降は打ち切り。無限ループ防止のため取得済 URL set を保持、同 URL 再訪問時は停止。各ページ取得は spec 002 の ArticleEnrichmentService 既存 fetch ロジック (User-Agent, charset 自動検出, 5MB 上限) を再利用。ページ間の遅延は 1 秒 (rate limit 配慮)。BottomStatusBar に「メタデータ取得中 (1/5)」のような複数ページ進捗を表示。Article は 1 件のままで、enrichment.rawHTML には全ページを連結した HTML を保存。spec 005 の 重複抑止ガード継承。canonical title は 1 ページ目のものを採用、og:image も 1 ページ目を採用。マルチページ検出失敗時は単一ページ動作 (現状) を維持。"

## User Scenarios & Testing

### User Story 1 - 連載記事を 1 件としてフルキャプチャ (Priority: P1)

ユーザーが news サイトや技術ブログで複数ページに分割された記事を共有保存したとき、現在は 1 ページ目しか取得できず、後半のページの内容が要約に反映されない。マルチページ追跡により、自動的に「次のページ」リンクを辿って全ページを結合し、1 件の Article として保存する。本文抽出 / 知識抽出は結合済みの全ページに対して走るので、要約・keyFacts・entities が記事全体をカバーする。

**Why this priority**: Web 記事の長文連載 (e.g., 大手 news サイトの調査記事 5 ページ、技術記事の「続きは page 2」) は分割が一般的。1 ページ目だけの要約では記事の主題や結論が捕捉できないことが多い。spec 006 (chunked summarization) と組み合わせると 5 ページ × 2000 文字 = 10000 文字を 10 chunk でフル要約可能になる。

**Independent Test**: rel=next pagination を持つ既知の記事 (例: news サイトの 3 ページ記事) を共有保存し、enrichment.rawHTML に 3 ページ分が結合されていること、knowledge セクションに後半ページの内容が反映されていることを確認できる。

**Acceptance Scenarios**:

1. **Given** ユーザーが 3 ページ構成の記事 (`<link rel="next">` で次ページを示す) を共有保存した状態、**When** enrichment service が走る、**Then** 1 → 2 → 3 ページ目を自動的に辿り、全 HTML が結合されて enrichment.rawHTML に保存される。canonical title / og:image は 1 ページ目のものを使用
2. **Given** ユーザーが 5 ページ構成の記事を共有保存した状態 (上限ぴったり)、**When** enrichment service が走る、**Then** 5 ページ全部を取得して終了する
3. **Given** ユーザーが 7 ページ構成の記事を共有保存した状態 (上限超え)、**When** enrichment service が走る、**Then** 5 ページのみ取得して打ち切り、`pageCountFetched = 5` / `pageCountSkipped = 2` のメタデータが記録される

---

### User Story 2 - 単一ページ記事の挙動を維持 (Priority: P1)

マルチページ追跡を導入してもほとんどの Web 記事は単一ページ。pagination リンクが検出できなかった場合は spec 002 の既存挙動 (1 ページのみ取得) をそのまま維持し、ユーザー体験に変化を与えない。

**Why this priority**: 既存挙動の互換性を保つことが重要。マルチページ追跡が暴走 (誤検出) して関係ないリンクを辿るのは致命的バグ。検出失敗時の安全側 fallback を P1 として定義する。

**Independent Test**: pagination リンクを持たない一般的なブログ記事 (e.g., zenn.dev の単一ページ記事) を共有保存し、enrichment.rawHTML が 1 ページ分だけ保存されていることを確認。

**Acceptance Scenarios**:

1. **Given** ユーザーが pagination 無しの記事を共有保存した状態、**When** enrichment service が走る、**Then** 1 ページ目のみ取得し、`pageCountFetched = 1` で完了する
2. **Given** ユーザーが pagination リンクっぽいが実は別記事への単なるリンクが含まれる記事を保存した状態、**When** enrichment service が走る、**Then** 厳格な検出ルール (rel=next 等の明示的指示のみ) でマルチページ追跡を起動せず、1 ページ目のみ取得

---

### User Story 3 - 取得進捗の可視化 (Priority: P2)

複数ページを順次取得するため、enrichment フェーズの所要時間が単一ページ時の 2-5 倍になる。BottomStatusBar に「メタデータ取得中 (1/5)」のように進捗を表示することで、ユーザーが完了予測を立てられるようにする。

**Why this priority**: spec 005 で knowledge 抽出の N/M 表示を導入し、spec 006 で chunk 進捗を表示した路線を継承。enrichment フェーズも長くなるなら同様の可視化が必要。

**Independent Test**: 5 ページ記事を共有保存し、BottomStatusBar の表示が「メタデータ取得中 (1/5)」「(2/5)」... と進むことを確認。

**Acceptance Scenarios**:

1. **Given** 5 ページ記事の enrichment が始まった状態、**When** 1 ページ目の HTTP fetch + パース + pagination 検出が完了して 2 ページ目の fetch に入る、**Then** BottomStatusBar が「メタデータ取得中 (2/5)」(まだ確定でない場合は「メタデータ取得中 2…」のような暫定表示でも可) に更新される
2. **Given** 単一ページ記事の enrichment 中、**When** BottomStatusBar を確認、**Then** 従来通り「メタデータ取得中: <タイトル>」(N/M 表示なし) のみ
3. **Given** マルチページ追跡が途中で打ち切られた状態 (例: ページ 3 で fetch 失敗、無限ループ検出、上限到達)、**When** BottomStatusBar の更新が止まる、**Then** 直前の表示 (例: 3/5) のまま BottomStatusBar が消える、または body フェーズへ遷移する

---

### Edge Cases

- **無限ループ**: ページ A → B → A (循環) の場合、URL set で A が既訪問と判定し、A を再 fetch する前に停止 (`pageCountFetched = 2`)。
- **rel=next が相対 URL**: 例 `<link rel="next" href="?page=2">`。1 ページ目の URL を base にして absolute URL に解決。
- **rel=next が違うドメイン**: 安全のため **同一ドメイン (host) のみ追跡**。クロスドメインリンクは検出時点で打ち切る。
- **rel=next が無いが pagination CSS クラス (`.next` `.pagination-next`) は存在**: spec 007 の検出ルールには含めるが、優先順位は rel=next が最も強い。複数候補がある場合は rel=next > class=next > 推測 URL パターン (?page=N) の順。
- **pagination URL パターンの誤検出**: 例えば「人気記事」リンクに `?page=2` がある場合、現在ページの URL から 1 文字違いで生成された URL のみ追跡 (例: 現在 `/article` なら `/article?page=2` のみ受理、`/popular?page=2` は無視)。
- **HTTP 404 / 403 / network error が途中ページで発生**: そこで打ち切り、それまでに取得したページで body 抽出 / 知識抽出を実行。`pageCountFetched < pageCountTotal` で記録。
- **同一 URL に rel=next で自分自身を指す壊れた HTML**: URL set で重複検出して停止。
- **ページ間で charset が異なる**: 各ページごとに spec 002 の charset 自動検出を独立適用。最終結合時は decode 済 String を `\n\n<!-- page X -->\n\n` 区切りで結合 (HTML パーサが破綻しないようコメント区切り)。
- **超巨大連結 HTML (5 ページ × 5MB)**: rawHTMLCacheLimit (spec 002 既存 = 2MB) を結合 HTML 全体に適用。超過時は rawHTML を nil で保存して body 抽出に使う最低限の本文だけ持つ。

## Requirements

### Functional Requirements

- **FR-001**: システムは記事の HTML から **`<link rel="next">`** を最優先で検出してマルチページ追跡を起動する
- **FR-002**: 次優先の検出ルールは **`<a rel="next">`** および **`<a class="next">`** (大文字小文字無視)
- **FR-003**: 第三優先の検出ルールは pagination URL パターン: 現在ページ URL に対して `?page=2` / `&page=2` / `/page/2` / `/?p=2` を生成し、それと同一の `<a href>` を本文中で見つけたとき
- **FR-004**: 検出された次ページ URL は、現在ページ URL を base にして **absolute URL に解決** する。スキーマは https に強制 (http の次ページは検出時に拒否)
- **FR-005**: マルチページ追跡は **同一ホスト (host)** のみ。次ページ URL が現在ページと異なるドメインなら追跡を打ち切る
- **FR-006**: 1 記事あたりの **最大ページ数は 5**。それ以降は打ち切り、`pageCountSkipped` (推定) を記録
- **FR-007**: 取得済 URL set を保持し、**同一 URL を 2 回 fetch しない** (無限ループ防止)
- **FR-008**: ページ間の **遅延は 1 秒** (`Task.sleep(for: .seconds(1))`、rate limit 配慮)
- **FR-009**: 各ページの fetch は spec 002 の既存ロジック (User-Agent / charset 自動検出 / 5MB 上限 / HTTPS のみ) を **再利用**
- **FR-010**: 全ページ取得後、各ページの decode 済 HTML を **`\n\n<!-- page N -->\n\n` 区切りで連結** して `enrichment.rawHTML` に保存
- **FR-011**: `enrichment.canonicalTitle` / `enrichment.summary` / `enrichment.ogImageURL` は **1 ページ目のもののみ採用** (連載タイトル・サムネは 1 ページ目代表とする)
- **FR-012**: `ArticleEnrichment` (@Model) に新規列を追加: `pageCountFetched: Int` (実取得数、>=1)、`pageCountSkipped: Int` (打ち切った推定残数、>=0)
- **FR-013**: BottomStatusBar は enrichment フェーズで **複数ページ確定後** に「メタデータ取得中 (N/M)」表示。M 確定前 (1 ページ目処理中) は従来通り「メタデータ取得中: <タイトル>」
- **FR-014**: pagination 検出に失敗した場合は **単一ページ動作** (現状の spec 002 の挙動) を維持。`pageCountFetched = 1, pageCountSkipped = 0` で保存
- **FR-015**: spec 005 で実装済の **重複抑止ガード** (同 article への並行 enrich 呼び出し)、**charset 検出**、**HTTPS 強制** をマルチページ追跡でも維持
- **FR-016**: 途中ページで HTTP error (4xx/5xx) または network error が発生したら、**そこで打ち切り**、それまでに取得した N ページで結合・保存・後続フェーズに渡す
- **FR-017**: `enrichment.rawHTML` の **2MB 上限** (spec 002 既存) は連結後の総量に適用。超過時は rawHTML を nil で保存し、body 抽出は 1 ページ目のみで動作
- **FR-018**: マルチページ追跡完了後、後続の body 抽出 (spec 003) と knowledge 抽出 (spec 004 + spec 006 chunked) は **連結済み HTML / 本文** に対して走る (既存パイプラインを利用)
- **FR-019**: 検出された次ページ URL の **クエリ正規化**: 同一ページの異なる query string バリエーション (例: `?utm_source=...` のみ違い) は同一 URL として扱う (重複検出の精度向上)
- **FR-020**: spec 007 が稼働してもユーザーが「次のページに移動」操作をする必要は無い (完全自動)

### Key Entities

- **ArticleEnrichment** (既存 @Model + 列追加):
  - 既存: `canonicalTitle`, `summary`, `ogImageURL`, `rawHTML`, `status`, `lastFetchedAt`, `retryCount`
  - 新規: `pageCountFetched: Int`, `pageCountSkipped: Int`
- **PageCrawlSession** (transient、永続化しない):
  - 1 つの enrichment ジョブで使うステート: 取得済 URL set, 取得済 HTML 配列, current page index, 中断理由 (HTTP error / loop / cross-domain / max pages)
- **PaginationLink** (transient):
  - 検出された次ページの候補: URL, 検出元 (rel=next / class=next / url-pattern), 信頼度 (high / medium / low)

## Success Criteria

### Measurable Outcomes

- **SC-001**: rel=next を持つ 3 ページ記事の保存後、enrichment.rawHTML に 3 ページ分の HTML が含まれている (各ページの本文に出る固有文字列で検証可能)
- **SC-002**: 5 ページ記事の保存後、`pageCountFetched == 5 && pageCountSkipped == 0`
- **SC-003**: 7 ページ記事の保存後、`pageCountFetched == 5 && pageCountSkipped >= 1` (上限到達)
- **SC-004**: 単一ページ記事の保存後、`pageCountFetched == 1 && pageCountSkipped == 0`、enrichment 完了時間が spec 002 比で +0.5 秒以内 (rel=next 検出のオーバーヘッドのみ)
- **SC-005**: 循環 pagination (A → B → A) の記事を保存しても無限ループせず、`pageCountFetched == 2` で停止
- **SC-006**: クロスドメイン rel=next の記事を保存しても外部ドメインを fetch せず、`pageCountFetched == 1` で停止
- **SC-007**: 5 ページ記事の総 enrichment 時間 ≤ 15 秒 (1 ページあたり 1.5-2 秒 fetch + 1 秒 delay × 4 = 約 12-14 秒)
- **SC-008**: 連載記事 (5 ページ × 2000 文字 = 10000 文字) を保存して、knowledge セクションに後半ページ固有の事実 / entity が含まれている (前半だけの要約に偏らない)

## Assumptions

- **検出ルールの優先順位**: rel=next が最も信頼度高 (HTML 標準仕様)、class=next は中程度、URL パターン推測は低 (誤検出リスク)。3 つのルールが衝突した場合は rel=next > class=next > URL パターンの順
- **同一ホストのみ**: クロスドメインの追跡はユーザーの意図と異なる可能性が高い (例: 「次の記事」リンクに別記事へのリンクを入れているケース)。MVP は安全側で同一ホスト限定
- **HTTPS のみ**: spec 002 既存制約を継承
- **遅延 1 秒は固定**: rate limit を厳守する保守的な値。動的調整 (Retry-After ヘッダ等) は将来 spec
- **ページ間 charset 不一致**: 各ページの decode は独立。連結時に文字列として結合 (バイト連結ではない) ので charset 不一致は問題にならない
- **rawHTML 2MB 上限超過時**: rawHTML を nil で保存。body 抽出は 1 ページ目のみで動作 (degradation)。これ以上の対応は将来の chunked storage 等で
- **ページ番号のメタデータ表示**: Detail 画面に「全 5 ページ取得 (上限到達で 2 ページスキップ)」のような注記を出すかは将来 spec。MVP は内部記録のみ
- **再試行 / リトライ**: 各ページの fetch は spec 002 の既存リトライポリシー (3 回バックオフ) を継承。マルチページ全体としての retry は MVP 不要
- **連結済み rawHTML を body 抽出に渡したときの挙動**: spec 003 の article/main/density スコアリングは結合 HTML 全体に対して走る。各ページの `<article>` タグが連結後に複数存在する可能性あるが、最初に見つかったものを使う既存挙動でほぼ妥当 (技術記事の 5 ページ目までの内容を含むケースは稀、優先順位として 1 ページ目の article で OK)
- **マルチページ自動追跡を OFF にする設定**: MVP では設定 UI を提供しない。常に自動。問題が出れば spec 010+ で「自動追跡を無効にする」トグル検討

## Dependencies

- **spec 002** (ArticleEnrichmentService): fetch 経路 / charset 検出 / HTTPS / 5MB 上限を再利用
- **spec 005** (重複抑止ガード, ProcessingMonitor, BottomStatusBar): 同 article への並行 enrich 抑止 + 進捗表示の API 拡張
- **spec 006** (chunked summarization): 連結後の本文が長文化するので、chunked パスとの組み合わせが効果的
