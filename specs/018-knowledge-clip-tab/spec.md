# Feature Specification: 知識 Clip タブ (Category 統合 AI ダイジェスト + Category 知識総まとめ詳細画面)

**Feature Branch**: `018-knowledge-clip-tab`
**Created**: 2026-05-05
**Status**: Draft

## なぜ (Why)

ユーザー要望:
> 「main 画面で news clip のように、知識 Clip を追加したい」+ 「Category 別でまとめ要点を絞って表示、複数記事で 1 つの投稿カード、まとめきれない時は別カード分割可」+ 「Category 詳細画面で今まで貯めた知識の総まとめ表示」

現状: ライブラリタブは記事一覧 (1 記事 = 1 行)、AI ブレインタブは Stats Row + Insight Card + Category List (Category 行 = タップで CategoryFilteredListView)。

問題:
- 「貯めた知識を流し読みで消費する」体験がない
- 記事ごとの essence は読めるが、**Category 全体としての統合理解** ができない
- 例: テクノロジーカテゴリに 30 記事あるが、「自分が今まで吸収したテクノロジー知識の総まとめ」を一目で見る画面がない

本 spec で 2 つの新画面を **新タブ「知識 Clip」** で提供:

1. **知識 Clip カードリスト** (タブ root): Category 別に AI 統合された 1 〜 N 枚のカード。各カードは複数記事の要点を 1 つに集約。News Clip 風の縦スクロール。
2. **Category 知識総まとめ詳細画面**: カードタップ → Category 内の知識を包括サマリ + Top KeyFact 10 + Top Entity 5 + 元記事一覧で深掘り表示。

ユーザー体験:
- 通勤中・隙間時間に「知識 Clip」タブを開く
- Category 別カードが縦並び (テクノロジー / 経済 / 健康...)
- 各カード: タイトル「テクノロジー」+ AI 統合 essence「最近 5 記事から: Apple Intelligence は...」+ Top KeyFact 3 + EntityChip 3
- 興味あるカードをタップ → 詳細画面で全 KeyFact / 全記事を深掘り
- 新記事保存 → 該当 Category カードに「更新あり」マーク → pull-to-refresh で再集約

## ゴール

- 新タブ「知識 Clip」で AI 統合 Category ダイジェストカードを縦表示
- カードは AI が複数記事の essence を統合した「要点集約」表示
- AI が「散らかった内容」と判断した Category は複数カードに分割
- カードタップで Category 知識総まとめ詳細画面に遷移、Top KeyFact 10 / Top Entity 5 / 元記事一覧
- 記事追加時に該当 Category カードを stale 化、pull-to-refresh で再集約
- Apple Intelligence 不可端末でも fallback (essence N 並べ) で機能提供

## 非ゴール

- 既読管理 / アーカイブ機能 → constitution V「不安喚起 UI 禁止」違反、不採用
- BGTask / scheduled refresh → ユーザー手動 refresh のみ MVP、将来 spec
- AI 生成インサイト (「あなたのテクノロジー知識傾向」風) → spec 035 候補
- 記事タイムライン (月別グルーピング) → 将来 spec
- マルチタグ間の集約調整 → AI 任せ
- Custom Category (CategorySeed 10 個固定の解消) → spec 036 候補
- BGTask / scheduled re-aggregation → 別 spec
- 横スワイプ TikTok / Stories 風 → 縦スクロール固定 (Q1=A 確定)

## ユーザストーリー

### US1 (P1) — 知識 Clip タブで Category 別 AI ダイジェスト閲覧

**As a** 通勤中・隙間時間にアプリを開くユーザー
**I want** 貯めた記事から AI が Category 別に統合した要点カードを縦スクロールで読みたい
**So that** 個別記事を全部読まなくても、自分の知識の全体像 (Category 別) を流し読みで把握できる

#### 受け入れ基準

- TabView 中央 (Library と AI ブレインの間) に「知識 Clip」タブが追加される (`lightbulb.fill` アイコン、Q9=A)
- タブ open → NavigationStack + ScrollView + LazyVStack でカード縦並び
- 各カード = 1 つの KnowledgeDigest (Category × cardIndex)、表示要素:
  - Category 名 (タイトル、large)
  - AI 統合 essence (~150 字)
  - Top KeyFact 3 個 (黒丸 bullet 形式)
  - 関連 EntityChip 3 個 (横並び)
  - 元記事数 (例: 「5 記事から」)
  - 最新元記事の savedAt (時間軸表示、spec 016 の SavedAtFormatter 再利用)
  - 小 OG 画像 (最新元記事の og:image があれば右肩 small)
