# Tasks: RecentDigest token 超過修正 + SchemaLoader bundle 同梱

**Branch**: `060-recent-digest-token-fix` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

軽い 2 件、全 US が P1。パス: repo root = `KnowledgeTree/`、app folder = `KnowledgeTree/KnowledgeTree/`。

凡例: `[P]` = 別ファイルで並列可

---

## Phase 1: Setup (Resources 同梱)

- [x] **T001 [P]** `KnowledgeTree/Resources/` 作成 + `docs/iknow-schema.md` を `KnowledgeTree/Resources/iknow-schema.md` にコピー
  - `mkdir -p KnowledgeTree/Resources && cp docs/iknow-schema.md KnowledgeTree/Resources/iknow-schema.md`
  - synchronized root group ゆえ自動メンバーシップ。docs/ 側は人間用に残置

---

## Phase 2: US1 (P1-10) RecentDigest token 削減

**Goal**: buildPrompt の token を 4096 未満に抑え、AI ヘッドライン生成を成功させる。
**Independent Test**: 50 件 Article で `buildPrompt().count` ≤ 3500、9 件目以降が prompt に非含有。

- [x] **T002 [P] [US1]** `KnowledgeTree/Services/RecentDigestService.swift` buildPrompt 改修
  - `static let promptArticleLimit = 8` + `static let promptCharBudget = 3000` 追加
  - buildPrompt 冒頭で `let promptArticles = Array(articles.prefix(promptArticleLimit))`
  - ループ内で entry 組み立て → `if prompt.count + entry.count > promptCharBudget { break }`
  - per-article 圧縮: essence `prefix(60)`→`prefix(50)`、firstFact `prefix(30)`→`prefix(20)`
  - 固定ヘッダの「件数 \(articles.count)」は維持 (FR-005)
  - contract: contracts/recent-digest-token.md
- [x] **T003 [US1]** `KnowledgeTreeTests/RecentDigestServiceTests.swift` に 2 ケース追加
  - `testBuildPromptStaysUnderCharBudget`: 50 件 (各 title/essence 長め) で `buildPrompt(articles:).count <= 3500`
  - `testBuildPromptLimitsArticleCount`: 9 件目以降の固有 title が prompt に非含有

**Checkpoint**: build SUCCEEDED、新 2 ケース PASS。

---

## Phase 3: US2 (SchemaLoader) bundle 同梱検証

**Goal**: iknow-schema.md がアプリ bundle に入り、SchemaLoader.load() が成功する。
**Independent Test**: ビルド成果物に iknow-schema.md が存在。

- [x] **T004 [US2]** bundle 同梱をビルド検証 (T001 後)
  - clean build 後 `find <DerivedData>/.../KnowledgeTree.app -name "iknow-schema.md"` で同梱確認
  - 万一 .md が Compile Sources に誤分類 → `KnowledgeTree.xcodeproj/project.pbxproj` に `PBXFileSystemSynchronizedBuildFileExceptionSet` で Resources 明示 (通常不要)
  - SchemaLoader.swift は無改修
  - contract: contracts/schema-bundle.md

**Checkpoint**: `find` で iknow-schema.md ヒット。

---

## Phase 4: Polish & 検証

- [x] **T005** clean build (iPhone 17 Simulator)、本 spec 由来 warning ゼロ + bundle に iknow-schema.md 確認
- [x] **T006** 全 unit test serial regression PASS (`-only-testing:KnowledgeTreeTests -parallel-testing-enabled NO`)
- [x] **T007** 静的検証: `ls Resources/iknow-schema.md` + `rg "promptArticleLimit|promptCharBudget" RecentDigestService.swift`
- [x] **T008** `CLAUDE.md` に spec 060 を 🔧 実装完了で追記
- [ ] **T009** 実機検証 (ユーザー、SC-002 ヘッドライン表示 + token 超過ログ消失 / SC-003 bundle load ログ)

---

## 依存グラフ

```
T001 (Resources copy) ── T004 (bundle 検証)
T002 (buildPrompt) ── T003 (test)
全実装 (T001-T004) → T005 → T006 → T007 → T008 → T009 (ユーザー)
```

## 並列例

- **T001 / T002** 並列 (別ファイル、独立)

## 実装戦略

- 両 US が P1。T001+T002 を並列着手 → T003 (test) / T004 (bundle 検証) → Polish。
- 本セッションは T001-T008 (build + unit test + static)、T009 実機検証はユーザー。
- 最終 commit はユーザー指示後。
