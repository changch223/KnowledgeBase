# Plan: 「最近のあなた」差分ダイジェスト

**Spec**: [spec.md](./spec.md)

## Technical Context

- Swift 6 / SwiftUI / SwiftData / Foundation Models / NaturalLanguage
- iOS 26+
- 既存 spec 018 (KnowledgeDigest) 同パターンで実装
- 規模: 中 (~340 行、~6-8 タスク)

## Constitution Check

全 7 原則 PASS (詳細 spec.md)。

## Architecture

```
[KnowledgeTreeApp]
  └── TabView (selection = .knowledgeClip default)
       └── KnowledgeClipView
            ├── 【新】RecentDigestSection (上部)
            │    └── RecentDigestService.fetchOrGenerate()
            │         ├── Foundation 経路: LanguageModelSession
            │         └── Fallback 経路: 各記事 essence 並べ
            ├── (既存) Category Digest List
            └── (既存) その他

[Services]
  ├── RecentDigestService (新)
  ├── LastOpenedStore (新、UserDefaults)
  └── (既存) KnowledgeDigestService

[Models]
  └── (既存 Article 再利用、Article.savedAt > lastOpenedAt で filter)

[ServiceContainer]
  └── recentDigestService (新)
```

## Implementation Outline

### Phase 1: Foundation
- T001 [P] LastOpenedStore.swift 新規 (UserDefaults wrapper、key: "knowledgeClip.lastOpenedAt")
- T002 [P] RecentDigestOutput @Generable struct → LanguageModelSessionProtocol.swift に追加
- T003 LanguageModelSessionProtocol.generateRecentDigest 追加 + Mock 拡張

### Phase 2: Service
- T004 RecentDigestService protocol + 実装 (Foundation + Fallback 分岐)
- T005 RecentDigestServiceTests 5 ケース

### Phase 3: UI
- T006 RecentDigestSection.swift 新規 (UI section、3 段落表示 + meta + DisclosureGroup)
- T007 KnowledgeClipView 改修 (最上部に section 挿入、@Query で fetch)

### Phase 4: Tab Selection
- T008 KnowledgeTreeApp で TabView selection binding 追加 (起動時 .knowledgeClip)
- T009 ServiceContainer に recentDigestService 追加 + bootstrap で構築

### Phase 5: Polish
- T010 build 警告ゼロ + 既存テスト全回帰
- T011 CLAUDE.md / ROADMAP 更新
- T012 実機検証 (ユーザー)

## 主要研究項目

1. **3 段落 prompt 安定化**: 「3 段落」を厳密に守らせる prompt 設計 (spec 018 DigestOutput 経験を活用)
2. **キャッシュ vs lastOpenedAt 競合**: タブを開く瞬間に lastOpenedAt が更新されると差分が空になる問題 → **lastOpenedAt の更新は 段落表示完了後** に遅延
3. **TabView selection binding が initial selection を反映するタイミング**: SwiftUI の挙動を実機検証
4. **Cold vs Warm start の判定**: Cold start でのみ default selection 強制、Warm start (背景から復帰) はユーザー選択維持

## MVP 範囲外

- 期間カスタム (e.g., 「過去 7 日」「過去 30 日」切替) — 「前回開いた時から今まで」一択
- 段落数カスタム (e.g., 1 / 3 / 5 段落切替) — 3 段落固定
- 段落から元記事への inline link — 段落単位の引用は実装せず、段落の下に「N 件の記事から」表示のみ
- 共有機能 (3 段落要約をシェア) — 将来 spec
