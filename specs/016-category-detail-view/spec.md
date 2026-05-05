# Feature Specification: Category 詳細画面 + ArticleRow 時間軸 + ArticleDetailView 本文折りたたみ

**Feature Branch**: `016-category-detail-view`
**Created**: 2026-05-05
**Status**: Draft

## なぜ (Why)

spec 015 で AI ブレインタブ v2 (Stats Row + Insight Card + Category List) を出荷し、実機検証を行ったところ:

**バグ B1 発覚**:
> AI ブレインタブの Category List で「テクノロジー 3 記事」と表示されるが、タップ先で 2 記事しか見えない、最新記事が一覧に追加されない

原因: Category List の数字は **Category 内全 Tag の Article union (重複排除)** で集計されているのに、タップ先 `TagFilteredListView` は **単一 Tag (topTagName)** の Article のみ表示。記事が複数 Tag に紐づくと数字 ≠ 実体の不整合が起こる。

**例**: テクノロジー = "Swift" {A, B} + "iOS" {A, C} → 数字 {A,B,C} = 3 件、タップ先 Swift = 2 件のみ。

**UX 要望** (実機検証から):
1. ArticleRow に「いつ保存したか」が見えない (時間軸の概念がない)
2. ArticleDetailView を開くといきなり長い本文が見える、初期は折りたたみたい
3. Category タップで「全 Tag 横断記事一覧 + Tag フィルター」の詳細画面が欲しい

本 spec は B1 を **Category 詳細画面新設で根本解決** + 上記 3 つの UX 改善を 1 spec に集約。

ユーザー体験:
- AI ブレインタブで「テクノロジー 3 記事」をタップ → **CategoryFilteredListView** へ遷移
- 上部に **タグフィルターチップ** (Swift / iOS / AI / Apple / Mac、上位 5 個 + 「+N」展開ボタン)
- 下部に **3 記事すべて** が savedAt desc で並ぶ (= 数字と実体一致)
- タグチップタップで OR フィルター (例: Swift をタップ → Swift を含む記事のみ)
- 各 ArticleRow に「2 日前」「2026/05/05」のような **時間軸表示**
- ArticleDetailView を開くと **本文は折りたたまれている**、「本文を読む」をタップで展開

## ゴール

- バグ B1 (Category 数字不整合) を CategoryFilteredListView 新設で根本解決
- 全 ArticleRow に savedAt の時間軸表示 (相対 + 絶対のハイブリッド)
- ArticleDetailView 本文を初期折りたたみ (DisclosureGroup)
- Category 詳細画面でタグフィルター OR 条件 (上位 5 + 「+N」展開)
- Apple-quiet 視覚言語 (DESIGN.md / spec 015) を維持

## 非ゴール

- タグフィルター AND / NOT 条件 — 将来 spec
- 折りたたみ状態の記事ごと永続化 — シンプル化のため毎回 collapsed
- savedAt 並び替え以外のソート (人気順 / AI スコア順) — 将来 spec
- Category 内 Tag フィルターのドラッグ並び替え — 将来 spec
- ArticleDetailView 本文の他形式 (例: Apple News 風 fade-out オーバーレイ) — 採用せず DisclosureGroup 一択
- 既存 TagFilteredListView の置き換え — TagListView 経由 (個別 Tag フィルター) は引き続き使用、AIBrainView からのみ参照外し

## ユーザストーリー

### US1 (P1) — Category タップで全記事 + タグフィルター

**As a** AI ブレインタブの Category List で「テクノロジー」をタップしたユーザー
**I want** Category 内の全記事を見つつ、特定タグで絞り込めるフィルターも使いたい
**So that** 自分の知識分野を俯瞰しながらも、特定トピック (例: Swift だけ) で深掘りできる

#### 受け入れ基準

- AI ブレインタブの Category 行をタップ → **CategoryFilteredListView** へ遷移
- NavigationTitle は Category 名 (例: 「テクノロジー」) large title
- 上部にタグフィルターチップ行: Category 内 Tag を記事数降順で表示
- 上位 5 個まで表示、6 個以降は「+3 ▼」ボタン表示
- 「+N」タップ → 全タグを下に展開 (DisclosureGroup or 同行展開)
- 各タグチップに記事数 caption ("Swift (5)")
- 下部に Article リスト (Category 内 Tag union 全記事、savedAt desc、重複排除)
- タップで ArticleDetailView シート (既存挙動)

### US2 (P1) — タグフィルター OR 条件

