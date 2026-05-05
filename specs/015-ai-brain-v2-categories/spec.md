# Feature Specification: AI ブレインタブ v2 + DesignSystem migration + Category 階層

**Feature Branch**: `015-ai-brain-v2-categories`
**Created**: 2026-05-05
**Status**: Draft

## なぜ (Why)

spec 011-014 で AI ブレインタブを構築 (PowerGauge / KnowledgeMap / RecentActivityCards) した後、ユーザーインタビューから以下の問題が判明:

| 問題 | 詳細 |
|---|---|
| グラフが意味不明 | KnowledgeMap のノードと線が並んでも「何がわかるか」が伝わらない |
| 数字だけで温度がない | PowerGauge の数値を見て「で、何?」になる |
| 構造が分散 | 縦・横・グラフで視線が定まらない |
| 演出が多すぎる | パルス / フェードイン / 横スクロールが情報密度の薄さを隠していた |

並行して project root の `DESIGN.md` で Apple-quiet (single accent / no gradient / no decoration) な視覚言語を確定。さらに、ユーザーは「AI 付与の Tag より上位の Category 階層が必要」と発言。

本 spec は **3 つを 1 spec に集約**:

1. **AI ブレインタブ v2 UI**: 縦スクロール 1 本のダッシュボード (Stats Row / AI Insight Card / Category List)
2. **DesignSystem.swift refactor**: DESIGN.md target に migration (gradient/phase token 削除 + Action Blue 等追加)
3. **Category 階層**: シードカテゴリ (10 個程度) を `Tag.categoryRaw` に Apple Foundation Models で 1 回推論

ユーザー体験:
- アプリ起動 → AI ブレインタブを開くと **静かなダッシュボード** が見える
- 「テクノロジー 12 記事 / 経済 8 記事 / 健康 5 記事 ...」のように **自分の知識分野が一目で俯瞰** できる
- カテゴリーをタップすると該当記事一覧へ
- 演出は控えめ (Stats Row カウントアップのみ、Reduce Motion で即時)

## ゴール

- AIBrainView の 3 セクション完全書き換え (Stats Row + AI Insight Card + Category List)
- 6-10 個のシードカテゴリで Tag を高レベル分類
- DesignSystem.swift を DESIGN.md target (Apple-quiet) に refactor
- 既存スキーマには `Tag.categoryRaw: String?` のみ追加 (lightweight migration)
- 廃止 (= AIBrainView から参照外す) する 3 view は **コード削除しない** (将来 spec で復活余地)

## 非ゴール

- Category 編集 UI (ユーザーがシードを増やす / 並び替え) — 将来 spec
- Category 動的分類 (Tag 追加のたびに LLM、現状は 1 回限り永続化) — 将来 spec
- Category 別 PowerGauge / グラフ復活 — 将来 spec
- KnowledgeMap / RecentActivityCards の v2 復活 — 将来 spec
- DesignSystem の更なる最適化 (Color asset 化、Liquid Glass) — 将来 spec
- 既存記事への背景 backfill (新記事保存時 + bootstrap で 1 回) — 内包だが拡張なし

## ユーザストーリー

### US1 (P1) — 自分の知識分野が一目で見える

**As a** 数十件の記事を保存してきたユーザー
**I want** AI ブレインタブを開いたら、自分がどのカテゴリーに何記事保存したかが俯瞰できる
**So that** 「自分はテクノロジーを多く読んでる」のような気付きを得て、興味の地図を確認できる

#### 受け入れ基準

- AI ブレインタブをタップ → 縦スクロール 1 本のダッシュボードが表示
- Section 1 (Stats Row): 「N 記事 / N 知識 / N ファクト」3 列統計
- Section 2 (AI Insight Card): 「最も読んでいる分野: テクノロジー (12 記事)」
- Section 3 (Category List): カテゴリー一覧、記事数降順、プログレスバー付き
- 横スクロール / グラフ / カウントアップ以外の演出なし
- カテゴリー名は日本語 (テクノロジー / 経済 / 健康 / デザイン / 学術 / アート / ニュース / スポーツ / エンタメ / その他)

### US2 (P1) — Category タップで該当記事一覧へ

