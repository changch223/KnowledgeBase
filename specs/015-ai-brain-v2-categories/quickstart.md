# Quickstart: spec 015 (AI ブレイン v2 + DesignSystem migration + Category) 実機検証手順

**Created**: 2026-05-05
**Branch**: `015-ai-brain-v2-categories`

---

## 検証 1: タグ 0 件 (新規インストール)

1. アプリアンインストール → spec 015 ビルドを installer
2. 起動 → AI ブレインタブをタップ

**期待**:
- Stats Row: 「0 記事 / 0 知識 / 0 ファクト」
- AI Insight Card: 「Safari から記事を保存しましょう」+ tray アイコン
- Category List: ContentUnavailableView「カテゴリーがありません」
- BottomStatusBar 非表示

✅ **SC-001 検証**

---

## 検証 2: タグあり、Category 分類済の表示

前提: 5+ 件の記事保存済 + AutoCategoryClassifier で Category 分類済

1. AI ブレインタブを開く

**期待**:
- Stats Row: 実数表示 (例: 30 記事 / 120 知識 / 350 ファクト)、起動時 0 → 実数 0.5 秒カウントアップ
- AI Insight Card: 「最も読んでいる分野: テクノロジー」+ 「12 記事」+ sparkles アイコン
- Category List: Category 降順、最多 (テクノロジー) のプログレスバー 100%、他は比率

✅ **SC-002 / SC-003 検証**

---

## 検証 3: Category タップ → 記事一覧

1. AI ブレインタブで「テクノロジー」行をタップ

**期待**:
- 0.5 秒以内に TagFilteredListView へ遷移
- Category 内最多 Tag (例: "Swift") の記事一覧
- 戻るボタンで Category List に戻る

✅ **SC-004 検証**

---

## 検証 4: 新記事保存 → Stats Row + Category 反映

1. AI ブレインタブを開いた状態で待機
2. Safari から記事を Share Sheet で保存
3. 戻ってくる
4. AI ブレインタブを観察

**期待**:
- Stats Row の記事数が +1、0.35 秒の数字 transition
- AutoCategoryClassifier が走り、新 Tag が "テクノロジー" 等に分類される
- 60 秒以内に Category List に反映 (Foundation Models 推論時間込み)

✅ **SC-005 検証**

---

## 検証 5: bootstrap backfill (既存 Tag → Category)

前提: spec 014 までで保存した既存 Tag (categoryRaw nil) が 10+ 件あるアプリ環境で、spec 015 ビルドを **初回起動**

1. spec 015 ビルド初回起動
2. BottomStatusBar を観察
3. 完了まで待機

**期待**:
- 起動直後、BottomStatusBar に「タグ整理中」(spec 013) → 完了 → 「全タグのカテゴリー分類中 N/M」(spec 015) と順次表示
- 進捗が 1 件ずつ進む (Foundation Models on-device で 1 件あたり 3-5 秒)
- 完了で BottomStatusBar 非表示
- Category List に 10 個程度の Category が表示
- 2 回目起動では「カテゴリー分類中」表示出ない (フラグ early return)

✅ **SC-006 / SC-009 検証**

---

## 検証 6: AutoCategoryClassifier の精度 (Foundation Models)

前提: Tag 名サンプル (Swift / iOS / 株式投資 / 健康 / UI デザイン / 量子力学 / クラシック音楽 / サッカー / 映画 / コーヒー)

1. これらの Tag を持つ記事を保存 (or 既存環境)
2. backfill 完了後 Category List を確認

**期待**:
- Swift / iOS → テクノロジー
- 株式投資 → 経済
- 健康 → 健康
- UI デザイン → デザイン
- 量子力学 → 学術
- クラシック音楽 → アート (or エンタメ)
- サッカー → スポーツ
- 映画 → エンタメ
- コーヒー → その他 (or ニュース)

精度 80% 以上を目標 (LLM 推論なので 100% は保証されない)。

