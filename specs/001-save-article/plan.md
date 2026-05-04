# Implementation Plan: 記事保存 (Share Sheet 経由)

**Branch**: `001-save-article` | **Date**: 2026-05-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-save-article/spec.md`

## Summary

ユーザーが iOS Share Sheet を介して任意のアプリ (Chrome / Safari 等) から URL を共有すると、KnowledgeTree 本体と独立した Share Extension がそれを受け取り、URL / タイトル / 保存日時を SwiftData に永続化する。アプリ本体は保存済み記事を新しい順に表示し、行タップで内蔵ブラウザビュー (`SFSafariViewController`) で元 URL を開け、左スワイプで即削除できる。同 URL の再共有は重複検出により拒否する。

技術的アプローチ: 既存の SwiftUI + SwiftData scaffold を拡張し、新規 Share Extension target を追加。Share Extension とアプリ本体は **App Group 共有** の SwiftData ModelContainer を介して同一ストアにアクセスする。アーキテクチャは Constitution Principle VI に従い、`ArticleStoreProtocol` / `ArticleSavingServiceProtocol` でデータ層・ビジネスロジック層を分離し、両 target から共有可能な状態にする。

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 17+ / iOS 26 SDK)
**Primary Dependencies**: SwiftUI、SwiftData、SafariServices (`SFSafariViewController`)、Foundation。サードパーティ依存なし (Constitution Additional Constraints)。
**Storage**: SwiftData。Share Extension とアプリ本体で **App Group 共有 ModelContainer** を使用。App Group ID は `group.<reverse-domain>.knowledgetree.shared` 形式 (実値は Bundle ID 確定後に xcconfig / entitlements に記入)。
**Testing**: XCTest (既存 `KnowledgeTreeTests` / `KnowledgeTreeUITests`)。SwiftData ユニットテストは `isStoredInMemoryOnly: true` の `ModelConfiguration` で実行 (Quality Gate / テスト)。
**Target Platform**: iOS 26+ / iPadOS 26+ (Constitution Principle IV)。本 spec は Apple Foundation Models を使わないため Apple Intelligence の有無に依らず動作するが、プロジェクト全体の対象端末制約 (Apple Intelligence 対応) に従う。
**Project Type**: モバイルアプリ (iOS + iPadOS)。Share Extension Target を追加 (合計 4 target: app / share extension / unit tests / UI tests)。
**Performance Goals**:
- ユーザー入力フィードバック ≤ 100 ms (パフォーマンスゲート)
- コールド起動 ≤ 2 s (200 ms 以上の悪化は要調査)
- 100 件超の `List` で 60 fps スクロール (Instruments で実測)
- `SFSafariViewController` 起動 ≤ 300 ms (SC-004)
- 重複検出メッセージ表示 ≤ 1 s (SC-009)

**Constraints**:
- ネットワークアクセスゼロ (Principle I + spec FR-010 + SC-005)
- 全 UI 文言は日本語、`Localizable.xcstrings` 経由 (Principle VII + FR-011)
- アクセシビリティ識別子全付与、Dynamic Type / Dark Mode / VoiceOver 対応 (Quality Gate)
- `fatalError` / `try!` / 強制アンラップは `App` レベルの `ModelContainer` 構築のみ
- macOS 対象外 (Principle IV)

**Scale/Scope**: 単一ユーザー / 単一端末 / iCloud 同期なし。MVP 想定保存件数 100〜数千件。

## Constitution Check

*GATE: Phase 0 research 前に通過必須。Phase 1 design 後に再評価。*

Reference: `.specify/memory/constitution.md` (v1.0.0)。すべて check するか、未 check 項目は **Complexity Tracking** で justification 必須。

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — 保存先は端末内 SwiftData (App Group container)。外部送信ゼロ (FR-010 / SC-005)。`SFSafariViewController` 経由の通信はユーザー意図の OS ブラウザ動作であり本アプリの送信ではない。
- [x] **II. MVP ファースト開発** — スコープは「Share Sheet 受け取り → 保存 → 一覧 → 内蔵ブラウザビュー閲覧 → 削除 → 重複拒否」のみ。本文抽出 / 要約 / 分類 / Safari Web Extension / Shortcut / iCloud 同期 / 検索 / タグ等は spec の Out of Scope に明示。
- [x] **III. ソースに基づいた知識生成** — `Article` エンティティが `url` を非 optional 必須属性として保持。本 spec では AI 生成物は無いが、将来 enrichment / 要約 / 分類 spec の派生データはすべて `Article` への non-optional 参照を持つ前提でデータモデルを設計 (data-model.md / Relationships 節)。
- [x] **IV. iOS の実現可能性を重視する** — 取り込み手段は Share Sheet (MVP 必須) のみを実装。Shortcuts / Safari Web Extension は Out of Scope。本 spec は Foundation Models を使わないため `SystemLanguageModel.availability` チェックは不要。プラットフォームは iOS 26+ / iPadOS 26+。macOS 対象外。
- [x] **V. シンプルで落ち着いた UX** — 0 件状態は不安喚起しない日本語メッセージ (FR-013)。スワイプ即削除でユーザーが control を持つ (US3)。未読数バッジなし。Share Extension は auto-save → 自動 dismiss の最小フロー。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — 4 層分離: Models (`Article`) / Services (`ArticleStoreProtocol` + `ArticleSavingServiceProtocol`) / Views (`ArticleListView` / `EmptyStateView` / `SafariView`) / Share Extension entry。データ層と保存ロジック層をプロトコル境界で隔離し、将来 SwiftData 以外の永続化や mock テストへの差し替えを可能にする。単一巨大 View なし。
- [x] **VII. 日本語ファースト** — 全 UI 文言・エラーメッセージ・空状態・スワイプアクションラベル・Share Extension のフィードバックを `Localizable.xcstrings` から日本語キーで取得 (FR-011 / SC-008)。spec / plan / research / contracts / quickstart はすべて日本語で記述。

### Quality Gates (二次ゲート)

- [x] **コード品質** — 新規型 (`Article`、`SwiftDataArticleStore`、`DefaultArticleSavingService`、`ShareViewController`、`SafariView`、`ArticleListView`、`EmptyStateView`) はすべて単一責務で分割。`fatalError` は `KnowledgeTreeApp` の `ModelContainer` 初期化のみで継続使用 (Principle 例外、許容範囲)。`try!` / 強制アンラップなし。新規 protocol (`ArticleStoreProtocol` / `ArticleSavingServiceProtocol`) は Share Extension とアプリ本体の 2 箇所で利用。
- [x] **テスト** — `KnowledgeTreeTests/` に `ArticleSavingServiceTests` (`MockArticleStore` で重複検出ロジック) と `SwiftDataArticleStoreTests` (`isStoredInMemoryOnly: true` の `ModelContainer`)。`KnowledgeTreeUITests/` に `SaveArticleUITests` (US1〜US3 の主要フローを `accessibilityIdentifier` ベースで検証)。Share Extension の UITest は OS 制約があるためロジックを Service 層に切り出して unit test し、Share UI の動作は quickstart の手動検証で担保 (research.md / R6 参照)。
- [x] **アクセシビリティ・UX 一貫性** — `accessibilityIdentifier` を以下に付与: `articleListRow`、`articleListEmpty`、`articleDeleteAction`、`articleSafariViewDoneButton`、`shareExtensionStatusLabel`。Dynamic Type 対応 (固定フォントサイズなし)。Dark Mode は SwiftUI default 配色で自動対応。VoiceOver 用 `accessibilityLabel` を一覧行 (タイトル + URL の組み合わせ) に付与。
- [x] **パフォーマンス** — `@Query<Article>(sort: \.savedAt, order: .reverse)` を使用。100 件超の検証は Instruments + 1000 件のシード状態で実施し PR に添付。`SFSafariViewController` 起動は同期的 (≤ 300 ms 容易達成)。重複検出は単一 `FetchDescriptor` 1 query (`fetchLimit: 1` + url predicate) で 1 s 以内に完了。escaping closure はすべて `[weak self]` または値型 capture。

**結論**: すべて check 通過。Complexity Tracking 不要。

## Project Structure

### Documentation (this feature)

```text
specs/001-save-article/
├── plan.md                              # This file
├── research.md                          # Phase 0 出力
├── data-model.md                        # Phase 1 出力
├── quickstart.md                        # Phase 1 出力
├── spec.md                              # /speckit-specify 出力
├── checklists/
│   └── requirements.md                  # /speckit-specify 出力
├── contracts/                           # Phase 1 出力 (内部プロトコル境界)
│   ├── article-store.md
│   ├── article-saving-service.md
│   └── share-received-item.md
└── tasks.md                             # Phase 2 出力 (/speckit-tasks で生成、本コマンドでは未作成)
```

### Source Code (repository root)

既存の Xcode scaffold を拡張する。新規 Share Extension Target を追加し、共有コードを両 Target にメンバーシップ追加する (物理的な `Shared/` ディレクトリは作らず Xcode の File Inspector でメンバーシップを管理)。

```text
KnowledgeTree.xcodeproj/                 # 既存 (要変更: Share Extension Target 追加、App Group capability)
KnowledgeTree/                           # 既存 app target
├── KnowledgeTreeApp.swift               # 既存。要変更: ModelContainer を App Group container にリホーム、Article schema を使用
├── Models/
│   └── Article.swift                    # 新規 (既存 Item.swift を置換 / 削除)
├── Services/
│   ├── ArticleStore.swift               # 新規 (protocol + SwiftData 実装)
│   └── ArticleSavingService.swift       # 新規 (protocol + 重複検出付き save 実装)
├── Views/
│   ├── ArticleListView.swift            # 新規 (US1/US2/US3 の中核 View — ContentView.swift を置換)
│   ├── EmptyStateView.swift             # 新規 (FR-013)
│   └── SafariView.swift                 # 新規 (UIViewControllerRepresentable で SFSafariViewController をラップ)
├── Localization/
│   └── Localizable.xcstrings            # 新規 (全 UI 文言の日本語キー)
└── Assets.xcassets                      # 既存 (アクセントカラー等)

