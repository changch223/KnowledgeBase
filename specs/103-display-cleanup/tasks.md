# spec 103 — 表示の整理（UI/UX 再設計 v2・第 1 段階）

> 先に `specs/REDESIGN-v2.md`（共通ルール）を読むこと。
> ブランチ: `103-display-cleanup`（main から）/ リスク: 低 / 新 AI 呼び出し: なし / @Model 変更: なし

## 目的
画面の構造は変えずに、「答え（AI の一言まとめ）が先、根拠と原文が後」に表示を並べ直す。ユーザーが探しているものに、少ないスクロールとタップで届くようにする。

## 現状の問題（スクリーンショットで確認済み）
1. 記事行の 3 行目が URL 全文。保存元はドメインがわかれば十分。
2. 記事詳細は「長いタイトル（サイト名付き）→ 写真 → タグ編集 → AI のまとめ」の順で、答えまで遠い。「知識サマリ」と「要約」の見出しがほぼ同じ内容に二重に付いている。
3. 追加画面が 5 つのセグメント（URL/メモ/ファイル/写真/音声）。ユーザーは貼り付ける前に種類を選ばされる。
4. 「知識抽出中 7/14」のステータスバーが画面下部に重なり、操作の邪魔になる。
5. 「超・まとめ」「知識サマリ」「要点」「まとめ」が近い意味で混在している。
6. `SavedAtFormatter` が `ja_JP` 固定。英語・中国語などの端末でも「今日 10:00」と日本語で出る（7 言語対応のバグ）。

---

## タスク

### T1. 保存元ラベルの純関数 `ArticleSourceLabel`
- 新規: `KnowledgeBase/Services/ArticleSourceLabel.swift`
- `static func label(for urlString: String) -> ArticleSourceLabel.Kind`
  - `enum Kind: Equatable { case domain(String), intake(RawArticleIntake.Source), unknown }`
  - `knowledgebase://<source>/<hash>`（`RawArticleIntake` の合成 URL）→ `.intake(source)`（`Source(rawValue: host)` で復元）
  - `http(s)` → `.domain(host)`。先頭の `www.` を除去。
  - それ以外・パース失敗 → `.unknown`
- 表示用: `Kind.localizedText: String`（`.domain` はそのまま、`.intake` は下の新キー、`.unknown` は空文字）
- 新キー（7 ロケール）:

| key | ja | en | zh-Hans | zh-Hant | ko | es | de |
|---|---|---|---|---|---|---|---|
| `article.source.note` | メモ | Note | 笔记 | 筆記 | 메모 | Nota | Notiz |
| `article.source.sharedText` | 共有テキスト | Shared text | 共享文本 | 分享文字 | 공유 텍스트 | Texto compartido | Geteilter Text |
| `article.source.file` | ファイル | File | 文件 | 檔案 | 파일 | Archivo | Datei |
| `article.source.image` | 写真 | Photo | 照片 | 照片 | 사진 | Foto | Foto |
| `article.source.audio` | 音声 | Audio | 音频 | 音訊 | 오디오 | Audio | Audio |

- テスト: `KnowledgeBaseTests/ArticleSourceLabelTests.swift` — `https://www.nikkei.com/x` → `.domain("nikkei.com")` / `knowledgebase://note/abc` → `.intake(.note)` / `knowledgebase://audio/abc` → `.intake(.audio)` / `"not a url"` → `.unknown`

### T2. タイトルのサイト名除去 `TitleCleaner`（表示のみ）
- 新規: `KnowledgeBase/Services/TitleCleaner.swift`
- `static func clean(_ title: String, host: String?) -> String`
  - 区切り `" | "`, `" - "`, `" – "`, `" — "`, `"｜"`, `" :: "` で末尾セグメントを取り出す。
  - 末尾セグメントが **サイト名と判定できるときだけ** 除去する: host のコア名（`www.` と TLD を除いた最初のラベル。例 `nikkei.com`→`nikkei`、`zenn.dev`→`zenn`）を小文字・空白除去で比較し、末尾セグメントに含まれる、または末尾セグメントがコア名に含まれる。
  - 除去後に空になる、または 5 文字未満になる場合は元のタイトルを返す。
  - 1 回だけ除去する（ループしない）。保存データ（`Article.title`）は **書き換えない**。
