# Research: Category 詳細画面 + ArticleRow 時間軸 + ArticleDetailView 本文折りたたみ (spec 016)

## R1 — CategoryFilteredDestination の配置と Hashable 実装

**Decision**: `KnowledgeTree/Views/ArticleListView.swift` の末尾 (既存 `TagFilteredDestination` の隣) に `struct CategoryFilteredDestination: Hashable { let category: Category }` を追加。

**Rationale**:
- 既存 `TagFilteredDestination: Hashable { let tagName: String }` が `ArticleListView.swift:190` に定義されている同パターン
- spec 015 の `Category` struct (CategorySeed.swift:14) は既に Hashable + Sendable
- 別ファイル化は依存関係が増えるだけで利点なし、既存 destination 群の隣がレビュアーフレンドリー

**Alternatives considered**:
- **A**: 専用 `Destinations.swift` に集約 → 既存 4 destination の移動も必要、本 spec の範囲外
- **B**: AIBrainView 内の private struct → CategoryFilteredListView から参照できず NG

## R2 — タグフィルターチップ「+N」展開の UX

**Decision**: `@State private var showsAllTags: Bool = false` でトグル。`false` 時は上位 5 個 + 「+%lld ▼」ボタン、`true` 時は全 Tag + 「閉じる ▲」ボタン。LazyHStack の中で同一 ScrollView に並べる (sheet や DisclosureGroup ではなく inline 展開)。

**Rationale**:
- inline 展開の方が文脈を失わない (sheet だと選択中の状態が見えなくなる)
- LazyHStack は標準で水平 ScrollView 内、Tag 多数でもパフォーマンス OK
- Tag 6 個 = 上位 5 + +1、Tag 30 個 = 上位 5 + +25、いずれも UX 一貫
- toggle の戻し: 「閉じる ▲」or 「-1 ▲」 → 簡潔のため「閉じる」固定

**Alternatives considered**:
- **A**: sheet で全表示 → 文脈損失、戻る操作が増える
- **B**: DisclosureGroup → vertical 展開に固定されてレイアウト崩れる
- **C**: 「+N ▼」を別行に縦展開 → 縦 space 取り過ぎ

## R3 — savedAt 時間軸フォーマット切替ロジック

**Decision**: 単一 helper `static func formatSavedAt(_ date: Date, now: Date = .now) -> String` を `ArticleRow.swift` 内 private extension に置く。Calendar / DateFormatter / RelativeDateTimeFormatter は static let で 1 回だけ初期化。

```swift
private enum SavedAtFormatter {
    static let calendar = Calendar.current
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f
    }()
    static let absoluteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()
    static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.unitsStyle = .short
        return f
    }()
    static func format(_ date: Date, now: Date = .now) -> String {
        if calendar.isDateInToday(date) {
            return "今日 " + timeFormatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "昨日 " + timeFormatter.string(from: date)
        }
        let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if daysAgo >= 0 && daysAgo <= 7 {
            return relativeFormatter.localizedString(for: date, relativeTo: now)
        }
        return absoluteFormatter.string(from: date)
    }
}
```

**Rationale**:
- DateFormatter 初期化は重い → static let で 1 回だけ
- `now: Date` を引数化 → unit test で時刻注入可能 (constitution テストゲートのテスト決定論性に準拠)
- Locale `ja_JP` 固定で「N 日前」「今日」等が日本語化
- Localizable.xcstrings 経由ではなく helper 内固定文字列 (「今日」「昨日」) → ja_JP 固定なので簡素化、ただし「reader.savedAtToday」「reader.savedAtYesterday」を将来 Localizable 化する余地は残す

**Alternatives considered**:
- **A**: 各文字列を Localizable.xcstrings 経由 → 多言語化準備としては正しいが MVP ではオーバーキル、ja_JP のみで十分 (constitution VII)
- **B**: ISO 8601 全表示 → ユーザーフレンドリーでない
- **C**: 「N 時間前」まで細かく → 仕様で「今日 HH:mm」固定なので不要

## R4 — ArticleDetailView 本文折りたたみの実装位置