**As a** CategoryFilteredListView で複数タグを選択したユーザー
**I want** 選択した「いずれか」のタグを持つ記事を絞り込みたい
**So that** 関連トピックを束ねて見られる (Swift + iOS の記事を一括表示)

#### 受け入れ基準

- タグチップ初期状態: 全て非選択 → Category 内全記事表示
- タグチップタップ → 選択 toggle (タップで選択 / 再タップで解除)
- 1 つ以上選択 → そのタグを持つ記事のみ表示 (OR 条件)
- 選択中チップは視覚的に強調 (Action Blue 背景 + white text、未選択は tagFill 背景 + ink text)
- 該当記事 0 件時 → ContentUnavailableView「該当記事がありません」
- 戻る or タブ切替 で選択状態リセット (シンプル化)

### US3 (P1) — ArticleRow 時間軸表示

**As a** ライブラリタブで記事一覧を見ているユーザー
**I want** いつ保存した記事か一目で分かる
**So that** 古い / 新しいの感覚が持てる、最近読んだ記事を見つけやすい

#### 受け入れ基準

- ArticleRow に savedAt 表示が追加される (URL 行の右隣、または別行末尾)
- フォーマット (現在時刻からの差分):
  - 今日: 「今日 14:30」
  - 昨日: 「昨日 09:15」
  - 過去 7 日以内: 「3 日前」
  - それ以上: 「2026/05/05」
- フォント: caption (DS.Typography.caption)、color secondary (muted)
- accessibilityLabel に savedAt の絶対値含める ("テクノロジー、12 記事、2026 年 5 月 5 日 14:30 保存")
- ArticleListView は spec 008 既存の savedAt desc sort を保持
- CategoryFilteredListView も savedAt desc sort

### US4 (P2) — ArticleDetailView 本文折りたたみ

**As a** 記事一覧から ArticleDetailView を開いたユーザー
**I want** いきなり長い本文が表示されず、要約と知識を先に見て、必要なら本文を展開したい
**So that** スクロールせず要点を把握できる、本文は読みたい時だけ読む

#### 受け入れ基準

- ArticleDetailView の本文セクションが `DisclosureGroup` で折りたたみ
- セクションタイトル: 「本文を読む」 (クリック可能、chevron で展開状態示す)
- 初期状態: collapsed (折りたたまれている)
- タップ → 標準 SwiftUI disclosure animation で展開
- 折りたたみ時は本文一切表示なし (高さゼロ)
- essence (要約) / KnowledgeSummary / 関連記事 / タグ等は **折りたたみ対象外** (常時表示)
- 折りたたみ状態は記事ごとに保持しない (毎回 collapsed で開く)
- accessibilityHint: 「タップして本文を展開」

### Edge Cases

- **Category 内 Tag が 0 件**: 通常起こらない (Tag が 0 件 = Category も計算されない)。万一の場合 ContentUnavailableView
- **Category 内 Tag が 1 件のみ**: タグフィルターチップ 1 個表示、「+N」ボタン非表示、フィルター無意味だが UI は機能
- **Category 内 Tag が 5 個ピッタリ**: 「+N」ボタン非表示、5 個全表示
- **Category 内 Tag が 6 個以上**: 上位 5 + 「+N」ボタン表示
- **タグチップで全選択**: 全選択 = 全タグ OR = Category 内全記事 (= 未選択と同じ結果)、機能としては動作
- **Article の savedAt が未来 (時計ずれ)**: RelativeDateTimeFormatter は「今すぐ」等を返す、許容
- **Article の savedAt が 1 年以上前**: 絶対日付 ("2025/01/15") で表示
- **本文 essence のみ存在 / 本文なし**: 本文セクション自体表示しない (折りたたみ DisclosureGroup 不出現)
- **Reduce Motion ON**: DisclosureGroup の expand/collapse は SwiftUI 標準アニメ、Reduce Motion で短縮 (機能不変)

## 機能要件

### 1. CategoryFilteredListView (新規 view)