---

## 検証 7: Reduce Motion 対応

1. 設定 → Accessibility → Reduce Motion ON
2. アプリ起動 → AI ブレインタブ

**期待**:
- Stats Row のカウントアップ **即時表示** (アニメーションなし)
- 機能不変 (数字 / カテゴリー / タップ遷移すべて動作)

設定を OFF に戻して動作確認。

✅ **SC-007 検証**

---

## 検証 8: Apple-quiet 視覚一貫性 (DesignSystem migration)

各画面で gradient / shadow / 多色 phase tint が消えていることを確認:

1. ライブラリタブ → ArticleRow leading edge accent が actionBlue (元: aiBrandEnd 紫系)、見た目軽微変化
2. ArticleRow の AI バッジが actionBlue 系
3. AI ブレインタブ全体に gradient 一切なし
4. BottomStatusBar の 4 phase 全て **同じ青色** (text のみで区別)

✅ **SC-008 検証**

---

## 検証 9: Dark Mode 互換

1. 設定 → Display → Dark Mode
2. アプリ起動 → AI ブレインタブ + ライブラリタブを確認

**期待**:
- DS.Color の adaptive 動作で背景・文字色が dark 系に
- actionBlue が dark でも視認可
- Category List のプログレスバーが dark でも視認可
- AI Insight Card の薄い actionBlue 背景が dark でも自然

---

## 検証 10: 既存ライブラリタブの完全保持

1. ライブラリタブで全機能確認:
   - 検索 / タグ一覧 / 記事行タップ / Detail シート / 関連記事 / 自動タグ提案 / 再抽出ボタン

**期待**:
- spec 014 までの動作と完全一致 (token 名変更による見た目軽微変化を除く)
- 検索ヒット / 関連記事表示 / Detail 表示すべて従来通り

✅ **SC-009 検証**

---

## 検証 11: VoiceOver

1. 設定 → Accessibility → VoiceOver ON
2. AI ブレインタブで swipe

**期待**:
- Stats Row → "AI パワー: N 記事、N 知識、N ファクト" 集約
- AI Insight Card → "最も読んでいる分野: テクノロジー、12 記事"
- 各 Category 行 → "テクノロジー、12 記事。タップで該当記事一覧へ遷移"
- BottomStatusBar (進行中時) → "全タグのカテゴリー分類中 12/47"

---

## 検証 12: Dynamic Type 最大

1. 設定 → Display → Text Size 最大
2. AI ブレインタブ確認

**期待**:
- Stats Row の数字が大きくなり、レイアウト崩れない (3 列分割が維持)
- Category Row のタイトル + プログレスバー + 記事数が縦並びになっても可
- AI Insight Card の長文が改行で対応

---

## 検証完了基準

すべて ✅ → spec 015 MVP 出荷可能

| SC | 検証 |
|---|---|
| SC-001 | 検証 1 (空状態 1 秒) |
| SC-002 | 検証 2 (カウントアップ 0.5 秒) |
| SC-003 | 検証 2 (Category List 降順 + プログレスバー) |
| SC-004 | 検証 3 (Category タップ 0.5 秒) |
| SC-005 | 検証 4 (新記事 60 秒以内反映) |
| SC-006 | 検証 5 (bootstrap backfill 100 Tag 60 秒、500 Tag 5 分) |
| SC-007 | 検証 7 (Reduce Motion 全停止) |
| SC-008 | 検証 8 (BottomStatusBar 4 phase 単一色) |
| SC-009 | 検証 5 + 10 (2 回目起動 1ms early return + ライブラリ完全保持) |

実機実行不可なら、Simulator + AutoCategoryClassifierTests + AutoCategoryBackfillRunnerTests で代替。実機検証は SC-005 / SC-006 (Foundation Models 推論時間) と SC-007 (Reduce Motion 動作) を確認するためにのみ必須。
