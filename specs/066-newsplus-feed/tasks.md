# Tasks: News+ 風フィード

**Branch**: `066-newsplus-feed` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

パス: `KnowledgeTree/KnowledgeTree/`。@Model 変更なし。US1/US2 = P1 core、US3 = P2。

## Phase 1: Foundation (FeedItem + FeedBuilder)
- [x] **T001** `Models/FeedItem.swift` 新規: enum (article/wikiUpdate/periodicDigest) + id + sortDate
- [x] **T002** `Services/FeedBuilder.swift` 新規: Protocol `FeedBuilding` + Default (Article savedAt 降順 + ConceptPage isHidden==false/updatedAt 降順 + 更新ガード 14d/本文あり + sortDate merge)、now 注入、定数 (wikiUpdateWindowDays=14 / maxArticles=60 / maxWikiUpdates=20)
- [x] **T003** `KnowledgeTreeTests/FeedBuilderTests.swift` 新規: 空 / merge 時系列 / 更新ガード (古い・本文なし・isHidden 除外) / AI ゼロ

**Checkpoint**: build + FeedBuilderTests PASS

## Phase 2: カード View (US1/US2)
- [x] **T004 [US2]** `Views/ArticleFeedCard.swift` 新規: 大判写真 (enrichment.ogImageURL / fallback) + タイトル + savedAt + preview + 関連 Wiki チップ + tap 遷移
- [x] **T005 [US2]** `Views/WikiFeedCard.swift` 新規: 借用写真 (relatedArticles.ogImageURL / kind.symbolName fallback) + 種別バッジ + name + preview + 更新ラベル + tap 遷移
- [x] **T006 [US1]** `Views/KnowledgeClipView.swift` 改修: 3 セクション → `feedBuilder.build()` の LazyVStack ForEach (FeedItem switch → ArticleFeedCard/WikiFeedCard)。navigationDestination 群維持 + pull-to-refresh 維持 + 空状態
- [x] **T007** `Services/ServiceContainer.swift` + `KnowledgeTreeApp.swift`: feedBuilder field + 構築 + 環境注入。`clip.tab.title` value を「フィード」に (xcstrings)
- [x] **T008** `project.pbxproj`: 新 4 ファイル (FeedItem/FeedBuilder/ArticleFeedCard/WikiFeedCard) を app target に追加 (KnowledgeTree/ は file-system-synchronized なら自動、要確認)

**Checkpoint**: build + 全テスト PASS

## Phase 3: 3 タイミング (US3, P2)
- [x] **T009 [US3]** periodicDigest カード挿入 (FeedBuilder + 新カード or WikiFeedCard 流用) + 関連 Wiki チップ仕上げ
- [ ] **T010 [US3]** FeedBuilderTests に periodicDigest 挿入ケース追加

## Phase 4: Polish & 検証
- [x] **T011** clean build (iPhone 17 Simulator) warning ゼロ
- [x] **T012** 全 unit test serial regression PASS
- [x] **T013** 静的検証 (FeedItem/FeedBuilder/カード grep + @Model 差分ゼロ)
- [x] **T014** CLAUDE.md に spec 066 追記
- [ ] **T015** 実機検証 (ユーザー、SC-001〜008)

## 依存
T001→T002→T003 / T002→T006 / T004+T005→T006 / T006→T007→T008 / Phase1-2→Phase3→Phase4

## 実装戦略
Phase 1 (FeedBuilder、純ロジック、テスト可) を先に固める → Phase 2 (UI)。一度に大量 Edit せず build 確認。最終 commit はユーザー指示後 (064/065 実機検証 + PR #22 マージ後が望ましい)。
