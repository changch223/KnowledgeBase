# Contract: 関係発見 embedding 補完 (Phase 1 / R1)

## 対象
- `KnowledgeTree/Services/ConceptSynthesisService.swift` (resynthesize + nearestConceptIDs)

## nearestConceptIDs
```swift
func nearestConceptIDs(for page: ConceptPage, in context: ModelContext) -> [UUID]
```
- page.embedding → `.asFloatArray`、nil なら `[]` return (FR-008)
- 全 ConceptPage fetch (isHidden==false、self 除外、embedding あり)
- `EmbeddingService.cosineSimilarity` で類似度、`>= relatedConceptThreshold (0.5)`、降順 `prefix(relatedConceptLimit=8)` の id

## resynthesize 挿入 (embedding 再生成後、generateBodyMarkdown 前)
```swift
let neighborIDs = nearestConceptIDs(for: conceptPage, in: context)
conceptPage.relatedConceptIDs = Array(Set(conceptPage.relatedConceptIDs + neighborIDs))
```

## 契約条件
| 条件 | 期待 |
|---|---|
| 近いページあり | relatedConceptIDs に追加 (SC-001) |
| embedding なし | スキップ、既存値維持 (FR-008) |
| AI 呼び出し | ゼロ (FR-002 / SC-002) |
| self / isHidden | 除外 |
| 既存 relatedConceptIDs | union で保全 (LintEngine/merge と非干渉) |
