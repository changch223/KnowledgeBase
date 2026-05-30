# Contract: ConceptPage 4 フィールド追加 + WikiPageKind (R1/R2)

## 対象
- `KnowledgeTree/Models/ConceptPage.swift`

## 追加フィールド (init 引数も追加、全 default)
```swift
var bodyMarkdown: String = ""
var kindRaw: String = "concept"
var isHidden: Bool = false
var bodyEditedByUser: Bool = false
```

## WikiPageKind enum + computed
```swift
enum WikiPageKind: String, CaseIterable {
    case person, concept, project
    var displayNameKey: String { "wiki.kind.\(rawValue)" }
    var symbolName: String {
        switch self { case .person: "person.fill"; case .concept: "lightbulb.fill"; case .project: "folder.fill" }
    }
}
extension ConceptPage {
    var kind: WikiPageKind {
        get { WikiPageKind(rawValue: kindRaw) ?? .concept }
        set { kindRaw = newValue.rawValue }
    }
}
```

## 契約条件
| 条件 | 期待 |
|---|---|
| 既存 ConceptPage を load | 新フィールドは default 値、破綻なし (CloudKit safe, SC-006) |
| SharedSchema.swift | 無改修 (ConceptPage 登録済) |
| kindRaw 不正値 | kind は .concept に fallback |
| init 後方互換 | 既存呼び出し (新引数なし) が default で通る |