**Decision**: `ArticleDetailView.swift:365` の `private var bodySection: some View` の中身を `DisclosureGroup("reader.bodyDisclosureLabel", isExpanded: $isBodyExpanded) { ... }` でラップ。`@State private var isBodyExpanded: Bool = false` を ArticleDetailView の state に追加。本文 paragraphs が空なら DisclosureGroup 自体非表示 (既存ガード `paragraphs.isEmpty` を再利用)。

**Rationale**:
- bodySection は既に独立した computed property → DisclosureGroup 化は局所改修
- `isExpanded` バインディング保持で SwiftUI 標準アニメ (Reduce Motion 自動対応)
- ArticleDetailView 起動毎に新規 instance → 毎回 collapsed が自然 (state は struct lifecycle 通り)
- spec 005 の sheet が記事タップ毎に ArticleDetailView を新生成する設計 → 折りたたみ状態は記事ごとに保持しないが画面起動毎にリセット (= 仕様通り)

**Alternatives considered**:
- **A**: Apple News 風 fade-out オーバーレイ → 仕様で却下 (DisclosureGroup 一択)
- **B**: 「本文を読む」を別 view (sheet) で表示 → 関連記事との文脈が切れる
- **C**: 本文折りたたみ状態を UserDefaults / SwiftData に永続化 → 将来 spec、MVP では不要

## R5 — CategoryFilteredListView の Tag 集計 / Article union 計算

**Decision**: CategoryFilteredListView 内の `@Query<Tag>` で全 Tag を取得 → `categoryRaw == self.category.name` の Tag のみ filter → 各 Tag.articles を union (Set 化) → 選択中フィルターで OR 絞り込み → savedAt desc sort。すべて computed property、@State 不要。

```swift
@Query private var allTags: [Tag]

private var categoryTags: [Tag] {
    allTags
        .filter { CategorySeed.category(for: $0.categoryRaw).name == category.name }
        .sorted { $0.articles.count > $1.articles.count }
}

private var filteredArticles: [Article] {
    let pool: [Tag] = selectedTagNames.isEmpty
        ? categoryTags
        : categoryTags.filter { selectedTagNames.contains($0.name) }
    var seen = Set<PersistentIdentifier>()
    var result: [Article] = []
    for tag in pool {
        for article in tag.articles where !seen.contains(article.persistentModelID) {
            seen.insert(article.persistentModelID)
            result.append(article)
        }
    }
    return result.sorted { $0.savedAt > $1.savedAt }
}
```

**Rationale**:
- spec 015 の `categoryRaw` 値は `CategorySeed.category(for:).name` で normalize 済 → 直接比較可能
- Set<PersistentIdentifier> による重複排除 = O(N), 1000 記事規模で十分
- `@State private var selectedTagNames: Set<String> = []` でフィルター状態保持
- 戻る or タブ切替 で view が destroyed → @State 自動リセット = 仕様通り

**Alternatives considered**:
- **A**: `@Query` で predicate `category == self.category` 直接 → SwiftData の predicate で String? 比較のサポート確認必要、refactor コスト高
- **B**: AutoCategoryBackfillRunner と同じ batch 集計 → リアルタイム更新が遅れる
- **C**: 集計結果を SwiftData に書き込み → 不要な writes 増加

## R6 — タグフィルター記事数 caption の計算

**Decision**: 各 `Tag.articles.count` を直接表示 (Category 全体での重複排除 union ではなく、その Tag が抱える生件数)。

例: テクノロジー = "Swift" {A, B} + "iOS" {A, C}
- Category 表示 (KnowledgeCategoryRow) = 3 件 (union {A,B,C})
- フィルターチップ Swift caption = 2 件 (Swift 単独)
- フィルターチップ iOS caption = 2 件 (iOS 単独)

**Rationale**:
- フィルターチップは「このタグでフィルターした時の表示件数」を予告する用途
- ユーザーが「Swift をタップしたら 2 件出る」と予測できる
- Category 全体の union は KnowledgeCategoryRow に表示済 (役割分離)

**Alternatives considered**:
- **A**: 全部 union 件数で揃える → タップ後の表示件数とずれる、UX 直感に反する

## R7 — テスト戦略

