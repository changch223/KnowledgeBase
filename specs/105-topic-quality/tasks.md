# spec 105 — トピックの質（UI/UX 再設計 v2・第 3 段階）

> 先に `specs/REDESIGN-v2.md`（共通ルール）を読むこと。spec 104 が main にマージ済みであること。
> ブランチ: `105-topic-quality`（main から）/ リスク: 高（AI 生成と token 上限に触れる）/ AI 呼び出し: 増やさない（大きいトピックでは減る）/ @Model 変更: `ConceptPage` に 2 列追加

## 目的
- 記事が多すぎるトピック（例: 「生成AI」31 件）の要点が、1 本の記事の事実になってしまう問題を直す。大きいトピックは **書架**（子トピックをまとめる見出し）として扱い、要点は範囲の狭い子トピックだけで作る。
- トピック詳細を「何のトピックか → 要点 → 前回から増えたこと → 子トピック・記事 → 詳しく」の固定順にする。今は「要点」「詳しく（旧まとめ）」「概要」が似た内容で 3 つ並んでいる。
- 前に開いたときから増えた要点に印を付ける。保存は不定期なので、日付ではなく「前回開いたとき」と比べる。

## 用語
- **書架トピック**: `ConceptShelfPolicy.isShelf(...) == true` のトピック。条件は「`level == .broad`、関連記事数 > `articleThreshold`（既定 15）、子トピックが 1 件以上」。
- **前回開いたとき**: トピック詳細を最後に閉じた時刻（新しい列 `ConceptPage.lastOpenedAt`）。フィードのカードが画面に出た時刻（既存 `lastSeenAt`）とは別物。`lastSeenAt` の意味と既存の並び替えロジックは変えない。

---

## タスク

### T1. データ列の追加
`KnowledgeBase/Models/ConceptPage.swift` に追加（どちらも default 付き = CloudKit lightweight 安全、コメントに spec 105）:
- `var lastOpenedAt: Date? = nil` — トピック詳細を閉じた時刻
- `var seenInsights: [String] = []` — 前回詳細を閉じたときに表示していた要点のスナップショット

### T2. 書架の判定 `ConceptShelfPolicy`
- 新規: `KnowledgeBase/Services/ConceptShelfPolicy.swift`
  - `static let articleThreshold = 15`（実機で 10 / 15 / 20 を比べてから確定。値を変えるときはこの定数だけを変える）
  - `static func isShelf(level: ConceptLevel, articleCount: Int, childCount: Int) -> Bool`
  - `static func newInsights(current: [String], seen: [String]) -> Set<String>` — `seen` が空なら空集合（初めて見るページは全部「新しい」にしない）。それ以外は `current` のうち `seen` に無いもの。
- テスト `KnowledgeBaseTests/ConceptShelfPolicyTests.swift`: broad・31 件・子 4 → true / broad・31 件・子 0 → false / broad・15 件・子 4 → false（境界は「超」）/ specific・40 件・子 3 → false / `newInsights` 3 件（seen 空 → 空 / 1 件追加 → その 1 件 / 同じ → 空）

### T3. 合成で書架の要点を作らない
ファイル: `KnowledgeBase/Services/ConceptSynthesisService.swift`（Foundation 実装の `_resynthesize`、373 行付近〜）
- 合成の前に子トピック数を数える: `FetchDescriptor<ConceptPage>(predicate: #Predicate { $0.parentConceptID == pid })` の `fetchCount`（`pid` はローカル定数に取り出してから predicate に入れる）。
- 書架なら:
  - `synthesizeWithAdaptiveRetry` を `compact: true` から始める（大きいトピックは overflow しやすいので最初から小型スキーマ。新しい生成メソッドは作らない）。そのための引数 `startCompact: Bool = false` を追加する。
  - 結果の `summary` は保存し、`crossSourceInsights = []`、`insightSourceArticleIDs = []` にする（要点は子トピックで出す）。
- 書架でないページの処理は一切変えない。
- **`@Generable` の型・`@Guide`・プロンプト本文は変更しない。** AI 呼び出し回数は同じか減る。
- Fallback 実装（136 行付近）も同じく書架なら `crossSourceInsights = []`。
- `KnowledgeBase/Resources/iknow-schema.md` に「書架トピック」の節を追記（条件と、要点を作らない理由を 3〜5 行で）。
- テスト: `ConceptSynthesisServiceTests` に 2 件（Mock セッションで、書架は insights が空・summary は保存 / 書架でないページは従来どおり insights 保存）。

### T4. ホームでの書架表示
ファイル: `KnowledgeBase/Services/FeedBuilder.swift`、`KnowledgeBase/Views/KnowledgeClipView.swift`、新規 `KnowledgeBase/Views/ConceptShelfSection.swift`
- `ConceptFeedEntry` に `var isShelf: Bool`（`topLevelConcepts` 内で `ConceptShelfPolicy.isShelf(level:articleCount:childCount: children.count)` を入れる）。
- 書架のエントリは、1 枚のカードではなく `ConceptShelfSection` で描く: 見出し行（トピック名・明朝、右に新キー `shelf.childCount %lld`、タップでトピック詳細へ）＋ 子トピックを `ConceptSummaryCard` で最大 3 件（子の `updatedAt` 降順）＋ 4 件以上あれば「すべて表示」行（既存のトピック詳細へ遷移）。
- 子トピックのカードの `onSeen` は既存と同じ `markConceptSeen` を呼ぶ。
- 並び順のロジック（pin → fresh → 記事数 → 更新日時）は変えない。書架もその順の中に 1 エントリとして並ぶ。
- 子トピックは書架の下にだけ出す（同じトピックをフィードに 2 回出さない。`topLevelConcepts` は `parentConceptID == nil` しか返さないので現状でも重複しない）。

