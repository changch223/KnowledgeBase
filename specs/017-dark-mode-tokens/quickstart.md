# Quickstart: spec 017 実機検証シナリオ

実機 (iPhone 15 Pro 以降 / iPad mini A17 Pro 以降) + Apple Intelligence 有効、または Simulator で実施。spec 017 実装完了後に以下 9 シナリオで検証。

## 前提

- spec 014/015/016 の実装が main にマージ済 (`66ab948`)
- 実機 / Simulator に最新ビルドをインストール済

## SC-001: Light Mode 完全保持

**手順**:
1. 設定 → 画面表示と明るさ → Light に設定
2. アプリ起動
3. ライブラリタブ / AI ブレインタブ / Detail シート / Category 詳細画面 を順に確認

**期待結果**:
- ✅ spec 016 までと完全同一の表示
- ✅ actionBlue が `#0a4d8c` (deep blue)
- ✅ parchment が `#faf8f3` (off-white)
- ✅ tagFill が `#eaeaef`
- ✅ 全 18 view で色味 / 配置 / 視認性が変わらない

## SC-002: Dark Mode への手動切替

**手順**:
1. アプリ起動 (Light Mode 状態)
2. 画面下からスワイプ → コントロールセンター → ダークモード切替 ボタン or
3. 設定 → 画面表示と明るさ → Dark に変更

**期待結果**:
- ✅ 1 秒以内に全画面が Dark 値で表示
- ✅ AI ブレインタブ背景が `#1c1c1e` (parchment Dark)
- ✅ actionBlue が `#3a8eef` (Dark の明 blue)
- ✅ tagFill chip が `#2c2c2e` (Dark)
- ✅ アプリ State (タグ選択 / 折りたたみ展開等) は維持される

## SC-003: 自動 (Auto) モードで日中/夜の切替

**手順**:
1. 設定 → 画面表示と明るさ → 自動 を ON
2. デバイスの時刻を昼設定 (12:00) → アプリ Light で表示
3. 時刻を夜設定 (22:00) → アプリ Dark に切替

**期待結果**:
- ✅ OS の Light/Dark 切替に追随
- ✅ 切替速度 ≤1 秒
- ✅ State 維持

## SC-004: AI ブレインタブの Dark 視覚

**手順**:
1. Dark Mode で AI ブレインタブを開く
2. Stats Row / AI Insight Card / Category List を順に確認

**期待結果**:
- ✅ Stats Row 数字 (記事 / 知識 / ファクト) が Dark 背景で読みやすい
- ✅ AI Insight Card のテキスト contrast 適切
- ✅ Category List の progress bar = 明 actionBlue (#3a8eef)、背景 = Dark tagFill (#2c2c2e)
- ✅ 各 Category 行の名前 / 件数が読みやすい

## SC-005: Category 詳細画面の Dark 視覚

**手順**:
1. Dark Mode で AI ブレインタブ Category 行をタップ → CategoryFilteredListView 遷移
2. タグフィルターチップを操作 (タップで選択 / 解除)
3. 「+N ▼」展開ボタンタップ
4. 記事リスト確認

**期待結果**:
- ✅ NavigationTitle (Category 名) が Dark 背景で読みやすい
- ✅ 未選択チップ = Dark tagFill (#2c2c2e) + ink primary text
- ✅ 選択中チップ = 明 actionBlue (#3a8eef) + white text、視覚強調
- ✅ 「+N ▼」ボタンの actionBlue が識別可能
- ✅ Article リスト全行 Dark 適応 (essence / KeyFact / chip / URL / savedAt)

## SC-006: ArticleDetailView 本文 DisclosureGroup の Dark 視覚

**手順**:
1. Dark Mode で記事をタップ → ArticleDetailView 起動
2. essence / KnowledgeSummary / 関連記事 / タグ / OG 画像 確認
3. 「本文を読む ▶」タップ → 本文展開
4. 各セクション Dark 視覚確認

**期待結果**:
- ✅ Header (OG 画像 + タイトル) が Dark 適応
- ✅ essence / KnowledgeSummary が読みやすい
- ✅ 「本文を読む」DisclosureGroup の chevron が識別可能
- ✅ 本文展開時の Text が Dark 背景で contrast 確保
- ✅ EntityChip / TagChip / KeyFactRow 全て Dark 適応
- ✅ 関連記事セクションも Dark で視認可能

## SC-007: Reduce Transparency ON 動作

**手順**:
1. 設定 → アクセシビリティ → 画面表示と文字サイズ → 透明度を下げる ON
2. かつ Dark Mode ON
3. アプリで全画面を順に操作 (フィルター / 検索 / Detail / 折りたたみ)

**期待結果**:
- ✅ 機能不変 (フィルター OR / 折りたたみ / 検索結果ハイライト 全て動作)
- ✅ 視認性が Light Mode 同等 (現状 blur 系を使っていないため影響軽微)
- ✅ クラッシュ / 表示崩れなし

## SC-008: Dark Mode 起動時のパフォーマンス

**手順**:
1. Dark Mode に設定済の状態でアプリを完全終了
2. アプリを起動
3. 起動時間と再描画フレームレートを観察

**期待結果**:
- ✅ コールド起動 ≤2 秒 (constitution Performance Gate)
- ✅ 再描画 ≤100ms
- ✅ 60fps 維持
- ✅ 100 件超のリスト (ArticleListView / CategoryFilteredListView) でも fps 不変

## SC-009: 廃止 view の Dark 表示確認

**手順** (廃止 view が AIBrainView から外れているのでアクセス困難、Preview or テスト code で確認):
1. Xcode Preview で `PowerGaugeCard` / `KnowledgeMapView` / `RecentActivityCards` を Dark スキーマで確認
2. または、これらの view を一時的に AIBrainView に戻して目視確認

**期待結果**:
- ✅ 全廃止 view が破綻なく Dark で表示 (alias 経由で auto adapt)
- ✅ aiBrandStart / End / NodeFill / NodeStroke 等が actionBlue (#3a8eef) ベースで識別可能
- ✅ 4 phase tint (phaseEnrichment / phaseBody / phaseKnowledge / phaseTagging) は全部 actionBlue で統一
- ✅ 将来 spec 031 で削除予定だが現状の表示には問題なし

## トラブルシュート

| 症状 | 対処 |
|---|---|
| Dark Mode で actionBlue が暗いまま | DesignSystem.swift の `Color.adaptive(...)` 適用が漏れているか確認 |
| 一部 view だけ Dark にならない | view 内で `.foregroundColor(Color(red:...))` 等の hex 直書きが残っているか確認 |
| 切替が遅い (>1 秒) | `Color(uiColor: ...)` の bridge コストか、UITraitCollection 評価のオーバーヘッドか調査 |
| Reduce Transparency で表示が壊れる | blur 系 (`.thinMaterial` 等) の使用箇所を確認 (本 spec の前提は blur ゼロ) |
| ColorAdaptiveTests が失敗 | UITraitCollection の resolvedColor の使い方確認 |

## 検証完了チェック

```
□ SC-001: Light Mode 完全保持
□ SC-002: Dark Mode 手動切替
□ SC-003: Auto モード追随
□ SC-004: AI ブレインタブ Dark 視覚
□ SC-005: Category 詳細画面 Dark 視覚
□ SC-006: ArticleDetailView 本文 Dark 視覚
□ SC-007: Reduce Transparency ON 動作
□ SC-008: Dark Mode 起動パフォーマンス
□ SC-009: 廃止 view Dark 表示
```

全 ✅ で spec 017 実機検証完了。
