# UI/UX 再設計 v2 — 実装ガイド（総覽）

> 対象読者: 実装担当（builder / Sonnet）。このファイル → 各 spec の `tasks.md` の順に読む。
> 提案の元資料（HTML プロトタイプ）: https://claude.ai/artifact/9fARk9Vj7iRJpVU7SLgKJP
> 作成日: 2026-11-19 / 基準コミット: main `342ec6e`

## 1. 一言で

このアプリは「毎日ニュースが流れてくる場所」ではなく、**ユーザーが意図して保存した記事・メモの置き場**。
だから設計は「今日なにが来たか」ではなく、**「保存したものが、AI によってどう整理されたか」をすぐ見られる・すぐ探せる**ことを軸にする。

## 2. 確定した決定（ユーザー承認済み）

| # | 決定 | 内容 |
|---|---|---|
| D1 | ホームの名前 | **「ナレッジ」のまま**（「きょう」は採用しない）。保存は不定期なので日付で語らない。既存キー `clip.tab.title` の値は変更しない |
| D2 | タブ構成 | **ナレッジ / ライブラリ / 検索**（検索は iOS 26 の `Tab(role: .search)`）。「AI チャット β」タブは廃止し、検索に統合 |
| D3 | チャットの扱い | 機能は消さない。検索欄で入力 →「AI に聞く」で既存 `ChatService` の会話画面へ。会話履歴は検索画面の「最近聞いたこと」 |
| D4 | 未開封の扱い | 数字バッジは出さない。記事カード/行に小さな点（●）のみ |
| D5 | 大きいトピック | 関連記事が **15 件超**の広い概念は「書架」（グループ見出し）にし、要点は子トピックだけで作る。実機で 10/15/20 を比較してから確定（spec 105） |
| D6 | その他 | 提案どおり（各 tasks.md に記載） |

## 3. 段階と順序

**ユーザー決定（2026-11-19）: 3 段階を 1 ブランチ `redesign-v2` で順に実装し、1 つの PR で一緒にリリースする。** 103 → 104 → 105 の順に、前の段階のビルド・テストが通ってから次へ進む。下表のブランチ名は使わない。

| spec | ブランチ | 内容 | リスク | 新 AI 呼び出し | @Model 変更 |
|---|---|---|---|---|---|
| [103](103-display-cleanup/tasks.md) | `103-display-cleanup` | 表示だけ整理（記事行・記事詳細・追加画面・処理中表示・用語） | 低 | なし | なし |
| [104](104-navigation-search/tasks.md) | `104-navigation-search` | タブ再構成・検索とチャット統合・ホーム再構成・出典プレビュー | 中 | なし | `Article.lastOpenedAt` 追加 |
| [105](105-topic-quality/tasks.md) | `105-topic-quality` | 書架化・トピック詳細の固定構成・新しい要点の印 | 高（token） | 減る方向のみ | `ConceptPage.seenInsights` 追加 |

各 tasks.md 冒頭の「main にマージ済みであること」は「同じブランチで前段階が完了していること」と読み替える。

## 4. 全段階共通のルール（違反したら差し戻し）

### データ / CloudKit
- `@Model` の **削除・rename 禁止**（型名もプロパティ名も）。CloudKit の record type が壊れる。
- 追加するプロパティは **必ず default 値付き**（`var x: Date? = nil` / `var y: [String] = []`）。
- `SharedSchema.swift` は触らない（既存 @Model への列追加だけなので不要）。

### 多言語（7 ロケール）
- `KnowledgeBase/Localization/Localizable.xcstrings`。source は **ja**。対応ロケールは **ja / en / zh-Hans / zh-Hant / ko / es / de の 7 つ**。
- 新しいキーは 7 ロケールすべてに値を入れる。既存キー（例: `library.tab.title`）の JSON ブロックをコピーして同じ形で追加する。
- 文言の値を変える場合も 7 ロケールすべてを更新する。書式指定子（`%@` `%lld`）は全ロケールで一致させる。
- 編集後は `python3 -c "import json;json.load(open('KnowledgeBase/Localization/Localizable.xcstrings'))"` で JSON が壊れていないか確認。
- 日付・数値の表示に `Locale(identifier: "ja_JP")` を直書きしない（spec 103 で既存の直書きを直す）。

### AI（Foundation Models）
- spec 103 / 104 では **AI 呼び出しを増やさない**。`@Generable` の型・`@Guide` も触らない。
- spec 105 で生成プロンプトを触る場合は、実機で `TokenProbe` / ログの token 数を確認してからマージ（上限 4096）。

### コード
- デザイントークンは `DesignSystem.swift` の `DS.*` を使う。色・フォントの直書きをしない。見た目の基準は `DESIGN.md`（和紙・墨・藍、明朝の見出し）。
- アプリ target は file-system-synchronized group。新規ファイルは `KnowledgeBase/` 配下に置けば pbxproj 編集不要。Share/Safari 拡張にも入れる必要があるファイル（@Model 等）を新規作成しない。
- 既存の `accessibilityIdentifier` は、消す/変える場合 UI テスト（`KnowledgeBaseUITests/V3RedesignUITests.swift`）も合わせて直す。
- 純関数にできるロジック（判定・並べ替え・文字列整形）は View の外に出し、`KnowledgeBaseTests/` にユニットテストを書く。

### ビルドとテスト
```bash
xcodebuild build -scheme KnowledgeBase -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme KnowledgeBase -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:KnowledgeBaseTests
```
- 各タスク完了ごとにビルド、各 spec 完了時にユニットテスト全件。新規 warning を出さない。
- UI テストはシミュレータ起動が不安定なことがある。失敗したら内容を報告し、無理に通そうとしない。

### 進め方（cc-crew）
- builder が実装 → **qa-reviewer が別体で検証**（builder 自身が合格を出さない）→ shipper が commit/PR。
- commit / push / PR はユーザーが指示したときだけ。
- 各 spec 完了時に、ルートの `CLAUDE.md` の「Active features in flight」に 1 項目追記（既存項目の書き方に合わせる）。
- 実機でしか確認できない項目（AI 生成・token・CloudKit）は「残: 実機検証」として明記して終える。

## 5. builder への依頼文（コピペ用）

```
目的: specs/<103|104|105>-*/tasks.md を実装する。
読むもの: specs/REDESIGN-v2.md（共通ルール）→ 該当 tasks.md → tasks.md に出てくるファイル。
制約: REDESIGN-v2.md §4 をすべて守る。tasks.md に無い改善はしない。判断が要る箇所・tasks.md と実コードが食い違う箇所は、推測で進めず報告に書く。
返すもの: タスクごとの完了/未完了、変更ファイル一覧、ビルド結果、ユニットテスト結果（件数）、受け入れ基準のチェック結果、実機でしか確認できない残項目。
```
完了後は qa-reviewer に「同じ tasks.md の受け入れ基準と §4 の共通ルールで敵対的に検証」を依頼する。

## 6. やらないこと（スコープ外）
- 新しい視覚スタイル（配色・フォント）の提案。現行の DESIGN.md を維持する。
- 通知、連続記録（streak）、未読数バッジ。
- ウィジェットの作り直し（バックログ。必要になったら別 spec）。
- 「一般知識で答える」をボタン化する変更（現行の自動フォールバック＋バッジを維持）。
