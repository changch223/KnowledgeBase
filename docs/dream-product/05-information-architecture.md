
# 05 — Information Architecture

## このファイルの目的

「アプリの内側でどうデータが構造化されているか」を、**実装言語に依存しない一般語** で記述する。
SwiftData @Model 固有名は使わず、概念名で書く (例: `Article` ではなく「保存ソース」)。

「秘書ループ + 家庭教師ループ + Compound moment」 (03 章) が乗る土台。

---

## 3 層 IA (Karpathy 踏襲)

```
┌───────────────────────────────────────────────────────────┐
│ Schema 層 (アプリ内部規約、ユーザーに見えない)              │
│   ・命名規約 / 概念粒度 / Lint ルール / 抽出 prompt 規約   │
└───────────────────────────────────────────────────────────┘
                       ↓ guides
┌───────────────────────────────────────────────────────────┐
│ Wiki 層 (LLM 自動メンテ、user 閲覧 + 部分編集可)             │
│   ・要約 (1:1 with source)                                   │
│   ・概念ページ (横断 synthesis、★ 本体価値)                 │
│   ・知識グラフ (entity 関係)                                 │
│   ・コミュニティ (concept クラスター、AI 命名)               │
│   ・質問結果ファイリング (chat 答えの永続化)                 │
│   ・活動ログ (時系列、内部のみ)                              │
│   ・カテゴリーダイジェスト (10 種固定カテゴリーまとめ)        │
└───────────────────────────────────────────────────────────┘
                       ↑ extract / synthesize
┌───────────────────────────────────────────────────────────┐
│ Raw 層 (immutable、人間キュレーション)                      │
│   ・保存ソース (Web 記事 / PDF / 画像 / AI 会話スクショ)     │
│   ・本文テキスト (元データ忠実)                              │
│   ・メタデータ (URL / 取得日 / sourceType 等)               │
└───────────────────────────────────────────────────────────┘
```

各層の所有権:

| 層 | 書き手 | 読み手 | 編集自由度 |
|---|---|---|---|
| Schema | アプリ開発者 (LLM が共進化提案) | LLM | 内部 hardcode、Settings で一部 opt-in |
| Wiki | **LLM が主**、user は補正 | 人間 (mobile UI) | LLM = 自由、user = rename/merge/delete |
| Raw | 人間 (Share Sheet) | LLM (read-only) | 追加・削除のみ、本文編集不可 |

---

## Raw 層 (保存ソース)

### ノード種別 1: 保存ソース

「ユーザーが共有した 1 つの情報単位」。

| 属性 | 中身 |
|---|---|
| id | 一意 ID (UUID) |
| sourceType | web / pdf / image / aiChat / plainText |
| url | 元 URL (web の場合) |
| title | ソースタイトル (元 OG / 抽出 / ユーザー編集) |
| savedAt | 保存日時 |
| originLanguage | 元言語 (en / ja / zh / ...) |
| isObsolete | 古くなった (新ソースで置き換わった) フラグ |

### ノード種別 2: 本文テキスト

「保存ソース 1 つに 1 つの本文」。

| 属性 | 中身 |
|---|---|
| sourceID | 保存ソースへの関係 |
| body | 本文テキスト (HTML 除去後) |
| rawHTML | 元 HTML (web の場合、デバッグ用) |
| extractionStatus | success / partial / failed |
| sourceLanguage | 抽出時点の本文言語 |

### Raw 層の不変ルール

- LLM は **読むだけ**、編集禁止
- ユーザーは追加・削除のみ、本文編集 UI を提供しない
- 元 URL / 元ファイルへのアクセスは常に維持 (信頼性の起点)

---

## Wiki 層 (LLM 自動メンテ、本体価値)

### ノード種別 3: 要約 (1:1 with 保存ソース)

「1 ソースから抽出された知識の凝縮」。

| 属性 | 中身 |
|---|---|
| sourceID | 保存ソースへの関係 |
| essence | 1 文 / 150 字以内、ソースの核心 |
| summary | 2-3 文 / 300 字以内、構造維持 |
| keyFacts | 3-5 件の事実 (引用元付き) |
| entities | 5-10 件の固有名詞 (人物 / モノ / 場所 / 概念) |
| extractionStatus | LLM 抽出の成否 |
| embedding | essence の vector (検索用) |

抽出は LLM、user は閲覧のみ。

### ノード種別 4: 概念ページ ★ (横断 synthesis、本体価値)

「複数の保存ソースに登場する entity / concept を 1 つにまとめたページ」。

**これが Wiki 層の核心**。Karpathy 思想の本体。

