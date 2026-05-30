# Research: RecentDigest token 超過修正 + SchemaLoader bundle 同梱

行番号は 2026-05-30 main @ `9e43f2f` 時点。

---

## R1: P1-10 RecentDigest.buildPrompt token 削減

**Decision**: `buildPrompt(articles:)` を 3 段で縮小:
1. **prompt 件数上限** `promptArticleLimit = 8`: ループ前に `let promptArticles = Array(articles.prefix(promptArticleLimit))`。
2. **token 概算ガード**: ループ内で累積 `prompt.count` を見積もり、安全上限 `promptCharBudget = 3000` 超過で `break`。
3. **per-article 圧縮**: `essence.prefix(60)` → `prefix(50)`、`firstFact.prefix(30)` → `prefix(20)`。

**現状 (verified)**:
- `RecentDigestService.swift:45` `maxArticles = 30`
- `:195` `static func buildPrompt(articles:)` が `for (i, article) in articles.enumerated()` で **全件**列挙
- 各記事: `title.prefix(50)` + `essence.prefix(60)` + `firstFact.prefix(30)` + ラベル ≈ 160 字 → 30 件で ~4800 字 ≈ 4089+ token

**Rationale**:
- 出力は「1 文ヘッドライン + テーマ 3 個」のみ → 30 件詳細は過剰。最新 8 件で代表性十分。
- token 概算ガードは「1 記事の essence が異常に長い」エッジ (Edge Cases) も吸収。
- `maxArticles=30` は `articleCount` 表示・差分判定に使われるため維持。prompt 構築だけ絞る → FR-005 (既存挙動不変) 準拠。
- 8 件 × ~130 字 + 固定文 ~400 字 ≈ 1440 字 ≈ 安全に 4096 未満。

**Alternatives considered**:
- per-article 圧縮のみ (件数据え置き) → 30 件 × 100 字 = 3000 字でギリギリ、安全マージン不足。件数削減が本質。
- 階層要約 (chunk して再要約) → ヘッドライン 1 文には過剰、複雑度増。却下。

**実装メモ**: signature 維持 (`articles: [Article]`)。内部で prefix。`promptArticleLimit` / `promptCharBudget` は `private static let` or テスト可視性のため `static let`。

---

## R2: SchemaLoader bundle 同梱

**Decision**: `docs/iknow-schema.md` を `KnowledgeTree/Resources/iknow-schema.md` にコピー。SchemaLoader.load() は無改修。

**現状 (verified)**:
- `SchemaLoader.swift:25` `Bundle.main.url(forResource: "iknow-schema", withExtension: "md")` → 常に nil
- `docs/iknow-schema.md` (6121 chars) は存在するが `docs/` はアプリ target 非所属
- pbxproj: app root group `path = KnowledgeTree` は **PBXFileSystemSynchronizedRootGroup** (line 290)

**Rationale**:
- synchronized root group ゆえ `KnowledgeTree/Resources/` 配下の新規ファイルは自動でターゲットメンバーシップ取得。
- `.md` は Xcode のデフォルトビルドルールで「Copy Bundle Resources」に分類される (コンパイル対象でないため) → `Bundle.main.url(forResource:)` が成功。
- SchemaLoader.load() / section(named:) / fallback は全て無改修。bundle に入るだけで `.bundle` source になる。
- `docs/iknow-schema.md` は人間用ドキュメントとして残置 (Resources/ がアプリ SSOT)。内容同一コピー。

**Alternatives considered**:
- `docs/iknow-schema.md` を直接 target に追加 → docs/ は synchronized group 外で pbxproj 個別参照が必要、保守性低。Resources/ コピーが素直。
- SchemaLoader に Bundle 注入 + test fixture → テスト可能性は上がるが本 spec の目的 (実 bundle 同梱) には不要。Out of Scope。

**実装メモ**:
- `mkdir KnowledgeTree/Resources/` → `cp docs/iknow-schema.md KnowledgeTree/Resources/`
- ビルド後 `find <DerivedData>/.../KnowledgeTree.app -name "iknow-schema.md"` で同梱確認。
- 万一 .md が Compile Sources に誤分類された場合のみ pbxproj に `PBXFileSystemSynchronizedBuildFileExceptionSet` で Resources 明示 (通常不要)。

---

## R3: テスト戦略

**Decision**:
- **RecentDigestServiceTests** (既存 13 ケース) に buildPrompt 上限ガード 2 ケース追加:
  - `testBuildPromptStaysUnderCharBudget`: 50 件 Article (各 title/essence 長め) でも `buildPrompt(articles:).count` が安全上限 (3500 字) 以内。
  - `testBuildPromptLimitsArticleCount`: 記事 9 件目以降のユニークな title が prompt に含まれない (promptArticleLimit=8 検証)。
  - 既存 `testGenerateTruncatesTo30Articles` (articleCount=30) は maxArticles 不変ゆえ regression なし。
- **SchemaLoaderTests** (既存 4 ケース): test bundle (`Bundle.main` = xctest) には iknow-schema.md が無いため実 bundle load の unit 検証は困難 → 既存 fallback テスト維持。実 bundle load は実機/起動ログ (SC-003) で確認。

**Rationale**: buildPrompt が `static func` でテスト直呼び可能。token 超過の本質 (prompt 文字数) を直接 assert できる。SchemaLoader は production の bundle 同梱が目的で、unit より起動ログ検証が確実。

**検証コマンド**:
```bash
xcodebuild clean build -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'
# bundle 同梱確認
find ~/Library/Developer/Xcode/DerivedData/KnowledgeTree-*/Build/Products/Debug-iphonesimulator/KnowledgeTree.app -name "iknow-schema.md"
xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO
```
