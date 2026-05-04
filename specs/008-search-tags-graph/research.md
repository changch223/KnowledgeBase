# Research: 振り返り支援 (Phase 0)

**Feature**: spec 008
**Date**: 2026-05-05

## R1: SwiftData Predicate の relationship traversal 限界

**Decision**: `Predicate<Article>` 内で `article.enrichment?.canonicalTitle?.localizedStandardContains(query) ?? false` の形を使う。動かない場合は `body.extractedText` のような heavy field は予備的に View 側で post-filter する fallback を用意。

**Rationale**:
- iOS 17 SwiftData `#Predicate` は to-one optional relationship の string contains を限定的にサポート
- iOS 26 SDK 時点では機能拡張が進んでいるが、`extractedKnowledge?.keyFacts.contains { ... }` のような nested collection contains は実装によっては動かないリスクあり
- 動作不能と判明した場合のフォールバック: `@Query` で全 Article 取得 → View 側 `articles.filter { ... }` で post-filter (1000 記事までは許容範囲)

**Alternatives considered**:
- A: 全フィールド Predicate 内で表現 (採用、可能なら)
- B: Article のみ Predicate、relationship target は post-filter (fallback)
- C: 手動で全文 index 構築 → SwiftData との二重管理、MVP 不要

**Implementation note**: 実装フェーズで動作確認、できなければ `SearchPredicate` の責任範囲を Article 直接フィールド (title, url) のみに絞り、relationship target 検索は `articles.filter { ... }` で View 側に移譲。Performance 計測で 200 ms 達成可否を判定。

---

## R2: タグ正規化の正しい範囲

**Decision**:
- 前後の `whitespacesAndNewlines` を trim
- `lowercased()` (`Locale.current` ではなく invariant lowercase)
- 50 文字超は prefix 50
- 空文字列 → nil
- 絵文字 / CJK / 全角は触らない

**Rationale**:
- `lowercased()` は Locale 不変が望ましい (例: トルコ語の i/I 問題回避)
- 50 文字上限は SwiftData のパフォーマンス + UI チップ表示の両面から
- 絵文字・全角は現代のユーザーが使うので restrictive にしない (タグ「📚」「読書メモ」はそのまま OK)

**Alternatives considered**:
- A: 厳格 normalize (ASCII のみ受理) → 日本語ユーザーに不便
- B: 採用案 (実用的バランス)
- C: NFKC normalize (Unicode 正規化) → 過剰、CJK 文字を破壊する可能性

---

## R3: `.searchable` の placement と挙動

**Decision**: `ArticleListView` の NavigationStack 内に `.searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always))` を配置。検索クエリが空文字列の場合は全記事表示 (現状動作維持)。

**Rationale**:
- `.navigationBarDrawer(displayMode: .always)` で常時表示 → ユーザーがスクロールせずアクセスできる
- iOS 標準の検索体験 (キャンセルボタン / ハッシュ / 履歴) を踏襲
- Localizable.xcstrings で placeholder を「記事を検索」など日本語化

**Alternatives considered**:
- A: 自前検索 UI (TextField + Cancel button) → アクセシビリティ / VoiceOver 対応の手間
- B: `.searchable(placement: .toolbar)` → 隠れて使いづらい
- C: `.searchable(placement: .navigationBarDrawer(.always))` (採用)

**Implementation note**: `@State private var searchQuery: String = ""` を ArticleListView に追加、`@Query(filter: SearchPredicate.predicate(query: searchQuery))` で SwiftData が自動再 fetch。

---

## R4: 動的 Predicate と SwiftUI の再 fetch トリガ

**Decision**: `@Query` の filter は computed property で構築し、searchQuery が変化するたびに SwiftUI が `@Query` を再評価する。

**Rationale**:
- SwiftUI 5+ の `@Query(filter:)` は filter の identity が変わると再 fetch トリガ
- View body 内で `Query(filter: ...)` を構築することは公式 recommended パターン
- 検索バー入力で `searchQuery` 変化 → body 再評価 → Query 再構築 → SwiftData 再 fetch

**Alternatives considered**:
- A: `@Query` 全件取得 → View で filter (サイズ 1000 までなら許容、フォールバック)
- B: 採用案 (動的 Predicate)

**Implementation note**:
```swift
struct ArticleListView: View {
    @State private var searchQuery: String = ""

    var body: some View {
        ArticleListContent(searchQuery: searchQuery)
            .searchable(text: $searchQuery, ...)
    }
}

struct ArticleListContent: View {
    let searchQuery: String
    @Query private var articles: [Article]

    init(searchQuery: String) {
        self.searchQuery = searchQuery
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        _articles = Query(
            filter: q.isEmpty ? nil : #Predicate { article in /* ... */ },
            sort: \.savedAt,
            order: .reverse
        )
    }
}
```

inner View に分けることで `@Query` の init 時 filter を渡せる (これは SwiftUI / SwiftData の慣用パターン)。

---

## R5: 関連記事計算のパフォーマンス

**Decision**: `RelatedArticleFinder.find` は SwiftData fetch ではなく、`@Query` で取得済の `articles` 配列に対する純粋関数で実装。Detail 画面の表示時に同期計算。

