# Implementation Plan: AI Chat (RAG)

**Branch**: `021-ai-chat-rag` (実装時に作成)
**Date**: 2026-05-06
**Spec**: [spec.md](./spec.md)

## Summary

新タブ「AI チャット」を 4 タブ目に追加。質問入力 → embedding ベース retrieval (top-k=5) → Foundation Models で回答生成 + 元記事引用。会話履歴 SwiftData 永続化。Apple Intelligence 不可時は Fallback (キーワードマッチ + KeyFact 並べ)。

技術アプローチ:
- **新 @Model 2 つ**: `ChatSession` / `ChatMessage`
- **新 service**: `ChatService` (protocol + Foundation + Fallback)、`EmbeddingService` (NLEmbedding)
- **新 view**: `ChatTabView` (root) / `ChatMessageRow` / `ChatInputField`
- **改修**: `Article.swift` (`essenceEmbedding: [Float]?` 追加)、`KnowledgeExtractionService.swift` (hook で embedding 生成)、`KnowledgeTreeApp.swift` (4 タブ目追加)、`SharedSchema.swift` / `Localizable.xcstrings`

## Technical Context

**Language/Version**: Swift 6
**Primary Dependencies**: SwiftUI, SwiftData, Foundation Models (`@Generable`), NaturalLanguage (NLEmbedding)
**Storage**: SwiftData (新 @Model 2 つ + Article.essenceEmbedding lightweight migration)
**Testing**: Swift Testing + in-memory ModelContainer + Mock LanguageModelSession + Mock NLEmbedding
**Target Platform**: iOS 26+ / iPadOS 26+ / Apple Intelligence 端末推奨
**Performance Goals**:
- 質問 → 回答 ≤5 秒 (Apple Intelligence 端末、top-k retrieval + Foundation Models 1 回)
- Fallback 質問 → 回答 ≤2 秒 (キーワードマッチのみ)
- 1000 記事規模で retrieval ≤500ms
**Constraints**:
- 外部 LLM API ゼロ (constitution I)
- ハルシネーション抑止プロンプト必須
- 既存 view 完全保持
**Scale/Scope**: ~15 ファイル、~1500 行、~25 タスク (特大スコープ、spec 016+018 並)

## Constitution Check

- [x] **I. プライバシーファースト**: NLEmbedding / Foundation Models on-device、外部送信ゼロ
- [x] **II. MVP**: 単純 RAG (1 質問 = 1 retrieval + 1 回答)、マルチターン文脈追跡 / 音声 / 画像は将来 spec
- [x] **III. ソース追跡**: ChatMessage.citedArticleIDs で必ず引用、UI に footnote 表示、ハルシネーション抑止プロンプト
- [x] **IV. iOS 実現可能性**: Apple Foundation Models + NLEmbedding 確立 API、Fallback で不可端末対応
- [x] **V. calm UX**: 通知ゼロ、履歴自動削除 (50 件超で FIFO)、ストレスなし
- [x] **VI. アーキテクチャ**: ChatService protocol で差し替え可能、UI / Service / Model 分離
- [x] **VII. 日本語ファースト**: 全 UI 日本語、prompt 日本語、回答も日本語固定

**Quality Gates**: 全 PASS

## Project Structure

```text
KnowledgeTree/
├── Models/
│   ├── ChatSession.swift              # 【新規】@Model
│   ├── ChatMessage.swift              # 【新規】@Model
│   └── Article.swift                  # 【改修】essenceEmbedding: [Float]? 追加
├── Services/
│   ├── ChatService.swift              # 【新規】protocol + Foundation + Fallback
│   ├── EmbeddingService.swift         # 【新規】NLEmbedding + cosine similarity
│   └── KnowledgeExtractionService.swift  # 【改修】embedding 生成 hook
├── Views/
│   ├── ChatTabView.swift              # 【新規】4 タブ目 root
│   ├── ChatMessageRow.swift           # 【新規】1 message
│   └── ChatInputField.swift           # 【新規】入力欄 + 送信ボタン
├── KnowledgeTreeApp.swift             # 【改修】4 タブ目追加
└── SharedSchema.swift                 # 【改修】2 model 追加
```

## 主要研究項目 (実装時に詳細化)

1. **Apple Intelligence Embedding API**: Foundation Models に embedding 関数あり? or NLEmbedding (NaturalLanguage) を使う?
2. **embedding 次元数**: NLEmbedding(language: .japanese) は 300 次元 (要確認)
3. **Article.essenceEmbedding 永続化**: `[Float]` を SwiftData `@Attribute(.externalStorage)` で別 file 保存 (1000 articles × 300 floats × 4 bytes ≈ 1.2 MB)
4. **cosine similarity 高速計算**: Accelerate framework (`vDSP_dotpr`) で 1000 articles 計算 ≤500ms
5. **prompt エンジニアリング**: 「必ず引用」「分からない時は『分かりません』」を厳守させる
6. **マルチターン**: 直前の 1 message のみ context に含める (MVP)、深いマルチターンは将来
7. **ハルシネーション検出**: 回答に citedArticleIDs が空 → 「分かりません」に置換

## Implementation Outline

### Phase 1: Setup
- T001: Localizable.xcstrings (~15 文言)
- T002: SharedSchema に ChatSession / ChatMessage 追加

### Phase 2: Foundational
- T003: ChatSession / ChatMessage @Model 新規
- T004: Article.essenceEmbedding 追加 (lightweight migration)
- T005: EmbeddingService 新規 (NLEmbedding + cosine similarity)

### Phase 3: US1 — 質問 → 回答
- T006: ChatService protocol + Foundation + Fallback
- T007: ChatService テスト (10 ケース): 質問 / retrieval / 引用 / Fallback / ハルシネーション抑止 / 期間フィルター / 履歴 / 削除 / 同時実行 / 大規模 1000 articles
- T008: KnowledgeExtractionService 改修 (hook で embedding 生成)

### Phase 4: US1 + US2 — Chat UI + 履歴永続化
- T009: ChatMessageRow 新規 (user / assistant 振り分け、引用 footnote)
- T010: ChatInputField 新規 (TextEditor + 送信 Button)
- T011: ChatTabView 新規 (LazyVStack + 入力欄 + .task で session 復元)

### Phase 5: US3 — 引用記事タップ
- T012: ChatMessageRow の引用 footnote → NavigationLink → ArticleDetailView (既存 spec 005)

### Phase 6: US4 — Fallback
- T013: FallbackChatService 実装 (キーワードマッチ + KeyFact 並べ)

### Phase 7: US5 — 履歴削除 + セッション切替 (P2)
- T014: SettingsView に「AI チャット履歴を削除」エントリ
- T015: ChatSession 切替 UI (将来 spec で詳細)

### Phase 8: KnowledgeTreeApp + Polish
- T016: 4 タブ目追加
- T017: build 警告ゼロ
- T018: 既存テスト全回帰
- T019: 実機検証

## MVP 範囲外 (将来 spec)

- マルチターン高度文脈追跡
- 音声入力 (Siri 統合)
- 画像 / PDF への質問
- 質問内容のオフライン学習
- 複数セッション同時表示
- セッション export / iCloud 同期
- 質問の auto-suggestion
- 引用記事の preview hover

## 規模

特大 (~1500 行、~25 タスク)、新 @Model 2 + 新 service 3 + 新 view 3 + 4 タブ目追加。spec 018 より大きめ。

## 状態

📝 specify+plan 完了。`/speckit-tasks` + `/speckit-implement` は spec 019 / 020 完了 + Apple Intelligence Embedding API 実機調査後に実施予定。
