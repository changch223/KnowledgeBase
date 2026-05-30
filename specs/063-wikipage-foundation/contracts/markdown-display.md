# Contract: Markdown 表示 + 訂正 + 非表示フィルタ (R5/R6/R7)

## R5: ConceptPageDetailView (表示)
- summary セクション下に bodyMarkdown を Markdown 整形表示
```swift
if !conceptPage.bodyMarkdown.isEmpty {
    // AttributedString(markdown:) の見出し対応を検証。
    // full parsing で不足なら行分割簡易レンダラ (見出し行 = font 変更)。
    Text(renderedWikiBody(conceptPage.bodyMarkdown))
}
```
- header に kind バッジ (kind.symbolName + 種別名)
- toolbar に isHidden トグル → 非表示で dismiss
- bodyMarkdown 空なら summary のみ (破綻しない、SC-001 シナリオ 2)

## R6: ConceptPageEditSheet (訂正)
- bodyMarkdown 編集 TextEditor
- kind 編集 Picker (WikiPageKind.allCases)
- 保存時 `bodyEditedByUser = true` (FR-007)

## R7: isHidden フィルタ
- ConceptPageListView (KnowledgeClipView 内) + FollowingPeopleSection の @Query:
```swift
@Query(filter: #Predicate<ConceptPage> { !$0.isHidden }, sort: ...)
```

## 契約条件
| 条件 | 期待 |
|---|---|
| bodyMarkdown あり | 見出し・箇条書き整形表示 (SC-001) |
| kind | バッジ表示 (SC-003) |
| 本文編集→保存 | 詳細反映 + bodyEditedByUser=true (SC-004) |
| 非表示トグル | 一覧から消える、データ残る (SC-005) |
| AttributedString 失敗 | plain text fallback (クラッシュなし) |

## 実装メモ
- iOS の `AttributedString(markdown:)` は見出し (`#`) を限定対応。`interpretedSyntax: .full` でも段落主体。spec の見出し・箇条書きを満たすため、実装時に full parsing の出力を確認 → 不足なら bodyMarkdown を改行分割して見出し行を判定する簡易レンダラ (純粋関数、unit test 可) を検討。
