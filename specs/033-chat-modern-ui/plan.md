# Plan: AI Chat モダン UI 刷新

**Spec**: [spec.md](./spec.md)
**Date**: 2026-05-08

## Technical Context

**Language/Version**: Swift 6 / SwiftUI 6
**Primary Dependencies**: SwiftUI (NavigationSplitView, ScrollView), SwiftData, Foundation Models (`LanguageModelSession.streamResponse`)
**Storage**: 既存 ChatSession / ChatMessage @Model 再利用 (新 attribute 不要)
**Testing**: Swift Testing + Mock LanguageModelSession (streaming も mock 化)
**Target Platform**: iOS 26+ / iPadOS 26+
**Performance Goals**:
- streaming 開始 ≤500ms (空 bubble 表示)
- 50 token/sec 以上 (Apple Intelligence 端末)
- multi-turn context が token 上限内に収まる (1500 token 上限)
**Constraints**:
- 既存 ChatService API は後方互換性維持 (send() の追加引数は default 値で)
- iPhone / iPad 両対応 (NavigationSplitView は両方で動く)
- streaming API が iOS で制約あれば擬似 streaming に fallback
**Scale/Scope**: 大 (~600 行、~20-25 タスク)

## Constitution Check

- [x] I (privacy): on-device only
- [x] II (MVP): 4 機能 (sidebar / multi-turn / streaming / inline link) に絞り込み
- [x] III (source): inline link で引用強化、本文 + DisclosureGroup の重複は意図的
- [x] IV (iOS 実現): NavigationSplitView 確立 API、streaming は要 R1 検証
- [x] V (calm UX): 削除確認 alert なし、streaming animation は穏やか
- [x] VI (architecture): ChatService protocol 維持、UI 拡張のみ
- [x] VII (日本語): 全 UI / prompt 日本語

**Quality Gates**: 全 PASS (R1 結果次第で streaming 方針が変わる)

## Architecture

```
[ChatTabView] (NavigationSplitView)
  ├── Sidebar (列 1)
  │   └── ChatHistorySidebar (新)
  │        ├── 「+ 新しいチャット」button
  │        └── List(allSessions, sort: lastMessageAt desc)
  │             └── ChatSessionRow (新) — title + preview + 時刻
  │                  └── .swipeActions { 削除 }
  └── Detail (列 2)
       ├── messageList (改修、streaming 対応)
       │   └── ChatMessageRow
       │        └── inline link AttributedString (改修)
       └── ChatInputField (既存維持)

[ChatService] (改修)
  ├── send(question:in:contextMessages:) — multi-turn 対応
  ├── deleteSession(_:) — 個別削除
  └── (将来) streamSend(...) — streaming wrapper

[LanguageModelSessionProtocol] (拡張)
  └── streamChatAnswer(prompt:) -> AsyncSequence<...>?  (R1 結果次第)

[Models] (変更なし、既存 ChatSession / ChatMessage 再利用)
```

## Implementation Outline

### Phase 1: 研究 (R1-R5、実装前に必須)

- **R1: Foundation Models streaming API** — `LanguageModelSession.streamResponse(generating:)` の存在 + AsyncSequence 形式 + @Generable との組合せを実機検証
- **R2: NavigationSplitView の iPhone 動作** — overlay 風になるか、push 風になるか実機確認
- **R3: SwiftUI Text + AttributedString での tap handler** — `URL` スキーム経由の tap、`onOpenURL` で受信
- **R4: 引用 inline link の prompt 表現** — LM が `[記事タイトル](article-id://UUID)` を確実に出力するか
- **R5: multi-turn context の token 数管理** — tokenizer (TextKit?) or 文字数簡易換算

### Phase 2: Foundation
- T001 [P] LanguageModelSessionProtocol に streamChatAnswer 追加 (or 擬似 streaming wrapper) — `Services/LanguageModelSessionProtocol.swift`
- T002 [P] ChatService.send に contextMessages 引数追加 (default 直前 4 message)
- T003 [P] ChatService.deleteSession(_:) 追加 + テスト
- T004 multi-turn prompt 構造改修 (`buildPromptWithContext`)

