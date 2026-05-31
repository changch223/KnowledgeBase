# Research: News+ 風フィード

Plan エージェント (READ ONLY 調査) で確認した事実ベース。

## R1: タブは進化、追加しない
`KnowledgeTreeApp.swift` AppTab は既に 3 タブ (.knowledgeClip / .library / .chat) = VISION と一致。`KnowledgeClipView` を mix フィードに置換、タブ名 `clip.tab.title` value を「フィード」に変更 (key 維持)。

## R2: FeedBuilder で merge (AI ゼロ)
RecentArticlesService.fetch パターン (savedAt 降順) + FollowingPeopleSection @Query (isHidden==false / updatedAt 降順) を踏襲。2 系列を sortDate merge。Wiki 更新カードは `updatedAt >= now - 14d && !bodyMarkdown.isEmpty` ガードで過多防止 (VISION 情報過多解消)。now 注入でテスト可能。

## R3: 写真借用 — 既存基盤で実現可
- `ArticleEnrichment.ogImageURL: String?` 既存 / `ThumbnailView(urlString:)` 既存 (AsyncImage + https ガード + placeholder)
- 先例: `KnowledgeClipCard` が `sourceArticles.compactMap(\.enrichment?.ogImageURL).first` で借用済
- Wiki カード: `conceptPage.relatedArticles?.compactMap { $0.enrichment?.ogImageURL }.first`
- fallback: `WikiPageKind.symbolName` + カテゴリ色
- News+ 風大判 (full-width) は ThumbnailView (72x72 固定) と別レイアウトの新カード View

## R4: 関連 Wiki チップ — 追加計算不要
`Article.relatedConcepts` は ConceptPage.relatedArticles の inverse として既配線。記事カードで `prefix(3)` を chip 表示、tap で `ConceptPageDetailDestination`。

## R5: MixedSurfaceCard 流用しない
既存 MixedSurfaceCard は KnowledgeDigest 依存 (spec 067 退役対象)。新 FeedItem を作る。

## R6: テスト戦略
FeedBuilderTests (in-memory ModelContainer + now 注入): 空 / merge 時系列 / 更新カード window (古い・本文なし除外) / 写真選択 (記事/借用/nil) / 周期ダイジェスト挿入。

検証: `xcodebuild clean build` + `xcodebuild test -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO`。