- 適用先: `ArticleRow.displayTitle` と `ArticleDetailView` の `displayTitle` の戻り値に通す。
- テスト: `KnowledgeBaseTests/TitleCleanerTests.swift` — `"生成AIの現在地 | 日経電子版"`+`nikkei.com` は除去しない（「日経」は英字コアと一致しない＝保守的で正しい）/ `"Swift 6 の新機能 - Zenn"`+`zenn.dev` → `"Swift 6 の新機能"` / `"What's new - Swift 6"`+`example.com` → 変更なし / `"Zenn"`+`zenn.dev` → 変更なし（空になるため）

### T3. 記事行 `ArticleRow` の整理
ファイル: `KnowledgeBase/Views/ArticleRow.swift`
- 2 行目: 現行どおり `essence` 優先。essence が無く、かつ `FeedBuilder.isProcessingComplete(article) == false` で知識抽出が未完（pending/extracting）のときは `enrichment.summary` ではなく、新キー `article.row.organizing`（ja「整理中…」/ en「Organizing…」/ zh-Hans「整理中…」/ zh-Hant「整理中…」/ ko「정리 중…」/ es「Organizando…」/ de「Wird geordnet…」）を `.tertiary` で表示。失敗・スキップ時は従来どおり `enrichment.summary` にフォールバック。
- 3 行目: `Text(article.url)` を `ArticleSourceLabel.label(for: article.url).localizedText` に置換（空なら非表示）。右側の保存日時はそのまま。
- 削除: entity チップ行（`topEntities` の HStack）と「AI 生成」カプセル（`knowledgeAIGeneratedLabel`）。行は「タイトル / 一言 / 保存元・日時」の 3 行に揃える。`topEntities` が未使用になれば削除。
- `combinedAccessibilityLabel` の `article.url` もラベル文字列に置換。
- 左端の墨のアクセントバーとサムネイルはそのまま。

### T4. `SavedAtFormatter` の多言語化
ファイル: `KnowledgeBase/Views/ArticleRow.swift`（同ファイル内の enum）、テスト `KnowledgeBaseTests/ArticleRowSavedAtTests.swift`
- `format(_ date: Date, now: Date = .now, locale: Locale = .autoupdatingCurrent)` に変更。全 formatter をこの locale で作る（static キャッシュをやめるか、locale ごとに作る）。
- 今日/昨日: `RelativeDateTimeFormatter`（`dateTimeStyle = .named`, `unitsStyle = .short` 等）の `localizedString(from: DateComponents(day: 0))` / `DateComponents(day: -1)` で「今日」「昨日」/「today」「yesterday」を得て、時刻（`setLocalizedDateFormatFromTemplate("Hm")`）と空白で連結。
- 7 日以内: 現行の relative 表示を locale 付きで。それ以上: `setLocalizedDateFormatFromTemplate("yMd")`。
- `accessibilityText` の `" 保存"` 直書きを新キー `savedAt.accessibility %@`（ja「%@ 保存」/ en「Saved %@」/ zh-Hans「%@ 保存」/ zh-Hant「%@ 儲存」/ ko「%@ 저장」/ es「Guardado %@」/ de「Gespeichert %@」）に。
- 既存テストは `locale: Locale(identifier: "ja_JP")` を渡して従来の期待値（「今日 HH:mm」「昨日 HH:mm」「yyyy/MM/dd」）が通ることを確認。期待値が変わる場合はテストを直す前に理由を報告。`en_US` のテストを 1 件追加（"today" を含む）。

