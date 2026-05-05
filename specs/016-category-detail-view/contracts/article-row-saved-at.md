# Contract: ArticleRow savedAt 時間軸表示

ArticleRow に「いつ保存したか」を 1 行で表示する純関数 helper + view 改修。

## SavedAtFormatter (新規 helper)

`ArticleRow.swift` 内 private extension に同居。

```swift
private enum SavedAtFormatter {
    static func format(_ date: Date, now: Date = .now) -> String
}
```

### 入出力契約

| 入力 (date と now の関係) | 出力例 | 詳細 |
|---|---|---|
| 同一日 (Calendar.isDateInToday) | `今日 14:30` | 「今日 」+ HH:mm (ja_JP) |
| 前日 (Calendar.isDateInYesterday) | `昨日 09:15` | 「昨日 」+ HH:mm (ja_JP) |
| 7 日以内 (今日でも昨日でもない) | `3 日前` | RelativeDateTimeFormatter (ja_JP, .short) |
| それ以上 (差分 > 7 日) | `2026/05/05` | DateFormatter "yyyy/MM/dd" (ja_JP) |
| 未来 (時計ずれ) | `今すぐ` 等 | RelativeDateTimeFormatter 任意 (許容) |

### 内部実装

- `Calendar.current.isDateInToday(date)` → 今日分岐
- `Calendar.current.isDateInYesterday(date)` → 昨日分岐
- それ以外 → `dateComponents([.day], from: date, to: now).day` で日数計算
- 0 ≤ daysAgo ≤ 7 → relative (今日/昨日 は前段で分岐済みなので実質 2-7 日前)
- それ以外 → absolute formatter

### 不変条件

- `now` 引数は default `.now` (test 注入可能)
- 全 formatter は `static let` で 1 回だけ生成 (パフォーマンス)
- Locale は `ja_JP` 固定

## ArticleRow View 改修

URL Text の隣 (HStack) または直下 (VStack) に savedAt Text を追加。

```swift
// URL 行の右に savedAt を並べる:
HStack(spacing: DS.Spacing.sm) {
    Text(article.url)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    Spacer(minLength: DS.Spacing.sm)
    Text(SavedAtFormatter.format(article.savedAt))
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .accessibilityLabel("保存日: \(absoluteAccessibilityDate)")
}
```

### accessibilityLabel

`combinedAccessibilityLabel` に savedAt の絶対値 ("2026年5月5日 14:30 保存") を追加。

```swift
private var savedAtAccessibilityText: String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateStyle = .long
    f.timeStyle = .short
    return "\(f.string(from: article.savedAt)) 保存"
}

private var combinedAccessibilityLabel: String {
    var parts: [String] = [displayTitle]
    // ... existing ...
    parts.append(savedAtAccessibilityText)  // 追加
    return parts.joined(separator: ", ")
}
```

## テストケース (ArticleRowSavedAtTests)

| # | now の固定値 | savedAt | 期待出力 |
|---|---|---|---|
| 1 | 2026-05-05 12:00 | 2026-05-05 14:30 (同一日) | `今日 14:30` |
| 2 | 2026-05-05 12:00 | 2026-05-04 09:15 (前日) | `昨日 09:15` |
| 3 | 2026-05-05 12:00 | 2026-05-02 12:00 (3 日前) | RelativeDateTimeFormatter の出力 (例: `3 日前`) |
| 4 | 2026-05-05 12:00 | 2026-04-01 12:00 (>7 日前) | `2026/04/01` |
| 5 | 2026-05-05 12:00 | 2026-05-05 14:30 (未来 2.5h) | (今日分岐優先) `今日 14:30` |

(5 ケース、純関数なので fixture 不要、Date(timeIntervalSince1970:) で固定値注入)

## 互換性

- ArticleListView / TagListView / TagFilteredListView / SearchResultsView 全てで自動的に savedAt 表示が増える (constitutional Quality Gate に準拠)
- 既存 layout の縦サイズが「URL 行 → URL + savedAt 行」で同じ (caption2 1 行のまま)
