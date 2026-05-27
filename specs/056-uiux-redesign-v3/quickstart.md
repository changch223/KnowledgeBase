# Quickstart: UIUX Redesign V3.0 実機検証

**Branch**: `056-uiux-redesign-v3` | **Date**: 2026-05-24

spec.md の SC-001〜SC-018 を実機検証手順化した 15 シナリオ。

## 事前準備

- iPhone 17 Simulator または実機 (iOS 26+)
- V2.5 → V3.0 アップデート検証用に、V2.5 build を別途用意 (任意)
- データ準備:
  - Article 5+ 件 (異なる日付で保存)
  - ConceptPage 3+ 件 (うち 1 件 isFollowing = true)
  - KnowledgeDigest 2+ 件
  - GraphNode 10+ 件 + GraphEdge 5+ 件
  - 古い ConflictProposal 1 件 (undecided)
  - isStale な SavedAnswer 1 件

---

## SC-001: 起動時 default tab = 知識 Clip

**手順**:
1. アプリ kill
2. アプリ起動

**期待結果**:
- 下部 tab bar の選択は **知識 Clip タブ**
- 既存ユーザーが他タブで前回終了していても、起動 default は 知識 Clip

**accessibility check**: `tab.knowledgeClip` が selected 状態

---

## SC-002: 3 タブ表示 (旧 root tab 不在)

**手順**:
1. アプリ起動
2. 下部 tab bar を確認

**期待結果**:
- 3 つの tab item のみ: `知識 Clip` / `ライブラリ` / `AI チャット`
- 学習 / AI ブレイン / Settings root tab が **存在しない**

---

## SC-003: 知識 Clip 1 秒以内表示

**手順**:
1. アプリ kill → 起動
2. 起動完了から 1 秒以内に画面状態を確認

**期待結果**:
- 知識 Clip タブの 3 セクション (最近の記事 / 続きが気になる / 追っている) が visible
- (スケルトン UI が一瞬出るのは許容、最終データ表示まで 1 秒以内)

**Instruments 測定**: タブ表示開始から最終 layout 完了まで 1000ms 以内

---

## SC-004: 差分ゼロで前回維持

**手順**:
1. 記事 5 件保存
2. 知識 Clip タブで「最近の記事」3 件表示確認
3. アプリ kill (新規記事追加なし)
4. アプリ再起動

**期待結果**:
- 「最近の記事」セクションが **空にならず**、前回と同じ 3 記事を表示
- 「+2 もっと見る」リンク等は維持

---

## SC-005: 続きが気になる 混在表示

**手順**:
1. ConceptPage 3 件 + KnowledgeDigest 2 件存在
2. 知識 Clip タブを開く

**期待結果**:
- 「続きが気になるもの」セクションに **5 件混在表示**
- ConceptPage 深掘りカード (`💡 アイコン + 概念名 + 「深掘りする」`) と Topic Dashboard カード (`📊 アイコン + カテゴリ名 + 「まとめを読む」`) が混在

---

## SC-006: ⚠️ 更新が必要 badge 件数 0 で非表示

**手順**:
1. ConflictProposal undecided = 0 + isStale SavedAnswer = 0
2. 知識 Clip タブを開く

**期待結果**:
- 「追っている人物・モノ」セクションに `⚠️ 更新が必要` サブヘッダ **非表示**
- ConflictProposal や Stale が 1 件以上ある状態で再確認:
  - 「⚠️ 更新が必要 (1)」または「(2)」 表示
  - badge tap → ActionItemsReviewView push

---

## SC-007: 知識 Clip 右上アバター → Settings

**手順**:
1. 知識 Clip タブ表示中
2. 右上アバター icon (`person.crop.circle`) tap

**期待結果**:
- SettingsView が sheet として表示 (NavigationStack 内)
- 既存 Settings 全エントリ (Tag 管理 / iCloud sync / Chrome / Safari / etc.) が表示
- swipe down で dismiss → 知識 Clip タブに戻る

---

## SC-008: 60fps 維持

**手順**:
1. Article 1000 件 / ConceptPage 100 件 / GraphNode 200 件状態を用意
2. 各タブ (知識 Clip / ライブラリ / AI チャット) で scroll up/down 各 5 秒
3. Instruments Time Profiler / Animation Hitches で測定

**期待結果**:
- 各 scroll で fps >= 58 (60fps 基準、frame drop 2 つ以内)
- LazyVStack による lazy 描画が機能

---

## SC-009: ライブラリ 日付別 grouping

**手順**:
1. 異なる日付の Article を保存: 今日 2 件 / 昨日 1 件 / 今週 3 件 / 今月 2 件 / それ以前 5 件
2. ライブラリタブを開く

**期待結果**:
- 5 つの date group section ヘッダ表示 (今日 / 昨日 / 今週 / 今月 / それ以前)
- 各 section 内の記事は savedAt desc ソート
- DisclosureGroup で折りたたみ可能

---

## SC-010: FAB → URL 入力 → 保存

**手順**:
1. 知識 Clip タブ表示中
2. 右下 FAB (`+ アイコン`) tap
3. URL 入力 sheet が出現
4. 有効 URL (`https://example.com`) を入力
5. 「保存」ボタン tap

**期待結果**:
- sheet が dismiss、ライブラリタブに新記事が追加 (savedAt = 今)
- 30 秒以内に保存完了
- 同 URL を再度追加しようとすると「既に保存済です」alert 表示

**エラーケース**:
- 無効 URL (`example.com`、scheme 無し) → 「有効な URL を入力してください」 error 表示
- 空欄 → 「保存」ボタン disabled

