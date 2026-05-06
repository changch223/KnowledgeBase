# Feature Specification: AI Chat (RAG) — 知積に質問して根拠付き回答

**Feature Branch**: `021-ai-chat-rag`
**Created**: 2026-05-06
**Status**: Draft (specify+plan only)

## なぜ (Why)

ユーザーが貯めた記事を knowledge base として「AI に質問して、元記事を引用した回答」を得たい。Constitution Principle II で「AI チャット / RAG」は将来扱いとされていたが、本 spec で MVP 入り。

ユースケース:
- 「最近のテクノロジーの記事で重要なポイントは?」→ AI が Top KeyFact + 引用記事を回答
- 「Swift 6 について保存した記事で何があった?」→ Swift 6 関連記事を retrieval + 要約回答
- 「先月読んだ経済記事の要点は?」→ 期間 + Category フィルター AI 統合回答

Constitution III「ソースに基づいた知識生成」の最強形 — AI 回答に必ず元記事 ID を引用 (footnote)、ハルシネーション抑止。

## ゴール

- 新タブ「AI チャット」(4 タブ目、`bubble.left.and.bubble.right.fill`)
- 質問入力 → 関連記事 retrieval (top-k cosine similarity) → Foundation Models で回答生成 + 引用
- 会話履歴の SwiftData 永続化 (`ChatSession` / `ChatMessage` @Model)
- ハルシネーション抑止: 「必ず引用」+ 「分かりません」フォールバック
- Apple Intelligence 不可端末でも fallback (簡易キーワード検索 + Top KeyFact 並べ)

## 非ゴール

- マルチターン高度文脈追跡 → 単純な RAG (1 質問 = 1 retrieval + 1 回答)
- 音声入力 → Siri 経由は副次効果
- ユーザー間共有 → 完全プライベート (constitution I)
- 外部 LLM API 呼び出し → on-device only (constitution I)
- 画像 / PDF への質問 → テキスト記事のみ
- 質問内容の学習 / 改善 → privacy 厳守

## ユーザストーリー (P1: US1-US3 / P2: US4-US5)

### US1 (P1) — 質問入力 + AI 回答 + 引用記事

ユーザーが質問を入力 → AI が関連記事 (top-k=5) を retrieve + Foundation Models で回答生成 + 引用記事を expandable footnote 表示。

### US2 (P1) — 会話履歴

セッションごとに `ChatSession` 永続化、`ChatMessage` (user / assistant) を時系列保存。タブ open 時に最新セッション復元。

### US3 (P1) — 引用記事タップで詳細

回答の引用記事 (footnote) タップ → ArticleDetailView 起動 (既存 spec 005)。元記事追跡可能 (Constitution III)。

### US4 (P2) — Apple Intelligence 不可時の fallback

embedding 生成不可 → 簡易キーワードマッチ retrieval + Top KeyFact 並べを「回答」として返す。AI 抽出 fallback (spec 015) と同パターン。

### US5 (P2) — 履歴削除 / セッション切替

設定からチャット履歴全削除 (privacy 配慮)。複数セッション切替 (画面左から swipe-in 風)。

## 機能要件 (抜粋、~30 FR)

### Embedding & Retrieval
- **FR-001**: 記事保存時 (`KnowledgeExtractionService` 完了 hook) で essence + KeyFact から embedding 生成 (Apple Intelligence の `NLEmbedding` or Foundation Models embedding API)
- **FR-002**: embedding を `Article.essenceEmbedding: [Float]?` 永続化 (新 attribute、lightweight migration)
- **FR-003**: 質問受信 → 質問 embedding 生成 → 全 article embedding と cosine similarity 計算 → top-k=5 取得
- **FR-004**: top-k 記事の essence + KeyFact を context に Foundation Models で回答生成

### Foundation Models 統合
- **FR-005**: `@Generable struct ChatAnswerOutput { answer: String, citedArticleIDs: [String] }`
- **FR-006**: prompt に「必ず引用記事 ID を返してください」「分からない時は『分かりません』と回答」を含める
- **FR-007**: 回答テキスト + citedArticleIDs を ChatMessage に保存

### Chat UI
- **FR-008**: 新タブ「AI チャット」(`bubble.left.and.bubble.right.fill`、4 タブ目)
- **FR-009**: 上部に過去 message リスト (LazyVStack)、下部に入力欄 + 送信ボタン
- **FR-010**: 各 message: user は右寄せ actionBlue 背景 / assistant は左寄せ tagFill 背景
- **FR-011**: assistant message に引用記事 footnote (タップで ArticleDetailView)

### Persistence
- **FR-012**: 新 @Model `ChatSession { id: UUID, createdAt: Date, lastMessageAt: Date, title: String }`
- **FR-013**: 新 @Model `ChatMessage { id: UUID, session: ChatSession, role: "user" | "assistant", text: String, citedArticleIDs: [String], timestamp: Date }`
- **FR-014**: SharedSchema.all に ChatSession / ChatMessage 追加
- **FR-015**: 50 セッション超過で古いを auto delete (FIFO)

### Apple Intelligence Fallback
- **FR-016**: `availability.isAvailable == false` で Fallback service 起動
- **FR-017**: Fallback: 質問のキーワード抽出 → Article.title / essence の文字列マッチ → top-k=3 → 「以下の記事が関連します」+ KeyFact 並べ

## 成功基準

- SC-001: AI チャットタブ open → 過去セッション最新が表示される
- SC-002: 質問入力 → 5 秒以内に回答 (Apple Intelligence 端末)、Fallback 端末は 2 秒以内
- SC-003: 回答に元記事引用 (1 つ以上) が含まれる
- SC-004: 引用タップ → ArticleDetailView 起動
- SC-005: 履歴永続化、アプリ再起動で復元
- SC-006: ハルシネーション抑止 — 知識なし質問で「分かりません」回答
- SC-007: 既存タブ完全保持 (回帰なし)

## 依存・前提

- spec 015 (Foundation Models / availability), spec 018 (KnowledgeDigest 経験), spec 019 (App Intent)
- Apple Intelligence の Embedding API (要研究)
- iOS 26+ / Apple Intelligence 対応端末推奨

## アサンプション

- embedding 次元数: 384 (典型的)
- cosine similarity 閾値: > 0.5 で関連と判定
- 50 セッション制限で privacy + ストレージのバランス
- マルチターンは「直前の 1 message のみ context に含める」(MVP 簡素化)
