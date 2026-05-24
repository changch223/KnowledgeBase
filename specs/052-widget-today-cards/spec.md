# Feature Specification: Widget「今日の学習カード」(WidgetKit)

**Feature Branch**: `052-widget-today-cards`
**Created**: 2026-05-24
**Status**: Draft (v2.0)
**Risk**: 🟡 MEDIUM (新 target、App Group + WidgetKit、AI 呼べない制約)

## なぜ

spec 044 学習タブで AI が「今深めるべきカード 5 つ」を surface するが、ユーザーがアプリを開かないと見えない。Lockscreen / Homescreen Widget で **ambient surface** できれば、「アプリを開く前に今日の学習が目に入る」体験になり、習慣化を促進する。Karpathy「保存した知識が compound する」を「保存しなくても見える」に拡張。

## ゴール

- **Lockscreen Widget** (accessoryInline / accessoryRectangular): 上位 1-2 カードを compact 表示、tap でアプリ起動 → 該当カード詳細
- **Homescreen Widget** (systemSmall / systemMedium): 上位 1-2 カード + label badge、tap でアプリ起動
- 数分おきに reload (TimelineProvider で 15 分間隔)
- WidgetKit 制約上 AI 呼べない → 既存 SurfaceService の cached data を読むだけ
- calm UX: Widget で push 通知ゼロ、Widget は静かな「のぞき窓」

## 非ゴール

- Live Activity (Dynamic Island): v2.5
- Widget からの「✓ わかった」直接記録 (URL scheme + intent でできるが MVP scope 外)
- Widget で AI chat / 概念ページ詳細表示 (タップでアプリ起動が王道)
- 複数 Widget 同時配置 (制限なし、ユーザー裁量)

## ユーザストーリー

### US1 (P1) — Lockscreen Widget で今日のカード

1. iPhone Lockscreen に Widget 追加 (accessoryRectangular)
2. 上位 1 カードの title + label badge ("新しい知識"等) 表示
3. tap で iKnow が起動 + 該当カード DeepDiveChat 直接遷移

### US2 (P1) — Homescreen Widget (Small)

1. systemSmall Widget で上位 1 カード表示 (lightbulb icon + name + label badge)
2. tap でアプリ起動 + 該当 DeepDiveChat

### US3 (P2) — Homescreen Widget (Medium)

1. systemMedium で上位 2 カード + 「+N more」 footer
2. 各カード tap で該当 DeepDiveChat

### US4 (P2) — Widget 空状態

1. 候補 0 件 → 「まだ学ぶカードがありません」placeholder
2. tap でアプリ起動 → 学習タブ

### US5 (P3) — Widget 更新頻度

1. 15 分間隔で TimelineProvider が SurfaceService 経由で再 fetch
2. アプリ内で「✓ わかった」したら Widget も次回 reload で反映

## 機能要件

- **FR-001**: 新規 Xcode target `iKnowWidget` 作成 (WidgetKit + SwiftData App Group 共有)
- **FR-002**: `LearningCardsWidget` 実装 (TimelineProvider + 3 family: accessoryRectangular / systemSmall / systemMedium)
- **FR-003**: SurfaceService を Widget 側からも呼べるよう、App Group SwiftData 経由で fetch
- **FR-004**: タップで deep link `iknow://learning/card/{uuid}` → KnowledgeTreeApp の `onOpenURL` で DeepDiveChat 起動
- **FR-005**: 0 件で placeholder「まだ学ぶカードがありません」
- **FR-006**: TimelineProvider entries は 15 分間隔、past entries `endDate` 設定
- **FR-007**: Widget の Locale 日本語、xcstrings 共有 (App Group + Widget Resources)
- **FR-008**: calm UX: Widget で urgent badge / 数字 counter ゼロ

## 成功基準

- SC-001: Widget 追加 → 1 分以内に上位カード表示
- SC-002: tap で iKnow 起動 → DeepDiveChat 該当カード遷移 (3 秒以内、Apple Intelligence あり)
- SC-003: Widget が 15 分以内に reload (アプリ内で ✓ した後、次の更新で反映)
- SC-004: 候補 0 件で placeholder
- SC-005: 各 Widget family (Lockscreen + Small + Medium) で動作
- SC-006: Widget memory / CPU 使用量が WidgetKit 制限内 (30MB / 100ms init)

## アサンプション + リスク

- WidgetKit + SwiftData App Group 共有が iOS 26 で安定
- SurfaceService が Widget extension target でも import 可能 (or duplicate code 必要)
- AI 呼べない制約は OK (SurfaceService は AI 不要、cached @Query で動く)
- Widget 用 deep link scheme `iknow://` 登録 (Info.plist URL Types)

**最大リスク**: SurfaceService が `@MainActor` + 既存 service 群依存。Widget target に分離して動かすには、SurfaceService を Widget target にも追加 + RefreshTrigger / 他依存を mock 化が必要。

## 規模

- 新規 target + WidgetKit boilerplate: ~150 行
- LearningCardsWidget view: ~200 行
- TimelineProvider + Entry: ~100 行
- Deep link handling (KnowledgeTreeApp + onOpenURL): ~50 行
- xcstrings: ~5 文言
- 合計 **~500 行**、tasks 10-15、期間 **1 週間**

## 依存

- spec 044 (UnderstandingCardSurfaceService、SurfaceService 共有必要)
- iOS 26+ WidgetKit
- App Group SwiftData container (現状利用、Widget 側読み込み)
- iCloud sync (spec 051) は **無関係** — Widget は local DB 読むだけ
