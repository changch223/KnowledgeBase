# KnowledgeTree (知積) — Spec Roadmap

**Last updated**: 2026-05-05
**Current branch**: `016-category-detail-view`
**Main HEAD**: `47a9338` (spec 013 merged)

このドキュメントは spec 001 〜 spec 040+ の全体計画を保存し、`/speckit-specify` 起動時の優先順位判断に使う。
更新は spec を新たに着手する / 完了させる毎に行う。

---

## Past — main マージ済または実装完了

| # | テーマ | 状態 | commit |
|---|---|---|---|
| 001-005 | MVP コア (保存 / OG / 本文 / 知識 / Detail) | ✅ main | `0fad9fd` (PR #1) |
| 006 | Chunked summarization | ✅ main | `74d167b` |
| 007 | Multi-page fetch | ✅ main | `640c89c` |
| 008 | 検索 + タグ + 関連 | ✅ main | `8f3ce4a` (+ `fbcde69` hot-fix) |
| 009 | BGTaskScheduler | ✅ main | `adc2221` |
| 010 | 階層 chunked summarization | ✅ main | `adc2221` |
| 011 | UI リブランディング + AI ブレイン v1 | ✅ main | `8b8671e` (PR #2) |
| 012 | AI Auto-Tag | ✅ main | `0e6e299` (PR #2) |
| 013 | Auto-Tag backfill | ✅ main | `dc877bd` (PR #2) |
| 014 | DesignSystem 統一 | 🟡 PR #3 OPEN | `b78c2f4` |
| 015 | AI ブレイン v2 + Category 階層 | 🟡 未 commit | (work tree) |
| 016 | Category 詳細 + 時間軸 + 折りたたみ | 🟡 未 commit | (work tree) |

---

## 🔥 Sprint 0 (即時) — 確定済 spec の取り込み

| 作業 | 内容 |
|---|---|
| spec 014 PR #3 マージ | 単独で完結、ブロッカーなし |
| spec 015 commit | 未 commit 分を 1 commit |
| spec 016 commit | 未 commit 分を 1 commit |
| spec 016 T022 実機検証 | B1 修正 + 4 UX 確認 (SC-001〜SC-009) |

**所要**: 0.5〜1 日

---

## 🥇 Sprint 1 — 高優先 (バグ + Dark Mode + 知識 Clip タブ)

ユーザー提供の最優先 3 項目。

### spec 017 — Dark/Light Mode 自動切り替え対応 (Apple-quiet 維持)

**動機**:
- DesignSystem.swift の `actionBlue` / `parchment` / `tagFill` 等は RGB 固定 → Light Mode 専用、Dark Mode で読みづらい
- iOS 標準 `.systemBackground` 等は auto-adapt するが、カスタム token は対応していない
- DESIGN.md Known Gaps で明示済

**スコープ**:
- DesignSystem に Dark variant 追加 (`Color(light:dark:)` ペア定義 or `@Environment(\.colorScheme)`)
- Hairline / parchment / actionBlue / tagFill 全 token を Dark 対応
- 全 18 view を Dark Mode で実機確認 (Dynamic Type も)
- Reduce Transparency 対応も同時に

**規模**: 中 (~3 日)
**依存**: spec 014 / 015 が main にあること

---

### spec 018 — 知識 Clip タブ (News Clip 風 3rd タブ)

**動機**:
- 現在のタブ構成: ライブラリ / AI ブレイン (2 タブ)
- ユーザー要望: 「main 画面で news clip のように知識 clip」表示するタブを追加
- 保存記事の AI 抽出 essence + KeyFact + entity を card 風に提示 → 隙間時間に知識消費

**スコープ**:
- 新タブ「知識 Clip」を TabView に追加 (3rd タブ)
- カード UI: 1 記事 1 枚、上に essence、中に top KeyFact 3 つ、下にタグ + 元記事リンク
- 縦スクロール (Apple News 風) or 横スワイプ (TikTok 風) — Q&A で確定
- フィルター: 全部 / 最近 7 日 / Category
- 「もう知ってる」「後で読む」操作 (将来 swipe アクションと連携)
- Empty / Skipped / Failed 記事の扱いを明確化

**Q&A 必要項目**:
1. カード遷移は縦 (News Style) or 横 (Story Style)?
2. 既読管理あり / なし? (constitution V「不安喚起 UI 禁止」と整合確認)
3. essence なしの記事はカード表示する?

**規模**: 大 (~5 日)
**依存**: spec 017 (Dark Mode) があると視覚整合性高

---

### spec 019 — 既知バグ修復 + 検証 backlog 消化

**動機**:
- BodyExtractorTests 2 件が pre-existing FAIL → 修復
- spec 011-015 の quickstart 未検証分を一気に消化
- Swift 6 strict concurrency warning 系の整理
- 「現在あるバグを直す」の集約

**スコープ**:
- BodyExtractorTests 失敗 root cause 調査 + 修復 (2 ケース: extractsFromMainTag / extractsByDensityScoringWhenNoSemanticTag)
- spec 011/012/013/014/015 quickstart 全シナリオを実機 + Simulator で消化
- Swift 6 strict concurrency warning ゼロ化 (`KnowledgeExtractor.defaultMaxBodyChars` 等)
- `onChange(of:perform:)` deprecated 修正

**規模**: 中 (~2 日)
**依存**: なし、独立

---

## 🥈 Sprint 2 — 中優先 (取り込み経路の拡張)

ユーザー提供の Chrome Shortcut → Safari Extension の流れ。

### spec 020 — Chrome 連携 (URLSession 経路 + iOS Shortcut 自動化)

**動機**:
- Constitution Principle IV で Shortcuts は「将来 / オプション」、本 spec で MVP 入り
- Chrome から記事を保存するのに毎回 Share Sheet タップが面倒
- ユーザー要望「Chrome のタブを開くと自動送信」

**スコープ**:
- iOS Shortcut Action として「URL 受信 → KnowledgeTree に保存」を提供
  - SiriKit / App Intents で expose
- Chrome の「Always open in xxx」連携
- 「URL を渡されたら、URLSession で fetch → ArticleSavingService」のフロー
- 重複 URL 検出 (既存 spec 001 ロジック再利用)
- ユーザーが Shortcut を初回セットアップする UI / オンボーディング

**Q&A 必要項目**:
1. Shortcut の Action 名は? (例: 「知積に保存」)
2. 保存後の通知 / バッジ表示は? (constitution V との整合)
3. Chrome 以外のブラウザ (Edge, Brave, Arc) もサポート?

**規模**: 大 (~5 日)
**依存**: なし、独立

---

### spec 021 — Safari Web Extension (閲覧ページ自動検知 + 取り込み)

**動機**:
- Constitution Principle IV で「Safari Extension は将来 / スコープ外」、本 spec で MVP 入り
- Safari でページ閲覧中、ボタン 1 タップで知積保存 (Share Sheet より速い)
- ページの `<meta>`, `og:image` 等を Safari 側で取得 → アプリへ受け渡し

**スコープ**:
- Safari Web Extension target を Xcode に追加
- ツールバーに知積アイコン → タップで現在の URL + メタ情報を抽出
- Extension 設定 UI (アプリ内): ON/OFF、自動取り込み、ホワイトリスト/ブラックリスト
- Storage 共有 (App Group)
- 自動取り込みモード時: 「特定ドメイン (zenn.dev / qiita.com 等) を訪問したら自動保存」

**Q&A 必要項目**:
1. ボタンタップ vs 自動取り込み、どちらをデフォルト?
2. Privacy: ブラウジング履歴を全部取るのか、明示同意ドメインのみ?
3. iOS / iPadOS / macOS どこまでサポート?

**規模**: 大〜特大 (~7-10 日)
**依存**: なし、独立。spec 020 と並列可

---

## 🥉 Sprint 3 — AI Chat (RAG)

### spec 022 — AI Chat (RAG) 処理フロー

**動機**:
- Constitution Principle II で MVP 範囲外と明示されていたが、本 spec で Apple Intelligence + 保存記事を knowledge base にした会話型 UI を実装
- Constitution Principle III「ソースに基づいた知識生成」と整合: AI 回答に必ず元記事 ID を引用 (footnote 形式)

**スコープ**:
- Vector embedding 生成 (Apple Intelligence の embedding 機能 or NLEmbedding)
- 質問入力 → 関連記事 retrieval (top-k cosine similarity)
- Foundation Models で回答生成 + 引用記事リスト
- 会話履歴の SwiftData 永続化 (`ChatSession`, `ChatMessage` @Model)
- AI チャット専用タブ追加 or AI ブレインタブ内のサブセクション

**Q&A 必要項目**:
1. embedding は記事保存時に precompute? それとも検索時 on-demand?
2. 会話履歴は何件保持? (古いは自動削除 vs 永続)
3. 「ハルシネーション抑制」をどう保証? (引用必須 / 「分かりません」フォールバック)
4. 専用タブ vs AI ブレイン内サブ?

**規模**: 特大 (~10-14 日)
**依存**: spec 017 (Dark Mode で視覚整合)

---

## 🪶 Sprint 4 以降 — その他 (ユーザー任せ枠、優先度判断は私)

### A 優先度高 (運用上必要)

| # | テーマ | 動機 | 規模 |
|---|---|---|---|
| 023 | ArticleRow 左 swipe (削除 / アーカイブ) | 削除手段がないと運用上限界 | 小 (~1 日) |
| 024 | Tag 編集 / 統合 / 削除 UI | AI Auto-Tag のみで誤りを直せない | 中 (~3 日) |
| 025 | Apple Intelligence 利用不可時の fallback | Simulator / 非対応端末で「何も生成されない」状態を解消 (Constitution I との両立要 spec.md 明記) | 中〜大 |

### B 中優先度 (UX 質向上)

| # | テーマ | 動機 | 規模 |
|---|---|---|---|
| 026 | タグフィルター AND / NOT 条件 | spec 016 spec.md 将来候補 | 小〜中 |
| 027 | 検索 relevance スコアリング (BM25 風) | spec 008 Assumptions で MVP 外 | 中 |
| 028 | ソート切替 (人気順 / AI スコア順 / Tag 数順) | spec 016 将来候補 | 中 |
| 029 | AI 生成物の手動編集 (essence / summary) | AI 誤りをユーザーが直せる、Constitution III 整合 | 中 |
| 030 | 検索履歴 + suggestions | spec 008 Assumptions で MVP 外 | 小 |

### C 設計穴埋め / クリーンアップ

| # | テーマ | 動機 | 規模 |
|---|---|---|---|
| 031 | 廃止 view (PowerGauge / KnowledgeMap / RecentActivity) のコード削除 | spec 015 で alias 残し、本 spec で本削除 | 小 |
| 032 | Stats Row 数字タップで該当一覧へ jump | spec 015 実機検証で出そうな自然延長 | 小 |
| 033 | iPad Split View (NavigationSplitView 化) | DESIGN.md Known Gaps、iPad 体験向上 | 大 |
| 034 | エクスポート / iCloud バックアップ | 災害復旧 + デバイス移行、Constitution I 整合確認 | 大 |
| 035 | Foundation Models prompt チューニング | Auto-Tag / AutoCategoryClassifier 精度向上 | 中 |

### 🆕 spec 023+ 候補 — 知識 Clip タブ UI/UX ブラッシュアップ (spec 018 出荷後)

**動機**: spec 018 の初版実装後、ユーザーが「カードに何を表示するか」「総まとめ詳細画面の内容」「期間フィルター挙動」「stale マーク見せ方」「マルチカード分割の自然さ」等で整理したい点が出てきた (2026-05-05 ユーザーメモ)。

**スコープ (ユーザーが整理予定)**:
- カード表示要素の見直し (今: タイトル + summary + KeyFact 3 + Entity 3 + savedAt + 小 OG)
- 詳細画面のセクション構成 (今: 総まとめ + KeyFact 10 + Entity 5 + 元記事一覧)
- AI 生成サマリのプロンプト品質
- 期間フィルター UX (現在 全部/7日/30日 の 3 段階)
- stale マーク表示 (今: 「更新あり」caption text)
- マルチカード分割の AI 判断条件
- 包括サマリ生成方式 (現在 Digest summary 結合、将来 AI 再要約)

**着手タイミング**: spec 018 実機運用後にユーザーが要件整理 → spec 化。優先度は Sprint 2 (Chrome Shortcut / Safari Extension) より低い扱いだが、運用フィードバックで上がる可能性あり。

---

### D 長期 (将来)

| # | テーマ | 動機 |
|---|---|---|
| 036+ | Category カスタム化 (10 個固定 → ユーザー追加可) | CategorySeed.allSeeds の hardcoded 解消 |
| 037+ | グラフ可視化 (entity ネットワーク Force-directed) | spec 008 Assumptions で MVP 外、spec 011 KnowledgeMap を改良復活 |
| 038+ | macOS 対応 | Constitution IV で future、コードベース共通化 |
| 039+ | 多言語 UI (en_US 等) | Constitution VII で日本語 first、余地は残す |
| 040+ | クロスドメイン pagination 許可 UI | spec 007 Assumptions で MVP 外 |
| 041+ | マルチページ動的 rate-limit | spec 007 Assumptions で MVP 外 |
| 長期 | レコメンド「関連する記事 AI 提案」 | Constitution II で future |

### E 明示的に MVP 範囲外 (当面着手しない)

Constitution Principle II「MVP ファースト」で将来扱い:

- AI チャット (spec 022 で持ち上げ済)
- RAG (spec 022 で持ち上げ済)
- レコメンド機能
- クラウド同期 (Principle I「ローカルファースト」と整合する設計が必要)

---

## 🗺️ Sprint 図解

```
[今週]                    [次週]                    [2-3 週目]
Sprint 0 ─────────────►  Sprint 1 ─────────────►  Sprint 1 続
spec 014 マージ           spec 017 Dark Mode        spec 018 知識 Clip
spec 015 commit                                     spec 019 既知バグ
spec 016 commit
spec 016 検証

[1 ヶ月後]                [2 ヶ月後]                [3 ヶ月後+]
Sprint 2 ─────────────►  Sprint 3 ─────────────►  Sprint 4
spec 020 Chrome Shortcut   spec 022 AI Chat (RAG)    spec 023+ お任せ枠
spec 021 Safari Extension                            (削除 swipe / Tag 編集 /
                                                      fallback / etc.)
```

---

## 更新ルール

- spec を新規着手する時に「現在着手中」を記録 (spec.md path + 状態)
- spec 完了時に Past 表に commit hash 追記
- 優先順位変更があれば Sprint 配置を修正
- 新しい候補 spec が浮上したら適切な Sprint に追加 / D セクションへ追記