### Phase 3: Sidebar UI
- T005 [US1] ChatHistorySidebar 新規 — `Views/ChatHistorySidebar.swift`
- T006 [US1] ChatSessionRow 新規 — `Views/ChatSessionRow.swift`
- T007 [US4] session row に .swipeActions 削除 + accept alert なし
- T008 [US5] 「+ 新しいチャット」button

### Phase 4: NavigationSplitView 統合
- T009 [US1] ChatTabView を NavigationSplitView 構造に改修
  - iPad: sidebar 常時 + detail
  - iPhone: sidebar overlay + ハンバーガー
- T010 [US1] toolbar にハンバーガーアイコン (iPhone のみ)
- T011 [US1] ChatTabView の pinnedSessionID と sidebar 連動

### Phase 5: Streaming UI (R1 結果次第で 2 案)

**案 A: 真 streaming (Foundation Models stream API 利用可なら)**
- T012 [US3] LanguageModelSession.streamChatAnswer 実装
- T013 [US3] ChatService に streamSend(...) 追加
- T014 [US3] ChatMessageRow に streaming text binding
- T015 [US3] 完了後 citedArticleIDs を別 prompt or @Generable 抽出

**案 B: 擬似 streaming (R1 で stream API 不可と判明した場合)**
- T012' [US3] AI 回答完了後、token 単位で **逐次表示**するアニメーション (10ms ごとに 1 文字追加)
- T013' [US3] 体感は本物 streaming に近い、実装はシンプル

### Phase 6: Inline link
- T016 [US6] prompt 改修: assistant に `[タイトル](article-id://UUID)` 形式を要求
- T017 [US6] AttributedString で inline link 描画
- T018 [US6] `.onOpenURL` で `article-id://` を受信、Article fetch + NavigationLink

### Phase 7: テスト + Polish
- T019 ChatServiceTests に multi-turn context 検証 (3 ケース) + deleteSession 検証 (2 ケース)
- T020 (案 A の場合) StreamWrapperTests
- T021 build 警告ゼロ + 既存テスト全回帰
- T022 CLAUDE.md / ROADMAP 更新
- T023 実機検証 (ユーザー、SC-001〜SC-012)

## 主要研究項目 (R1〜R5、実装前に決着)

### R1: Foundation Models streaming API
**状況**: iOS 26 Apple Intelligence で `LanguageModelSession.streamResponse` が存在するか不明。
**調査方法**: Apple Developer ドキュメント + 実機 prototype。
**Decision (暫定)**:
- 利用可なら案 A
- 不可なら案 B (擬似 streaming) で MVP、真 streaming は将来 spec

### R2: NavigationSplitView の iPhone 挙動
**状況**: iPhone では sidebar が overlay 風 or push 風? 自動切替?
**Decision (暫定)**: SwiftUI 標準動作に従う、必要なら `.navigationSplitViewStyle(.balanced)` で調整

### R3: SwiftUI inline link tap handler
**Decision**: `Text(AttributedString)` で `link` 属性を設定、`environment(\.openURL)` でハンドリング、`onOpenURL` で URL scheme 受信。

### R4: prompt での inline link 表現
**Decision**: prompt で `[タイトル](article-id://UUID)` 形式を強く指示 + post-process regex で正規化。LM が破った場合の fallback として、citedArticleIDs と本文 regex 突合せで補完。

### R5: token 数管理
**Decision**: 簡易文字数換算 (1 token ≈ 0.5 字、日本語) で 1500 token = 3000 字を上限。超過時は古い順 truncate。tokenizer 厳密化は将来 spec。

## MVP 範囲外 (将来 spec)

- Markdown rich rendering (見出し / リスト / コードブロック)
- session 内検索
- session タイトルのユーザー編集
- session export / import / iCloud 同期
- 複数モデル切替
- 音声入力 / 出力
- 引用記事の hover preview (iPad の context menu 対応)
- token 使用量表示

## 依存関係

- **spec 021 hot-fix の `pinnedSessionID` パターン** がそのまま使える
- **spec 021 の ChatService protocol** 維持、後方互換 (default 引数で send 拡張)
- **streaming API の存在** に Phase 5 が依存 (R1 結果で実装方法分岐)

## 規模

大 (~600 行、~20-25 タスク)、spec 016 + 018 並。実装は次セッション以降、可能なら Phase 1 (研究) を先に済ませて Decision を固める。