### T5. 記事詳細 `ArticleDetailView` の並べ替え
ファイル: `KnowledgeBase/Views/ArticleDetailView.swift`、`KnowledgeBase/Views/KnowledgeSummaryView.swift`
- 現在の順（223 行付近〜）: バナー → `headerSection`（タイトル・保存元・写真）→ `tagsSection` → `knowledgeSection` → `bodySection` → 関連記事 → 派生トピック → 過去の見解
- 新しい順:
  1. バナー（変更なし）
  2. タイトル + 保存元・日時（`headerSection` から写真を除いた部分。保存元は T1 のラベルを使う）
  3. `knowledgeSection`（AI のまとめ）
  4. 写真（`headerSection` から切り出した `imageSection`。高さ 160 のまま）
  5. `bodySection`（本文）
  6. `derivedConceptPagesSection`（この記事が入っているトピック）
  7. `RelatedArticlesSection`
  8. `tagsSection`（最下部へ移動）
  9. 過去の見解（変更なし）
- **注意**: 既存コメントにあるとおり、写真（AsyncImage）と `bodySection` は `.id(refreshTick)` の外に置く（毎秒の再生成で画像のちらつき・DisclosureGroup のリセットが起きるため）。`.id(refreshTick)` を付けるのは `knowledgeSection` だけのまま。
- `KnowledgeSummaryView`: essence（太字）の直後に summary 段落を見出しなしで続ける（`knowledge.summary.heading`「要約」の見出し Text を表示しない。キーは残す）。
- 用語は T8 で変更。

### T6. 追加画面を「入力欄ひとつ」に
ファイル: `KnowledgeBase/Views/AddArticleSheet.swift`
- 新規純関数: `KnowledgeBase/Services/IntakeInputClassifier.swift`
  - `enum Result: Equatable { case url(URL), note(String), empty }`
  - `static func classify(_ text: String) -> Result`: 前後空白を除去 → 空なら `.empty`。空白・改行を含まない 1 トークンで `http`/`https` スキームの URL として解釈できれば `.url`。`www.` 始まりなら `https://` を補って `.url`。それ以外は `.note(trimmed)`。
  - テスト `KnowledgeBaseTests/IntakeInputClassifierTests.swift`: `"https://a.com/x"`→url / `"  https://a.com  "`→url / `"www.a.com"`→`https://www.a.com` / `"これは https://a.com のメモ"`→note / `"ftp://a.com"`→note / `""`→empty
- UI:
  - セグメント `Picker`（`addArticle.modePicker`）を削除。
  - 上部に複数行 `TextField(axis: .vertical, lineLimit 3...12)` を 1 つ。placeholder 新キー `addArticle.input.placeholder`（ja「URL を貼るか、メモを書く」/ en「Paste a URL or write a note」/ zh-Hans「粘贴网址或写笔记」/ zh-Hant「貼上網址或寫筆記」/ ko「URL을 붙여넣거나 메모 작성」/ es「Pega una URL o escribe una nota」/ de「URL einfügen oder Notiz schreiben」）。`accessibilityIdentifier("addArticle.urlField")` をこの欄に付ける（UI テスト互換）。キーボードは既定（URL 専用キーボードにしない）、自動大文字化 off。
  - 入力欄が空のときだけ、その下に `PasteButton(payloadType: URL.self)` を表示。貼り付けたら欄に URL を入れて **そのまま保存**（1 タップ保存）。`UIPasteboard` を直接読まない（ペースト許可ダイアログを出さないため）。
  - その下に添付ボタン 3 つを横並び: ファイル（`showFileImporter = true`）/ 写真（既存 `PhotosPicker`）/ 音声（`showAudioImporter = true`）。ラベルは既存キー `addArticle.mode.file` / `addArticle.mode.image` / `addArticle.mode.audio` を流用。
  - 添付を選んだら内部 `mode` を `.file/.image/.audio` にし、既存のプレビュー UI（ファイル名 / OCR 中・OCR 結果 / 文字起こし中・結果）を入力欄の代わりに表示。右上に「×」（`xmark.circle.fill`）で添付を解除しテキスト入力に戻る。
  - 添付なしのとき、保存時に `IntakeInputClassifier` で `.url` → 既存 `saveURL()`、`.note` → 既存 `saveNote()`。`.empty` は保存ボタン無効。
  - メモのタイトル欄（`noteTitle`）は廃止。`RawArticleIntake.save(title:)` には空文字を渡し、既存の `derivedTitle` に任せる（`RawArticleIntake.derivedTitle(rawTitle:body:)` は空タイトルなら本文の先頭行 40 字を使う。確認済み）。
  - `Mode` enum は private のまま内部状態として残してよい。`canSave` / `save()` の分岐は新しい状態に合わせる。
  - footer の説明文は、添付中のみ既存の各 footer キーを表示。テキスト入力時は新キー不要（placeholder で足りる）。