**Rationale**:
- 関連記事計算は all articles を traverse する必要があるので SwiftData Predicate では複雑
- 1000 記事の Set intersection は数 ms で完了 (entity name 配列は各記事 5-10 件程度)
- 同期計算でメインスレッドブロックは無視できるレベル

**Alternatives considered**:
- A: 同期計算 (採用) → 200ms 以内、シンプル
- B: 非同期計算 (Task.detached) → 1000 記事レベルでは過剰
- C: 事前計算してキャッシュ → 記事追加・更新ごとに無効化が必要、複雑

**Implementation note**: Detail 画面が `@Query` から取得した articles を `RelatedArticlesSection` view に渡す。section 内で `RelatedArticleFinder.find(for: article, in: articles)` を computed property で呼ぶ。

---

## R6: 自動タグ提案の表示優先順位

**Decision**: salience 降順 → 同 salience 内は order 昇順 (entity 配列の元順序) → 上位 5 件 → 既存タグと一致するもの除外

**Rationale**:
- salience は AI が判断した重要度なので最優先
- order は LLM が生成した順序で「重要度に対して二次的な並び」として妥当
- 上位 5 件は UI チップが画面に並ぶサイズ感

**Alternatives considered**:
- A: 採用案
- B: salience >= 5 のみ → 厳しすぎ、提案候補がほぼ出ない
- C: 全 entity を提案 → ユーザー疲労 (10+ 提案は鬱陶しい)

---

## R7: Tag の SwiftData 多対多 relationship 設計

**Decision**:
- `Tag` (@Model): `id: UUID`, `name: String` (`@Attribute(.unique)`), `articles: [Article]` (relationship)
- `Article` (@Model 既存): `tags: [Tag]` (relationship, inverse: `Tag.articles`)
- delete rule: 多対多のため Article 削除時に Tag 自体は残る (relationship のみ解除)
- 孤児削除は `TagStore` が手動で実施

**Rationale**:
- `@Attribute(.unique)` で name 重複が DB レベルで弾かれる
- 多対多 inverse 指定で SwiftData が正しく relationship 管理
- Article cascade delete は Tag を残す (他 article で参照されている可能性ある)

**Alternatives considered**:
- A: `Article.tagNames: [String]` シリアライズ → 検索 / フィルタが SwiftData クエリで困難
- B: 採用案 (多対多 @Model)

**Implementation note**: SwiftData iOS 17 では多対多 relationship の inverse 指定が必須 (片側のみだと意図しない挙動)。両 @Model に `@Relationship` で定義。

---

## R8: 検索ハイライトの実装

**Decision**: `SearchHighlighter.highlight(text:query:) -> AttributedString` を純粋関数で実装。マッチ範囲を bold + 最初のマッチを中心に excerpt 切り出し。

**Rationale**:
- AttributedString は SwiftUI で素直に Text() に渡せる
- 純粋関数なのでテスト容易
- excerpt は前後 30 文字を上限 (UI スペース)

**Alternatives considered**:
- A: View 内で manual rendering (Range 計算 + 複数 Text 連結) → コード散乱
- B: AttributedString (採用) → SwiftUI ネイティブ

**Implementation note**:
```swift
struct SearchHighlighter {
    static func highlight(_ text: String, query: String, excerptRadius: Int = 30) -> AttributedString? {
        guard !query.isEmpty,
              let range = text.range(of: query, options: .caseInsensitive) else {
            return nil
        }
        let start = text.index(range.lowerBound, offsetBy: -excerptRadius, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: excerptRadius, limitedBy: text.endIndex) ?? text.endIndex
        let excerpt = String(text[start..<end])
        var attrs = AttributedString(excerpt)
        if let attrRange = attrs.range(of: query, options: .caseInsensitive) {
            attrs[attrRange].font = .body.bold()
        }
        return attrs
    }
}
```

---

## R9: 既存テストへの影響

**Decision**: 既存 spec 001-006 のユニットテストは無修正で pass。spec 008 の追加 view / service は独立、既存 service の API 拡張なし。

**Rationale**:
- `Article.tags` を追加するだけで既存 ArticleStore の挙動は変わらない
- ArticleListView は @Query を inner view に分けて refactor するが、表示挙動は同じ
- spec 005 の RefreshTrigger / NotificationCenter / Timer fallback は継承

**Alternatives considered**:
- A: 既存テスト修正前提 → 後方互換破壊
- B: 採用案

---

## サマリ

| Topic | Decision |
|---|---|
| R1 SwiftData Predicate 限界 | 動的 Predicate 試行、不可なら View 側 post-filter フォールバック |
| R2 タグ正規化 | trim + lowercase + 50 char prefix |
| R3 .searchable placement | navigationBarDrawer(.always) |
| R4 動的 Predicate | inner View で @Query 構築 |
| R5 関連記事計算 | 同期純粋関数 (1000 記事規模で OK) |
| R6 自動提案優先 | salience desc → order asc → 上位 5 → 既存タグ除外 |
| R7 Tag 多対多 | @Model + @Attribute(.unique) + 両側 @Relationship |
| R8 ハイライト | AttributedString + excerpt ±30 文字 |
| R9 既存テスト | 無修正 pass |

NEEDS CLARIFICATION 残数: 0。Phase 1 へ進める。