| 属性 | 中身 |
|---|---|
| id | 一意 ID |
| name | 概念名 (例: "Apple Intelligence", "Tim Cook", "Foundation Models") |
| nameAliases | 同義語 (例: "アップル インテリジェンス") |
| categoryRaw | 所属 10 種固定カテゴリー |
| summary | AI 合成、複数ソースから統合した「今わかっていること」(200-400 字) |
| crossSourceInsights | 文字列リスト、複数ソース横断で見えた知見 (例: 「v1 から v2 への進化点」「業界の反応」) |
| relatedSourceIDs | 関連保存ソースの ID 配列 |
| relatedConceptIDs | 関連概念の ID 配列 (graph 経由) |
| userUnderstanding | 0-5、ユーザー理解度 (内部、UI には出さない) |
| isFollowing | ユーザーがピン (フォロー) 中か |
| isStale | 新ソース ingest で「再合成必要」とマーク |
| embedding | summary の vector (検索用) |
| createdAt / updatedAt | 時刻 |

**lifecycle**:
- 自動生成: 2+ 保存ソースに同名 entity が登場した瞬間
- 自動更新: 新ソース ingest 完了 → `isStale = true` → BGTask で再合成
- 削除: ユーザー手動 (TagStore 同パターン)、自動削除なし
- merge: ユーザーが「Apple = アップル を 1 つに」と指示すると統合 (lint 提案経由 or 直接)

### ノード種別 5: 知識グラフノード (entity 単位)

「概念ページ より粒度が細かい、graph 表示用のノード」。

| 属性 | 中身 |
|---|---|
| id | 一意 ID |
| name | entity 名 |
| categoryRaw | カテゴリー |
| salience | 重要度 1-5 |
| mentionCount | 言及記事数 |
| isActive | カテゴリー内 30 ノード上限超過で false |
| relatedConceptID | 概念ページとの 1:1 関係 (任意) |

**注**: 概念ページ (種別 4) と graph ノード (種別 5) の関係は 1:1 or N:1。粒度が違う:
- 概念ページ = ユーザーに見せる「読める単位」
- graph ノード = 関係性を表現する「構造単位」

### ノード種別 6: 知識グラフエッジ (関係)

```
ノード A --[関係ラベル]--> ノード B (確信度 0.5-1.0)
```

| 属性 | 中身 |
|---|---|
| sourceNodeID | エッジの起点 |
| targetNodeID | エッジの終点 |
| label | 関係 (例: "CEO of", "develops", "released by", null = 共起のみ) |
| confidence | 0.0-1.0 (AI 抽出時の確信度) |
| isUncertain | 0.5-0.7 範囲なら true |
| weight | 観測回数 (新記事で同関係が観測されたら +1) |
| categoryRaw | カテゴリー |

### ノード種別 7: コミュニティ (concept クラスター)

「graph 構造から検出された entity の集まり、AI で命名」。

| 属性 | 中身 |
|---|---|
| id | 一意 ID |
| name | AI 命名 (例: "Apple エコシステム", "AI 業界トレンド") |
| summary | コミュニティの中身を 1-2 文で説明 |
| categoryRaw | 所属カテゴリー |
| level | 0 (細粒度) / 1 (中) / 2 (粗) - 階層的 |
| memberNodeIDs | メンバー graph ノード ID 配列 |
| memberCount | メンバー数 |
| createdAt / updatedAt | 時刻 |

**生成**: 起動時 + 週 1 BGTask で K-means or Louvain ベース検出。

### ノード種別 8: 質問結果ファイリング (SavedAnswer)

「秘書 chat / 家庭教師 chat の答えで価値あるものを永続化」。

| 属性 | 中身 |
|---|---|
| id | 一意 ID |
| question | ユーザーの質問 |
| answer | AI 答え (引用付き) |
| citedSourceIDs | 引用元ソース ID 配列 |
| relatedConceptIDs | 答えで触れた概念ページ ID 配列 |
| sessionID | 元の chat session (任意) |
| savedAt | 保存日時 |
| isPinned | ユーザーがピン |

**生成**: Compound moment 条件 1 で自動、ユーザーが「📌 保存」タップでも明示。

### ノード種別 9: 活動ログ (内部、log.md 相当)

「ingest / query / lint / compound の時系列記録」。

| 属性 | 中身 |
|---|---|
| eventType | ingest / query / lint / compound_concept / compound_answer / etc. |
| message | 詳細メッセージ |
| relatedSourceID | 関連ソース (任意) |
| relatedConceptID | 関連概念 (任意) |
| createdAt | 時刻 |

**UI 露出**: デフォルト非表示、Settings で opt-in 表示。

### ノード種別 10: カテゴリーダイジェスト

「10 種固定カテゴリーごとに AI が合成したまとめ」。

| 属性 | 中身 |
|---|---|
| categoryRaw | カテゴリー (テクノロジー / 経済 / 健康 / 教育 / アート / 等) |
| cards | 1-3 個のダイジェストカード (各 ~150 字) |
| topEntityNames | 主要 entity 3-5 |
| isStale | 新ソースで再合成必要 |
| updatedAt | 時刻 |

