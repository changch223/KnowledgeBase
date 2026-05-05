# Quickstart: spec 014 (デザインシステム + Phase 3/4 視覚改善) 実機検証手順

**Created**: 2026-05-05
**Branch**: `014-design-system`
**前提**: iPhone 17 Pro 等、spec 013 まで実装済 + spec 014 ブランチビルドをインストール。

---

## 検証 1: AI ブレインタブの視覚改善 (Phase 3)

### 手順

1. アプリ起動 → AI ブレインタブをタップ
2. 各セクションをスクロールして観察

### 期待結果

| 項目 | 期待 |
|---|---|
| 上部背景 | full-bleed AI brand gradient (Apple Weather 風)、上から下へフェード |
| Navigation Title | "AI ブレイン" が large title 表示 |
| Scroll Indicator | 非表示 (スクロール中も縦バー出ない) |
| **PowerGaugeCard** | ① ultraThinMaterial 背景 + AI gradient overlay + 上端の specular highlight が視認 ② 数字 3 つ (記事 / 知識 / キーファクト) が縦並び mini-stats cluster (Apple Health 式) ③ Divider 区切り ④ shadow がゆっくりパルス (radius 8 ↔ 16) ⑤ scale jitter なし (= 文字位置がブレない) |
| **KnowledgeMapView** | ① エッジが gradient stroke (源側濃く、外側薄く) ② ノードが radial gradient (中心明、外周暗) ③ ノードに drop shadow ④ ラベルが pill 背景で可読性 up |
| **RecentActivityCards** | ① アイコンが円形色付き背景 (Apple Health 式) ② 今週: tray アイコン + accentColor / 育ったテーマ: leaf + green / 新しい繋がり: dots + purple ③ カード固定サイズ + シャドウ + ヘアラインボーダー |

✅ **SC-002 / SC-003 検証**: 4 層 ZStack + radial gradient ノード

---

## 検証 2: ArticleRow / ArticleListView (Phase 4)

### 手順

1. ライブラリタブを開く
2. 数記事の行を観察

### 期待結果

| 項目 | 期待 |
|---|---|
| knowledge 完了記事の行 | 左端に **3pt 縦バー (緑紫色)** が表示 |
| knowledge 未完 / failed 記事の行 | 縦バー **非表示** |
| 「AI 生成」ラベル | 平の HStack ではなく **Capsule 化** (薄い背景色付き) |
| List 全体 | `.listStyle(.plain)` 適用、完了記事のセパレータは控えめ (or 非表示) |

✅ **SC-004 検証**: knowledge 完了記事の左端アクセント

---

## 検証 3: ArticleDetailView の polish (Phase 4)

### 手順

1. 任意の記事行をタップ → Detail シート

### 期待結果

| 項目 | 期待 |
|---|---|
| OG 画像 | 200pt 高さ、下端にフェードオーバーレイ (画像と本文の境界が滑らか) |
| ローディング状態 | 背景に薄いピル / placeholder |
| ボタン | 配色 / 角丸が DS.Radius.chip / DS.Color.* 系で統一 |
| 本文セクション | DS.Spacing.section で余白統一 |

---

## 検証 4: EmptyStateView の入場 + ボブ演出 (Phase 4)

### 手順

1. ライブラリタブで全記事を削除 (または新規インストール)
2. 空状態を表示
3. 数秒待機して観察

### 期待結果

| 項目 | 期待 |
|---|---|
| 起動直後 | tray アイコンが scale 0.8 → 1.0 で **ふわっと入場** |
| 静止後 | scale +0.03 / -0.03 周期 (2 秒) で **ゆっくりボブ** |
| 案内テキスト | 「Safari で記事を開いて「共有」→ アプリ名 で保存できます」が tertiary 色で表示 |

---

## 検証 5: Reduce Motion 対応 (US2 / SC-005)

### 手順

1. 設定 → Accessibility → Motion → Reduce Motion を **ON**
2. アプリを起動
3. AI ブレインタブ + ライブラリタブで観察

### 期待結果