**Decision**:
- **新規 unit test**: 2 ファイル
  - `CategoryFilteredListViewTests.swift` (5 ケース): in-memory ModelContainer + Tag/Article fixture、computed property `categoryTags` / `filteredArticles` を直接呼ぶ
  - `ArticleRowSavedAtTests.swift` (5 ケース): `SavedAtFormatter.format(_:now:)` を時刻注入で全分岐 (今日 / 昨日 / 4 日前 / 30 日前 / 未来) 検証
- **既存テスト**: 66+ ケースが無傷で PASS (回帰なし)
- **UI test**: 本 spec では追加せず、実機検証 (quickstart 9 シナリオ) で代替
- **fixture pattern**: `private typealias Tag = KnowledgeTree.Tag` (既存 spec 011-015 同パターン)

**Rationale**:
- DisclosureGroup の SwiftUI 標準アニメ / NavigationStack 遷移は SwiftUI 内部で保証 → unit test 範囲外
- フィルター computed property と日付フォーマット切替は純関数 = テスト容易
- UI test は spec 011 で書いた 6 ケースが廃止されており、本 spec で再構築は別 spec のスコープ

**Alternatives considered**:
- **A**: snapshot test → 環境依存、本プロジェクトでは未導入
- **B**: UI test 追加 → 実機検証で十分、保守コスト増

## R8 — Localizable.xcstrings 新規文言

**Decision**: 以下 5 個を追加 (必要最小限):

| Key | 日本語 |
|---|---|
| `category.detail.tagFilter.expand` | `+%lld 件のタグ ▼` |
| `category.detail.tagFilter.collapse` | `閉じる ▲` |
| `category.detail.empty.title` | `該当記事がありません` |
| `category.detail.empty.description` | `タグフィルターを変更して再表示してください` |
| `reader.bodyDisclosureLabel` | `本文を読む` |

「今日」「昨日」「N 日前」「YYYY/MM/DD」は SavedAtFormatter 内の hardcoded 日本語 / RelativeDateTimeFormatter / DateFormatter で表現 (Locale ja_JP 固定なので Localizable 経由不要)。

**Rationale**:
- Constitution VII (日本語ファースト) では「ja_JP 主言語」、本 spec は ja_JP のみで十分
- `LocalizedStringKey` 経由のものだけ xcstrings に登録、helper 内固定文字列は対象外
- 将来 en_US 対応時に SavedAtFormatter 内の「今日」「昨日」を Localizable 化する余地は残る

**Alternatives considered**:
- **A**: 全文言 Localizable 化 → 過剰、helper 内固定文字列の方が保守容易
- **B**: 「今日 HH:mm」を `today.withTime` のような複雑キー化 → ja_JP に閉じるなら不要

## R9 — AIBrainView の navigationDestination 構成

**Decision**: 既存 2 つの `.navigationDestination(for:)` (TagFilteredDestination / EntityFilteredDestination) はそのまま保持し、3 つ目として `.navigationDestination(for: CategoryFilteredDestination.self) { dest in CategoryFilteredListView(category: dest.category) }` を追加。

**Rationale**:
- AIBrainView の NavigationLink は KnowledgeCategoryRow 行のみが Category 行 (Stats Row / Insight Card は非 NavigationLink)
- TagFilteredDestination はもう Category 行から呼ばれないが、Insight Card 内の Tag 推薦タップ等で将来活用余地あり → 残す
- EntityFilteredDestination は EntityChip タップで使う → 残す

**Alternatives considered**:
- **A**: TagFilteredDestination を AIBrainView から削除 → 残しても害なし、削除コストの方が高い

## R10 — KnowledgeCategoryRow の topTagName 削除安全性

**Decision**: `topTagName: String` プロパティを削除。AIBrainView 側の呼び出しから `topTagName: entry.topTagName,` 行を削除。CategoryListEntry struct から `topTagName` を削除。

**Rationale**:
- 旧用途は NavigationLink target を作るため → spec 016 で CategoryFilteredDestination に置換され不要
- accessibility 用途で残す案もあるが、Category 名 + 記事数で十分情報伝達できる
- 削除しないと「使われていない property」となり constitution コード品質ゲート違反 (死コード禁止)

**Alternatives considered**:
- **A**: `_ topTagName: String = ""` で残す → 死コード、保守時の混乱要因
- **B**: `topTagName` を accessibilityLabel に入れる → 「上位タグ」情報は accessibility にも不要、Category 名 + 件数で十分