- カード並び順 = Category 内最新元記事の savedAt desc (Q7=A)
- 1000 件規模でも 60fps 維持 (LazyVStack、Q10=A)
- TabView 順: ライブラリ → 知識 Clip → AI ブレイン (Q18=B)

### US2 (P1) — マルチカード分割

**As a** 大量記事を貯めたユーザー
**I want** 散らばった内容の Category は AI が自動で複数カードに分割してくれる
**So that** 1 つの長大なまとめカードで読みづらくならず、トピック別に集約される

#### 受け入れ基準

- AI (Foundation Models) が `@Generable struct DigestOutput { let cards: [Card] }` で N 個の Card を返す
- AI 判断: 「1 つにまとまらない時は N 個に分けてください」というプロンプト
- 各 Card は同 Category の異なる側面を扱う (例: テクノロジー → AI トピック / Mobile トピック)
- カード並び内では cardIndex asc + Category の最新 savedAt で Category 間並び決定
- 1 Category = 1 Card のみが基本、AI が 2 個以上必要と判断した場合のみ分割

### US3 (P1) — pull-to-refresh で再集約

**As a** 新記事を保存した後で「知識 Clip」を開いたユーザー
**I want** 該当 Category のカードに「更新あり」マークを見て、pull-to-refresh で最新統合まとめを取得したい
**So that** 自分のタイミングで AI 集約コストを払い、最新の知識統合を確認できる

#### 受け入れ基準

- 新記事保存後 (KnowledgeExtractionService 完了 hook で)、該当 Category の全 KnowledgeDigest を `isStale = true` 化
- 知識 Clip タブで stale カードに「更新あり」インジケータ表示 (例: 軽い「・」マーク or accentColor caption「更新あり」)
- 標準 SwiftUI `.refreshable { ... }` でユーザーが pull-down → KnowledgeDigestService.regenerateAllStale() 起動
- ローディング中はインジケータ表示 (標準 SwiftUI)
- 完了後、stale フラグ解除、新カード反映
- 複数 stale Category がある場合は全て一括再集約

### US4 (P1) — Category 知識総まとめ詳細画面

**As a** 「テクノロジー」カードをタップしたユーザー
**I want** Category 内の知識を包括的に把握できる詳細画面を見たい
**So that** カードの要点だけでなく全 KeyFact / 全 Entity / 全元記事を深掘りできる

#### 受け入れ基準

- カードタップ → CategoryKnowledgeDetailView (新画面、AI ブレインタブ Category タップ先 CategoryFilteredListView とは別画面、Q19=B)
- NavigationTitle = Category 名 (large)
- 表示要素:
  - 包括サマリ (top 段落、Category 内全 Digest の summary を結合 or 全記事の essence を AI 統合した 500 字程度の長文要約)
  - Top KeyFact 10 個 (Category 内全記事 KeyFact から salience 順)
  - Top Entity 5 個 (Category 内全記事 Entity から出現頻度順)
  - 元記事一覧 (CategoryFilteredListView を embed or 同等の Article リスト、savedAt desc)
- 元記事タップで ArticleDetailView 起動 (既存挙動)
- pull-to-refresh で当該 Category の全 Digest を再集約

### US5 (P2) — Empty state / 抽出中表示

**As a** 初回起動 or 記事ゼロ / AI 抽出中のユーザー
**I want** 「何が起きているか」「次に何をすればいいか」が一目でわかる
**So that** 困惑せず、Safari Share or 待機行動に進める

#### 受け入れ基準

- 記事 0 件: ContentUnavailableView「Safari から記事を保存しましょう」(AI Insight Card と同パターン)
- 記事はあるが essence 持つカードゼロ (全部 extracting 中): プレースホルダ「AI が知識を集約中です...」+ ProgressView
- どちらでもない通常状態は本セクション表示なし (Q17=C 場面別)

### Edge Cases

