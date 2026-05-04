# Contract: TagStore + TagNormalizer

**Files**:
- `KnowledgeTree/Services/TagStore.swift` (新規)
- `KnowledgeTree/Services/TagNormalizer.swift` (新規)

## TagNormalizer

### 責務
タグ名の正規化を行う純粋関数。Tag インスタンス生成 / 保存前に必ず通す。

### API

```swift
struct TagNormalizer {
    /// 正規化:
    /// 1. trim whitespacesAndNewlines
    /// 2. lowercased() (Locale.current ではなく invariant)
    /// 3. 50 文字超は prefix 50
    /// 4. 結果が空なら nil
    static func normalize(_ raw: String) -> String?
}
```

### 不変条件

1. 戻り値は `nil` または非空文字列
2. 戻り値は trim 済 (前後空白なし)
3. 戻り値は lowercased
4. 戻り値の `count <= 50`

### テストケース

```swift
@Test("空文字列は nil")
func emptyReturnsNil()

@Test("空白のみは nil")
func whitespaceOnlyReturnsNil()

@Test("trim + lowercase")
func trimsAndLowercases()

@Test("50 文字超は prefix")
func truncatesTo50()

@Test("絵文字は保持")
func preservesEmoji()

@Test("CJK 文字は保持")
func preservesCJK()

@Test("全角空白も trim")
func trimsFullwidthSpace()

@Test("OAuth と oauth と OAUTH は同一に正規化")
func sameTagDifferentCase()
```

---

## TagStore

### 責務
Article への Tag 追加・削除、タグマスタの管理 (孤児削除)。SwiftData ModelContext を経由。

### API

```swift
@MainActor
final class TagStore {
    let context: ModelContext
    let refreshTrigger: RefreshTrigger?

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil)

    /// raw タグ名を正規化して article に追加。重複なら no-op。
    /// - Returns: 正規化後の name (添加成功 / 既存) または nil (空文字列等)
    @discardableResult
    func addTag(rawName: String, to article: Article) throws -> String?

    /// 正規化済 name で article から tag を除去。tag.articles が空になったら削除。
    func removeTag(normalizedName: String, from article: Article) throws

    /// 全 Tag を name asc で fetch (タグ一覧画面用)
    func fetchAllTags() throws -> [Tag]

    /// 孤児 tag (articles 空) を一括 cleanup (bootstrap 時に呼ぶ等)
    func cleanupOrphans() throws
}
```

### 動作詳細

#### addTag(rawName:to:)

```swift
func addTag(rawName: String, to article: Article) throws -> String? {
    guard let normalized = TagNormalizer.normalize(rawName) else {
        return nil
    }
    // 既存 tag を fetch (unique 制約あり)
    var descriptor = FetchDescriptor<Tag>(
        predicate: #Predicate<Tag> { $0.name == normalized }
    )
    descriptor.fetchLimit = 1
    let existing = try context.fetch(descriptor).first

    let tag: Tag
    if let existing {
        tag = existing
    } else {
        tag = Tag(name: normalized)
        context.insert(tag)
    }

    // 重複チェック (article.tags に既に同 tag あり)
    if !article.tags.contains(where: { $0.name == normalized }) {
        article.tags.append(tag)
    }

    try context.save()
    refreshTrigger?.bump()
    return normalized
}
```

#### removeTag(normalizedName:from:)

```swift
func removeTag(normalizedName: String, from article: Article) throws {
    guard let tag = article.tags.first(where: { $0.name == normalizedName }) else {
        return  // no-op
    }
    article.tags.removeAll { $0.name == normalizedName }
    if tag.articles.isEmpty {
        context.delete(tag)
    }
    try context.save()
    refreshTrigger?.bump()
}
```

#### fetchAllTags

```swift
func fetchAllTags() throws -> [Tag] {
    var descriptor = FetchDescriptor<Tag>(
        sortBy: [SortDescriptor(\.name, order: .forward)]
    )
    return try context.fetch(descriptor)
}
```

#### cleanupOrphans

```swift
func cleanupOrphans() throws {
    let allTags = try fetchAllTags()
    let orphans = allTags.filter { $0.articles.isEmpty }
    for tag in orphans {
        context.delete(tag)
    }
    if !orphans.isEmpty {
        try context.save()
        refreshTrigger?.bump()
    }
}
```

### 不変条件

1. addTag(rawName:) で raw が空 / 空白のみ → nil 返却、副作用無し
2. addTag は同 article への重複追加で no-op
3. removeTag は存在しない tag に対して no-op
4. tag.articles.isEmpty なら addTag/removeTag のいずれかで自動削除 (両方とも save 時にチェック)
5. addTag / removeTag 完了時、refreshTrigger.bump() で UI に伝播

### テストケース

```swift
@Test("addTag 新規 tag 作成 + article 紐付け")
func addNewTag()

@Test("addTag 既存 tag を再利用")
func addExistingTag()

@Test("addTag 同 article への重複は no-op")
func addDuplicateNoOp()

@Test("addTag 空文字列は nil 返却")
func addEmptyReturnsNil()

@Test("addTag 大文字混入は正規化")
func addNormalizesCase()

@Test("removeTag 関連付け解除 + 孤児なら削除")
func removeAndCleanup()

@Test("removeTag 他 article で参照中なら tag は残る")
func removeKeepsTagForOthers()

@Test("removeTag 存在しないタグは no-op")
func removeNonexistentNoOp()

@Test("fetchAllTags は name 昇順")
func fetchAllSorted()

@Test("cleanupOrphans が孤児を削除")
func cleanupOrphans()
```
