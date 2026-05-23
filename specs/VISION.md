# iKnow (旧 知積 / KnowledgeTree) — Product Vision

**Last updated**: 2026-05-23
**Status**: v2.0 (dream-product spec ベースで全面改訂)
**Bundle ID**: 継承 (旧 知積 と同一 App Store ID 維持)

---

## ❯ 一文ビジョン (canonical)

> **日常で触れたあらゆる情報をアプリに共有して、その情報は AI が読み解き・繋ぎ・要約しながら、活用されないままの眠っている知識を自動で蓄積でき、自分唯一のものとして所用し、iPhone の Apple Intelligence をさらに進化させ差別化できる『新たな AI』として あなたに使えるようになる。必要に応じて knowledge を Gemini / ChatGPT などに共有して、さらに進化できる AI になる。秘書のように大事な情報を整理して要点を提示し、スピーディーに情報キャッチアップでき、必要に応じて自分の理解として腹落ちするまで会話で深堀りできるアプリ。**

### 短縮版 (1 文)

> 「日常で触れた情報を AI が体系化し、秘書のように要点を、家庭教師のように深堀りを、完全 on-device で提供する『Apple Intelligence をあなた専用に進化させた』アプリ」

---

## ❯ 中核哲学

すべての設計判断は、Andrej Karpathy のこの一文に集約される:

> "**You can outsource your thinking, but you cannot outsource your understanding.**"
> (思考は外部化できても、理解は外部化できない。)

### 一般人向け翻訳: 「秘書 + 家庭教師」が 1 つになった AI

| ロール | 担当 | 実装 |
|---|---|---|
| **秘書** (Outsource Thinking) | 「あれ何だっけ」「これまとめて」 | News Clip 風カード + 秘書 chat |
| **家庭教師** (Understanding) | 「これって何で?」「腹落ちしたい」 | 学習カード + 「✓ わかった/🤔 もっと」+ 深堀り chat |

→ **「思考は委ねていい、ただし理解は委ねさせない」設計を貫く**。

---

## ❯ Apple Intelligence を進化させる「あなた専用 AI」という位置づけ

### Base = Apple Intelligence (Foundation Models)

- iPhone 標準搭載、追加 API 課金ゼロ、完全 on-device

### 差別化 = ユーザー固有の context

- 一般的な ChatGPT / Gemini は「世界の知識」だけ
- 本アプリは「**あなたが触れた情報の context**」を AI に継続注入
- → **あなただけの過去・興味を理解する AI** になる

---

## ❯ 2 つの中核ループ + Compound Moment

```
┌─────────────────────────────────────────┐
│ Loop 1: 秘書ループ (Outsource Thinking) │
│ 共有 → 抽出 → 蓄積 → 提示 → 引用       │
└─────────────────────────────────────────┘
                  ↕ Compound moment
┌─────────────────────────────────────────┐
│ Loop 2: 家庭教師ループ (Understanding)   │
│ surface → 興味 → 深堀り → 腹落ち → file │
└─────────────────────────────────────────┘
                  ↕ Compound moment
        wiki が育つ flywheel
```

### Compound moment 4 条件

1. 秘書 chat 答えに引用 ≥ 2 件 → SavedAnswer 自動保存 + 関連概念ページ更新
2. 家庭教師深堀り会話の終わり → 新 insight が概念ページに append
3. 「✓ わかった」タップ → userUnderstanding スコア + 関連 1-hop 波及
4. 新記事 ingest → 既存概念ページ stale → BGTask で再合成

---

## ❯ 設計原則 (11 個)

### 普遍原則 7 つ (Karpathy / SAGE / cortex 由来)

1. **Knowledge compounds** — RAG 使い捨てではなく、永続成長する成果物
2. **説明文 = 検索精度の本体** — AI が書く要約が embedding 入力
3. **bookkeeping は LLM が全部やる** — 人間は読む / 問う / 考える
4. **Runbook pattern** — 答え / カードに「次のアクション」内蔵
5. **自己進化** — ingest → 更新 → query → file → 次の問い、ループ
6. **ハルシネーション位置を意識的に設計** — LLM 介在は抽出時のみ、検索 / 表示 / 編集は決定論的
7. **AI が書く前提の設計** — 人が書く前提では維持不能、AI 主体で初めて成立

