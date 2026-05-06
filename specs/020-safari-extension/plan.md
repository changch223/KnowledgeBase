# Implementation Plan: Safari Web Extension

**Branch**: `020-safari-extension` (実装時に作成、本 spec は specify+plan のみ)
**Date**: 2026-05-06
**Spec**: [spec.md](./spec.md)

## Summary

Safari Web Extension target 新設で iOS Safari ツールバーに「知積」アイコンを追加、1 タップで現在ページの URL + title + og:image を保存。spec 019 ArticleSavingActor + SettingsView を再利用、設定画面に「Safari 拡張」エントリ + Setup Guide を追加。

技術アプローチ:
- **新 Target**: `KnowledgeTreeSafariExtension` (Safari Web Extension テンプレート、Xcode で追加)
- **新 JS files**: `background.js` / `content.js` / `popup.html` / `manifest.json` (extension 内、~200 行)
- **新 Swift files**: `SafariWebExtensionHandler.swift` (Safari → Native bridge)、`SafariSetupView.swift` (新 view)
- **改修**: `SettingsView.swift` (Safari 拡張エントリ追加)、`Localizable.xcstrings` (~10 文言)
- **既存再利用**: `ArticleSavingActor.shared.save(url:title:)` (spec 019)

## Technical Context

**Language/Version**: Swift 6 + JavaScript (ES2022)
**Primary Dependencies**: SafariServices, AppIntents (spec 019 ArticleSavingActor 経由)
**Storage**: 既存 SwiftData (App Group 共有、Article @Model 再利用)
**Testing**: Swift Testing for native handler、Safari Extension 動作は実機検証 (Simulator 不可)
**Target Platform**: iOS 26+ / iPadOS 26+ Safari (macOS は将来)
**Project Type**: ネイティブ iOS app + Safari Web Extension target
**Performance Goals**: Safari アイコンタップ → 保存完了 ≤1 秒
**Constraints**:
- 既存 spec 019 ArticleSavingActor 完全再利用
- Apple-quiet 路線維持 (silent 保存、通知ゼロ)
- 既存 view (ArticleListView / 知識 Clip / AI ブレイン) 完全保持
**Scale/Scope**: ~10 ファイル (Swift + JS + manifest)、~700 行、~15 タスク (中-大スコープ)

## Constitution Check

- [x] **I. プライバシーファースト**: Safari Extension → ArticleSavingActor → ローカル SwiftData、外部送信ゼロ
- [x] **II. MVP**: 手動タップ保存のみ、自動取り込み / macOS / 他ブラウザは将来 spec
- [x] **III. ソース追跡**: 保存記事は spec 002/003 backfill で URL → 元記事追跡可能
- [x] **IV. iOS 実現可能性**: Safari Web Extension iOS 16+ 確立 API、Constitution IV「将来項目」を MVP 入り
- [x] **V. calm UX**: silent 保存、独自 UI 通知ゼロ、Setup は SettingsView 内 (任意)
- [x] **VI. アーキテクチャ**: SafariWebExtensionHandler (native bridge) + ArticleSavingActor (既存) で経路分離
- [x] **VII. 日本語ファースト**: Setup Guide / Settings entry / manifest description 全文言日本語

**Quality Gates**: 全 PASS (新 target 追加で pbxproj 変更大、ただし code 品質 / テスト / アクセシビリティ / パフォーマンス整合)

## Project Structure

```text
KnowledgeTree/
├── (既存)

KnowledgeTreeSafariExtension/         # 【新規 target】
├── Resources/
│   ├── manifest.json                  # WebExtension manifest v3
│   ├── background.js                  # ツールバーボタンクリックハンドラ
│   ├── content.js                     # ページ DOM から title / og:image 抽出
│   └── icons/                         # toolbar icon (16/32/64/128 px)
├── SafariWebExtensionHandler.swift    # Native bridge: JS → Swift
├── Info.plist
└── KnowledgeTreeSafariExtension.entitlements

KnowledgeTree/Views/
├── SettingsView.swift                 # 【改修】Safari 拡張エントリ追加
└── SafariSetupView.swift              # 【新規】Setup Guide + iOS 設定 deeplink
```

## 主要研究項目 (実装時に詳細化)

1. Safari Web Extension manifest v3 仕様 (iOS Safari 17+)
2. `browser.runtime.sendNativeMessage` で JS → Swift 通信
3. SafariWebExtensionHandler から ArticleSavingActor 呼び出し (App Group ModelContainer)
4. iOS 設定アプリ Safari Extension 画面の deeplink (`prefs:root=SAFARI&path=WEB_EXTENSIONS`)
5. content script で `document.querySelector('meta[property="og:image"]')` 等の安全取得
6. icon image セット (3-4 サイズ、actionBlue 単色)

## Implementation Outline

### Phase 1: Setup
- T001: Localizable.xcstrings に Safari 拡張用 10 文言追加
- T002: Xcode で新 target `KnowledgeTreeSafariExtension` を Safari Web Extension テンプレートで追加

### Phase 2: Foundational
- T003: manifest.json + content.js + background.js 実装
- T004: SafariWebExtensionHandler.swift 実装 (JS → Swift bridge → ArticleSavingActor)

### Phase 3: US1+US2 — Toolbar Tap で保存
- T005: ツールバーボタンクリック → content script → background.js → native handler → ArticleSavingActor のフロー動作確認

### Phase 4: US3 — SettingsView 拡張
- T006: SafariSetupView 新規 (3 ステップガイド + 「iOS 設定を開く」deeplink)
- T007: SettingsView に「Safari 拡張」エントリ追加

### Phase 5: Polish
- T008: build 警告ゼロ確認
- T009: 既存テスト全回帰
- T010: 実機検証 (Safari Extension は Simulator 制限あり、実機検証必須)

## 未解決の研究タスク

実装時 (`/speckit-tasks` + `/speckit-implement` 起動時) に詳細化する項目:
- iOS 設定 → Safari Extension 有効化の deeplink URL (確実な scheme 確認)
- WebExtension API の iOS Safari 制約 (許可される manifest fields)
- Native messaging のメッセージサイズ上限
- icon の Dark Mode 対応 (ベクター or 複数サイズ)

## MVP 範囲外 (将来 spec)

- macOS Safari 対応
- 自動取り込み (ホワイトリストドメイン)
- ページ本文の取得 (現状は title + url + og:image のみ)
- バッジ表示 (保存済み URL の indicator) — constitution V 違反疑い、却下傾向
- 設定エクスポート / インポート

## 規模

中-大 (~700 行、~10-15 タスク)、Safari Extension target 追加で pbxproj 変更大、実機検証必須。

## 状態

📝 specify+plan 完了。`/speckit-tasks` + `/speckit-implement` は spec 019 完了 + 実機検証後に実施予定。
