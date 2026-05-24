# Implementation Plan: Widget「今日の学習カード」(WidgetKit)

**Branch**: `052-widget-today-cards` (実装は `v2-cloudkit-widget` 内)
**Date**: 2026-05-24
**Spec**: [spec.md](./spec.md)
**Risk**: 🟡 MEDIUM (新 target 必要)

## Summary

WidgetKit で iKnow の lockscreen + homescreen Widget を追加。spec 044 SurfaceService を App Group 経由で読み込み、上位 1-2 カードを ambient 表示。tap で deep link 経由でアプリ起動 + DeepDiveChat 該当カード遷移。AI 呼ばない (Widget 制約)、~500 行、1 週間。

## Technical Context

- **iOS 26+**: WidgetKit (StaticConfiguration + TimelineProvider)
- **新 target**: `iKnowWidget` (Widget Extension)
- **データ共有**: App Group SwiftData container (現状の `AppGroup.identifier` を Widget target にも追加)
- **AI 呼べない**: Foundation Models は app process 専用、Widget は @Query / SurfaceService 計算済データを読むだけ
- **規模**: ~500 行、tasks 10-15

## Constitution Check

- [x] I (privacy): Widget も App Group 経由でローカル DB 読むだけ、外部送信ゼロ ✅
- [x] II (MVP): Lockscreen + Homescreen Small/Medium のみ、Live Activity 等は v2.5 ✅
- [x] III (source 追跡): タップでアプリ起動、ChatService 経由で citedArticles 維持 ✅
- [x] IV (実現可能性): WidgetKit 標準 ✅
- [x] V (calm UX): 数字 / バッジ ゼロ、placeholder で迷路化防止 ✅
- [x] VI (architecture): SurfaceService を Widget target にも追加 (App Group 共有) ✅
- [x] VII (日本語): xcstrings 共有 ✅

## 主要技術判断

### R1: 新 target `iKnowWidget`

Xcode で「File → New → Target → Widget Extension」、name = `iKnowWidget`、include Configuration Intent = NO (StaticConfiguration で十分)。

pbxproj に新 target 追加 + App Group capability 同じ identifier。

### R2: SurfaceService の Widget target 共有

3 案:
- (a) UnderstandingCardSurfaceService.swift を Widget target にも add (file membership 拡張) — 推奨
- (b) Widget 専用簡略 SurfaceService 別実装 — 重複コード
- (c) Shared framework target 作成 — overkill

採用 (a)。SurfaceService が App Group SwiftData 経由で動くため Widget でも動く。

### R3: TimelineProvider

```swift
struct LearningCardsProvider: TimelineProvider {
    func placeholder(in context: Context) -> CardsEntry { ... }
    func getSnapshot(in context: Context, completion: @escaping (CardsEntry) -> Void) { ... }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CardsEntry>) -> Void) {
        let cards = fetchTopCards()  // SurfaceService 経由
        let entry = CardsEntry(date: .now, cards: cards)
        let nextUpdate = Date().addingTimeInterval(15 * 60)  // 15 分後
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
```

### R4: Deep link

`iknow://learning/card/{uuid}` で Widget tap → アプリ起動 → KnowledgeTreeApp の `.onOpenURL` で UnderstandingCard 解決 + DeepDiveChat push。

Info.plist に `LSApplicationQueriesSchemes` + URL Types 追加。

### R5: Widget UI

```swift
struct LearningCardsWidgetView: View {
    let entry: CardsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangularContent
        case .systemSmall: smallContent
        case .systemMedium: mediumContent
        default: smallContent
        }
    }
}
```

各 family で適切な情報密度 (title + label / title + icon + label / 2 cards + footer)。

## Project Structure

```text
iKnowWidget/                              # ★ 新規 target
├── iKnowWidget.swift                     # @main entry
├── LearningCardsWidget.swift             # Widget definition
├── LearningCardsProvider.swift           # TimelineProvider
├── LearningCardsWidgetView.swift         # SwiftUI view
└── Info.plist

KnowledgeTree/
├── KnowledgeTreeApp.swift                # ★ 改修 (onOpenURL handler 追加)
├── Services/UnderstandingCardSurfaceService.swift  # ★ Widget target にも file membership 追加
└── Localization/Localizable.xcstrings    # ★ 改修 (~5 文言追加)
```

## タスク

- T001 Xcode で iKnowWidget target 追加 + App Group capability + Bundle ID
- T002 LearningCardsProvider (TimelineProvider) 実装
- T003 LearningCardsWidgetView (3 family 対応)
- T004 LearningCardsWidget (StaticConfiguration)
- T005 UnderstandingCardSurfaceService を Widget target に add
- T006 KnowledgeTreeApp.onOpenURL deep link handler
- T007 Info.plist URL Types 追加
- T008 xcstrings 5 文言追加
- T009 Build + 全 unit test regression
- T010 実機検証 (Widget 追加 + Lock 画面 + Homescreen tap)

## 実装規模

~500 行、10 tasks、期間 **1 週間**。

## 検証

1. Xcode → Widget 追加 → Lockscreen に accessoryRectangular 表示
2. Lockscreen tap → iKnow 起動 → DeepDiveChat 遷移
3. Homescreen Small / Medium も同様
4. 候補 0 件で placeholder
5. アプリ内で ✓ わかった後、Widget が次回 reload で反映 (15 分以内)