### T7. 処理中表示を 1 行に
- 新規: `KnowledgeBase/Views/ProcessingInlineStatus.swift`
  - `ProcessingMonitor` を受け取り、`monitor.totalActiveCount > 0` のときだけ `SumiKnowledgeSpinnerSmall()` + 新キー `status.inline.organizing %lld`（ja「%lld 件を整理中」/ en「Organizing %lld items」/ zh-Hans「正在整理 %lld 项」/ zh-Hant「正在整理 %lld 項」/ ko「%lld개 정리 중」/ es「Organizando %lld elementos」/ de「%lld Einträge werden geordnet」）を 1 行で表示。`.caption`、`.secondary`、背景なし。フェーズ名・記事名・N/M は出さない。
  - `accessibilityIdentifier("processingInlineStatus")`
- `ArticleListView`: 86 行付近の `BottomStatusBar(monitor:)` の配置をやめ、リスト先頭（検索結果・フィルタ行より上）に `ProcessingInlineStatus` を置く。
- `KnowledgeClipView`: `LazyVStack` の先頭に同じものを置く（`ProcessingMonitor` は environment から取得。取得方法は `ArticleListView` に合わせる）。
- `BottomStatusBar` の参照がゼロになったらファイルを削除。UI テストに `bottomStatusBar` の参照が無いことは確認済み。

### T8. 用語の統一（xcstrings の値のみ変更・キーは変えない）

| key | 現在の ja | 新 ja | en | zh-Hans | zh-Hant | ko | es | de |
|---|---|---|---|---|---|---|---|---|
| `clip.section.concepts` | 超・まとめ | トピック | Topics | 主题 | 主題 | 주제 | Temas | Themen |
| `feed.badge.wiki` | まとめ | トピック | Topic | 主题 | 主題 | 주제 | Tema | Thema |
| `knowledge.section.title` | 知識サマリ | この記事の要点 | Key points | 本文要点 | 本文重點 | 이 글의 요점 | Puntos clave | Kernpunkte |
| `detail.section.knowledge` | 知識サマリ | この記事の要点 | Key points | 本文要点 | 本文重點 | 이 글의 요점 | Puntos clave | Kernpunkte |
| `wiki.body.sectionTitle` | まとめ | 詳しく | Details | 详细说明 | 詳細說明 | 자세히 | Detalles | Details |

- 用語の定義（今後の文言もこれに従う）: **トピック** = AI が記事を束ねたページ（ConceptPage）/ **要点** = 結論の箇条書き / **概要** = 段落の説明 / **詳しく** = Wiki 本文。
- チャット入力の `"Fast"` / `"Think"`（`ChatInputField.swift` 28・39 行）を新キーに: `chat.mode.quick`（ja「すばやく」/ en「Quick」/ zh-Hans「快速」/ zh-Hant「快速」/ ko「빠르게」/ es「Rápido」/ de「Schnell」）、`chat.mode.think`（ja「じっくり」/ en「Thorough」/ zh-Hans「深入」/ zh-Hant「深入」/ ko「깊게」/ es「A fondo」/ de「Gründlich」）。旧キー `"Fast"` `"Think"` は xcstrings から削除してよい（参照ゼロを grep で確認してから）。
- 他言語の既存訳が上表と違う場合も上表で上書きする。

---