### T5. トピック詳細の固定構成
ファイル: `KnowledgeBase/Views/ConceptPageDetailView.swift`（`aliveBody` 104 行付近）
- 新しい順:
  1. `heroTitleSection`: 名前 + 直下に `summary` 全文を「何のトピックか」として表示（120〜180 字の想定）。上位トピックのパンくず（`parentBreadcrumb`）は現行どおり。
  2. 要点（`crossSourceInsightsSection`）: 最初の 3 件だけ表示し、4 件目以降は「すべて表示（N）」で展開（新キー `concept.insights.showAll %lld`）。`ConceptShelfPolicy.newInsights` に入る要点の先頭に藍の点（直径 7pt、`accessibilityLabel` 新キー `concept.insight.new`）。出典表示（spec 089・spec 104 のプレビュー）はそのまま。書架で要点が空ならセクションごと出さない。
  3. 前回から増えたこと（新規 `sinceLastOpenSection`）: `lastOpenedAt` 以降に保存された関連記事を最大 3 件（`ArticleRow` を簡易表示）。`lastOpenedAt == nil` または 0 件なら出さない。見出し新キー `concept.sinceLastOpen`。
  4. `childConceptsSection`（子トピック）。書架ではこれを要点の位置（2 の場所）に繰り上げる。
  5. `relatedArticlesSection`（記事）
  6. `wikiBodySection`（「詳しく」）: 既定で折りたたみ（`DisclosureGroup`）。
  7. `SavedAnswerSection`、`relatedConceptsSection`（現行どおり）
- `summarySection`（「概要」）は 1 の hero に統合したので本体から外す（コードは削除してよい。`ConceptPage.detail.summary.title` キーは参照ゼロなら削除）。
- `.onDisappear` で `conceptPage.lastOpenedAt = .now`、`conceptPage.seenInsights = conceptPage.crossSourceInsights` を入れて保存（`.onAppear` ではなく閉じるとき。開いている間は点が消えないように）。
- 新キー（7 ロケール）:

| key | ja | en | zh-Hans | zh-Hant | ko | es | de |
|---|---|---|---|---|---|---|---|
| `shelf.childCount %lld` | 子トピック %lld | %lld subtopics | %lld 个子主题 | %lld 個子主題 | 하위 주제 %lld | %lld subtemas | %lld Unterthemen |
| `concept.insights.showAll %lld` | すべて表示（%lld） | Show all (%lld) | 显示全部（%lld） | 顯示全部（%lld） | 모두 보기 (%lld) | Mostrar todo (%lld) | Alle anzeigen (%lld) |
| `concept.insight.new` | 前回から追加 | New since last visit | 上次之后新增 | 上次之後新增 | 지난번 이후 추가 | Nuevo desde tu última visita | Neu seit dem letzten Besuch |
| `concept.sinceLastOpen` | 前回から増えた記事 | Added since last visit | 上次之后新增的文章 | 上次之後新增的文章 | 지난번 이후 추가된 글 | Añadido desde tu última visita | Seit dem letzten Besuch hinzugefügt |

### T6. ホームのカードにも新しい要点の印
ファイル: `KnowledgeBase/Views/ConceptSummaryCard.swift`
- 要点の箇条書き（`keyPointsView`）で、`ConceptShelfPolicy.newInsights(current:seen:)` に入る要点の行頭を藍の点にする（通常の行頭記号と置き換え）。件数やバッジは出さない。

### T7.（任意・P3）「前に保存したもの」
- ユーザー判断で省略可。実装する場合のみ:
  - ホームの最下部に、保存から 30 日以上たった記事を最大 2 件。候補は「未開封」または「最後に開いてから 30 日以上」。
  - 選び方はアプリを開いたときに 1 回だけランダムに決め、セッション中は固定（`orderedConceptIDs` と同じスナップショット方式）。毎日の固定ローテーションにはしない。
  - 見出し新キー `feed.rediscover.title`（ja「前に保存したもの」/ en「Saved a while ago」/ zh-Hans「之前保存的」/ zh-Hant「之前儲存的」/ ko「예전에 저장한 것」/ es「Guardado hace tiempo」/ de「Früher gespeichert」）。

---

## 受け入れ基準
- [ ] 関連記事 16 件以上かつ子トピックありの広いトピックが、ホームで「見出し＋子トピックのカード」として出る
- [ ] 書架トピックを再合成すると要点が空になり、summary は残る。書架でないトピックの合成結果は従来と同じ
- [ ] トピック詳細の順が「何のトピックか → 要点（3 件＋すべて表示）→ 前回から増えた記事 → 子トピック → 記事 → 詳しく（折りたたみ）」
- [ ] 一度詳細を閉じたあとに要点が増えると、次に開いたときその要点に点が付く。初めて開くページには点が付かない
- [ ] `@Generable` の型・`@Guide`・プロンプト本文に差分が無い（`git diff` で確認して報告）
- [ ] 新規キーが 7 ロケールすべてで値を持つ
- [ ] ビルド成功・ユニットテスト全件成功・新規 warning なし

## 実機で確認（ユーザー・マージ前に必須）
- Xcode のログで、書架トピック（例「生成AI」）の合成が overflow せず、`compact` から始まっていること
- 定数 `ConceptShelfPolicy.articleThreshold` を 10 / 15 / 20 に変えて、子トピックの要点の質を比べる。決めた値を `CLAUDE.md` に記録
- 書架にならなかったトピックの要点が改修前と同等であること
