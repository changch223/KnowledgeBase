# Quickstart: Wiki ページ相互リンク + 関係発見 検証

## ビルド & unit test (このセッション担保)
```bash
cd /Users/changchiawei/Desktop/KnowledgeTree
xcodebuild clean build -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO
```

## 静的検証
```bash
rg "nearestConceptIDs|sanitizeConceptLinks" KnowledgeTree/Services/ConceptSynthesisService.swift
rg "extractConceptID|onConceptLinkTap" KnowledgeTree/Views/ConceptPageDetailView.swift
rg "concept-id" KnowledgeTree/Resources/iknow-schema.md
# @Model 変更ゼロ確認
git diff --stat KnowledgeTree/Models/ConceptPage.swift   # → 差分なしが正
```

## 実機検証シナリオ (ユーザー後追い)
| SC | シナリオ | 期待 |
|---|---|---|
| SC-001 | 関連する概念ページが複数ある状態で 1 つ開く | 「つながる人物・モノ」に関連ページ表示 |
| SC-002 | 記事取り込み時のログ | embedding 補完で AI 呼び出しなし |
| SC-003 | 本文に他ページ名を含む概念ページを開く | 名前がリンク表示、tap で該当ページ遷移 |
| SC-004 | AI が存在しないリンクを書いた場合 | プレーンテキスト化、dead link なし |
| SC-006 | リンク先を削除後に tap | crash しない |

## 既存回帰
- WikiBodyGenerationTests (spec 063) / ConceptSynthesisServiceTests / ConceptPageStoreTests
- relatedConceptsSection 表示 / merge 時の relatedConceptIDs 整合
