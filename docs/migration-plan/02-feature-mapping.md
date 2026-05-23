# 02 — Feature Mapping (現 spec ↔ dream feature)

## Status: Skeleton (Phase 1 で詳細化予定)

## このファイルの目的

現知積の 44 spec を、dream spec (`docs/dream-product/04-features.md` の ~40 機能) と 1:1 マッピング。
**どの現 spec がどの dream feature に貢献しているか、どこを拡張するか** を見える化。

---

## マッピング表 (Phase 1 で詳細化)

| 現 spec | dream feature | 関係 |
|---|---|---|
| spec 001 (記事保存) | A1 (Share Sheet 投入) | ✅ 完全カバー |
| spec 002 (enrichment) | A1 | ✅ 完全カバー |
| spec 003 (本文抽出) | B1 (本文抽出) | ✅ 完全カバー |
| spec 004 (要約) | B3-B5 (essence / summary / KeyFact / entity) | ✅ 完全カバー |
| spec 005 (Detail UI) | D2 (秘書 chat) | ✅ 部分 |
| spec 006 (chunked) | B1 / 長文対応 | ✅ 内部 |
| spec 007 (multipage) | A1 拡張 | ✅ |
| spec 008 (search/tag/graph) | F1 (検索) + C1 (タグ) + C2 (graph) | ✅ |
| spec 009 (BG extraction) | B7 (BGTask 基盤) | ✅ |
| spec 010 (hierarchical) | B1 拡張 | ✅ |
| spec 011 (AI ブレインタブ) | ❌ 廃止 → 知識 Clip 統合 | ❌ |
| spec 012-013 (Auto-Tag) | B6 (Auto-Tag) | ✅ |
| spec 014 (DesignSystem) | F1 (UI 基盤) | ✅ |
| spec 015 (Category 階層) | B6 (Auto-Category) + C8 | ✅ |
| spec 016 (Category 詳細) | D3 (カテゴリー詳細) | ✅ |
| spec 017 (Dark Mode) | F1 | ✅ |
| spec 018 (知識 Clip + Digest) | C9 (Digest) + D2 | ✅ |
| spec 020 (Safari Web Extension) | A2 (Safari) | ✅ |
| spec 021 (AI Chat RAG) | D2 (秘書 chat) | ✅ |
| spec 022 (削除手段) | F2 (削除 UX) | ✅ |
| spec 024 (Tag 編集) | F3 (Tag 管理) | ✅ |
| spec 030 (LazyVStack 削除) | F2 | ✅ |
| spec 033 (Chat モダン UI) | D2 改修済 | ✅ |
| spec 034 (PDF) | A1 (PDF 入力) | ✅ |
| spec 035 (RecentDigest) | C9 + D1 | ✅ |
| spec 036 (DynamicTopics) | C5 (Community 前身) | 🔀 統合 |
| spec 037 (Conflict) | F2 (WikiLint 前身) | 🔧 拡張 |
| spec 038 (用語整理 P1) | F1 (xcstrings) | ✅ |
| spec 040 (Knowledge Graph A) | C2 (graph) | ✅ |
| spec 041 (Knowledge Graph B UI) | D5 (graph UI) | ✅ |
| spec 042 (英語翻訳) | B2 (翻訳) | ✅ |
| spec 044 (検索 ranking) | F1 (検索) | ✅ |
| **【新】 spec 045** | **C4 (ConceptPage) ★** | ➕ 新規 |
| **【新】 spec 046** | **C8 (SavedAnswer)** | ➕ 新規 |
| **【新】 spec 047** | **F4 (WikiLint 拡張)** | ➕ 新規 |
| **【新】 spec 048** | **C5 (Community 検出)** | ➕ 新規 |
| **【新】 spec 049** | **E1-E11 (Understanding Chat)** | ➕ **新規 ★最大** |
| **【新】 spec 050** | **A3-A4 (写真 / AI 会話入力)** | ➕ 新規 |
| **【新】 spec 051** | **D8 (Widget)** | ➕ 新規 |
| **【新】 spec 052** | **F5 (Export)** | ➕ 新規 |
| **【新】 spec 053** | (タブ再編 + 廃止) | ➕ 新規 |
| **【新】 spec 054** | (リブランディング) | ➕ 新規 |

---

## 次のステップ

Phase 1 で各行を詳細化:
- どの fields / methods が継承されるか
- 改修が必要な箇所
- 新規実装の規模見込み