- **Apple Intelligence 利用不可** (Simulator / 非対応端末 / 設定 OFF): Foundation 失敗 → fallback (FallbackKnowledgeDigestService) で essence 上位 3 個を並べた簡易 summary + 元記事 KeyFact をそのまま list 化、機能不変 (Q16=A)
- **Category 内 essence 持つ記事 0 件**: その Category のカード非表示
- **Category 内記事 1 件のみ**: AI 統合スキップ、その記事の essence をそのまま summary に (1 記事から N 記事への統合は同じパス)
- **同じ Category で連続 stale → refresh**: regenerateAllStale が冪等、複数回呼んでも結果同じ
- **AI 集約中にユーザーが別タブ切替**: pull-to-refresh は `Task` で起動、cancel 不要 (バックグラウンド継続)
- **大量 Category (10 個全部) を一括 refresh**: 順次 await で逐次処理、UI は最初の Category から段階表示
- **新記事保存中に Clip タブ open**: stale フラグはまだ立っていない (KnowledgeExtractionService 完了 hook 後に立つ)、最新表示でない可能性あり
- **Reduce Motion ON**: pull-to-refresh の SwiftUI 標準アニメは Reduce Motion 自動短縮、機能不変
- **Dark Mode** (spec 017): 全カード token 経由で auto adapt、視認性確保
- **iPad Split View**: TabView は size class 関係なく動作、本 spec では layout 個別調整なし (将来 spec 033)

## 機能要件

### 1. 新タブ「知識 Clip」

- **FR-001**: TabView の 3rd タブとして `KnowledgeClipView` を配置 (順序: ライブラリ → 知識 Clip → AI ブレイン)
- **FR-002**: tabItem は `Label("clip.tab.title", systemImage: "lightbulb.fill")`、文言「知識 Clip」
- **FR-003**: accessibilityIdentifier "tab.knowledgeClip"
- **FR-004**: NavigationStack + ScrollView + LazyVStack 構造、`.refreshable { ... }` で pull-to-refresh

### 2. KnowledgeClipCard 表示

- **FR-005**: 各カードは 1 つの `KnowledgeDigest` を表示
- **FR-006**: 表示要素 (上から):
  - Category 名 (例: 「テクノロジー」、large title)
  - 元記事数 caption (例: 「5 記事から」)
  - 最新元記事の savedAt (時間軸表示、spec 016 SavedAtFormatter 再利用)
  - 統合 summary (~150 字)
  - Top KeyFact 3 個 (`・` bullet 形式)
  - 関連 EntityChip 3 個 (横並び LazyHStack)
  - タップ可能 (Button buttonStyle .plain で全領域タップで CategoryKnowledgeDetailView 起動)
- **FR-007**: 並び順 = Category 内最新元記事の savedAt desc (Category 全体の updateAt 推定)、同 Category 内 cardIndex asc
- **FR-008**: stale Category の Card は「更新あり」インジケータ表示 (caption text or「・」マーク、actionBlue 色)

### 3. Category 期間フィルター (Q6=B-1)

- **FR-009**: 上部にチップ「全部 / 7 日 / 30 日」セグメント (Q6=B-1)
- **FR-010**: チップ選択で表示カードを期間内 (元記事の savedAt が範囲内) に絞り込む
- **FR-011**: デフォルト「全部」

### 4. KnowledgeDigest 永続化

- **FR-012**: 新 @Model `KnowledgeDigest` を SwiftData schema に追加
  - `id: UUID` (`@Attribute(.unique)`)
  - `categoryRaw: String`
  - `cardIndex: Int`
  - `summary: String`
  - `topKeyFacts: [String]` (3 個)
  - `topEntityNames: [String]` (3 個)
  - `generatedAt: Date`
  - `isStale: Bool`
  - `sourceArticles: [Article]` (`@Relationship(deleteRule: .nullify)`、Constitution III non-optional)
- **FR-013**: SwiftData lightweight migration (新 @Model 追加、既存スキーマ無改変)
- **FR-014**: KnowledgeDigest は KnowledgeDigestService 以外から書き込まれない (read-only from views)

### 5. KnowledgeDigestService (新 service)

- **FR-015**: protocol `KnowledgeDigestService` を MainActor で定義
  - `regenerate(for category: Category) async throws -> [KnowledgeDigest]`: 該当 Category の Article 群から AI 統合 Digest を生成 (マルチカード分割は AI 判断)
  - `regenerateAllStale() async throws`: 全 Category の stale Digest を一括再生成
  - `markStale(for category: Category)`: 記事追加時に該当 Category の Digest を stale 化