### 本アプリ固有原則 4 つ

A. **完全 on-device** — Foundation Models のみ、クラウド API 一切なし
B. **Calm UX** — 通知ゼロ / バッジゼロ / streak ゼロ
C. **受動 + 能動の両モード共存** — Widget で受動、Chat で能動
D. **一般 iPhone ユーザーが今日から使える** — CLI / Markdown 不要

---

## ❯ ターゲット (7 ペルソナ)

| # | 仮名 | 属性 |
|---|---|---|
| 1 | タブ太郎 | 35 歳 IT 系、タブ 80+ 開きっぱなし |
| 2 | 学さん | 22-23 歳、学生 / 資格勉強中 |
| 3 | 作る花子 | 40 歳 ライター / 研究者 |
| 4 | 好奇さん | 50 歳 趣味で歴史 / 科学探求 |
| 5 | 育子さん | 33 歳 子育て中、時間細切れ |
| 6 | 七六さん | 67 歳 シニア、字小さい NG |
| 7 | 営みさん | 45 歳 経営者 / リーダー、業界動向キャッチ |

→ **一般 iPhone ユーザー全般** (年齢 / 職業不問)。

---

## ❯ 4 タブ構成 (iKnow)

```
1. 学習        (起動 default、新規)   ← 家庭教師ループ
2. AI チャット                         ← 秘書ループ (能動 query)
3. 知識 Clip                           ← 受動 surface + Wiki ブラウズ + 気づきの種
4. ライブラリ                           ← Raw 層 (保存記事 + 検索)
+ Widget (タブ外、ambient surface)
```

---

## ❯ V1 機能 (10 spec、4-5 ヶ月想定)

| spec | 内容 | 規模 |
|---|---|---|
| spec 045 | ConceptPage @Model + Service + UI ★ | 大 |
| spec 046 | SavedAnswer + Chat filing | 小 |
| spec 047 | WikiLint 拡張 (← ConflictDetection 拡張統合) | 中 |
| spec 048 | EntityCommunity (← TopicClustering 発展) | 中 |
| spec 049 | Understanding Chat (Main、新タブ) ★ 最大 | 大 |
| spec 050 | 写真 / AI 会話入力 (OCR + 構造判定) | 中 |
| spec 051 | Widget (3 サイズ) | 中 |
| spec 052 | Export (zip + markdown) | 小 |
| spec 053 | タブ再編 + AI ブレイン廃止 | 中 |
| spec 054 | iKnow リブランディング (icon + xcstrings + App Store) | 小 |

詳細は `docs/migration-plan/04-implementation-roadmap.md`。

---

## ❯ 入力源

| 入力源 | V1 | V2 | V3+ |
|---|---|---|---|
| Web 記事 (Share Sheet) | ✅ | | |
| PDF (Share Sheet) | ✅ | | |
| Safari Web Extension | ✅ | | |
| 写真 / スクリーンショット (OCR) | ✅ | | |
| AI 会話スクショ (ChatGPT/Gemini/Claude) | ✅ | | |
| プレーンテキスト | ✅ | | |
| Web search (BYOK) | | ✅ | |
| Reading List / Pocket 一括 import | | ✅ | |
| YouTube transcript | | ✅ | |
| ポッドキャスト音声 | | | ✅ |
| メール / メッセージ転送 | | | ✅ |

---

## ❯ 出力 / Export

- zip 全体 export (V1)
- Markdown 個別 export (V1)
- iOS Share Sheet 経由共有 (V1)
- Obsidian 互換 vault (V2)

→ **export は user 主体**、アプリは外部送信ゼロ。

---

## ❯ 既存ツール対比 (差別化軸)