KnowledgeTreeShareExtension/             # 新規 target
├── ShareViewController.swift            # 新規 (NSExtensionItem から URL/Title 抽出 → ArticleSavingService に委譲)
├── Info.plist                           # 新規 (NSExtensionActivationRule で URL を受理)
└── KnowledgeTreeShareExtension.entitlements  # 新規 (App Group capability)

# Xcode の File Inspector で Article.swift / ArticleStore.swift /
# ArticleSavingService.swift の Target Membership を
# KnowledgeTree と KnowledgeTreeShareExtension の両方で ON にする。

KnowledgeTreeTests/                      # 既存 unit tests
├── KnowledgeTreeTests.swift             # 既存 (空に近い、削除または最小化)
├── ArticleSavingServiceTests.swift      # 新規 (MockArticleStore で重複検出 / 通常保存 / Title fallback)
└── SwiftDataArticleStoreTests.swift     # 新規 (in-memory ModelContainer)

KnowledgeTreeUITests/                    # 既存 UI tests
├── KnowledgeTreeUITests.swift           # 既存 (置換または最小化)
├── KnowledgeTreeUITestsLaunchTests.swift # 既存 (launch screen smoke test として継続)
└── SaveArticleUITests.swift             # 新規 (US1: 起動して空状態確認 + シード後に一覧表示 / US2: 行タップで SVC 表示 / US3: スワイプ削除)
```

**Structure Decision**:
- 既存 `KnowledgeTree` Xcode project に **Share Extension target を追加** (4 target 構成)。
- 新規 protocol + SwiftData 実装は `KnowledgeTree/Models/` と `KnowledgeTree/Services/` 配下に置き、Xcode File Inspector で **両 target (app / share extension) の Member** として登録する。
- 既存の `Item.swift` は `Article.swift` に置換 (削除)。`ContentView.swift` は `ArticleListView.swift` に置換 (削除)。
- macOS 関連の deployment target / destination は本 spec の plan では触れず、constitution の deferred TODO として別途処理する。
- App Group ID 形式: `group.<reverse-domain>.knowledgetree.shared` (実値は Apple Developer Team / Bundle ID 決定後に確定、xcconfig または entitlements に記入)。

## Complexity Tracking

> **Constitution Check で violations が無いため未記入。**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (なし) | — | — |
