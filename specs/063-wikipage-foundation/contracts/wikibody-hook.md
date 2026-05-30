# Contract: bodyMarkdown 生成 hook + kind 判定 (R4)

## 対象
- `KnowledgeTree/Services/ConceptSynthesisService.swift` (`resynthesize`)

## 生成ロジック (summary 生成後に追加)
```
1. if conceptPage.bodyEditedByUser { skip bodyMarkdown 生成 }   // FR-007 訂正保護
2. else if availability.isAvailable {
     prompt = buildWikiBodyPrompt(conceptPage, relatedArticles)  // summary + 圧縮 essence
     do {
       body = try await session.generateWikiBody(prompt: prompt)
       if !body.trimmed.isEmpty { conceptPage.bodyMarkdown = body }
       // 空なら既存保持 (防御)
     } catch { /* fallback へ */ }
   }
3. fallback: bodyMarkdown が空なら summary を流用
4. kind 判定: if !bodyEditedByUser (kind 未編集) { conceptPage.kind = inferKind(relatedArticles) }
```

## kind 判定
```
relatedArticles → extractedKnowledge → entities の type 集計
person/organization 優勢 → .person
それ以外 → .concept
(project は当面なし、将来拡張)
```

## buildWikiBodyPrompt
- 入力: conceptPage.name + summary + relatedArticles の essence (既存圧縮定数で truncate)
- schema.md の Wiki 本文ルール (SchemaLoader.section) を prompt に embed
- token: 入力上限を設け hierarchical 経路でも 4096 内

## 契約条件
| 条件 | 期待 |
|---|---|
| availability あり + 成功 | bodyMarkdown に AI 本文 (SC-001) |
| availability なし | summary を bodyMarkdown に (SC-002 fallback) |
| bodyEditedByUser=true | 生成スキップ、既存維持 (SC-004) |
| 空 AI 出力 | 既存 bodyMarkdown 保持 |
| token | 超過しない (plain string + 入力圧縮、SC-002) |
| summary 生成 | 不変 (既存 regression) |
