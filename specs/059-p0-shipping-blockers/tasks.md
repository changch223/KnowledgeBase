# Tasks: Sprint 1 P0 出荷ブロッカー修正

**Branch**: `059-p0-shipping-blockers` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

全 User Story が P1 (出荷必須)。P0 単位で phase 分割、各 phase は独立して実装・検証可能。
パス: repo root = `KnowledgeTree/`、app folder = `KnowledgeTree/KnowledgeTree/`。

凡例: `[P]` = 別ファイルで並列可 / `[任意]` = optional

---

## Phase 1: Setup (xcstrings)

- [x] **T001** `KnowledgeTree/Localization/Localizable.xcstrings` に 12 文言追加 ✅
  - `list.empty.instruction` = 「Safari で記事を開いて「共有」→ iKnow で保存できます」 (P0-1)
  - `onboarding.page1.title`/`.body` 〜 `onboarding.page4.title`/`.body` (8 文言、P0-2)
  - `onboarding.skip` / `onboarding.next` / `onboarding.start` (3 文言、P0-2)
  - Page 4 body は現行導線文言 (contracts/onboarding-localization.md 参照)
  - 全 ja value、key は dot-notation

**Checkpoint**: xcstrings 追加完了、key 命名が既存規則と整合。

---

## Phase 2: US1 (P0-1) ライブラリ空状態 placeholder 解消

**Goal**: 空状態に「アプリ名」ではなく「iKnow」を表示。
**Independent Test**: 記事ゼロで空状態 → 「iKnow」表示、「アプリ名」0 箇所。

- [x] **T002** `KnowledgeTree/Views/EmptyStateView.swift:28` を `Text("list.empty.instruction")` に置換 ✅
  - 既存 accessibilityIdentifier `articleListEmpty`、entrance animation / bob は無改修
  - contract: contracts/empty-state-localization.md

**Checkpoint**: `rg "アプリ名" Views/EmptyStateView.swift` → 0 hit。

---

## Phase 3: US2 (P0-2) Onboarding 廃止タブ案内修正

**Goal**: Page 4 を現行導線へ、全 4 ページ xcstrings 化。
**Independent Test**: onboarding 全ページに「学習タブ」「AIブレイン」0 箇所、Page 4 が現行導線案内。

- [x] **T003** `KnowledgeTree/Views/OnboardingView.swift` の `pages` 配列を xcstrings key 化 + Page 4 書き換え ✅ (LocalizedStringKey 化 + onboarding.page.N id)
  - `OnboardingPage.title`/`.body` を `Text(LocalizedStringKey)` 表示に
  - Page 4 body: 「『知識 Clip』タブの『続きが気になる』から、AI 家庭教師と対話して理解を深められます。…」
  - [任意] 各ページ root に `accessibilityIdentifier("onboarding.page.\(index)")`
  - スキップ/次へ/はじめる ボタン文言も key 化、既存 id `onboarding.skip`/`onboarding.next` 維持
  - contract: contracts/onboarding-localization.md

**Checkpoint**: `rg "学習タブ|AIブレイン" Views/OnboardingView.swift` → 0 hit。

---

## Phase 4: US3 (P0-3) Settings 重複 iCloud Section 削除

**Goal**: iCloud Section 1 つのみ、旧 placeholder 削除。
**Independent Test**: Settings に iCloud Section 1 つ、「近日対応」0 箇所、toggle/alert/banner 維持。

- [x] **T004 [P]** `KnowledgeTree/Views/SettingsView.swift:198-216` 旧 placeholder Section を削除 ✅
  - 動作する toggle (:54-101) / 確認 alert (:311-329) / restartBanner は無改修
  - 前後 Section 区切りが壊れないこと、未使用化文言の残骸無しを確認
  - contract: contracts/settings-icloud-cleanup.md

**Checkpoint**: `rg "settings.icloud.placeholder|近日対応" Views/SettingsView.swift` → 0 hit。

---

## Phase 5: US4 (P0-4) Chat 引用リンク navigation 配線 ★肝

**Goal**: 引用リンク tap で ArticleDetailView へ遷移。
**Independent Test**: 引用付き回答のリンク tap → 記事詳細表示、該当なしでクラッシュなし。