| 項目 | 期待 (Reduce Motion ON) |
|---|---|
| PowerGauge カウントアップ | **即時表示** (0 から実数までのアニメなし) |
| PowerGauge shadow パルス | **停止** (常に同一 radius) |
| KnowledgeMap 新ノード fade-in | (Reduce Motion 検証は spec 014 の範囲、本来 spec 011 で fade-in が追加されている。ifMotionAllowed が適用されていれば即時表示) |
| EmptyStateView 入場 / ボブ | **両方停止** (静止) |
| AI ブレイン 上部 gradient | 静的、ジッター無し |

機能 (タグ付与 / 数字更新等) は変わらない。Reduce Motion を OFF に戻すと装飾が再開。

✅ **SC-005 検証**

---

## 検証 6: Dark Mode (FR-027)

### 手順

1. 設定 → Display → Dark Mode
2. アプリを起動 → AI ブレインタブ + ライブラリタブを確認

### 期待結果

| 項目 | 期待 |
|---|---|
| `surfacePrimary` / `surfaceSecondary` | システム設定通りに dark 系背景 |
| AI gradient | 紫青系のまま、視認性 OK |
| 各 overlay | 暗背景でも視認可 (primary opacity 系のため adaptive) |
| 文字 | primary / secondary / tertiary が dark mode 用色に切り替わる |

---

## 検証 7: Dynamic Type 最大サイズ (FR-026)

### 手順

1. 設定 → Display → Text Size を **最大** に
2. アプリを起動 → 各画面を確認

### 期待結果

| 項目 | 期待 |
|---|---|
| PowerGauge | 数字が大きくなる、レイアウト崩れなし |
| ArticleRow | タイトルが多行になっても切れず表示 |
| RecentActivityCards | カード固定サイズ内で文字が伸縮、必要なら scroll |
| Detail | 全セクション読める、ボタンタップ可 |

---

## 検証 8: VoiceOver

### 手順

1. 設定 → Accessibility → VoiceOver ON
2. AI ブレインタブで swipe 読み上げ

### 期待結果

| 項目 | 期待 |
|---|---|
| PowerGauge | "AI パワー: N 記事、N 知識、N キーファクト" 1 単位で読み上げ (`accessibilityElement(.combine)` 既存) |
| ArticleRow leading edge accent | **読み上げない** (`accessibilityHidden(true)` で隠蔽済) |
| ArticleRow タイトル + AI バッジ | 読み上げ可、自然な順序 |
| EmptyStateView | アイコン読み飛ばし、タイトル + 案内文を読み上げ |

---

## 検証 9: iPad での見た目 (Constitution Per-PR ゲート)

### 手順

1. iPad シミュレータ or 実機 (M1 以降の iPad Pro / iPad Air、または iPad mini A17 Pro)
2. アプリ起動 → 各画面確認

### 期待結果

| 項目 | 期待 |
|---|---|
| AI ブレインタブ | iPhone と同じレイアウトだが幅広 (3 セクション縦並び) |
| KnowledgeMap | 領域が広いので force-directed が iPad で安定 |
| RecentActivityCards | 横スクロール、3 枚以上見える可能性あり |
| ArticleRow | リスト幅広、サムネイル + テキストの比率が iPhone と同じ |

iPad 専用レイアウトは将来 spec、本 spec では adaptive layout 任せ。

---

## 検証完了基準

すべて ✅ → spec 014 の MVP は出荷可能

| SC | 検証項目 |
|---|---|
| SC-001 | (コードレビュー) `grep -r "cornerRadius: [0-9]" KnowledgeTree/Views/` で magic number ゼロ |
| SC-002 | 検証 1 (PowerGauge 4 層 ZStack) |
| SC-003 | 検証 1 (KnowledgeMap radial gradient) |
| SC-004 | 検証 2 (knowledge 完了記事の縦バー) |
| SC-005 | 検証 5 (Reduce Motion で全アニメ停止) |
| SC-006 | (自動) `xcodebuild test -only-testing:KnowledgeTreeTests` 66 ケース pass |
| SC-007 | (自動) `xcodebuild build` 成功 + 警告 0 |

実機で実行できない場合は、SC-006 / SC-007 のみ確認すれば最低限。視覚 polish の確認は SC-002〜SC-005 を実機で行うのが望ましい。