**As a** 「テクノロジー」分野の記事を見直したいユーザー
**I want** Category List で「テクノロジー」をタップ → 該当記事一覧へ遷移
**So that** カテゴリーから記事の発掘が始まる

#### 受け入れ基準

- Category List 各行をタップ → そのカテゴリーに属する Tag の記事一覧 (新しい順)
- 既存 `TagFilteredListView` の延長として実装可
- 戻るボタンで Category List に戻る
- カテゴリーが空 (該当 Tag なし) → 行自体表示されない

### US3 (P1) — Apple-quiet な視覚体験

**As a** spec 014 の派手な視覚 (gradient / shadow / phase tint) に違和感があったユーザー
**I want** 静かでアップルらしい一貫した見た目
**So that** 落ち着いて記事や知識に向き合える

#### 受け入れ基準

- 全 view で interactive 要素は **Action Blue 単一色** (DESIGN.md の primary)
- gradient 全廃 (PowerGauge / KnowledgeMap / RecentActivityCards から参照外す + DesignSystem.swift から token 削除)
- BottomStatusBar の 4 phase (enrichment / body / knowledge / tagBackfilling) tint も全部 Action Blue 1 色、phase label text のみで区別
- Surface は white (canvas) と parchment (#faf8f3) の 2 色のみ
- Reduce Motion ON で全演出停止

### US4 (P2) — 新しい記事の Category 自動分類

**As a** 記事を Safari から Share Sheet で保存したユーザー
**I want** AI が自動で記事のカテゴリーを判定し、AI ブレインタブの Category List に反映
**So that** 何もしなくても自分の知識地図が育っていく

#### 受け入れ基準

- 記事保存 → AutoTagApplier で Tag が自動付与 (spec 012 既存)
- 新規 Tag が作成された場合、AutoCategoryClassifier で Category を 1 回推論し、`Tag.categoryRaw` に保存
- 推論失敗 / Foundation Models 利用不可 → `categoryRaw = "その他"` (fallback)
- 既存 Tag (categoryRaw = nil) は bootstrap 時の 1 度限り backfill で classify (spec 013 と同じパターン、別フラグ)
- AI ブレインタブの Category List に新カテゴリーが反映される (Tag が増えた直後 or バックグラウンド分類完了後)

### Edge Cases

- **記事 0 件 (新規インストール)**: Stats Row 全部 0、AI Insight Card「Safari から記事を保存しましょう」、Category List Empty State 「カテゴリーがありません」
- **タグ 0 件・記事あり (knowledge 抽出未完など)**: Stats Row は記事数のみ、Category List Empty State
- **全タグが「その他」(fallback)**: Category List に「その他」だけ表示、それでも機能する
- **シードに該当しないニッチタグ (例: SwiftData)**: AutoCategoryClassifier が「テクノロジー」推論、または「その他」fallback
- **Tag 名が複数カテゴリーに該当しうる (例: AI = テクノロジー or 学術)**: AutoCategoryClassifier の判断で 1 つのみ。後で改善する場合は Category 編集 UI (将来 spec)
- **bootstrap backfill 中にユーザーが AI ブレインタブを開く**: BottomStatusBar に「カテゴリー分類中」表示、Category List は分類済 Tag のみで先行表示
- **アプリ強制終了 → 次回起動**: backfill フラグが false なら再実行
- **Foundation Models 利用不可**: AutoCategoryClassifier 全体を skip、全 Tag が `categoryRaw = nil` のまま → Category List に「その他」だけ表示 (recoverable)

## 機能要件

### 1. AI ブレインタブ v2 UI (3 セクション)

- **FR-001**: AIBrainView を完全書き換え。NavigationStack 内に縦 ScrollView 1 本のみ、3 セクションを上から `AIBrainStatsRow` → `AIInsightCard` → Category List で配置
- **FR-002**: ScrollView の `.scrollIndicators(.hidden)`、navigationBarTitleDisplayMode は default (中サイズ、large でない)
- **FR-003**: NavigationDestination は spec 008 既存の `TagFilteredDestination` を再利用 (Category List 行 タップ時)
- **FR-004**: BottomStatusBar は overlay として継続表示 (両タブ共通、spec 005 既存メカニズム)

### 2. Section 1 — Stats Row

- **FR-005**: 3 列等幅、各列に「数字 (`.title2.bold` / `monospacedDigit`)」+「ラベル (`.caption`)」
- **FR-006**: 数字 3 種:
  - 記事 = `Article` 全件 count
  - 知識 = `KnowledgeEntity.name` (lowercased + trim) で重複排除した count
  - ファクト = `KeyFact` 全件 count
- **FR-007**: 起動時 (onAppear) に 0 → 実数 0.5 秒カウントアップ。`DS.Animation.ifMotionAllowed` で Reduce Motion 対応
- **FR-008**: `dsCardBackground()` で薄い surface (parchment) 背景 + hairline border
- **FR-009**: タップ不可 (情報表示のみ)

### 3. Section 2 — AI インサイトカード

- **FR-010**: タグ 0 件: 「Safari から記事を保存しましょう」(`.body` text + `tray.and.arrow.down.fill` アイコン)
- **FR-011**: タグ 1 件以上: 「最も読んでいる分野: {トップ Category 名} (N 記事)」+ `sparkles` SF Symbol
- **FR-012**: トップ Category = `Tag.categoryRaw` でグループ化 → 各 Category の記事数合計が最大のもの
- **FR-013**: 同点が複数ある場合、Category seed の定義順序で最初のもの
- **FR-014**: 「その他」のみが存在する場合、「その他」表示
- **FR-015**: 背景は薄い `actionBlue.opacity(0.05)` (DS.Color.actionBlueLight 等の新 token) + hairline border
- **FR-016**: タップ不可 (情報表示のみ)

### 4. Section 3 — Category List

- **FR-017**: 各行 = `KnowledgeCategoryRow`、 Category 名 + プログレスバー + 「N 記事」label
- **FR-018**: 並び順: 記事数の多い順 (降順)。同数の場合 Category seed 定義順
- **FR-019**: 表示対象: 記事 (= Tag を介して Article) が 1 件以上ある Category のみ。0 件 Category は非表示
- **FR-020**: プログレスバー幅 = `(このカテゴリーの記事数 / 最多カテゴリーの記事数) × 利用可能幅`
- **FR-021**: プログレスバー色 = Action Blue (single accent rule)
- **FR-022**: 行タップ → そのカテゴリーに属する Tag のうち最初/任意 1 個の `TagFilteredListView` へ遷移 (MVP)、または将来 spec の `CategoryFilteredListView`
- **FR-023**: Empty State (Category 0 件): `ContentUnavailableView` 「カテゴリーがありません」
- **FR-024**: 行間 hairline divider

### 5. Category 階層 (シード mapping + 静的分類)

- **FR-025**: `CategorySeed.swift` で **10 個のシードカテゴリー** を定義 (テクノロジー / 経済 / 健康 / デザイン / 学術 / アート / ニュース / スポーツ / エンタメ / その他)
- **FR-026**: 各シードに `name` (日本語) + `englishName` (将来 i18n) + `order` (表示順) を持つ
- **FR-027**: `Tag` モデルに `categoryRaw: String?` 属性追加 (lightweight migration、Schema バージョン bump)
- **FR-028**: `AutoCategoryClassifier` protocol を新設、production 実装は Apple Foundation Models 経由 (Tag.name → Category.name 推論、1 回/Tag)
- **FR-029**: TagStore.addTag 内で新規 Tag 作成時、AutoCategoryClassifier を fire-and-forget で呼び出し、結果を `categoryRaw` に保存
- **FR-030**: bootstrap で UserDefaults フラグ `auto_category_backfill_v1_done` をチェック、false なら全 Tag (`categoryRaw == nil`) を classify (spec 013 と同パターン)
- **FR-031**: Foundation Models 利用不可 / 推論失敗 → `categoryRaw = "その他"` (fallback)
- **FR-032**: AutoCategoryClassifier mock 実装 (test 用) を提供、`InMemoryAutoCategoryClassifier` で hardcoded mapping
- **FR-033**: BottomStatusBar に「カテゴリー分類中」phase を追加 (`.categoryClassifying`、tint は Action Blue 統一)

### 6. DesignSystem.swift refactor (DESIGN.md target migration)

- **FR-034**: `DesignSystem.swift` から **9 token 削除**: aiBrandStart / End / Edge / NodeFill / NodeStroke / phaseEnrichment / phaseBody / phaseKnowledge / phaseTagging
- **FR-035**: `DesignSystem.swift` に **5 token 追加**: actionBlue (#0a4d8c) / actionBlueFocus (#1565b8) / parchment (#faf8f3) / knowledgeTile (#f5f5f7) / tagFill (#eaeaef)
- **FR-036**: 既存の `dsCardBackground` / `dsAIGradientBackground` ViewModifier を整理: `dsAIGradientBackground` は **削除** (gradient 廃止)、`dsCardBackground` のみ維持
- **FR-037**: BottomStatusBar の `phaseTintColor()` 関数を全 case Action Blue に統一、case 区別は label text のみ
- **FR-038**: ArticleRow の leading edge accent を `aiBrandEnd` → `actionBlue` に置き換え (見た目軽微)
- **FR-039**: 廃止 view (PowerGaugeCard / KnowledgeMapView / RecentActivityCards) は **コード残存** (AIBrainView から参照外すのみ)
- **FR-040**: 廃止 view 内で削除トークンを参照している箇所は token 名を新トークンにマッピング (compile error 回避)

### 7. ストレスゼロ + Apple-quiet (DESIGN.md Do's/Don'ts 準拠)

- **FR-041**: gradient 全廃 (DesignSystem token + 全 view 内 LinearGradient / RadialGradient 直接記述も)
- **FR-042**: shadow は **完全廃止** (KnowledgeMap も廃止のため)
- **FR-043**: 演出は Stats Row カウントアップのみ、`DS.Animation.ifMotionAllowed` で Reduce Motion 対応
- **FR-044**: push 通知 / バッジ / トースト / ストリーク / ランキング / 先週比 / レベル数字 全廃
- **FR-045**: フォントは Apple-tight letter-spacing (DS.Typography 既存)、日本語は letter-spacing 0
- **FR-046**: VoiceOver は Stats Row を `accessibilityElement(.combine)` で集約読み上げ「N 記事、N 知識、N ファクト」

### 8. 既存挙動の保持

- **FR-047**: ライブラリタブ (ArticleListView / Detail / search / TagListView) の挙動は変更しない (token 名のみ更新)
- **FR-048**: spec 005 RefreshTrigger / NotificationCenter / scenePhase live update メカニズムは維持
- **FR-049**: spec 012 AutoTagApplier (auto-tag) は変更なし、Category は Tag 作成後の追加処理として連携
- **FR-050**: spec 013 AutoTagBackfillRunner は変更なし

## 主要エンティティ

### 改修される @Model

| Model | 改修内容 |
|---|---|
| `Tag` | `categoryRaw: String?` 属性を追加 (default nil)。lightweight migration |

### 新規 transient struct

| Struct | 用途 |
|---|---|
| `Category` | シードカテゴリー定義 (`name`, `englishName`, `order`) |
| `CategorySnapshot` | Category 別記事数のメモリ集計 (display 用) |

### 新規 service / protocol

| Service | 役割 |
|---|---|
| `CategorySeed` (enum) | 10 個のシードカテゴリーを static let で定義、display order を保証 |
| `AutoCategoryClassifier` (protocol) | Tag → Category 推論 |
| `FoundationModelsAutoCategoryClassifier` | Apple Foundation Models 実装 (`@Generable`) |
| `InMemoryAutoCategoryClassifier` | テスト用 mock |
| `AutoCategoryBackfillRunner` | bootstrap で全 Tag を 1 回 classify (spec 013 と同パターン) |
| `BackfillFlagStore` (既存) | `auto_category_backfill_v1_done` キー追加 |

### 廃止される token (DesignSystem.swift)

aiBrandStart / End / Edge / NodeFill / NodeStroke / phaseEnrichment / phaseBody / phaseKnowledge / phaseTagging

## 成功基準 (Success Criteria)

- **SC-001**: 新規インストール直後 AI ブレインタブで Stats Row 全 0 + Insight Card 「保存しましょう」+ Category List Empty が 1 秒以内表示
- **SC-002**: 30 記事保有時、Stats Row のカウントアップが 0.5 秒で完了
- **SC-003**: タグ 5 件以上 + 全 Tag が classify 済の状態で、Category List が降順 + 最多のプログレスバー 100% 表示
- **SC-004**: Category 行タップ → TagFilteredListView 遷移 0.5 秒以内
- **SC-005**: 新記事保存 → AutoTagApplier → AutoCategoryClassifier → Category List 反映が 60 秒以内 (Apple Foundation Models 推論時間込み)
- **SC-006**: bootstrap backfill が 100 Tag で 60 秒以内、500 Tag で 5 分以内
- **SC-007**: Reduce Motion ON で全演出停止、機能不変
- **SC-008**: BottomStatusBar 4 phase 全て Action Blue 1 色、phase label text のみで区別
- **SC-009**: 既存ライブラリタブの挙動が spec 014 までと完全一致 (回帰なし)

## 依存・前提

- **spec 001-014** までの全機能稼働済 (現在 main = `47a9338`、spec 014 PR #3 OPEN → merge 済前提)
- **iOS 26+** / iPadOS 26+
- **既存 SwiftData schema** + `Tag.categoryRaw: String?` 1 属性追加 (lightweight migration)
- spec 012 AutoTagApplier / spec 013 AutoTagBackfillRunner / spec 008 TagStore を再利用
- spec 005 RefreshTrigger / ProcessingMonitor を Category 分類進捗に拡張

## アサンプション

- **シードカテゴリー固定**: 10 個に固定、ユーザー編集 UI は将来 spec
- **classify は 1 回限り**: Tag.categoryRaw が nil の時のみ実行、再分類は将来 spec
- **fallback は「その他」**: Foundation Models 失敗 / 不明 / nil → 「その他」
- **複数カテゴリー該当タグ**: 1 つに絞る、未来 spec で多重対応
- **Category タップ遷移**: MVP では `TagFilteredListView` (Category 内最も記事多い Tag) 経由、将来 spec で `CategoryFilteredListView` 新設
- **token 削除に伴う既存 view 影響**: PowerGaugeCard / KnowledgeMapView / RecentActivityCards はコード残存だが内部で削除トークンを参照 → 新トークンに mapping (例: aiBrandStart → actionBlue.opacity(0.15))
- **MainActor 実行**: AutoCategoryClassifier は MainActor (TagStore.addTag フローと一致)
- **Foundation Models 推論時間**: 1 Tag ~5 秒想定、100 Tag で 8-10 分かかりうる → bootstrap backfill は ProcessingMonitor で「カテゴリー分類中 N/M」表示

## ロールアウト

- 既存ユーザーへの破壊的変更:
  - AI ブレインタブの見た目が大幅変更 (PowerGauge / KnowledgeMap / RecentActivity 廃止) → migration アラートは出さず、起動時に新 UI を体験
  - Tag.categoryRaw は migration で nil 追加、初回起動時に backfill が走る (BottomStatusBar で「カテゴリー分類中」表示)
- 既存記事のデータは保持、Tag も保持、Category だけが新規追加
- ライブラリタブの挙動は完全に保持

## 非機能

- **パフォーマンス**: AIBrainView 起動 ≤ 1 秒、Stats Row カウントアップ 0.5 秒、Category List 表示 ≤ 0.3 秒
- **メモリ**: Category snapshot は computed property、永続化なし。`@Query<Tag>` 全件 + メモリ集計で 1000 タグ規模なら 5MB 以下
- **電池**: AutoCategoryClassifier は Foundation Models on-device、Tag 作成時 1 回のみ、過剰消費なし
- **アクセシビリティ**: Stats Row 集約読み上げ、Category List 各行 「テクノロジー、12 記事」読み上げ
- **Dark Mode**: DS.Color の adaptive で対応
- **Dynamic Type**: 全テキストが Dynamic Type 互換

## オープン質問

なし。確定済 (Q&A 経由):
- Category 実体: シードカテゴリー静的 mapping (Foundation Models で 1 回推論)
- spec scope: 1 spec に集約 (UI v2 + DesignSystem refactor + Category)
