# Implementation Plan: News+ 風フィード

**Branch**: `066-newsplus-feed` | **Date**: 2026-05-31 | **Spec**: [spec.md](./spec.md)

## Summary

「知識 Clip」タブを Apple News+ 風フィードに進化。新 transient `FeedItem` enum + 新 service `FeedBuilder` (純 fetch+merge、AI ゼロ) で記事と Wiki 更新を時系列 mix。新カード View `ArticleFeedCard` / `WikiFeedCard` (写真 = `ArticleEnrichment.ogImageURL` 借用 + 種別アイコン fallback)。`KnowledgeClipView` を 3 セクション → mix LazyVStack に置換。@Model 変更ゼロ = CloudKit 安全。

## Technical Context
- Swift 6 / SwiftUI / SwiftData + CloudKit、@Model 変更なし
- 新規 5 ファイル (FeedItem / FeedBuilder / ArticleFeedCard / WikiFeedCard / FeedBuilderTests) + 改修 4 (KnowledgeClipView / ServiceContainer / KnowledgeTreeApp / xcstrings) + pbxproj (app target のみ)
- Testing: FeedBuilder 純ロジック (merge/sort/写真選択/更新カードガード) を unit test

## Constitution Check
- I privacy: on-device fetch のみ ✅ / II 引き算: 3 セクション → 1 mix で簡素化 ✅ / III source: 記事/Wiki は不変素材、辿れる ✅ / IV iOS: LazyVStack + AsyncImage(ThumbnailView) 標準 ✅ / V calm: AI ゼロ、過多ガード ✅ / VI: @Model 不変、Protocol+DI ✅ / VII 日本語 ✅

## 設計 (Plan エージェント診断ベース)

### R1 FeedItem (transient enum)
`enum FeedItem: Identifiable, Hashable { case article(Article) / wikiUpdate(ConceptPage) / periodicDigest([ConceptPage]); var sortDate: Date }`。id は case 別 (article.id / page.id / "digest-<最古>")。

### R2 FeedBuilder (新 service、@MainActor、AI ゼロ)
- Article を savedAt 降順 fetch (RecentArticlesService パターン)
- ConceptPage を isHidden==false + updatedAt 降順 fetch (FollowingPeopleSection パターン)
- Wiki 更新カード = `updatedAt >= now - wikiUpdateWindowDays(14)` && `!bodyMarkdown.isEmpty (or summary 非空)`
- 2 系列を sortDate で merge → `[FeedItem]`
- 周期ダイジェスト: 一定間隔ごとに periodicDigest を差し込む (例: 先頭 or N 件ごと、最近更新 Wiki 上位束ね) — P2
- now 注入 (`now: () -> Date = { .now }`) でテスト可能

### R3 写真借用 (ArticleEnrichment.ogImageURL、既存 ThumbnailView)
- 記事カード: `article.enrichment?.ogImageURL`
- Wiki カード: `conceptPage.relatedArticles?.compactMap { $0.enrichment?.ogImageURL }.first` (KnowledgeClipCard 先例)
- fallback: `WikiPageKind.symbolName` + カテゴリ色 / 記事は favicon or 色ブロック
- 大判カード用に News+ 風 View 新規 (ThumbnailView は 72x72 固定なので別レイアウト)

### R4 関連 Wiki チップ (Article.relatedConcepts 既存 inverse)
記事カード内に `article.relatedConcepts?.prefix(3)` を capsule chip 表示、tap で ConceptPageDetailDestination 遷移。

### R5 KnowledgeClipView 置換
3 セクション (RecentArticlesSection/InterestingNextSection/FollowingPeopleSection) → `feedBuilder.build()` の `[FeedItem]` を LazyVStack で ForEach。既存 navigationDestination 群 (Article / ConceptPageDetailDestination / 他) 全再利用。pull-to-refresh / deep link 維持。タブ名 `clip.tab.title` value を「フィード」に。

### R6 テスト
FeedBuilderTests: 空 / article+wiki merge 時系列順 / 更新カード window ガード (古い除外/本文なし除外) / 写真選択 (記事 ogImage / Wiki 借用 / fallback nil) / 周期ダイジェスト挿入。

## blast radius
- 新規: Models/FeedItem.swift / Services/FeedBuilder.swift / Views/ArticleFeedCard.swift / Views/WikiFeedCard.swift / KnowledgeTreeTests/FeedBuilderTests.swift
- 改修: Views/KnowledgeClipView.swift / Services/ServiceContainer.swift / KnowledgeTreeApp.swift (feedBuilder 構築+登録, タブ名) / Localizable.xcstrings / project.pbxproj (app target のみ、Share/Safari/Widget 不要)
- 不変: ThumbnailView / ArticleEnrichment / Article・ConceptPage @Model / 全 navigationDestination / RecentArticlesService・RecentDigestService (残置、フィード内で headline 再利用可)

## 検証
- clean build + 全 unit test serial regression
- 実機 (時系列 mix / 写真 / fallback / チップ遷移 / 60fps / 空状態) はユーザー

## Out of Scope
旧モデル退役 (spec 067) / 検索 / @Model 変更