- **FR-016**: `FoundationModelsKnowledgeDigestService` 実装: Apple Foundation Models で `DigestOutput { cards: [Card] }` を `@Generable` で生成、入力は Category 内全 Article の essence (Q11=A)
- **FR-017**: `FallbackKnowledgeDigestService` 実装: Apple Intelligence 不可時に essence 上位 3 個 + KeyFact list を簡易結合した Digest を 1 個生成 (Q16=A)
- **FR-018**: `SystemLanguageModel.availability` チェックで Foundation/Fallback を切替、bootstrap で適切な実装を inject

### 6. KnowledgeExtractionService 連携

- **FR-019**: `KnowledgeExtractionService` の知識抽出完了 hook 後で、該当記事の Tag (categoryRaw) → Category を引いて `KnowledgeDigestService.markStale(for:)` を呼ぶ
- **FR-020**: 既存 spec 012 (Auto-Tag) / spec 013 (Auto-Tag backfill) / spec 015 (AutoCategoryClassifier) との整合維持

### 7. CategoryKnowledgeDetailView (新画面)

- **FR-021**: NavigationDestination として CategoryKnowledgeDetailView を新設 (`CategoryDigestDetailDestination(category:)` Hashable)
- **FR-022**: 表示要素 (上から):
  - 包括サマリ (Category 全 Digest の summary を結合 or 全 essence を再 AI 統合した長文要約 ~500 字)
  - 区切り
  - Top KeyFact セクション (Category 内全記事 KeyFact から salience 順 top 10、SwiftUI List 形式)
  - 区切り
  - Top Entity セクション (Category 内全記事 Entity から出現頻度順 top 5、EntityChip 横並び)
  - 区切り
  - 元記事一覧 (CategoryFilteredListView を embed or 同等の Article LazyVStack、savedAt desc)
- **FR-023**: 元記事タップで ArticleDetailView 起動 (既存挙動)
- **FR-024**: pull-to-refresh で `KnowledgeDigestService.regenerate(for: category)` 起動

### 8. 期間フィルター (Q6=B-1)

- **FR-025**: 知識 Clip タブ上部に SegmentedPicker風 チップ「全部 / 7 日 / 30 日」、accessibilityIdentifier "clip.timeFilter"
- **FR-026**: 選択期間内に元記事 (sourceArticles の最新 savedAt) を持つ Digest のみ表示
- **FR-027**: デフォルト "全部"

### 9. Empty / Failure / Loading 表示

- **FR-028**: 記事 0 件 → ContentUnavailableView「Safari から記事を保存しましょう」(systemImage: `lightbulb`) + Share Sheet 案内文
- **FR-029**: 記事はあるが essence 0 件 (全 extracting 中) → プレースホルダ「AI が知識を集約中です...」+ ProgressView
- **FR-030**: pull-to-refresh 中 → 標準 SwiftUI ProgressView (Refresh control)
- **FR-031**: AI 集約失敗時 → fallback で簡易 Digest 表示 + caption「(簡易表示中)」(視覚マーク)

### 10. ストレスゼロ + Apple-quiet (DESIGN.md / spec 014/017 準拠)

- **FR-032**: 単一 accent rule 維持 (actionBlue 1 色、stale マーク含む)
- **FR-033**: gradient / shadow / 多色 phase tint 全廃継続
- **FR-034**: Dark Mode (spec 017) と整合 (DS.Color.* 経由で auto adapt)
- **FR-035**: 既読管理 / バッジ / トースト / ストリーク 全廃継続 (constitution V)

### 11. 既存挙動の保持

- **FR-036**: ライブラリタブ (ArticleListView / TagListView / 検索 / 関連記事) は完全保持
- **FR-037**: AI ブレインタブ (Stats Row / Insight Card / Category List → CategoryFilteredListView) は完全保持
- **FR-038**: ArticleDetailView (DisclosureGroup 本文 / KnowledgeSummary / EntityChip) は完全保持
- **FR-039**: spec 005 RefreshTrigger / NotificationCenter / scenePhase live update メカニズム維持

## 主要エンティティ

### 新規 @Model

#### KnowledgeDigest (新規)

