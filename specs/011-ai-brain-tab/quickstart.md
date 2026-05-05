# Quickstart: spec 011 (UI リブランディング + AI ブレインタブ) 実機検証手順

**Created**: 2026-05-05
**Branch**: `011-ai-brain-tab`
**前提**: iPhone 17 Pro 等の Apple Intelligence 対応端末。Apple Intelligence 有効化済。spec 010 までのデータが入っていない場合は新規インストール。

## 検証 1: 新規インストール直後の空状態

### 手順

1. アプリをアンインストール (旧データ削除のため)
2. Xcode から build & run でインストール
3. ホーム画面でアイコンを確認
4. アプリを起動
5. 下部タブバーの右側「AI ブレイン」(SF Symbol `brain` アイコン) をタップ

### 期待結果

| 項目 | 期待 |
|---|---|
| ホーム画面アイコン名 | 「知積」と表示される |
| タブバー左 | 「ライブラリ」(SF Symbol `books.vertical`) |
| タブバー右 | 「AI ブレイン」(SF Symbol `brain`) |
| AI ブレインタブ初期表示 | 1 秒以内に表示 (ローディングインジケータ不要) |
| PowerGaugeCard | 「0 記事を吸収済」「0 知識 · 0 キーファクト」「Your AI is growing」 |
| カウントアップアニメーション | 0 のままでも 0 → 0 のアニメーションは発火 (実害なし) |
| パルスアニメーション | scale 1.0 ↔ 1.02 で 2 秒周期、目立たない |
| KnowledgeMap | ContentUnavailableView「まだ記事がありません。Safari から記事を保存しよう！」 |
| RecentActivityCards | カード A: 「今週はまだ吸収していません」/ カード B: 「最近育ったテーマ — まだありません」/ カード C: 「新しい繋がり — まだありません」 |

✅ **SC-001 検証**: 1 秒以内に空状態表示

---

## 検証 2: 30 件の記事保有時の PowerGauge カウントアップ

### 前提

- spec 010 までで 30 件以上の記事が保存されている (Share Sheet または開発時データ投入)

### 手順

1. アプリを完全終了 (App Switcher で swipe up)
2. アプリを起動
3. 「AI ブレイン」タブをタップ
4. PowerGaugeCard を観察 (動画撮影推奨)

### 期待結果

| 項目 | 期待 |
|---|---|
| カウントアップ開始タイミング | タブ表示と同時 (.onAppear) |
| カウントアップ持続時間 | 約 0.6 秒で実数 (例: 30) に到達 |
| カウントアップ curve | easeOut (最初速く、最後ゆっくり) |
| 数字 transition | `.contentTransition(.numericText())` で 1 桁ずつめくれる |
| 知識数 / キーファクト数 | 数字は瞬時 (アニメーションなし、サブ情報のため) |

✅ **SC-002 検証**: 0.6 秒で count up 完了

---

## 検証 3: KnowledgeMap 60fps + force-directed 200ms (100 タグ環境)

### 前提

- 100+ タグ + 200+ エッジ (KnowledgeEntity 共有) が存在する状態を作る
  - 開発用 seed スクリプト or 実データで 100 件以上の異なるタグを保存

### 手順

1. アプリ起動 → AI ブレインタブ
2. KnowledgeMap セクションが表示
3. Xcode Instruments を attach (Time Profiler + SwiftUI テンプレート)
4. ピンチイン / アウトを 5 回繰り返す
5. ドラッグでパンを 10 回繰り返す
6. ノードをタップして TagFilteredListView へ遷移、戻るで再表示

### 期待結果

| 項目 | 期待 |
|---|---|
| 初期 force-directed 計算 | onAppear 後 200ms 以内に完了 (`KnowledgeMapBuilder.buildGraph` 1 回実行) |
| Canvas 描画 fps | 60fps を維持 (1 秒あたり 60 frame、Instruments で実測) |
| ピンチズーム応答性 | ジェスチャ開始から 16ms 以内に scale 反映 |
| ドラッグパン応答性 | 同上、offset 反映 |
| ノードタップ → 遷移 | タップから TagFilteredListView 表示まで 0.5 秒以内 |
| メモリ peak | 50MB 以下 |

✅ **SC-003 / SC-004 / SC-006 検証**: 60fps + 200ms + 0.5 秒遷移

### Instruments スクリーンショット

PR に以下を添付:

- Time Profiler: AIBrainView 表示中の CPU 使用率と main thread 使用率
- SwiftUI: AIBrainView の Body Update 頻度と View Type Cost

---