---

## SC-011: AI チャット 空状態 Suggested prompts 3 件

**手順**:
1. AI チャット履歴を全削除 (Settings → チャット履歴削除) または初インストール状態
2. AI チャットタブを開く

**期待結果**:
- 空状態 placeholder「💬 何でも聞いて」+ 3 つの suggested prompts 表示
- 各 prompt 30 字以内、tap 可能
- prompts 内容例:
  - 「最近保存した記事の要点は?」
  - 「{最新 ConceptPage 名} について教えて」
  - 「{最新 Category} 分野で何があった?」
- データ無し状態 (ConceptPage 0 / Category 0) では generic fallback 3 件

**prompt tap 時**:
- prompt が user message として送信される
- AI 応答開始

---

## SC-012: AI チャット 📊 アイコン → Knowledge Graph 全体画面

**手順**:
1. AI チャットタブ表示中
2. 右上 toolbar の 📊 (`chart.dots.scatter` icon) tap

**期待結果**:
- 2 秒以内に KnowledgeGraphFullScreenView が push 遷移
- 全 Category subgraph が List + Section 表示
- node tap → GraphNodeDetailView push (既存動作維持)
- GraphNode 0 件状態では empty state「まだ知識グラフがありません」

---

## SC-013: 既存全機能新動線で動作

**手順**: 以下を順に確認:

| 既存機能 | 新動線 | 確認手順 |
|---|---|---|
| 家庭教師ループ (spec 044) | 知識 Clip → 続きが気になる → ConceptPage カード | カード tap → DeepDiveChatView 起動、3 ボタン (✓ わかった / 🤔 もっと / ✗ 興味ない) 動作 |
| Knowledge Graph (spec 040) | AI チャット → 📊 → 全体画面 | node tap → GraphNodeDetailView、編集 toolbar 動作 |
| iCloud sync (spec 051) | アバター → Settings → iCloud sync | toggle 動作、確認 alert 表示 |
| Tag 管理 (spec 024) | アバター → Settings → Tag 管理 | rename / merge / delete 動作 |
| ConceptPage 詳細 (spec 042) | 知識 Clip 続きが気になる → カード | DeepDiveChatView toolbar 「学習する」動作 |
| SavedAnswer (spec 043) | アバター → Settings → AI チャット履歴 | 保存済答え一覧、Live check 動作 |

**期待結果**: 全機能が **新動線経由で V2.5 と同じ動作**

---

## SC-014: 既存ユーザー初回 tooltip

**手順**:
1. V2.5 build からのアップデート (`spec056_v3_migrated` = false 状態)
2. V3.0 起動

**期待結果**:
- 初回起動時に「タブが新しくなりました ✨ — 知識 Clip / ライブラリ / AI チャット の 3 つにまとめました」 tooltip 表示
- dismiss 後、`spec056_v3_migrated` = true 永続化
- 2 回目以降の起動では tooltip 非表示

---

## SC-015: 既存 unit test 全 PASS

**手順**:
```bash
xcodebuild test \
  -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KnowledgeTreeTests \
  -parallel-testing-enabled NO
```

**期待結果**:
- `** TEST SUCCEEDED **`
- regression 0 件 (spec 040/041/042/043/044/046/047/051 全関連 test PASS)
- 新規 19 ケース (RecentArticlesServiceTests 8 + SuggestedPromptGeneratorTests 6 + LibraryDateGrouperTests 5) PASS

---

## 既存機能 Regression 一覧

| spec | 検証ポイント |
|---|---|
| spec 001 | Share Extension → 記事保存 (Phase B 後も継続) |
| spec 008 | 検索 (ライブラリ上部の検索バーから動作) |
| spec 018 | KnowledgeDigest 生成 (Topic Dashboard 経由表示) |
| spec 022/030 | swipe + contextMenu 削除 (ライブラリで継続) |
| spec 034 | PDF 保存 (Share Extension 経由維持) |
| spec 035 | LastOpenedStore (差分判定の since 基準として活用) |
| spec 042 | ConceptPage 詳細 + 自動生成 (動作変化なし) |
| spec 043 | SavedAnswer auto-save + 履歴 (Settings 配下で継続) |
| spec 044 | 家庭教師ループ (新動線経由で完全動作) |
| spec 051 | CloudKit sync (Settings → iCloud toggle 動作維持) |

---

## 実機検証フロー (推奨)

1. **新規インストール検証** (1 時間):
   - SC-001 / SC-002 / SC-003 / SC-007 / SC-011 (新規 user の主要 flow)
   - empty states 確認 (US11)

2. **データありユーザー検証** (1 時間):
   - 上記事前準備でデータ作成
   - SC-004 / SC-005 / SC-006 / SC-009 / SC-010 / SC-012 (full feature flow)

3. **動線継続性検証** (30 分):
   - SC-013 (既存機能 5-6 個を新動線経由で動作確認)

4. **アップデート検証** (15 分):
   - V2.5 build → V3.0 build アップデート
   - SC-014 (tooltip 表示) + 既存データ全継承確認

5. **性能検証** (30 分):
   - SC-008 (Instruments で 60fps 計測)
   - SC-003 (起動 1 秒以内)

6. **regression** (Simulator で自動):
   - SC-015 (xcodebuild test)

---

## Acceptance Criteria

全 15 シナリオが ✅ PASS で V3.0 release 可能。
1 つでも ❌ FAIL なら原因分析 + 修正 + 再検証。