- [x] **T005 [P]** `KnowledgeTree/Views/ChatMessageRow.swift` に callback 追加 ✅
  - `var onArticleLinkTap: ((Article) -> Void)? = nil` prop 追加
  - OpenURLAction の `_ = article` を `onArticleLinkTap?(article)` に置換
- [x] **T006** `KnowledgeTree/Views/ChatTabView.swift` call site (:218) に `onArticleLinkTap: { navigationPath.append($0) }` 注入 ✅
  - **修正点**: ChatTabView は `NavigationStack {` (path なし) だった → `@State navigationPath` 追加 + `NavigationStack(path: $navigationPath)` 化。既存 `.navigationDestination(for: Article.self)` は無改修で発火。
- [x] **T007** `extractArticleID(from:)` は**既に `static`** (昇格不要) + `ChatMessageRowLinkTests` 3 ケース (valid / non-article scheme / malformed UUID) ✅

**Checkpoint**: build SUCCEEDED、callback 配線が型整合。

---

## Phase 6: US5 (P0-5) UI test 刷新

**Goal**: 廃止タブ参照削除、現行 3 タブ検証 suite 追加。
**Independent Test**: `tab.learning`/`tab.aibrain` 0 件、V3 suite 5 シナリオ compile。

- [x] **T008 [P]** 旧 UI test 削除 (独立) ✅
  - `KnowledgeTreeUITests/UnderstandingTabUITests.swift` 削除 (git rm)
  - `KnowledgeTreeUITests/AIBrainTabUITests.swift` 削除 (git rm)
- [x] **T009** pbxproj 編集 — **不要** ✅
  - `KnowledgeTreeUITests` は **PBXFileSystemSynchronizedRootGroup** (pbxproj line 305)、旧ファイルは明示参照ゼロ → add/remove が自動反映。手動編集なし。
- [x] **T010** `KnowledgeTreeUITests/V3RedesignUITests.swift` 新規作成 5 シナリオ ✅ (compile 通過)
  - (1) tab.knowledgeClip load (2) Add Article sheet (3) tab.library navigate (4) tab.chat empty-state (5) Settings via Avatar
  - 不足 accessibilityIdentifier は実装側に最小限追加
  - contract: contracts/v3-uitest-suite.md

**Checkpoint**: build-for-testing 成功 (compile)、`rg "tab.learning|tab.aibrain" KnowledgeTreeUITests/` → 0 hit。

---

## Phase 7: Polish & 検証

- [x] **T011** clean build (iPhone 17 Simulator) ✅ exit 0。warning は `Skipping duplicate build file` 30 件 (pbxproj 既存問題) + GraphExtractionService:50 (spec 040 既存) のみ、**本 spec 由来 warning ゼロ**
- [x] **T012** 全 unit test serial regression ✅ `** TEST SUCCEEDED **`、失敗ケースゼロ (新規 ChatMessageRowLinkTests 3 含む)
- [x] **T013** 静的検証 grep: 「アプリ名」「近日対応」「settings.icloud.placeholder」live 0 hit、「学習タブ/AIブレイン/tab.learning/tab.aibrain」は説明コメント + 意図的 negative assertion のみ ✅
- [x] **T014** `CLAUDE.md` に spec 059 を 🔧 実装完了で追記 ✅
- [ ] **T015** 実機検証 (ユーザー、quickstart SC-001〜SC-005 + UI test 実機実行 + 既存回帰)

---

## 依存グラフ

```
T001 ─┬─ T002 (P0-1)
      └─ T003 (P0-2)
T004 (P0-3, 独立)
T005 (P0-4) ─┬─ T006
             └─ T007 [任意]
T008 (P0-5) ── T009 ── T010
全実装 → T011 → T012 → T013 → T014 → T015 (ユーザー)
```

## 並列例

- T001 後: **T002 / T003** 並列
- 同時並列: **T004 / T005 / T008** (別ファイル、独立)

## MVP / 実装戦略

- 全 5 P0 が出荷必須 = 全タスクが MVP。
- P0 単位で独立検証可能なので、Phase 2-6 を順次 or 並列で。
- 最終 commit はユーザー指示後 (実機検証 SC-001〜005 後を想定)。
- 本セッションは T001-T014 (build + unit test + static check)、T015 実機検証はユーザー。
