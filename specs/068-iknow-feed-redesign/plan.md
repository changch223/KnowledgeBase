# Implementation Plan: iKnow タブ 自然 mix フィード + inline おすすめ carousel

**Branch**: `068-iknow-feed-redesign` | **Date**: 2026-06-06 | **Spec**: [spec.md](./spec.md)

## Summary

iKnow タブを App Store Today 風に再設計。縦フィード (記事+Wiki 時系列 mix、見出し無し) の途中に横スクロール「おすすめ」carousel (recommend 5、記事+Wiki 混在) を挿入。AI 処理中の記事は除外。タブ名「フィード」→「iKnow」。@Model 変更ゼロ + AI 呼び出しゼロ (純 fetch + 数値スコア)。

## Technical Context
- Swift 6 / SwiftUI / SwiftData + CloudKit、@Model 変更なし
- 改修: KnowledgeClipView (carousel 挿入 + 見出し除去) / FeedBuilder (AI 処理中除外 + recommend 純関数追加) / xcstrings (iKnow 文言) / KnowledgeTreeApp (タブ名は xcstrings 値変更で自動)
- 新規: ArticleShelfCard / WikiShelfCard (横用コンパクトカード) / RecommendCarousel + FeedBuilderTests に recommend ケース
- Testing: recommend 純関数 (Wiki スコア / 記事スコア / top5 / AI 処理中除外) を unit test

## Constitution Check
- I privacy: on-device fetch のみ ✅ / II 引き算: 見出し除去で簡素化 ✅ / III source: 記事/Wiki 不変素材 ✅ / IV iOS: LazyHStack + AsyncImage 標準 ✅ / V calm: AI ゼロ + 処理中非表示 ✅ / VI: @Model 不変、純関数 ✅ / VII 日本語 ✅

## 設計

### R1 AI 処理中除外 (FR-003)
`FeedBuilder.assemble` の article filter に追加: `article.extractedKnowledge?.status == .succeeded || == .partiallySucceeded`。pending/processing/failed/nil は除外。Wiki 側は既存 (本文/要約あり) ガード継続。

### R2 recommend 純関数 (FR-005/006)
```swift
static func recommend(articles: [Article], wikiPages: [ConceptPage], now: Date, limit: Int = 5) -> [FeedItem]
```
- Wiki スコア = `relatedArticles.count * wikiArticleWeight(2.0)` + 最近更新ボーナス (`updatedAt` が新しいほど高、14日減衰)
- 記事スコア = 新しさ (savedAt が新しいほど高)、succeeded のみ
- 両者を Double スコア軸で sort desc、上位 limit を FeedItem 化
- AI 呼び出しゼロ、now 注入でテスト可

### R3 横用コンパクトカード (FR-004/008)
- `ArticleShelfCard` (写真上 ~150x100 + タイトル 2行) / `WikiShelfCard` (借用写真 or kind アイコン + 名前 + 種別バッジ)
- NavigationLink で各 destination (既存 Article / ConceptPageDetailDestination)

### R4 carousel 挿入 (FR-004/009)
KnowledgeClipView の縦 LazyVStack の固定位置 (例: index 3 の後) に `RecommendCarousel` (ScrollView(.horizontal) { LazyHStack { ShelfCard } }) を挿入。重複除外なし (FR-009)。候補 < 閾値 (例 3) なら非表示。

### R5 見出し除去 + タブ名 (FR-001/002)
- KnowledgeClipView は既に見出し無し縦 mix (spec 066) → carousel 挿入のみ
- xcstrings `clip.tab.title` 「フィード」→「iKnow」、`clip.nav.title` も「iKnow」

### R6 テスト
FeedBuilderTests に: recommend Wiki スコア優先 / 記事新しさ / top5 cap / AI 処理中除外 (assemble) / recommend が pending 記事を除く。

## blast radius
- 改修: Views/KnowledgeClipView.swift / Services/FeedBuilder.swift / Localization/Localizable.xcstrings
- 新規: Views/ArticleShelfCard.swift / Views/WikiShelfCard.swift / Views/RecommendCarousel.swift / FeedBuilderTests 拡張
- 不変: FeedItem / ArticleFeedCard / WikiFeedCard / 全 @Model / navigationDestination
- pbxproj: 新 3 View は app target file-system-synchronized で自動

## 検証
- clean build + 全 unit test serial regression
- 実機 (処理中非表示 / carousel / recommend 順 / 60fps / 遷移) はユーザー

## Out of Scope
旧 section view 削除 / 学習導線復活 / AI 推薦 / @Model 変更
