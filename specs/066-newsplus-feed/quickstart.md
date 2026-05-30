# Quickstart: News+ 風フィード 検証

## ビルド & unit test
```bash
cd /Users/changchiawei/Desktop/KnowledgeTree
xcodebuild clean build -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO
```

## 静的検証
```bash
rg "struct FeedItem|FeedBuilder|ArticleFeedCard|WikiFeedCard" KnowledgeTree/
rg "wikiUpdateWindowDays" KnowledgeTree/Services/FeedBuilder.swift
git diff --stat KnowledgeTree/Models/ConceptPage.swift KnowledgeTree/Models/Article.swift  # @Model 差分なしが正
```

## 実機検証シナリオ (ユーザー後追い)
| SC | シナリオ | 期待 |
|---|---|---|
| SC-001 | フィードを開く | 記事と Wiki が時系列 mix 表示 |
| SC-002 | 記事/Wiki カード tap | 各詳細へ遷移 |
| SC-003 | 画像のある記事/Wiki | 写真表示 |
| SC-004 | 画像なしカード | 種別アイコン+色 fallback、崩れず |
| SC-005 | 古い/本文なし Wiki | 更新カードに出ない (過多なし) |
| SC-006 | 記事カードの関連 Wiki チップ tap | 概念詳細へ |
| SC-008 | 高速スクロール | 60fps、画像遅延ロード |

## 既存回帰
- pull-to-refresh / deep link / タブ遷移 / ライブラリ・AI チャットタブ
- 064/065 (関連リンク / AI 削減) は別ブランチ PR #22 で検証済
