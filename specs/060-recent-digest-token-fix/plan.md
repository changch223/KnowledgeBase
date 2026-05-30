# Implementation Plan: RecentDigest token 超過修正 + SchemaLoader bundle 同梱

**Branch**: `060-recent-digest-token-fix` | **Date**: 2026-05-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/060-recent-digest-token-fix/spec.md`

## Summary

実機ログで顕在化した 2 件を解消。**P1-10**: `RecentDigestService.buildPrompt` が全 30 件を列挙し ~4089 token で 4096 超過 → prompt 用件数を 8 件に制限 + token 概算ガード + per-article 圧縮。**SchemaLoader**: `docs/iknow-schema.md` が bundle 外で毎回 code fallback → `KnowledgeTree/Resources/iknow-schema.md` にコピーして bundle 同梱 (SchemaLoader.load() 無改修)。新規 schema/service/@Model ゼロ、protocol 変更ゼロ。

## Technical Context

**Language/Version**: Swift 6 / SwiftUI (iOS 26 target)
**Primary Dependencies**: Foundation (Bundle API), FoundationModels (token 上限 4096)
**Storage**: SwiftData (本 spec では @Model 変更ゼロ)
**Testing**: Swift Testing (`@Test`/`#expect`)。buildPrompt は `static func` でテスト直呼び可能
**Target Platform**: iOS 26 (iPhone / iPad)
**Project Type**: mobile
**Performance Goals**: 既存維持。prompt 縮小で AI 生成成功率向上 (副次的に latency 改善)
**Constraints**: AI コンテキスト上限 ~4096 token。日本語 char≈token 近似。既存 fallback 経路を壊さない
**Scale/Scope**: 改修 1 + 新規 1 (Resources/.md) + テスト = ~150-250 行

## Constitution Check

- **I (privacy)**: prompt 縮小 + bundle 同梱のみ、on-device 維持、外部送信ゼロ ✅
- **II (MVP / 引き算)**: prompt 肥大の是正 = 引き算、token 効率化 ✅
- **III (source 追跡)**: ヘッドラインは保存記事ベースで生成、変わらず ✅
- **IV (iOS 実現可能性)**: Foundation Models token 上限への適合、Bundle API 標準 ✅
- **V (calm UX)**: 「最近の記事」が本来の AI 出力で表示され体感改善 ✅
- **VI (architecture)**: RecentDigestService 内部調整 + Resources 同梱、protocol/schema 変更ゼロ ✅
- **VII (日本語ファースト)**: prompt 文言・schema.md 日本語維持 ✅

**結論**: 全 7 原則 PASS。

## Project Structure

```
specs/060-recent-digest-token-fix/
├── spec.md / plan.md / research.md / data-model.md / quickstart.md
├── contracts/ (recent-digest-token.md / schema-bundle.md)
└── checklists/requirements.md

KnowledgeTree/
├── Services/RecentDigestService.swift   # P1-10 改修 (R1)
└── Resources/iknow-schema.md            # 新規 (R2, docs/ からコピー)
KnowledgeTreeTests/RecentDigestServiceTests.swift  # token ガード追加
docs/iknow-schema.md                     # 人間用に残置 (Resources/ が SSOT)
```

## Phase 0: Research (research.md)

- **R1 (P1-10)**: buildPrompt に `promptArticleLimit = 8` + token 概算ガード (累積 char 上限 3000) + per-article 圧縮 (essence 60→50, fact 30→20)。maxArticles=30 は差分判定/articleCount 用に維持。
- **R2 (SchemaLoader)**: `docs/iknow-schema.md` → `KnowledgeTree/Resources/iknow-schema.md` コピー。synchronized root group ゆえ自動同梱、.md は Copy Bundle Resources 分類 (ビルド検証)。SchemaLoader.load() 無改修。
- **R3 (テスト)**: RecentDigestServiceTests に buildPrompt 上限ガード 2 ケース追加。SchemaLoader は test bundle 制約で実 bundle 検証困難 → 既存 fallback テスト維持 + 実機ログで SC-003 確認。

## Phase 1: Design & Contracts

### data-model.md
@Model 変更ゼロ。詳細 [data-model.md](./data-model.md)。

### contracts/
- `recent-digest-token.md` (R1)
- `schema-bundle.md` (R2)

### quickstart.md
SC-001〜SC-005 の検証手順。

## Complexity Tracking

特記事項なし。全変更が既存パターンの範囲内、Constitution 違反ゼロ。

## 検証 (このセッション)

- `xcodebuild clean build` → SUCCEEDED + warning ゼロ + bundle に iknow-schema.md が入ることを `find` で確認
- `xcodebuild test -only-testing:KnowledgeTreeTests` serial → 全 regression PASS
- 実機 SC-002 (ヘッドライン表示) / SC-003 (bundle load ログ) はユーザー後追い
