# Tasks: iKnow タブ 自然 mix フィード + inline おすすめ carousel

**Branch**: `068-iknow-feed-redesign` (main から) | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

@Model 変更なし。AI 呼び出しゼロ。

## Phase 1: ロジック (FeedBuilder)
- [x] **T001** `Services/FeedBuilder.swift`: assemble の article filter に AI 処理完了条件追加 (.succeeded/.partiallySucceeded のみ、FR-003)
- [x] **T002** `Services/FeedBuilder.swift`: `recommend(articles:wikiPages:now:limit:)` static 純関数 + 定数 (recommendLimit=5 / wikiArticleWeight=2.0 / recommendRecencyWindowDays=14 / carouselMinItems=3 / carouselInsertIndex=3)
- [x] **T003** `KnowledgeTreeTests/FeedBuilderTests.swift`: recommend テスト (Wiki 記事数×更新で上位 / 記事新しさ / top5 cap / AI 処理中除外 / isHidden 除外) + assemble の処理中除外ケース

**Checkpoint**: build + FeedBuilderTests PASS

## Phase 2: 横用カード + carousel (US2)
- [x] **T004 [US2]** `Views/ArticleShelfCard.swift` 新規 (横用コンパクト、写真上+タイトル下、tap 遷移)
- [x] **T005 [US2]** `Views/WikiShelfCard.swift` 新規 (借用写真/kind fallback + 種別バッジ、tap 遷移)
- [x] **T006 [US2]** `Views/RecommendCarousel.swift` 新規 (控えめ見出し + ScrollView(.horizontal)+LazyHStack)

## Phase 3: フィード統合 + タブ名 (US1)
- [x] **T007 [US1]** `Views/KnowledgeClipView.swift`: 縦 LazyVStack に carousel 挿入 (carouselInsertIndex の後、候補 < carouselMinItems で非表示)。recommendItems を @Query から算出
- [x] **T008** `Localization/Localizable.xcstrings`: `clip.tab.title` / `clip.nav.title` を「iKnow」に + carousel 見出し文言 (`feed.recommend.title` = おすすめ)

## Phase 4: 検証
- [x] **T009** clean build (iPhone 17 Simulator) warning ゼロ
- [x] **T010** 全 unit test serial regression PASS
- [x] **T011** 静的検証 (recommend/Shelf カード grep + iKnow 文言 + @Model 差分ゼロ)
- [x] **T012** CLAUDE.md に spec 068 追記
- [ ] **T013** 実機検証 (ユーザー、SC-001〜006)

## 依存
T001→T002→T003 / T002→T007 / T004+T005→T006→T007 / T007→T008 / Phase1-3→Phase4

## 実装戦略
Phase 1 (純ロジック、テスト可) を先に固める → Phase 2 (カード) → Phase 3 (統合)。一度に大量 Edit せず build 確認。最終 commit はユーザー指示後。アイコンは newspaper 維持 (好みで後変更)。

## Phase 5: v2 改訂 (ユーザー対話、2026-06-06)
- [x] **T014** For You Wiki 横棚を一番上に固定 (Wiki のみ、recommend に空 articles)
- [x] **T015** 縦 mix に カテゴリー/タグ ハイライトカード追加 (FeedItem 2 case + highlights/interleaveHighlights 純関数)
- [x] **T016** CategoryHighlightCard / TagHighlightCard 新規 (アイコンで区別、色なし、tap→既存 destination)
- [x] **T017** KnowledgeClipView 統合 (@Query allTags + highlight 配線 + TagFilteredDestination navigationDestination)
- [x] **T018** xcstrings (feed.category.counts / feed.tag.total / feed.highlight.recent)
- [x] **T019** FeedBuilderTests +3 (highlights category / 小カテゴリ除外 / interleave)
- [x] **T020** build + 全 test PASS (iPhone 17 Simulator)
- [ ] **T021** 実機検証 (ユーザー、For You Wiki 上部固定 / 4 種カード / 今週+N / カテゴリ・タグ tap 遷移)

## 判定基準メモ
「最近伸びてる」= 直近 7 日 (highlightRecentWindowDays) に追加された記事数 = 「今週 +N」。
記事少 (recentCount=0) なら「今週 +N」chip は非表示、カテゴリ名+総数のみ表示。
