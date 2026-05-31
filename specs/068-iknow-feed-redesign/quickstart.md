# Quickstart: iKnow タブ 自然 mix フィード 検証

## ビルド & unit test
```bash
cd /Users/changchiawei/Desktop/KnowledgeTree
xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO
```

## 静的検証
```bash
rg "func recommend|partiallySucceeded|\.succeeded" KnowledgeTree/Services/FeedBuilder.swift
rg "RecommendCarousel|ArticleShelfCard|WikiShelfCard" KnowledgeTree/Views/
python3 -c "import json;d=json.load(open('KnowledgeTree/Localization/Localizable.xcstrings'));print(d['strings']['clip.tab.title']['localizations']['ja']['stringUnit']['value'])"  # → iKnow
git diff --stat KnowledgeTree/Models/  # @Model 差分なしが正
```

## 実機検証シナリオ (ユーザー後追い)
| SC | シナリオ | 期待 |
|---|---|---|
| SC-001 | iKnow タブを開く | 記事+Wiki が見出し無しで時系列 mix |
| SC-002 | 記事保存直後 → 完了後 | 処理中は出ず、完了後に現れる |
| SC-003 | フィードをスクロール | 途中に横スクロール carousel |
| SC-004 | carousel | 関連記事多+最近更新の Wiki が上位 |
| SC-006 | カード tap | 各詳細遷移 |
| - | 高速スクロール | 60fps |

## 既存回帰
- FAB / deep link / pull-to-refresh / タブ遷移
- ArticleFeedCard / WikiFeedCard (縦用) 表示
