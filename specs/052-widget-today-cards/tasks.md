# Tasks: Widget「今日の学習カード」(WidgetKit)

**Feature**: spec 052
**Branch**: `052-widget-today-cards`
**Scope**: 新規 Xcode target + Widget code + deep link、~500 行、1 週間

---

## Phase 0: Xcode target setup (user 操作必須、~10 分)

- [ ] T001 User: Xcode で Widget Extension target 追加
  - File → New → Target → Widget Extension
  - Product Name: `iKnowWidget`、Include Configuration Intent: OFF
  - Embed in: KnowledgeTree
- [ ] T002 User: iKnowWidget target に App Group capability 追加 (main app と同 identifier 共有)
- [ ] T003 User: Bundle ID 確認 + Claude に報告

## Phase 1: Widget 実装 (Claude、~3 時間)

- [ ] T004 Replace Xcode 生成 boilerplate (`iKnowWidget/iKnowWidget.swift`) with `LearningCardsWidget` (StaticConfiguration + 3 family supported: accessoryRectangular / systemSmall / systemMedium)
- [ ] T005 Create `iKnowWidget/LearningCardsProvider.swift` (TimelineProvider with 15-min refresh、placeholder / snapshot / timeline impl)
- [ ] T006 Create `iKnowWidget/LearningCardsWidgetView.swift` (SwiftUI view、family switch、icon + name + label badge)
- [ ] T007 Create `iKnowWidget/WidgetCardSnapshot.swift` (App Group SwiftData ModelContainer 経由で UnderstandingCardSurfaceService.surfaceTopCards(limit: 2) を呼ぶ Widget 専用 wrapper、@MainActor)
- [ ] T008 Add file membership: spec 044 の `UnderstandingInteraction.swift` (含 transient struct) + spec 042 `ConceptPage.swift` + spec 043 `SavedAnswer.swift` + その他必要な @Model を iKnowWidget target にも追加 (pbxproj edit)
- [ ] T009 Add file membership: `UnderstandingCardSurfaceService.swift` + 依存 service / store を iKnowWidget target にも追加
- [ ] T010 `iKnowWidget/Info.plist`: NSExtension dict + UISupportedFamilies に accessoryRectangular / systemSmall / systemMedium

## Phase 2: Deep link 配線 (Claude、~1 時間)

- [ ] T011 `KnowledgeTree/Info.plist` に URL Types 追加 (`iknow://` scheme)
- [ ] T012 `KnowledgeTreeApp` の TabView に `.onOpenURL { url in ... }` handler 追加、`iknow://learning/card/{uuid}` を解析して `selectedTab = .learning` + `DeepDiveChatView` push
- [ ] T013 `LearningCardsWidgetView` で each card に `widgetURL(URL(string: "iknow://learning/card/\(card.id.uuidString)"))` 設定

## Phase 3: 文言 + Polish (Claude、~30 分)

- [ ] T014 `Localizable.xcstrings` に 5 文言追加 (「今日の学習」/「学ぶカードがありません」/「タップで学習を始める」/「+%lld 件」/「最新」)
- [ ] T015 `iKnowWidget` target にも `Localizable.xcstrings` file membership 追加 (xcstrings は共有可能)

## Phase 4: Build + 実機検証 (Claude → user)

- [ ] T016 `xcodebuild build -scheme iKnowWidget` SUCCEEDED
- [ ] T017 `xcodebuild build -scheme KnowledgeTree` SUCCEEDED (main app + Widget embed)
- [ ] T018 User: 実機に install → Widget を Lockscreen / Homescreen に追加 → カード表示確認
- [ ] T019 User: Widget tap → アプリ起動 + DeepDiveChatView 該当カード遷移
- [ ] T020 User: app 内で「✓ わかった」→ Widget が 15 分以内に reload (新カードに切替)

## Phase 5: PR (Claude、~10 分)

- [ ] T021 CLAUDE.md に spec 052 を 🔧 実装完了 マーク
- [ ] T022 commit + push + PR 作成

---

## 実装注意点

### Widget target でできないこと
- Foundation Models (AI) — Widget は extension process、AI 不可
- @Observable / RefreshTrigger 経由の reactive update — Widget は TimelineProvider しか使えない
- 大きなメモリ使用 — Widget は ~30MB 制限

### Widget target でできること
- App Group SwiftData container 経由でローカル DB 読み込み
- UnderstandingCardSurfaceService の純粋ロジック (AI なし) 呼び出し
- 15 分 interval で reload

### App Group container 共有
main app と Widget が同じ `AppGroup.identifier` を持つことで、main app が保存した記事 / 概念 / 学習履歴を Widget が読める。書き込みは main app だけ。

### TimelineProvider 設計
```swift
struct LearningCardsProvider: TimelineProvider {
    func placeholder(in context: Context) -> CardsEntry {
        CardsEntry(date: .now, cards: [.placeholder])
    }
    func getSnapshot(in context: Context, completion: @escaping (CardsEntry) -> Void) {
        Task { @MainActor in
            let cards = await WidgetCardSnapshot.fetchTop(limit: context.family == .systemMedium ? 2 : 1)
            completion(CardsEntry(date: .now, cards: cards))
        }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CardsEntry>) -> Void) {
        Task { @MainActor in
            let cards = await WidgetCardSnapshot.fetchTop(limit: context.family == .systemMedium ? 2 : 1)
            let entry = CardsEntry(date: .now, cards: cards)
            let next = Date().addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}
```

### 注: KnowledgeDigest の crash 再発予防
spec 051 で適用した defensive snapshot pattern を Widget でも採用。`UnderstandingCard` を直接保持せず、`WidgetCardSnapshot` 値型 struct に必要 field だけ copy。

---

## 規模

- 新規 5 files (iKnowWidget/*.swift 4 + Info.plist 1)
- 改修 3 files (main Info.plist URL Types + KnowledgeTreeApp deep link + Localizable.xcstrings)
- pbxproj edit (target 追加は Xcode UI、file membership は Claude)
- ~500 行
- 22 tasks
- 期間 1 週間 (集中作業 1-2 日 + Phase 0 user 操作 + 実機検証)
