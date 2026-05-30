# Quickstart: WikiPage 土台 検証

## ビルド & unit test (このセッション担保)

```bash
cd /Users/changchiawei/Desktop/KnowledgeTree
xcodebuild clean build -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO
```

## 静的検証

```bash
# 4 フィールド追加
rg "bodyMarkdown|kindRaw|isHidden|bodyEditedByUser" KnowledgeTree/Models/ConceptPage.swift
# plain string 生成
rg "generateWikiBody" KnowledgeTree/Services/LanguageModelSessionProtocol.swift
# SharedSchema 無改修 (ConceptPage のみ、新 @Model なし)
rg "WikiPage" KnowledgeTree/SharedSchema.swift && echo "NG: 新 @Model 混入" || echo "OK: schema 無改修"
# isHidden フィルタ
rg "isHidden" KnowledgeTree/Views/FollowingPeopleSection.swift KnowledgeTree/Views/KnowledgeClipView.swift
```

## 実機検証シナリオ (ユーザー後追い)

| SC | シナリオ | 期待 |
|---|---|---|
| SC-001 | 複数記事が紐づく概念ページ詳細を開く | 要約の下に Markdown 整形本文 (見出し・箇条書き) |
| SC-002 | 記事保存 → bodyMarkdown 生成 | Xcode ログに `exceededContextWindowSize` 出ない、本文生成成功 |
| SC-003 | 人物ページ / 概念ページを開く | 種別バッジ (人物 / 概念) 表示 |
| SC-004 | 本文を編集保存 → 再度記事保存で再生成トリガ | 編集本文が消えない (bodyEditedByUser 保護) |
| SC-005 | ページを非表示 | 一覧・FollowingPeopleSection から消える |
| SC-006 | アップデート後、既存の概念ページを開く | 破綻せず表示 (本文は空 → 次回生成で埋まる) |

## 既存回帰チェック

- ConceptSynthesis: summary 生成 / crossSourceInsights / isStale フロー不変
- ConceptPageDetailView: 既存 5 セクション (summary / insights / 関連記事 / SavedAnswer / 関連概念) 維持
- ConceptPageStore: rename / merge / delete 不変
