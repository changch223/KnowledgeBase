# Quickstart: spec 018 実機検証シナリオ

実機 (iPhone 15 Pro 以降 / iPad mini A17 Pro 以降) + Apple Intelligence 有効、または Simulator (Apple Intelligence 不可) で実施。spec 018 実装完了後に以下 12 シナリオで検証。

## 前提

- spec 014/015/016/017 main マージ済 (`66ab948`)、spec 018 実装完了
- 実機 / Simulator に最新ビルドをインストール済
- 既存 articles + tags + categoryRaw データが端末に存在

## SC-001: 新タブ「知識 Clip」表示

**手順**:
1. アプリ起動
2. TabBar を確認

**期待結果**:
- ✅ TabBar 中央に「知識 Clip」タブ (`lightbulb.fill` アイコン)
- ✅ タブ順: ライブラリ → 知識 Clip → AI ブレイン
- ✅ accessibilityIdentifier "tab.knowledgeClip"

## SC-002: Category 別 AI 統合カード表示

**手順**:
1. 知識 Clip タブをタップ
2. カード一覧を確認

**期待結果**:
- ✅ 初期表示 ≤300ms
- ✅ Category 別 KnowledgeClipCard が縦並び (LazyVStack)
- ✅ 並び順は Category 内最新元記事の savedAt desc
- ✅ 60fps 維持 (1000 記事規模で確認)

## SC-003: カード表示要素の正確性

**手順**:
1. 知識 Clip タブで 1 つのカードを目視確認

**期待結果**:
- ✅ Category 名 (上、sectionTitle)
- ✅ 「N 記事から · X 日前」(Header 下、caption)
- ✅ 統合 summary (~150 字、body font)
- ✅ KeyFact 3 個 (「・」bullet 形式)
- ✅ EntityChip 3 個 (横スクロール、Capsule)
- ✅ stale な Category なら「更新あり」caption (右上)
- ✅ 最新元記事に OG 画像があれば 48x48 サムネ (右)

## SC-004: 期間フィルター

**手順**:
1. 知識 Clip タブで上部チップ「7 日」をタップ
2. カード一覧を確認

**期待結果**:
- ✅ 切替 ≤100ms
- ✅ 過去 7 日以内に元記事が 1 件以上ある Category のみ表示
- ✅ 「全部」チップ → 全 Digest 表示
- ✅ 「30 日」チップ → 過去 30 日以内
- ✅ 選択中チップは actionBlue 背景 + white text

## SC-005: カードタップで詳細画面遷移

**手順**:
1. 知識 Clip タブで「テクノロジー」カードをタップ
2. CategoryKnowledgeDetailView を確認

**期待結果**:
- ✅ 遷移 ≤300ms
- ✅ NavigationTitle = 「テクノロジー」(large)
- ✅ 上部に「総まとめ」セクション (Digest summary 結合)
- ✅ 「重要ポイント」セクション (Top KeyFact 10 個、頻度順)
- ✅ 「関連する概念」セクション (Top Entity 5 個、頻度順)
- ✅ 「元記事」セクション (ArticleRow 一覧、savedAt desc)
- ✅ 元記事タップ → ArticleDetailView シート (既存挙動)
- ✅ pull-to-refresh で当該 Category のみ再集約

## SC-006: stale マーク動作

**手順**:
1. Safari Share から新記事を保存
2. 知識 Clip タブを開く (60 秒以内)
3. 該当 Category のカードを確認

**期待結果**:
- ✅ AI 抽出完了後 (≤60 秒) に該当 Category カードに「更新あり」マーク表示
- ✅ stale フラグは AI 抽出完了後の hook で立つ
- ✅ アプリ再起動でも stale 状態保持

## SC-007: pull-to-refresh で再集約

**手順**:
1. stale Category がある状態 (SC-006 後など)
2. 知識 Clip タブで pull-down (画面下に向けて引く)
3. 完了まで待つ

**期待結果**:
- ✅ ProgressView (標準 SwiftUI) 表示
- ✅ Category 1 個当たり ≤10 秒で再集約完了
- ✅ 全 stale 一括 ≤30 秒 (10 Category)
- ✅ 完了後、stale マーク消える、最新カード反映
- ✅ アプリ State (期間フィルター等) は維持

## SC-008: Apple Intelligence 不可 (fallback) 動作

**手順**:
1. Apple Intelligence 不可端末 / 設定 OFF or Simulator で起動
2. 知識 Clip タブを開く
3. 表示されるカードを確認