## 検証 4: 新記事保存後の PowerGauge live update (1 秒以内)

### 手順

1. AI ブレインタブを開いた状態で待機
2. 別アプリ (Safari) に切り替え
3. 適当な記事 URL を Share Sheet → 「知積」 (KnowledgeTree)
4. 共有完了後、「知積」アプリに戻る
5. AI ブレインタブの PowerGauge を観察

### 期待結果

| 項目 | 期待 |
|---|---|
| Article 数表示 | 共有後 1 秒以内に +1 反映 |
| カウントアップ animation | 旧値 → 新値で 0.4 秒の easeOut animation |
| KnowledgeMap | knowledge 抽出完了後 (chunked summarization 完了後) に新ノードが 0.4 秒 fade-in |
| RecentActivity カード A | 即座に「今週 N+1 件」に更新 |

✅ **SC-005 検証**: 1 秒以内 live update

### 注意

knowledge 抽出は spec 009/010 の BG task で進行するため、PowerGauge の「知識 · キーファクト」数は数十秒〜数分で更新される (即時ではない)。これは仕様通り。

---

## 検証 5: 既存ライブラリタブの完全保持 (回帰テスト)

### 手順

1. アプリ起動 → ライブラリタブが選択されていること (デフォルト)
2. 以下を spec 010 までと同じ操作で確認:
   - 検索バーで「Swift」検索 → 該当記事一覧
   - 上部タグ一覧ボタン → TagListView 遷移
   - タグタップ → TagFilteredListView 遷移
   - 戻るボタンで戻る
   - 記事行タップ → ArticleDetailView シート
   - シート内: 関連記事セクション、自動タグ提案、再抽出ボタン
3. シートを閉じて検索文字列をクリア

### 期待結果

| 項目 | 期待 |
|---|---|
| ArticleListView の挙動 | spec 010 までと完全一致 (UI 1px 違わない) |
| 検索 / タグフィルタ / シート | すべて正常動作 |
| BottomStatusBar | enrichment / body / knowledge 進捗表示が変わらず |
| spec 005 の live update | 検索バー閉じている状態で新記事保存 → 即一覧反映 |

✅ **SC-007 検証**: 既存挙動完全保持

---

## 検証 6: タブ切替時のステート保持

### 手順

1. ライブラリタブで「Swift」検索 + タグフィルタ「iOS」を適用
2. AI ブレインタブに切替
3. ライブラリタブに戻る

### 期待結果

| 項目 | 期待 |
|---|---|
| 検索文字列 | 「Swift」が保持される |
| タグフィルタ | 「iOS」が保持される |
| スクロール位置 | おおよそ同じ位置 |
| AI ブレインタブのスクロール位置 | 同様に保持 (TabView 標準挙動) |

---

## 検証 7: VoiceOver / Dark Mode / Dynamic Type

### VoiceOver

1. Settings → Accessibility → VoiceOver オン
2. AI ブレインタブを開く
3. 各要素を swipe で読み上げ:
   - 「AI ブレイン、見出し」
   - 「AI パワー: 30 記事、120 知識、450 キーファクト」(PowerGauge)
   - 「タグ Swift、12 記事、ボタン」(各 KnowledgeMap ノード)
   - 「今週の吸収: 5 件」(カード A) など

### Dark Mode

1. Settings → Display → Dark
2. AI ブレインタブを開く

| 項目 | 期待 |
|---|---|
| グラデーション背景 | Dark でも自然な色味 |
| 文字色 | Primary / Secondary が自動切替 |
| Canvas 線色 | `.secondary.opacity(0.3)` で見える |

### Dynamic Type

1. Settings → Display → Text Size → 最大
2. AI ブレインタブを開く

| 項目 | 期待 |
|---|---|
| PowerGauge 数字 | レイアウト崩れなし、改行で対応 |
| カードタイトル | 同上 |
| ノードラベル | Caption はもともと小さいが、最大サイズで読める |

---

## 検証完了基準

すべて ✅ → spec 011 の MVP は出荷可能

| SC | 検証項目 |
|---|---|
| SC-001 | 検証 1 (空状態 1 秒) |
| SC-002 | 検証 2 (カウントアップ 0.6 秒) |
| SC-003 | 検証 3 (60fps) |
| SC-004 | 検証 3 (ノードタップ → 遷移 0.5 秒) |
| SC-005 | 検証 4 (live update 1 秒) |
| SC-006 | 検証 3 (force-directed 200ms) |
| SC-007 | 検証 5 (既存挙動回帰) |
| SC-008 | 検証 1 (ホーム画面 label「知積」) |