- **FR-001**: 新規 navigation destination type `CategoryFilteredDestination(category: Category)` を Hashable で定義
- **FR-002**: NavigationStack の `.navigationDestination(for: CategoryFilteredDestination.self)` を AIBrainView に追加
- **FR-003**: NavigationTitle は Category.name (large title)
- **FR-004**: 画面構成: 上部タグフィルター行 (LazyHStack horizontal scroll) + 下部 Article リスト (LazyVStack)
- **FR-005**: タグフィルターチップは Category 内全 Tag を記事数降順で表示
- **FR-006**: 上位 5 個まで表示、6 個以降は「+%lld ▼」ボタン
- **FR-007**: 「+N」タップで全タグを展開 (DisclosureGroup or sheet、実装で詰める)
- **FR-008**: 各チップに記事数 caption (例: 「Swift (5)」)
- **FR-009**: チップタップで選択 toggle、選択中は Action Blue 背景 / white text、未選択は tagFill 背景 / ink text
- **FR-010**: フィルター 0 個選択 = 全記事、1 個以上 = OR 条件
- **FR-011**: Article リストは Category 内 Tag union (重複排除) → フィルター適用 → savedAt desc sort
- **FR-012**: ArticleRow を再利用 (spec 016 で savedAt 表示追加済)
- **FR-013**: 該当記事 0 件 → ContentUnavailableView「該当記事がありません」(systemImage: `doc.text.magnifyingglass`)

### 2. AIBrainView 改修 (Category 行タップ先変更)

- **FR-014**: `KnowledgeCategoryRow` の `NavigationLink(value: TagFilteredDestination(...))` を `NavigationLink(value: CategoryFilteredDestination(category: category))` に変更
- **FR-015**: AIBrainView の NavigationStack に `.navigationDestination(for: CategoryFilteredDestination.self)` を追加
- **FR-016**: `KnowledgeCategoryRow.topTagName` プロパティは不要に (削除 or accessibility 用に保持)
- **FR-017**: B1 バグ自然解決 (タップ先で全 Tag union 記事を表示 → 数字 = 実体)

### 3. ArticleRow 時間軸表示

- **FR-018**: ArticleRow 内、URL 行の右側または最下部に savedAt 表示を追加
- **FR-019**: フォーマット判定 (現在時刻と savedAt の差):
  - 同一日 (Calendar.isDateInToday) → 「今日 HH:mm」
  - 前日 (Calendar.isDateInYesterday) → 「昨日 HH:mm」
  - 7 日以内 → RelativeDateTimeFormatter で「N 日前」
  - それ以上 → DateFormatter で「YYYY/MM/DD」
- **FR-020**: 言語: 日本語 (RelativeDateTimeFormatter は locale `ja_JP`)
- **FR-021**: フォント: `.caption` / foregroundStyle `.secondary`
- **FR-022**: accessibilityLabel に savedAt 絶対値を含める

### 4. ArticleDetailView 本文折りたたみ

- **FR-023**: 本文セクションを `DisclosureGroup("本文を読む") { ... 本文 ... }` でラップ
- **FR-024**: 初期状態 collapsed (`@State private var isBodyExpanded: Bool = false`)
- **FR-025**: SwiftUI 標準 disclosure animation を使用 (Reduce Motion 自動対応)
- **FR-026**: 折りたたみ時は body view が `EmptyView` 等で render されない
- **FR-027**: essence / KnowledgeSummary / 関連記事 / タグ / AI バッジ / OG 画像は折りたたみ対象外、常時表示
- **FR-028**: 本文存在しない記事 (`article.body?.extractedText == nil`) は DisclosureGroup 自体非表示
- **FR-029**: タップで状態切替、折りたたみ状態は次回 ArticleDetailView 起動時にリセット (毎回 collapsed)
- **FR-030**: accessibilityHint: 「タップして本文を展開 / 折りたたむ」

### 5. ストレスゼロ + Apple-quiet (DESIGN.md 準拠継続)

- **FR-031**: 全 view で interactive 要素は Action Blue 単一色
- **FR-032**: gradient / shadow / 多色 phase tint なし (spec 015 継承)
- **FR-033**: 演出は標準 SwiftUI animation (DisclosureGroup expand / Tag toggle ripple) のみ
- **FR-034**: push 通知 / バッジ / トースト / ストリーク / レベル / ランキング 全廃継続

### 6. 既存挙動の保持

- **FR-035**: ライブラリタブの ArticleListView / TagListView は ArticleRow の savedAt 追加以外無改修
- **FR-036**: spec 005 RefreshTrigger / NotificationCenter / scenePhase live update メカニズム維持
- **FR-037**: spec 012 AutoTagApplier / spec 013 AutoTagBackfillRunner / spec 015 AutoCategoryClassifier は変更なし
- **FR-038**: 既存の TagFilteredListView は ArticleListView の TagListView 経由で引き続き機能 (個別 Tag フィルター用、AIBrainView からのみ参照外し)

## 主要エンティティ

新規 @Model なし、新 schema migration なし。

### 新規 transient struct

| Struct | 用途 |
|---|---|
| `CategoryFilteredDestination` | NavigationStack の `.navigationDestination(for:)` 用 (Hashable、`category: Category` を保持) |

### 改修 view file

