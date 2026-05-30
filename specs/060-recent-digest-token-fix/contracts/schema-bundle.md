# Contract: SchemaLoader bundle 同梱 (R2)

## 対象

- 新規 `KnowledgeTree/Resources/iknow-schema.md` (docs/iknow-schema.md のコピー)
- `KnowledgeTree/Services/SchemaLoader.swift` (**無改修**)
- `KnowledgeTree.xcodeproj/project.pbxproj` (synchronized group ゆえ通常自動、要ビルド検証)

## 変更

```bash
mkdir -p KnowledgeTree/Resources
cp docs/iknow-schema.md KnowledgeTree/Resources/iknow-schema.md
```

`SchemaLoader.load()` の `Bundle.main.url(forResource: "iknow-schema", withExtension: "md")` が bundle 同梱により成功するようになる (コード変更なし)。

## 契約条件

| 条件 | 期待 |
|---|---|
| ビルド成果物 | `KnowledgeTree.app/iknow-schema.md` が存在する |
| 起動時 SchemaLoader.load() | `.bundle` source で load 成功、ログ「loaded iknow-schema.md from bundle」(SC-003) |
| 「not in bundle」ログ | 出ない (SC-003) |
| bundle load 失敗時 (将来の破損等) | code fallback `.fallback` で安全動作 (無改修、FR-007) |
| docs/iknow-schema.md | 人間用に残置 (削除しない) |
| .md のビルド分類 | Copy Bundle Resources (Compile Sources でない)。誤分類時のみ pbxproj exception |

## テスト

- unit: test bundle に .md が無いため実 bundle load 検証は困難 → 既存 SchemaLoaderTests (fallback) 維持。
- 実機/シミュレータ: 起動ログ SC-003 で確認。
- ビルド: `find <app> -name iknow-schema.md` で同梱確認。