---

## Schema 層 (内部規約、ユーザーから隠す)

### 規約の例

- カテゴリーは **10 種固定** (テクノロジー / 経済 / 健康 / 教育 / アート / ニュース / 趣味 / 仕事 / 生活 / その他)
- 概念ページの `summary` は **200-400 字** に制限
- `crossSourceInsights` は **最大 7 件**
- グラフノードは **カテゴリー内 30 上限** (超過は salience 低を deactivate)
- entity 抽出は **3-7 個 / ソース**
- KeyFact 抽出は **3-5 件 / ソース**

### 規約の出口

- LLM 抽出 prompt の制約として埋め込む
- WikiLint (健全性チェック) の判定基準として使う
- ユーザーには見えない (Settings に出さない)

### 進化

- Karpathy 流: 規約は時間と共に進化させる、LLM 自身に「規約と実体の乖離」を提案させる
- 本アプリ V1: アプリ開発者が hardcode で固定、V3+ で動的 schema 進化検討

---

## Lifecycle (生成 → 更新 → 削除)

各ノードのライフサイクルを通して:

```
[保存ソース 投入]
   ↓
[本文抽出]
   ↓
[要約 生成]           ─→ [概念ページ 自動生成 / 更新]
   ↓                      ↓
[entity 抽出]         [graph ノード / エッジ 生成]
                          ↓
                     [コミュニティ検出 (週1)]
                          ↓
                     [カテゴリーダイジェスト 再生成]

[ユーザーが chat で質問]
   ↓
[chat 答え 生成 + 引用]
   ↓
[Compound: SavedAnswer 自動保存 + 関連概念ページ更新]

[ユーザーが「✓ わかった」]
   ↓
[概念ページの userUnderstanding +1]

[ユーザーが手動 rename / merge / delete]
   ↓
[該当ノード 更新 / 削除]

[週 1 BGTask: WikiLint]
   ↓
[同義異名 / 孤立 / 概念候補 検出]
   ↓
[「気づきの種」セクションに soft proposal 表示]
```

---

## ノード間関係 (主要)

```
保存ソース ──1:1── 本文テキスト
保存ソース ──1:1── 要約
保存ソース ──N:N── 概念ページ (relatedSourceIDs 経由)
保存ソース ──N:N── タグ
保存ソース ──N:N── SavedAnswer (citedSourceIDs 経由)

概念ページ ──N:N── 概念ページ (relatedConceptIDs 経由、graph 経由)
概念ページ ──1:1── 知識グラフノード (任意)
概念ページ ──N:N── SavedAnswer (relatedConceptIDs 経由)

知識グラフノード ──多対多── 知識グラフノード (エッジ経由)
知識グラフノード ──N:1── コミュニティ (memberNodeIDs 経由)

コミュニティ ──1:N── カテゴリー (categoryRaw 経由)
カテゴリーダイジェスト ──1:1── カテゴリー
```

---

## Wiki 層の「育ち方」(時系列イメージ)

| 時期 | Wiki の状態 |
|---|---|
| 初回起動 | 空、Raw 層も空 |
| 5 ソース投入後 | 要約 5、概念ページ 2-3 (entity 重複が出始める) |
| 20 ソース投入後 | 要約 20、概念ページ 10-15、グラフ 30 ノード、コミュニティ 2-3 |
| 50 ソース投入後 | 要約 50、概念ページ 30+、グラフ 100 ノード、コミュニティ 5-7、SavedAnswer 10+ |
| 200 ソース投入後 | 要約 200、概念ページ 100+、グラフ 500 ノード、コミュニティ 15+、SavedAnswer 50+ |

→ **時間とともに wiki が複利で太る**、これが本アプリの本質的価値。

---

## アンチパターン (避ける IA 設計)

| アンチパターン | なぜダメ |
|---|---|
| ユーザーに「カテゴリー作って」と要求 | カテゴリーは 10 種固定、ユーザー編集なし (Notion の罠) |
| 概念ページを user が手書きする UI | LLM が書く前提、user は補正のみ |
| 削除して履歴が消える | ActivityLog に削除記録残す (取り消し可能性) |
| Raw 層を user が編集可 | 元データ忠実性が崩れる |
| グラフ無制限ノード | iPhone 負荷、UI 破綻 → 30 ノード上限で deactivate |
| 概念ページが時系列で append のみ | summary が肥大化、定期的に再合成して圧縮 |

---

## 次に読むファイル

- `06-ux-flows.md` — このデータ構造が UI でどう見えるか
- `07-tech-constraints.md` — このデータ構造を支える技術 (SwiftData / Foundation Models 等)