| File | 改修内容 |
|---|---|
| `CategoryFilteredListView` | **新規** (Category 詳細画面の本体) |
| `AIBrainView` | NavigationLink target 変更 + `.navigationDestination(for:)` 追加 |
| `KnowledgeCategoryRow` | topTagName 削除 (不要)、accessibilityLabel 微調整 |
| `ArticleRow` | savedAt 時間軸表示追加 |
| `ArticleDetailView` | 本文を DisclosureGroup でラップ |
| `Localizable.xcstrings` | 新規文言 (「本文を読む」「該当記事がありません」「+%lld」「今日」「昨日」等) |

## 成功基準 (Success Criteria)

- **SC-001**: B1 バグ修正確認 — Category List 「テクノロジー 3 記事」をタップ → CategoryFilteredListView で 3 記事すべて表示 (数字 = 実体)
- **SC-002**: タグフィルター 0 個 → Category 内全記事、1 個以上 → OR 条件記事のみ、表示切替が 0.3 秒以内
- **SC-003**: タグ 6 個以上ある Category で「+N」ボタンタップ → 残りタグ展開が 0.3 秒以内
- **SC-004**: 新記事を Safari Share で保存 → 60 秒以内に CategoryFilteredListView の最新追加 (savedAt desc top に表示)
- **SC-005**: ArticleRow に savedAt 表示が全行で見える、今日/昨日/相対/絶対の自動切替が正しい
- **SC-006**: ArticleDetailView を開いた瞬間は本文 collapsed、「本文を読む」タップで 0.5 秒以内展開
- **SC-007**: Reduce Motion ON で DisclosureGroup expand / Tag toggle が短縮 / 即時、機能不変
- **SC-008**: 既存ライブラリタブ (検索 / タグ一覧 / Detail シート / 関連記事) が spec 015 までと完全一致 (回帰なし)
- **SC-009**: spec 015 までの全 unit テスト (66 ケース以上) が無傷で pass

## 依存・前提

- spec 001-015 までの全機能稼働済 (現在 main = `47a9338`、spec 014 PR #3 / spec 015 ブランチ未 commit)
- iOS 26+ / iPadOS 26+
- 既存 SwiftData schema 完全保持 (新 attribute / migration なし)
- spec 015 の `Category` / `CategorySeed` を再利用
- spec 008 の `Tag` / `TagFilteredListView` を再利用 (既存挙動)

## アサンプション

- **タグフィルター OR 条件のみ**: AND / NOT は将来 spec で追加検討
- **「+N」展開後の折りたたみ復帰**: 「-N」or 戻るで折りたためる、details は実装で詰める
- **タグチップ選択状態の永続化**: しない (画面遷移でリセット)
- **savedAt 表示位置**: ArticleRow 既存の URL 行の右側 or 別行末尾、実装で見映えで決定
- **DisclosureGroup の標準 SwiftUI 挙動**: animation / accessibility / Dynamic Type は OS 任せ
- **本文の essence と KnowledgeSummary**: 折りたたみ対象外で常時表示、要約は記事を開いた時の主役
- **CategoryFilteredListView と TagFilteredListView の使い分け**: AIBrainView からは Category 経由、ArticleListView の TagListView からは個別 Tag

## ロールアウト

- ユーザーへの破壊的変更:
  - AI ブレインタブ Category タップ先が変わる (B1 修正、UX 改善のみ、機能損失なし)
  - ArticleDetailView 本文の見え方が変わる (初期折りたたみ、ユーザーは「本文を読む」タップ必要)
- 既存データ完全保持、schema 変更なし
- ライブラリタブの既存挙動完全保持

## 非機能

- **パフォーマンス**: CategoryFilteredListView 初期表示 ≤300ms、タグフィルター切替 ≤100ms (1000 記事規模で計測)
- **メモリ**: タグフィルター集計は memory 内 computed property、`@Query<Tag>` 全件 + Article relationship 経由
- **アクセシビリティ**: 全 interactive 要素に accessibilityLabel / Hint、Dynamic Type 互換、VoiceOver 動作確認済
- **Dark Mode**: DS.Color 既存 adaptive
- **ローカライゼーション**: 全文言 Localizable.xcstrings 経由

## オープン質問

なし (確定済 Q&A 経由 3 点: 日付形式 / フィルター件数 / 本文折りたたみ仕様)。

将来 spec 候補:
- タグフィルター AND / NOT
- 折りたたみ状態の記事ごと永続化
- ソート切替 (人気順 / AI スコア順)
- ArticleRow の左 swipe アクション (削除 / お気に入り)
