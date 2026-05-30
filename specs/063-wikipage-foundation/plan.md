# Implementation Plan: WikiPage 土台 — 概念ページに Markdown 本文を持たせる

**Branch**: `vision-llm-wiki` | **Date**: 2026-05-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/063-wikipage-foundation/spec.md`

## Summary

LLM Wiki 再設計の第 1 段階前半。ConceptPage を rename せず 4 フィールド追加 (bodyMarkdown / kindRaw / isHidden / bodyEditedByUser、全て default 付き = CloudKit lightweight migration 安全) で「Markdown 本文を持つ Wiki ページ」に進化させる。本文は **plain string 生成** (`session.respond(to:)`、@Generable 不使用) で token 超過 (schema serialization ~1500 token) を最初から回避。Markdown は iOS 標準 `AttributedString(markdown:)` で表示。AI 管理が基本だがユーザーが本文訂正/非表示/種別変更できる (訂正は再生成で無断上書きしない)。新 @Model ゼロ・rename ゼロ・SharedSchema 無改修。

## Technical Context

**Language/Version**: Swift 6 / SwiftUI (iOS 26)
**Primary Dependencies**: SwiftData, Foundation (AttributedString markdown), FoundationModels (plain string respond)
**Storage**: SwiftData + CloudKit。ConceptPage に default 付きフィールド追加のみ (lightweight migration 安全)
**Testing**: Swift Testing。generateWikiBody は plain string でテスト容易
**Target Platform**: iOS 26 (iPhone / iPad)
**Project Type**: mobile
**Performance Goals**: bodyMarkdown 生成は記事保存の Ingest に 1 回追加 (VISION「AI 2-3 回」内)。plain string で token 安定
**Constraints**: CloudKit Production deploy 済 (rename/削除禁止、追加は default 必須)。token 4096 上限を plain string + 入力圧縮で回避
**Scale/Scope**: 改修 7 + 新規 1 + xcstrings + schema.md = ~350-500 行

## Constitution Check

- **I (privacy)**: on-device、Wiki は端末内 SwiftData、外部送信ゼロ ✅
- **II (MVP / 引き算)**: 7 分裂を WikiPage 1 つに畳む第一歩、新 @Model 作らず既存進化 ✅
- **III (source 追跡)**: bodyMarkdown は relatedArticles (不変 Raw source) から生成、辿れる ✅
- **IV (iOS 実現可能性)**: AttributedString(markdown:) + plain string respond、標準 API ✅
- **V (calm UX)**: AI 管理が基本、ユーザー訂正は任意。token 安定で「整理中…」滞留解消 ✅
- **VI (architecture)**: ConceptPage 進化 (rename なし)、Protocol+DI、CloudKit 安全 ✅
- **VII (日本語ファースト)**: bodyMarkdown 日本語生成、UI 文言日本語 ✅

**結論**: 全 7 原則 PASS。

## Project Structure

```
specs/063-wikipage-foundation/
├── spec.md / plan.md / research.md / data-model.md / quickstart.md
├── contracts/ (conceptpage-fields / generate-wikibody / wikibody-hook / markdown-display)
└── checklists/requirements.md

KnowledgeTree/
├── Models/ConceptPage.swift              # 4 フィールド + WikiPageKind enum
├── Services/LanguageModelSessionProtocol.swift  # generateWikiBody plain string + Mock
├── Services/ConceptSynthesisService.swift       # bodyMarkdown 生成 hook + kind 判定
├── Views/ConceptPageDetailView.swift            # Markdown 表示 + kind バッジ + 非表示
├── Views/ConceptPageEditSheet.swift             # bodyMarkdown/kind 編集
├── Views/FollowingPeopleSection.swift (+ KnowledgeClipView ConceptPageListView)  # isHidden フィルタ
├── Localization/Localizable.xcstrings           # Wiki 文言
└── Resources/iknow-schema.md                    # Wiki 本文生成ルール追記
KnowledgeTreeTests/WikiBodyGenerationTests.swift  # 新規
```

## Phase 0: Research (research.md)

- **R1**: ConceptPage に 4 フィールド追加 (bodyMarkdown / kindRaw / isHidden / bodyEditedByUser、default 付き)。SharedSchema 無改修。
- **R2**: `WikiPageKind: String` enum (person/concept/project) + 表示名 + SF Symbol + localizationKey。
- **R3**: `generateWikiBody(prompt:) -> String` plain string (`session.respond(to:)`、generateTutorReply と同型、@Generable 不使用で token ~1500 節約)。Mock 追従。
- **R4**: resynthesize で bodyMarkdown 生成 hook (bodyEditedByUser 保護 / 空出力保持 / fallback summary)。kind は KnowledgeEntity.type 集計判定。
- **R5**: ConceptPageDetailView で `Text(AttributedString(markdown:))` 表示 + kind バッジ + isHidden トグル。
- **R6**: ConceptPageEditSheet に bodyMarkdown TextEditor + kind Picker、保存で bodyEditedByUser=true。
- **R7**: ConceptPageListView / FollowingPeopleSection の @Query に isHidden==false。
- **R8**: iknow-schema.md に Wiki 本文生成ルール追記 (SchemaLoader 経由)。
- **R9**: WikiBodyGenerationTests 5 ケース + 既存 regression。

詳細は [research.md](./research.md)。

## Phase 1: Design & Contracts

### data-model.md
ConceptPage に 4 フィールド追加 (CloudKit safe)。新 @Model ゼロ。詳細 [data-model.md](./data-model.md)。

### contracts/
- `conceptpage-fields.md` (R1/R2)
- `generate-wikibody.md` (R3)
- `wikibody-hook.md` (R4)
- `markdown-display.md` (R5/R6/R7)

### quickstart.md
SC-001〜SC-007 の検証手順。

## Complexity Tracking

特記なし。ConceptPage 進化は VISION + Plan 診断で確定の最小コア。token は plain string で構造的に回避 (過去 spec の数値チューニング地獄を脱する)。

## 検証 (このセッション)

- `xcodebuild clean build` → SUCCEEDED + warning ゼロ
- `xcodebuild test -only-testing:KnowledgeTreeTests` serial → 全 regression + WikiBodyGenerationTests PASS
- 実機 (bodyMarkdown 表示 / token ログ / 既存データ) はユーザー後追い