## 受け入れ基準
- [ ] 記事行が「タイトル / 一言（または整理中…）/ 保存元・日時」の 3 行。URL 全文・entity チップ・AI 生成バッジが無い
- [ ] メモ・ファイル・写真・音声で保存した記事の保存元が「メモ」等と表示される
- [ ] 記事詳細で、AI のまとめが写真より上にある。「要約」見出しが無い。タグが下部にある
- [ ] 追加画面にセグメントが無い。URL を貼って保存 → 従来どおり記事保存。文章を書いて保存 → メモとして保存。添付 3 種が従来どおり動く
- [ ] クリップボードに URL があるとき、貼り付けボタン 1 タップで保存される
- [ ] 画面下部のステータスバーが無く、処理中はリスト先頭に 1 行だけ出る
- [ ] 端末言語を English にすると、保存日時が英語で出る
- [ ] 新規・変更キーが 7 ロケールすべてで値を持つ
- [ ] ビルド成功・ユニットテスト全件成功・新規 warning なし

## 実機で確認（ユーザー）
- 長いタイトルのサイト名が消えすぎていないか（日本語サイトは除去されないのが正常）
- 追加画面の貼り付けボタン（iOS のペースト許可が出ないこと）

---

## 実装メモ（builder / 2026-11-19）

**状態**: T1〜T8 すべて実装。ビルド SUCCEEDED、`-only-testing:KnowledgeBaseTests` TEST SUCCEEDED（753 ケース pass / 0 fail）。新規 warning なし。

**新規**: `Services/ArticleSourceLabel.swift` / `TitleCleaner.swift` / `IntakeInputClassifier.swift`（3 つとも `nonisolated enum`。プロジェクト既定が MainActor で、テストの Equatable 比較が warning になるため）、`Views/ProcessingInlineStatus.swift`、テスト 3 本（ArticleSourceLabelTests 4 / TitleCleanerTests 4 / IntakeInputClassifierTests 6）。
**変更**: ArticleRow（T3/T4）、ArticleDetailView（T2/T5）、KnowledgeSummaryView（T5）、AddArticleSheet（T6）、ArticleListView / KnowledgeClipView（T7）、ChatInputField（T8）、Localizable.xcstrings、ArticleRowSavedAtTests（ja_JP を明示 + en_US 1 件追加）。
**削除**: `Views/BottomStatusBar.swift`（`git rm` 済み。参照ゼロ確認済み）。

**解釈・差異**:
- `chat.mode.quick` / `chat.mode.think` は xcstrings に既存（絵文字付き・コード未参照）だったため、新規追加ではなく値を tasks.md の文言（絵文字なし）で上書き。`Fast` / `Think` キーは参照ゼロを確認して削除。
- 時刻は `setLocalizedDateFormatFromTemplate("Hm")` だと ja で `9:15`（桁揃いなし）になり既存テスト期待値（`昨日 09:15`）が崩れるため、`dateFormat = "HH:mm"` 固定。日付は template `yMMdd`（ja で `2026/04/05`、en は `04/05/2026`）。`yMd` だと `2026/4/5` になる。
- `accessibilityText` のテストは端末言語依存を避け「保存で終わる or Saved で始まる」を許容。
- T7: `ProcessingInlineStatus` は List の中ではなく ArticleListView の VStack 先頭（リストの上、スクロールしない固定行）に配置。KnowledgeClipView は LazyVStack 先頭。
- T3: 「整理中…」は knowledge.status が pending / extracting のときのみ（status nil・skipped・failed は従来の enrichment.summary）。
- T6: 添付ボタン 3 つはテキスト入力モードのときだけ表示。添付中は × で解除してから選び直す。`addArticle.mode.url` / `note` / `label`、`addArticle.url.placeholder`、note 系キーは未使用になったが xcstrings に残置。
- xcstrings: 新キー 9（article.source.* 5 / article.row.organizing / savedAt.accessibility %@ / addArticle.input.placeholder / status.inline.organizing %lld）、値更新 7（T8 の 5 + chat.mode 2）、削除 2（Fast / Think）。差分は該当キーのみ。

**実機で確認が必要**: PasteButton の 1 タップ保存（許可ダイアログが出ないこと）、英語端末での保存日時表示、長いタイトルのサイト名除去、追加画面の添付 3 種の動作、処理中 1 行表示。UI テストは未実行。