| フィールド | 型 | 説明 |
|---|---|---|
| `id` | `UUID` (`@Attribute(.unique)`) | 一意キー |
| `categoryRaw` | `String` | CategorySeed.allSeeds.name の値 |
| `cardIndex` | `Int` | マルチカード分割時の順序 (0/1/2...)、単独なら 0 |
| `summary` | `String` | 統合 essence (~150 字) |
| `topKeyFacts` | `[String]` | 統合 KeyFact list (3 個、JSON 配列で永続化) |
| `topEntityNames` | `[String]` | 関連エンティティ名 (3 個) |
| `generatedAt` | `Date` | 生成日時 |
| `isStale` | `Bool` | 新記事追加で true、再集約で false |
| `sourceArticles` | `[Article]` | `@Relationship(deleteRule: .nullify)` で元記事 (Constitution III non-optional) |

`SharedSchema.all` に `KnowledgeDigest.self` を追加 (lightweight migration、既存データ無傷)。

### 新規 transient struct

| Struct | 用途 |
|---|---|
| `CategoryDigestDetailDestination` | NavigationStack の `.navigationDestination(for:)` 用 (Hashable、`category: Category` 保持) |
| `DigestOutput` | Foundation Models `@Generable` 出力 (`cards: [DigestCardOutput]`) |
| `DigestCardOutput` | 1 カード分の AI 出力 (`summary`, `topKeyFacts`, `topEntityNames`, `sourceArticleIDs`) |

### 新規 service

| Service | 責務 |
|---|---|
| `KnowledgeDigestService` (protocol) | regenerate / regenerateAllStale / markStale |
| `FoundationModelsKnowledgeDigestService` | Apple Foundation Models 経由で AI 統合 |
| `FallbackKnowledgeDigestService` | Apple Intelligence 不可時の essence 並べ簡易統合 |

### 新規 view

| View | 配置 |
|---|---|
| `KnowledgeClipView` | 3rd タブ root (タブ全体) |
| `KnowledgeClipCard` | 1 カード (KnowledgeDigest 表示) |
| `CategoryKnowledgeDetailView` | カードタップ先の詳細画面 |

### 改修

| File | 改修内容 |
|---|---|
| `KnowledgeTreeApp.swift` | TabView 3rd タブ追加 + KnowledgeDigestService inject + bootstrap で stale 全再集約 |
| `KnowledgeExtractionService.swift` | 知識抽出完了 hook で `KnowledgeDigestService.markStale(for:)` 呼び出し |
| `Article.swift` | `KnowledgeDigest` への inverse relationship 追加 (`@Relationship var digests: [KnowledgeDigest]`) |
| `Localization/Localizable.xcstrings` | 新規文言 (`clip.tab.title` / Empty state / 「全部」「7 日」「30 日」/ 「更新あり」/ 「(簡易表示中)」/ 「AI が知識を集約中です...」/ 「Safari から記事を保存しましょう」など 10 文言) |

## 成功基準 (Success Criteria)

- **SC-001**: 新タブ「知識 Clip」が TabView 中央に表示される (`lightbulb.fill` アイコン、accessibilityIdentifier "tab.knowledgeClip")
- **SC-002**: 知識 Clip タブ open → Category 別 AI 統合カードが LazyVStack で縦並び表示、初期表示 ≤300ms (1000 件規模)
- **SC-003**: カードに タイトル + summary + KeyFact 3 + EntityChip 3 + タグ + savedAt + 小 OG が正しく表示される
- **SC-004**: 期間チップ「7 日」タップ → 7 日以内の記事を含む Category のみ表示、切替 ≤100ms
- **SC-005**: カードタップ → CategoryKnowledgeDetailView 遷移、包括サマリ + Top KeyFact 10 + Top Entity 5 + 記事一覧表示、遷移 ≤300ms
- **SC-006**: 新記事を Safari Share で保存 → AI 抽出完了後 60 秒以内に該当 Category のカードに「更新あり」マーク表示 (isStale = true)
- **SC-007**: pull-to-refresh で `regenerateAllStale` 起動、ローディング表示 → 完了後最新カード反映、Category 1 個当たり ≤10 秒 (Foundation Models 1 回呼び出し)
- **SC-008**: Apple Intelligence 不可状態 (Simulator) で fallback (essence 並べ) カード表示、機能不変
- **SC-009**: 記事 0 件 Empty state「Safari から記事を保存しましょう」表示
- **SC-010**: 記事はあるが extracting 中の状態でプレースホルダ「AI が処理中」表示
- **SC-011**: マルチカード分割確認 (記事多数 + 散らかった内容で AI が `cardIndex` 1 以上の Card を生成)
- **SC-012**: 既存ライブラリタブ / AI ブレインタブの全機能 (検索 / Tag / Category タップ / Detail シート / 関連記事 / spec 016 B1 修正) が完全保持 (回帰なし)
- **SC-013**: 既存 unit test 全回帰 PASS + 新規 KnowledgeDigest / KnowledgeDigestService / view test が PASS