**期待結果**:
- ✅ FallbackKnowledgeDigestService で生成された簡易カード表示
- ✅ summary = 「最近の N 記事から: [essence1] / [essence2] / ...」形式
- ✅ KeyFact 3 / Entity 3 は元記事から salience 順
- ✅ 「(簡易表示中)」など視覚マーク (実装で詰める)
- ✅ 機能不変 (タップ → 詳細画面、フィルター動作)

## SC-009: Empty state (記事 0 件)

**手順**:
1. 新規インストール直後 (記事 0 件)
2. 知識 Clip タブを開く

**期待結果**:
- ✅ ContentUnavailableView「Safari から記事を保存しましょう」表示
- ✅ systemImage: `lightbulb`
- ✅ description: 「Share Sheet で「知積」を選択」(spec 011 と同パターン)

## SC-010: 抽出中プレースホルダ

**手順**:
1. 記事を 1 件以上保存、AI 抽出開始直後 (まだ essence 0 件)
2. 知識 Clip タブを開く

**期待結果**:
- ✅ プレースホルダ「AI が知識を集約中です...」表示
- ✅ ProgressView (標準 SwiftUI) 同時表示
- ✅ AI 抽出完了 → 自動的にカード表示に切替 (spec 005 RefreshTrigger 経由 live update)

## SC-011: マルチカード分割確認

**手順** (環境準備が必要):
1. 同 Category に異なるトピックの記事 5+ 件保存 (例: テクノロジー = AI 系 3 + Mobile 系 3)
2. 知識 Clip タブで再集約 → カード確認

**期待結果**:
- ✅ AI が判断してマルチカード生成 (cardIndex 0, 1)
- ✅ 同 Category で複数 KnowledgeClipCard が縦並び
- ✅ 各カードのトピックが分離 (例: Card 0 = AI、Card 1 = Mobile)
- ✅ sourceArticles が各カードで適切に分配

## SC-012: 既存タブ完全保持 (回帰確認)

**手順**:
1. ライブラリタブで以下を全て試す:
   - 検索バー入力 → 検索結果ハイライト
   - タグ一覧タブ → 個別 Tag タップで TagFilteredListView 遷移
   - ArticleRow タップで ArticleDetailView 起動
   - 関連記事タップで sheet 切替
2. AI ブレインタブで以下を全て試す:
   - Stats Row 表示
   - AI Insight Card 表示
   - Category List タップで CategoryFilteredListView 遷移 (spec 016 B1 修正)
   - タグフィルター OR 条件
   - 「+N ▼」展開
3. ArticleDetailView の本文 DisclosureGroup 折りたたみ確認

**期待結果**:
- ✅ spec 014/015/016/017 までと完全一致 (回帰なし)
- ✅ 既存 unit test 100+ ケース全 PASS

## トラブルシュート

| 症状 | 対処 |
|---|---|
| 知識 Clip タブが表示されない | KnowledgeTreeApp の TabView 改修確認、ビルド再実行 |
| カードが空 | KnowledgeDigestService が起動時に bootstrap で regenerateAllStale 呼んでいるか確認、isStale 全て true で初期化されるべき |
| Foundation Models エラー | Apple Intelligence 設定 ON か、対応端末か確認 |
| stale マーク立たない | KnowledgeExtractionService の hook 実装確認、Tag.categoryRaw が正しく設定されているか確認 |
| 期間フィルターが期待通りでない | TimeFilter.cutoffDate 計算ロジック確認 |
| pull-to-refresh が動作しない | `.refreshable` modifier の closure 実装確認 |
| 詳細画面の総まとめが空 | digestsForCategory が空、Digest 未生成、再集約必要 |
| マルチカード分割されない | AI prompt の `@Guide` 内容確認、記事数 5+ で内容散らかってるか |

## 検証完了チェック

```
□ SC-001: 新タブ表示
□ SC-002: Category 別カード
□ SC-003: カード表示要素
□ SC-004: 期間フィルター
□ SC-005: 詳細画面遷移
□ SC-006: stale マーク
□ SC-007: pull-to-refresh
□ SC-008: Fallback 動作
□ SC-009: Empty state
□ SC-010: 抽出中プレースホルダ
□ SC-011: マルチカード分割
□ SC-012: 既存タブ完全保持
```

全 ✅ で spec 018 実機検証完了。
