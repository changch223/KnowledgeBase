# Quickstart: spec 016 実機検証シナリオ

実機 (iPhone 15 Pro 以降 / iPad mini A17 Pro 以降) + Apple Intelligence 有効。spec 016 実装完了後に以下 9 シナリオで検証。

## 前提

- spec 015 までの実装が main または本ブランチにマージ済
- 既存 articles + tags + categoryRaw データが端末に存在 (実検証可能な状態)

## SC-001: B1 バグ修正確認 (Category タップで全記事表示)

**手順**:
1. アプリ起動 → AI ブレインタブを開く
2. Category List で Tag を 2 つ以上紐づく記事を含む Category (例: 「テクノロジー」) を確認
3. 表示数字 (例: 3 記事) を記憶
4. Category 行をタップ
5. CategoryFilteredListView に遷移、タグフィルター 0 個選択状態で記事リストを確認

**期待結果**:
- ✅ 記事リストに **3 件すべて** 表示される (B1 で見えなかった記事も含む)
- ✅ 数字 = 実体一致 (3 = 3)
- ✅ savedAt desc 順 (最新が top)

## SC-002: タグフィルター OR 条件

**手順**:
1. 上記 CategoryFilteredListView 上で
2. タグフィルターチップ「Swift」をタップ → 選択 (Action Blue 背景)
3. 表示記事を確認 (Swift を持つ記事のみ)
4. タグフィルターチップ「iOS」を追加タップ
5. 表示記事を確認 (Swift or iOS を持つ記事の OR 集合)
6. 「Swift」を再タップで解除
7. 表示記事を確認 (iOS のみ)

**期待結果**:
- ✅ 各操作で表示切替が 0.3 秒以内
- ✅ OR 条件正しく適用 (重複は表示されない)
- ✅ 選択中チップは Action Blue 背景 + white text、未選択は tagFill + ink text

## SC-003: 「+N ▼」展開

**手順** (Tag 6 個以上の Category 必要):
1. CategoryFilteredListView 上で「+N ▼」ボタンをタップ
2. 残りのタグが LazyHStack 内に追加表示されることを確認
3. ボタン文言が「閉じる ▲」に変化
4. 「閉じる ▲」をタップ
5. 上位 5 個 + 「+N ▼」に戻る

**期待結果**:
- ✅ 展開 0.3 秒以内
- ✅ 横スクロール可能で全タグ操作できる
- ✅ 戻る挙動が対称

## SC-004: 新記事 60 秒以内反映

**手順**:
1. CategoryFilteredListView 開いたまま、Safari で新記事を Share Sheet で保存
2. アプリに戻る (CategoryFilteredListView は表示中)
3. 60 秒以内に新記事が一覧の最上部 (savedAt desc top) に追加されるか確認

**期待結果**:
- ✅ 60 秒以内に反映 (spec 005 RefreshTrigger 経由 live update)
- ✅ AI 抽出完了次第、Category 自動分類されたら最新記事として top 表示

## SC-005: ArticleRow に savedAt 表示

**手順**:
1. ライブラリタブで ArticleRow 一覧を確認
2. 各行の URL 行の右側 (or 直下) に savedAt 表示があるか確認
3. 今日保存した記事 → 「今日 HH:mm」
4. 昨日保存した記事 → 「昨日 HH:mm」
5. 5 日前の記事 → 「5 日前」 (RelativeDateTimeFormatter ja_JP)
6. 30 日前の記事 → 「2026/04/05」 (絶対日付)

**期待結果**:
- ✅ 全分岐で正しく表示
- ✅ font: caption / color: secondary
- ✅ accessibilityLabel に絶対日付含む (VoiceOver 確認)

## SC-006: ArticleDetailView 本文折りたたみ

**手順**:
1. ArticleRow をタップ → ArticleDetailView シート起動
2. ヘッダー / essence / KnowledgeSummary / 関連記事 / タグ / OG 画像 / AI バッジが表示されていることを確認
3. 本文セクションが「本文を読む ▶」のみで折りたたまれていることを確認
4. 「本文を読む ▶」をタップ → 0.5 秒以内に展開
5. 再タップで折りたたみ
6. シートを閉じて再度同じ記事を開く → 再び collapsed (毎回リセット)

**期待結果**:
- ✅ 初期 collapsed
- ✅ 展開アニメ 0.5 秒以内
- ✅ 折りたたみ状態が記事ごと記憶されない (毎回 collapsed で開く)

## SC-007: Reduce Motion 動作確認

**手順**:
1. 設定 → アクセシビリティ → 動作 → 視差効果を減らす ON
2. アプリで CategoryFilteredListView を開く
3. タグフィルターチップ tap で短縮アニメ確認
4. ArticleDetailView の DisclosureGroup tap で短縮アニメ確認

**期待結果**:
- ✅ アニメが短縮 / 即時化される
- ✅ 機能不変 (フィルター OR / 展開 / 折りたたみ動作)

## SC-008: ライブラリタブ既存挙動回帰

**手順**:
1. ライブラリタブで以下を全て試す:
   - 検索バー入力 → 検索結果ハイライト
   - タグ一覧タブ → 個別 Tag タップで TagFilteredListView 遷移
   - ArticleRow タップで ArticleDetailView 起動
   - 関連記事タップで sheet 切替

**期待結果**:
- ✅ spec 015 までと完全一致 (回帰なし)
- ✅ ArticleRow に savedAt 表示が **追加されている** (本 spec の改修)

## SC-009: 既存 unit test PASS

**手順**:
```bash
xcodebuild -project KnowledgeTree.xcodeproj \
  -scheme KnowledgeTree \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  test
```

**期待結果**:
- ✅ spec 015 まで 66+ ケース全 PASS
- ✅ 新規 CategoryFilteredListViewTests (8 ケース) PASS
- ✅ 新規 ArticleRowSavedAtTests (5 ケース) PASS
- ✅ 警告ゼロ

## トラブルシュート

| 症状 | 対処 |
|---|---|
| Category 数字 ≠ 表示記事数 | spec 015 の AutoCategoryClassifier / CategorySeed.category(for:) 経由で `Tag.categoryRaw` が正しい値か確認 |
| savedAt 表示が出ない | ArticleRow.swift の改修が反映されているか確認 (Cmd+Shift+K + Cmd+B) |
| DisclosureGroup が常時展開 | `@State isBodyExpanded` の初期値が false か確認 |
| RelativeDateTimeFormatter が英語 | Locale(identifier: "ja_JP") が設定されているか確認 |
| 「+N ▼」が出ない | Category 内 Tag が 5 個以下なら正しい挙動 |
