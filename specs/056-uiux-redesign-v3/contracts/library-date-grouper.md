# Contract: LibraryDateGrouper

## Purpose

ライブラリタブで Article を Apple Photos 風の日付別 5 group に分類する純粋関数 + enum。

## Type Definitions

```swift
enum LibraryDateGroup: String, CaseIterable, Identifiable {
    case today      // 今日 0:00 以降
    case yesterday  // 昨日 0:00 - 今日 0:00 未満
    case thisWeek   // 今週月曜 0:00 - 昨日 0:00 未満
    case thisMonth  // 今月 1 日 0:00 - 今週月曜 0:00 未満
    case earlier    // 今月 1 日 0:00 より前
    
    var id: String { rawValue }
    
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .today: return "library.dateGroup.today"
        case .yesterday: return "library.dateGroup.yesterday"
        case .thisWeek: return "library.dateGroup.thisWeek"
        case .thisMonth: return "library.dateGroup.thisMonth"
        case .earlier: return "library.dateGroup.earlier"
        }
    }
}

struct LibraryDateGrouper {
    /// Article 配列を日付別 group に分類して返す。
    /// 各 group 内は savedAt desc ソート、空 group は除外。
    /// Date は now 注入で deterministic test 可能。
    static func group(
        _ articles: [Article],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [(LibraryDateGroup, [Article])]
    
    /// 1 つの Date を date group に分類。
    static func classify(
        _ date: Date,
        now: Date,
        calendar: Calendar
    ) -> LibraryDateGroup
}
```

## Implementation

```swift
struct LibraryDateGrouper {
    static func group(
        _ articles: [Article],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [(LibraryDateGroup, [Article])] {
        var groups: [LibraryDateGroup: [Article]] = [:]
        for article in articles {
            let group = classify(article.savedAt, now: now, calendar: calendar)
            groups[group, default: []].append(article)
        }
        return LibraryDateGroup.allCases.compactMap { group -> (LibraryDateGroup, [Article])? in
            guard let articles = groups[group], !articles.isEmpty else { return nil }
            let sorted = articles.sorted { $0.savedAt > $1.savedAt }
            return (group, sorted)
        }
    }
    
    static func classify(
        _ date: Date,
        now: Date,
        calendar: Calendar
    ) -> LibraryDateGroup {
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!
        
        // 今週月曜 0:00 (firstWeekday = 2 monday を想定、locale により異なる場合あり)
        var weekStart: Date = {
            var startOfWeek = todayStart
            let weekday = calendar.component(.weekday, from: todayStart)
            // ISO 8601 monday-first を想定: 月=2..日=1
            let daysFromMonday = (weekday + 5) % 7  // 月=0, 火=1, ..., 日=6
            return calendar.date(byAdding: .day, value: -daysFromMonday, to: todayStart)!
        }()
        
        // 今月 1 日 0:00
        let monthStartComponents = calendar.dateComponents([.year, .month], from: now)
        let monthStart = calendar.date(from: monthStartComponents)!
        
        if date >= todayStart {
            return .today
        } else if date >= yesterdayStart {
            return .yesterday
        } else if date >= weekStart {
            return .thisWeek
        } else if date >= monthStart {
            return .thisMonth
        } else {
            return .earlier
        }
    }
}
```

## Behavior

| Case | Input Article savedAt | Output |
|---|---|---|
| 今日 | 今 - 1 時間 | `.today` |
| 昨日 | 今 - 25 時間 | `.yesterday` |
| 今週 (火曜想定) | 今週月曜 6:00 | `.thisWeek` |
| 今月 | 今月 1 日午後 | `.thisMonth` |
| それ以前 | 先月 | `.earlier` |
| 境界 (今日 0:00) | 今日 0:00 ちょうど | `.today` (>= todayStart) |
| 境界 (昨日 23:59) | 今日 0:00 - 1 秒 | `.yesterday` |

## UI 結合

```swift
struct LibraryGroupedView: View {
    @Query(sort: \Article.savedAt, order: .reverse)
    private var allArticles: [Article]
    
    private var grouped: [(LibraryDateGroup, [Article])] {
        LibraryDateGrouper.group(allArticles)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(grouped, id: \.0) { (group, articles) in
                    Section {
                        DisclosureGroup {
                            ForEach(articles) { article in
                                ArticleRow(article: article)
                            }
                        } label: {
                            Text(group.localizedTitle)
                                .font(.headline)
                        }
                    }
                }
            }
        }
    }
}
```

## Test Cases (5 件)

1. **5 group 分類**: 5 つの異なる savedAt 入力 → 全 5 group が non-empty
2. **空配列**: 空 input → 空 result
3. **savedAt desc ソート**: 同 group 内で確認、新しい順
4. **境界**: 今日 0:00 ちょうど → today、今日 0:00 - 1 秒 → yesterday
5. **large data 1000 件**: group 処理 100ms 以内 (Instruments 測定)

## Performance

- O(N) で全 article 1 回 scan + group 内 sort O(N log N)
- 1000 件で 100ms 以内 (Swift 標準 sorted で十分)
- 各 group 内 limit が小さい場合 (今日 = 数件) は実質 O(N) dominant

## xcstrings 追加

- `library.dateGroup.today` = "今日"
- `library.dateGroup.yesterday` = "昨日"
- `library.dateGroup.thisWeek` = "今週"
- `library.dateGroup.thisMonth` = "今月"
- `library.dateGroup.earlier` = "それ以前"

## Locale 注意

- Calendar の `firstWeekday` は locale 依存 (日本では月曜 = 2、米国では日曜 = 1)
- 本実装は ISO 8601 月曜始まり想定で hardcode、将来 locale 対応が必要なら calendar.firstWeekday を使う形に refactor

## DI / Lifecycle

- 純粋 static method、Service container 不要
- LibraryGroupedView から直接呼出 (`LibraryDateGrouper.group(articles)`)