## 依存・前提

- spec 014/015/016/017 の実装が main マージ済 + 本 work tree に spec 017 commit 待機 (現在 main = `66ab948`)
- iOS 26+ / iPadOS 26+ + Apple Intelligence 端末 (推奨)
- 既存 SwiftData schema 完全保持 (KnowledgeDigest 新 @Model 追加のみ、lightweight migration)
- spec 015 の `Category` / `CategorySeed` を再利用
- spec 016 の `CategoryFilteredListView` / `SavedAtFormatter` / `CategoryFilter` 純関数を再利用 (CategoryKnowledgeDetailView 内 embed 含む)
- spec 017 の Dark Mode token を再利用 (DS.Color.* 経由で auto adapt)
- 既存 Foundation Models 統合パターン (`@Generable` / `LanguageModelSession`) を踏襲

## アサンプション

- **Foundation Models の 1 回プロンプトで複数 Card 生成**: `@Generable` で `DigestOutput { cards: [Card] }` の構造化出力、AI が判断
- **N 記事の essence 統合上限**: Category 内最大 50 記事まで (それ以上は最新 50 件で集約)、トークン上限対策
- **包括サマリ生成**: CategoryKnowledgeDetailView 起動時に AI に「全 Digest の summary を統合」をリクエスト or 全 Digest summary を結合表示 (実装で詰める)
- **isStale フラグの粒度**: Category 単位 (cardIndex 関係なく Category 全 Digest が stale 化)
- **再集約のトランザクション性**: regenerate(for:) は古い Digest を delete + 新 Digest を insert のアトミック操作
- **markStale の冪等性**: 既に stale な Category への markStale は no-op
- **AI 失敗時の fallback トリガー**: `regenerate` 内で try catch、Foundation Models 失敗時に Fallback service を internal 呼び出し
- **Empty Category (記事 0 / essence 0)**: KnowledgeDigest を生成しない (DB 書き込みなし)、view 側で非表示
- **Category 名の locale 依存**: 日本語固定 (CategorySeed)、AI prompt も日本語
- **iPad Split View**: TabView の size class 標準動作、本 spec で個別調整なし (spec 033 で対応)

## ロールアウト

- ユーザーへの破壊的変更:
  - TabView に新タブ追加 (機能損失なし、追加のみ)
  - 既存 ライブラリ / AI ブレインタブの内容は完全保持
- 既存データ完全保持 (KnowledgeDigest 新 @Model のみ、Article / Tag / Category 無改変)
- スキーマ migration: lightweight (既存データ無傷で KnowledgeDigest テーブルが追加される)

## 非機能

- **パフォーマンス**:
  - 知識 Clip タブ初期表示 ≤300ms (1000 記事 / 100 Digest 規模)
  - カード遷移 ≤300ms
  - Foundation Models 1 Category 集約 ≤10 秒
  - pull-to-refresh 全 stale 一括 ≤30 秒 (10 Category)
- **メモリ**: KnowledgeDigest は SwiftData lazy load、`@Query` で fetch 範囲限定
- **アクセシビリティ**: 全 interactive 要素に accessibilityLabel / Hint、Dynamic Type 互換、VoiceOver 対応
- **Dark Mode**: spec 017 の DS.Color adaptive 経由で自動対応
- **ローカライゼーション**: 全 UI 文言 Localizable.xcstrings 経由、Foundation Models prompt も日本語
- **オフライン**: Apple Intelligence on-device で外部通信ゼロ (constitution I 整合)

## オープン質問

なし (確定済 Q&A 19 問で全方針確定)。

将来 spec 候補:
- AI 生成インサイト (「あなたのテクノロジー知識傾向: AI > Swift > Mac」) → spec 035 候補
- 記事タイムライン (月別グルーピング) → 別 spec
- BGTask 自動再集約 (毎日 1 回) → 別 spec
- カード swipe アクション (「読了」「もう見ない」) → constitution V 違反、不採用
- Custom Category (10 個固定の解消) → spec 036 候補
- 包括サマリの履歴保存 (前回サマリと比較) → 将来 spec
- 知識 Clip カードの Share Sheet 出力 (SNS / メモアプリへ) → 将来 spec
