# Implementation Plan: iCloud sync (SwiftData CloudKit private database)

**Branch**: `051-cloudkit-sync` (実装は `v2-cloudkit-widget` 内)
**Date**: 2026-05-24
**Spec**: [spec.md](./spec.md)
**Risk**: 🔴 HIGH (App Group + CloudKit 共存 + schema migration)

## Summary

Phase A のみ: schema audit + 修正 + opt-in toggle + 基本 sync 動作 + technical spike。Phase B/C は別 spec。実装着手前に **technical spike (1-2 日)** で App Group + CloudKit 共存 + 既存データ migration の動作検証必須。

## Technical Context

- **iOS 26+**: SwiftData CloudKit 安定版
- **Apple Developer**: CloudKit container `iCloud.app.KnowledgeTree` 作成必要
- **既存影響**: 全 @Model schema 改修、約 15 model × 平均 30 行 = ~450 行
- **Schema 衝突**: `@Attribute(.unique)` 削除でアプリ層 dedup ロジック必要
- **規模**: ~1100 行、tasks 20-30、期間 **2-3 週間**

## Constitution Check

- [x] I (privacy): CloudKit private DB は **ユーザー自身の iCloud 内のみ**、Apple サーバーに保存されるが他人非公開、Apple のプライバシー枠組み準拠 ✅
- [x] II (MVP): V2.0 の核機能、Phase A focus + B/C 分離 ✅
- [x] III (source 追跡): Article / 知識 entity の relationship 維持 (CloudKit でも nullify 動作) ✅
- [x] IV (実現可能性): SwiftData CloudKit 標準、ただし **spike で動作確認必須** ⚠️
- [x] V (calm UX): sync 通知 / バッジゼロ (FR-015) ✅
- [x] VI (architecture): ModelConfiguration 切替の単一責任、Service 改修ゼロ ✅
- [x] VII (日本語): xcstrings 追加 ~10 文言 ✅

**Quality Gates**:
- コード品質: schema audit で `@Attribute(.unique)` を application-level dedup に置換、test カバー必須
- テスト: in-memory ModelContainer での schema 動作 + Mock CloudKit (XCTest で CKContainer.default() を MockContainer に DI)
- パフォーマンス: 初回 push の background 動作、UI block ゼロ

## 主要技術判断

### R1: Technical spike (1-2 日、実装前必須)

**目的**: 不確実性を実装着手前に解消。失敗したら spec 自体を中止 or Phase 分割し直し。

実機で以下を確認:
1. `ModelConfiguration(schema:, groupContainer:, cloudKitDatabase: .private)` が iOS 26 で動くか
2. Share Extension が同 container を読み書きできるか (CloudKit 経由でも)
3. 既存 local DB から CloudKit に migrate する API (`PersistentContainer.migrate(to:)`) があるか、またはアプリ側で全 fetch → re-insert する必要があるか
4. `@Attribute(.unique)` 削除前後の動作差 (silent fail / 例外 / 既存 record 重複等)

**Output**: research.md に spike 結果記録、Phase A 着手判断。

### R2: Schema 改修 (~15 model)

対象 @Model:
- Article / ArticleEnrichment / ArticleBody / ExtractedKnowledge / KeyFact / KnowledgeEntity
- Tag / KnowledgeChunkProgress / BackgroundExtractionQueueEntry
- KnowledgeDigest / ChatSession / ChatMessage
- ConflictProposal / UserTopic / GraphNode / GraphEdge
- ConceptPage / SavedAnswer / UnderstandingInteraction

各 model で:
- `@Attribute(.unique) var id: UUID` → `var id: UUID = UUID()` (default 必須)
- relationship optional 化 audit
- 全 attribute に default value 追加

### R3: Application-level dedup

各 Store に id 重複チェックを追加:
```swift
private func insertIfNotExists(_ article: Article) {
    let id = article.id
    let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.id == id })
    if (try? context.fetchCount(descriptor)) ?? 0 > 0 { return }
    context.insert(article)
}
```

8+ Store の改修。

### R4: Sync toggle UI

```swift
@AppStorage("icloud_sync_enabled") private var iCloudEnabled: Bool = false
@State private var showConfirmEnable = false

Toggle("iCloud で同期", isOn: $iCloudEnabled)
    .onChange(of: iCloudEnabled) { _, new in
        if new {
            showConfirmEnable = true
        } else {
            // OFF: 再起動が必要かもしれない
        }
    }
```

トグル ON で ModelContainer を再構築 → アプリ全体再起動 (iOS 26 が要求するかもしれない)。

### R5: Migration UX (Phase B)

本 spec では「toggle ON で sync 開始」「初回 push は CloudKit に任せる」のみ。詳細 progress UI は Phase B。

## Project Structure

```text
KnowledgeTree/
├── SharedSchema.swift                    # ★ 改修 (CloudKit config branch)
├── Models/{Article, Tag, ConceptPage, ...}.swift  # ★ 全 15 model 改修
├── Services/
│   ├── ArticleStore.swift                # ★ 改修 (dedup logic)
│   ├── TagStore.swift                    # ★ 改修
│   ├── ConceptPageStore.swift            # ★ 改修
│   └── ... (各 Store)
├── Views/
│   └── SettingsView.swift                # ★ 改修 (toggle 実装)
└── KnowledgeTreeApp.swift                # ★ 改修 (ModelContainer 動的構築)

specs/051-cloudkit-sync/
├── spec.md
├── plan.md (this file)
├── research.md (Phase 0 — technical spike 結果)
├── data-model.md (Phase 1 — 改修後 schema)
├── contracts/ (Phase 1)
│   ├── cloudkit-config.md
│   ├── settings-icloud-toggle.md
│   └── store-dedup-pattern.md
└── tasks.md (Phase 2)
```

## Phase 構成

- **Phase 0** (1-2 日): Technical spike — App Group + CloudKit 共存 + migration API 検証
- **Phase 1** (3-4 日): Schema audit + 全 15 model 改修 + dedup logic
- **Phase 2** (2-3 日): Toggle UI + Settings + ModelContainer 動的構築
- **Phase 3** (2-3 日): Tests + edge case 対応
- **Phase 4** (1 日): Build + 全 unit test regression + 実機 spike 検証
- **Phase 5** (Phase B 別 spec): Migration UI + progress

## MVP 範囲

T001-T015 が MVP (Phase A 全)、T016+ は Phase B/C で別 spec。

## 実装規模

~1100 行 + tests ~300 行 = **~1400 行**、tasks 約 25、期間 **2-3 週間**。

## 検証 (quickstart 想定、Phase 1 完了後に書く)

1. Settings toggle ON → 確認 alert
2. OK → アプリ再起動 (or 自動再起動 banner)
3. 起動後、CloudKit sync 開始
4. 他端末でアプリ起動 → データ同期
5. 編集 / 削除も双方向同期
6. Toggle OFF → ローカル動作復帰
7. iCloud quota 不足 → warning 表示

## Out of Scope

- Phase B: Migration UI / progress (~150 行、spec 054)
- Phase C: Conflict resolution / sync indicator (~200 行、spec 055)
- Shared zone / 共有: v3.0+
- バックアップ機能: Apple iCloud バックアップ任せ