| 既存ツール | 足りないこと |
|---|---|
| ChatGPT / Claude / Gemini | 「あなたが読んだもの」が context にならない |
| NotebookLM | 蓄積が compound しない、RAG 都度検索 |
| Pocket / Reading List | 貯めるだけ、繋がりも要約も自動化なし |
| Apple Notes / Bear / Notion | 整理が人間任せ |
| Obsidian + LLM | CLI / Markdown 必須、デスクトップ必須、一般人ハードル高 |
| Anki / 学習アプリ | 「貯める」が別アプリ、生活との接点なし |
| iOS Apple Intelligence (base) | あなた固有 context を持たない、ジェネリック |

→ **「読んだあらゆる情報を貯めて、AI が体系化し、必要な時に質問でき、理解したいときには深堀りもでき、Apple Intelligence をあなた専用に進化、完全 on-device、一般人向け iPhone アプリ」は存在しない**。

---

## ❯ 成功の定義 (5 項目)

| 条件 | 中身 |
|---|---|
| **眠っている知識の活性化** | タブ・Pocket・Bookmark が活きてくる、「読まずに忘れていた」が「読まなくても要点が頭に入る」に |
| **「あなた専用 AI」感** | 「他の人の AI と自分の AI が違う」と感じる |
| **維持コスト ≈ 0** | 「保存するだけ」で知識が育つ、「整理しなきゃ」ストレスが消える |
| **理解の増幅** | 「読んだものを自分のものにする」体験、深堀り会話で腹落ち |
| **既存に無いカテゴリの製品** | 「AI が wiki を作って育てて教えてくれる、一般人向け全部入りモバイル知識ベース」として認知 |

---

## ❯ 明示的な非ゴール (V1)

- アプリ内から自動でクラウド LLM API を呼ぶ (永久になし)
- マルチユーザー / 共有 / コラボ (V?)
- 課金 / サブスク / 広告 (V?)
- アナリティクス SDK / 3rd party クラッシュレポート
- ゲーミフィケーション / streak / バッジ / レベル
- push 通知 default ON (opt-in OFF default のみ)
- 「正解 / 不正解」テスト UI
- 自動 ingest (RSS / web crawler 等)
- 「整理して」を user に要求する UI
- Android / Web / Mac / iPad (V1)、Mac/iPad は V3+

詳細は `docs/dream-product/08-non-goals.md`。

---

## ❯ 関連ドキュメント

| ドキュメント | 役割 |
|---|---|
| `docs/concept-review/karpathy-llm-wiki/01-07.md` | Karpathy / SAGE / Tableau AKG / cortex 外部研究 (思想基盤) |
| `docs/dream-product/00-10.md` | Zero-base dream product spec (11 ファイル、3360 行) |
| `docs/migration-plan/00-07.md` | 現知積 → iKnow 移行ロードマップ (7 ファイル、1250 行) |
| `specs/001-044/` | 現知積 spec 群 (継続活用 + 改修 + 一部廃止) |
| `specs/045-054/` (今後作成) | iKnow V1 新規 spec |

---

## ❯ 改訂履歴

| 日付 | 改訂内容 |
|---|---|
| 2026-05-08 | 初版 (知積 v1、6 設計原則、4 タブ、機能 X/Y/Z/W) |
| **2026-05-23** | **v2.0 全面改訂** (iKnow にリブランディング、11 設計原則、2 ループ + Compound moment、V1 spec 045-054、dream-product spec ベース) |

### v1 → v2 の主な変化

- 一文ビジョン: 「読んだ知識を AI が体系化」→ 「Apple Intelligence をあなた専用に進化させる秘書 + 家庭教師」
- 設計原則: 6 → 11 (Karpathy / SAGE / cortex 由来 7 + 固有 4)
- タブ構成: 4 タブ維持、ただし起動 default = 学習 (新規)、AI ブレイン → 知識 Clip 統合
- 機能スコープ: X/Y/Z/W (spec 035-038) → V1 spec 045-054 (10 新規)
- アプリ名: 知積 (KnowledgeTree) → iKnow (Bundle ID 継承)
- ターゲット: エンジニア中心 → 一般 iPhone ユーザー (7 ペルソナ拡張)
