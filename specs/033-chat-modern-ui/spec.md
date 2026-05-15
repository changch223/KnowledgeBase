# Feature Specification: AI Chat モダン UI 刷新

**Feature Branch**: `033-chat-modern-ui` (実装時に作成)
**Created**: 2026-05-08
**Status**: Draft (specify+plan のみ)
**Vision**: [VISION.md](../VISION.md) — 「必要な時だけ開けば最新の自分が見える、優しい第二の脳」の対話部分

## なぜ (Why)

spec 021 (AI Chat / RAG) の実機検証 (2026-05-06) で出たユーザー要望:

> 「Gemini / Claude / ChatGPT の UI を真似して良い。**左側が会話履歴一覧、ハンバーガーで隠れる形**にして、**context window で会話できる**ようにして、たとえば、**詳しく教えて**で追加質問する際に、**深掘り**できるようにしたい」

現状の AI チャットは:
- ✅ 質問 → 回答 (single-turn) は動作
- ❌ 過去の会話履歴を **左側にサイドバー表示** していない (タブ開く度に最新セッション 1 つだけ)
- ❌ **multi-turn 深掘り** ができない (毎回ゼロから retrieval)
- ❌ assistant 回答が **一括表示** (体感が遅い、最大 5 秒待つ)
- ❌ 引用記事は DisclosureGroup の下にまとめ (本文中での **inline link** ではない)

これらを Gemini / Claude / ChatGPT 風モダン UI で刷新する。

## ゴール

知積 AI チャットを **モダン Chat 体験** に:
- 左側に **会話履歴サイドバー** (iPhone: ハンバーガー overlay、iPad: NavigationSplitView)
- **multi-turn context** (直前 N message を AI に渡して深掘り対応)
- assistant 回答の **token streaming 表示** (体感の高速化)
- 引用記事の **inline リンク化** (本文中で chip のように埋め込み、tap で詳細)
- session 個別削除 / 切替 / 新規作成

## 非ゴール

- 複数 session 同時表示 → 1 session のみアクティブ
- session のエクスポート / 共有 → 完全プライベート (Constitution I)
- 音声入力 / 出力 (Siri 経由) → 別 spec
- Markdown rendering (見出し / リスト / コードブロック) → MVP は inline link のみ、リッチ化は将来 spec
- session 内検索 → 将来 spec
- session タイトルのユーザー編集 → 自動命名のみ (最初の user message 30 字)
- 複数モデル切替 → Apple Intelligence + Fallback の 2 経路のみ
- 「考え中...」アニメーションの高度化 → 既存 ProgressView 維持

## ユーザストーリー

### US1 (P1) — 履歴サイドバーで session 切替

1. AI チャットタブ右上 (or 左上) のハンバーガーアイコン tap
2. 左から履歴サイドバー slide-in (iPhone) or 常時表示 (iPad)
3. session 一覧 (lastMessageAt 降順): 各 row に title (最初の user message の先頭 30 字) + 最終 message プレビュー + 時刻
4. row tap で当該 session を表示

### US2 (P1) — 「詳しく教えて」で multi-turn 深掘り

1. 質問送信 → assistant 回答 (1 回目)
2. ユーザーが「**詳しく教えて**」「**先ほどの記事について**」と追加質問
3. AI が **直前の数 message** (user + assistant) を context に取り込み、より深い回答を生成
4. 引用記事は前回と同じ retrieval だけでなく、必要なら新規 retrieval (簡易判定)

### US3 (P1) — assistant 回答 token streaming

1. 質問送信
2. assistant message が **空の状態で表示**、AI が token ごとに streaming 描画
3. ユーザーは生成中の途中経過を見られる (Claude / ChatGPT 風)
4. 完了後に最終的な引用 chip / inline link が表示

### US4 (P2) — session 個別削除

1. 履歴サイドバーで session row を **左 swipe** (or 長押し)
2. 「削除」赤ボタン
3. 当該 session + message が削除 (cascade)
4. アクティブな session が削除されたら最新 session に切替 or 新規 create

### US5 (P2) — 新規 session 作成

1. 履歴サイドバー上部に「**+ 新しいチャット**」ボタン
2. tap で空 session 作成、入力欄 focus

### US6 (P2) — 引用記事の inline link

1. assistant 回答内で引用 → `[記事タイトル]` のような inline 表示
2. tap で ArticleDetailView へ NavigationLink
3. DisclosureGroup の下部リストは補助的に残す (重複だが、見つけやすさ向上)

## 機能要件

### Sidebar UI

- **FR-001**: iPad は NavigationSplitView (sidebar 常時 + main detail)
- **FR-002**: iPhone は sheet/sidebar overlay (ハンバーガーで toggle、画面の 80% 幅)
- **FR-003**: サイドバー内: 「+ 新しいチャット」button + session list (lastMessageAt 降順)
- **FR-004**: session row: title + 最終 user message プレビュー (1 行) + 相対時刻 (3 時間前 / 昨日 / 2 日前 等)
- **FR-005**: session row 左 swipe → 「削除」 (List + .swipeActions)
- **FR-006**: session row tap → currentSession 切替 (pinnedSessionID 更新)
- **FR-007**: アクティブ session row はハイライト

### Multi-turn Context

- **FR-008**: ChatService.send に `contextMessages: [ChatMessage]` 引数追加 (default は直前 4 message = 2 ペア)
- **FR-009**: prompt 構造改修: `## 直近の会話` セクションを参考記事の前に挿入
- **FR-010**: prompt 例:
  ```
  ## 直近の会話
  user: Swift 6 とは?
  assistant: Swift 6 は...
  user: 詳しく教えて  ← 今の質問

  ## 参考記事
  ...
  ```
- **FR-011**: context 上限 token 管理 (最大 1500 token、超過は古い順で truncate)
- **FR-012**: 「詳しく教えて」「先ほどの〇〇」のような曖昧質問は retrieval 件数を減らす (top-k=3) + context を厚く

### Streaming UI

- **FR-013**: LanguageModelSession.streamResponse API 使用 (Foundation Models iOS 26+ 確立、要 R 調査)
- **FR-014**: ChatMessageRow が AsyncSequence の partial 文字列を受信して逐次描画
- **FR-015**: streaming 中はカーソル / blink animation で生成中を示す
- **FR-016**: streaming 完了後に citedArticleIDs を取得 (現状の @Generable 構造体は最終結果のみなので、別途 streaming 後 1 回 prompt 実行 or @Generable streaming 機能調査)

**MVP fallback**: streaming API が制約多い場合は、**3 段階表示** (考え中 → 部分表示 → 完成) で擬似 streaming も可。

### Session 個別削除

- **FR-017**: ChatService.deleteSession(_ session: ChatSession) throws を追加
- **FR-018**: cascade で message も削除
- **FR-019**: アクティブ session 削除時は allSessions.first (最新) に切替、空なら新規 create

### 新規 session

- **FR-020**: ChatService.createSession() を「+ 新しいチャット」button から呼ぶ
- **FR-021**: 新 session の pinnedSessionID 設定で即切替

### Inline 引用 link

- **FR-022**: assistant 回答に `[記事タイトル](article-id://UUID)` 形式の inline link を埋め込む prompt
- **FR-023**: 表示時に SwiftUI Text + AttributedString で link 化
- **FR-024**: tap で `article-id://UUID` URL scheme → Article fetch → NavigationLink push
- **FR-025**: 既存 DisclosureGroup の引用記事一覧は **補助的に残す** (重複だが、見つけやすさ + accessibility)

## 成功基準

### US1 履歴サイドバー
- SC-001: AI チャットタブで左上ハンバーガー tap → サイドバー slide-in
- SC-002: 過去 session が時系列で表示
- SC-003: row tap で session 切替
- SC-004: iPad は常時 split view 表示

### US2 multi-turn
- SC-005: 「詳しく教えて」で前回 user-assistant ペアを context に取り込み、回答が深まる
- SC-006: 直前 4 message が prompt に含まれる (verification: prompt log)

### US3 streaming
- SC-007: 質問送信後、空 assistant bubble が即時表示
- SC-008: token ごとに本文が伸びる (Apple Intelligence 端末)
- SC-009: 完了後 citedArticleIDs が DisclosureGroup に表示

### US4-6
- SC-010: session 個別削除動作
- SC-011: 「+ 新しいチャット」で空 session 即時切替
- SC-012: 本文中の `[記事タイトル]` inline link tap で詳細遷移

## アサンプション

- iOS 26+ Foundation Models で streaming API が利用可 (要研究 R1)
- iPad での NavigationSplitView は SwiftUI 標準
- multi-turn context は最大 1500 token (4096 token 上限 ÷ 2 弱、参考記事と prompt 命令分を確保)
- inline link の URL scheme `article-id://` 形式

## 依存・前提

- spec 021 の ChatService / ChatSession / ChatMessage @Model 既存
- spec 021 の Foundation Models + Fallback 経路
- spec 021 hot-fix (currentSession を @Query から動的算出) の挙動

## 想定実装規模

### 新規ファイル
- `Views/ChatHistorySidebar.swift` (~120 行) — サイドバー UI
- `Views/ChatSessionRow.swift` (~60 行) — session row
- `Views/Article+InlineLinkURL.swift` (~30 行) — URL scheme helper
- 任意: `Services/ChatStreamingService.swift` (~80 行) — streaming wrapper、研究結果次第

### 改修ファイル
- `Views/ChatTabView.swift` (~150 行改修) — NavigationSplitView 構造、サイドバー toggle、新規 button
- `Views/ChatMessageRow.swift` (~80 行改修) — streaming 表示、inline link tap handler
- `Services/ChatService.swift` (~120 行改修) — send に contextMessages 引数、prompt 構造、deleteSession 追加
- `Services/LanguageModelSessionProtocol.swift` (~30 行) — streaming API 拡張 (or wrapper)
- `Localizable.xcstrings` (~10 文言追加)

### テスト
- `ChatServiceTests.swift` (5-8 ケース追加)
  - multi-turn context が prompt に含まれる
  - deleteSession で cascade
  - inline link 形式の prompt 出力検証
  - streaming wrapper (mock 経由)

### 合計
~600 行、~20-25 タスク (大スコープ、spec 016 + 018 並)

## Constitution

- I (privacy): on-device、外部送信ゼロ
- II (MVP): multi-turn / streaming / sidebar / 個別削除のみ、Markdown rich text / 検索 / export は将来
- III (source 追跡): inline link で本文中での引用追跡を強化
- IV (実現可能性): NavigationSplitView (iOS 16+) + Foundation Models streaming (要 R1)
- V (calm UX): streaming は穏やかなアニメ、deletion は確認 alert なし (Constitution V)
- VI (architecture): ChatService に protocol 拡張、UI と service 分離維持
- VII (日本語): 全 UI 日本語、prompt 日本語

## 状態

📝 specify 完了 (2026-05-08)。`/speckit-plan` は本ファイルと同時、`/speckit-tasks` + `/speckit-implement` は実機での動作確認 + ユーザー判断後に実施。
