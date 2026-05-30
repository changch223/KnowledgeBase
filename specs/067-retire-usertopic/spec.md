# Feature Specification: UserTopic 退役 (死蔵コード削除、CloudKit 安全)

**Feature Branch**: `067-retire-usertopic`
**Created**: 2026-05-31
**Status**: Draft
**Input**: ユーザー判断「UserTopic だけ削除」+ CloudKit を壊さない大前提

## 背景

VISION v2 (LLM Wiki) で「7 分裂概念を WikiPage に畳む」を進めた。spec 065 で UserTopic の生成 (起動時 K-means clustering) は既に停止済み。コード調査で **UserTopic は完全に孤児 (orphan)** と判明:
- 表示する View (`UserTopicCandidateRow` / `UserTopicDetailView`) はどの画面からも呼ばれていない
- 生成 service (`TopicClusteringService`) は spec 065 で起動経路から除外済み
- Wiki (ConceptPage) 生成にも、AI チャット RAG にも、フィードにも一切使われていない

一方、GraphNode / KnowledgeDigest は今も「表示」で使われている (AI チャット関連エンティティ / Category 詳細グラフ・ダイジェスト) ため、本 spec の対象外。

**CloudKit 制約**: `@Model UserTopic` を SharedSchema から削除すると CloudKit record type (`CD_UserTopic`) と Article の relationship 定義が変わり、既存ユーザーのデータ破壊リスクがある。そこで本 spec は **死蔵コード (View / Service / 配線 / テスト) のみ削除し、@Model 定義と SharedSchema 登録・Article.userTopics inverse は残す**。これで「コードが綺麗になる + 生成完全停止 + CloudKit 完全安全」を同時に満たす。

**1 文の本質**: 「孤児になった UserTopic の死蔵コード (UI/Service/配線) を削除して整理する。@Model は CloudKit 安全のため残す」

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 不要コードが消えてビルドが軽くなる (Priority: P1)

開発者視点。使われていない UserTopic 関連の View・Service・テストがコードベースから消え、メンテ対象が減る。アプリの動作は一切変わらない (元々画面に出ていなかったため)。

**Why this priority**: VISION の「引き算」原則。死蔵コードは混乱の元。

**Independent Test**: ビルド + 全テストが通り、アプリの画面・動作に変化がないことを確認。

**Acceptance Scenarios**:

1. **Given** UserTopic 関連の死蔵コード, **When** 削除する, **Then** ビルド成功 + 全テスト PASS
2. **Given** アプリ起動, **When** 各タブ・画面を開く, **Then** 削除前と同じ表示 (UserTopic は元々未表示)
3. **Given** 既存ユーザーのデータ (CloudKit 同期済), **When** アップデート後に起動, **Then** データ破綻なし (@Model 残置ゆえ)

---

### Edge Cases

- **既存 UserTopic レコード**: DB / CloudKit に残るが、読む側のコードが無いので無害 (@Model 定義は残すので SwiftData は正常に開く)。
- **CloudKit**: @Model / SharedSchema / Article.userTopics inverse を残すため record type 変更ゼロ = migration 不要。
- **再導入**: 将来 UserTopic を使いたくなったら @Model が残っているので View/Service を書き直すだけ。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 孤児 View (`UserTopicCandidateRow` / `UserTopicDetailView`) を削除しなければならない。
- **FR-002**: 生成 service (`TopicClusteringService`) とそのテストを削除しなければならない。
- **FR-003**: `ServiceContainer` / `KnowledgeTreeApp` の TopicClustering 配線 (field / 構築 / 登録) を削除しなければならない。
- **FR-004**: `@Model UserTopic` 定義・`SharedSchema` 登録・`Article.userTopics` inverse は**削除してはならない** (CloudKit 安全のため残す)。
- **FR-005**: アプリの画面・動作は削除前と一致しなければならない (UserTopic は元々未表示)。
- **FR-006**: ビルド成功 + 全 unit test 回帰 PASS しなければならない。

### Key Entities

- **UserTopic** (@Model): **残す** (CloudKit record type 保護)。読む側コードのみ削除。
- **TopicClusteringService / UserTopicCandidateRow / UserTopicDetailView**: 削除対象 (孤児)。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: UserTopic 関連の死蔵コード (View 2 + Service 1 + テスト 1 + 配線) が削除される。
- **SC-002**: @Model UserTopic / SharedSchema 登録 / Article.userTopics inverse が残る (CloudKit 安全)。
- **SC-003**: クリーンビルド成功 + 全 unit test 回帰 PASS。
- **SC-004**: アプリの画面・動作が削除前と一致 (実機、ユーザー)。

## Assumptions

- UserTopic は spec 065 で生成停止済み、かつ表示 UI が孤児であることをコードで確認済み。
- @Model 物理削除は CloudKit 破壊リスクゆえ行わない。死蔵コード削除のみで「引き算」の実質効果を得る。
- KnowledgeTree/ app group は file-system-synchronized なので、ファイル削除は pbxproj 自動反映 (手動編集不要)。ただし TopicClusteringService が Share/Safari/Widget extension target にも属する場合は pbxproj 確認が必要。

## Dependencies

- **spec 065** (UserTopic 生成停止) — 前提。
- **spec 036** (UserTopic 導入元)。

## Out of Scope

- GraphNode / GraphEdge / KnowledgeDigest の退役 (今も表示で使用中、対象外)。
- @Model UserTopic の物理削除 + CloudKit schema 変更 (リスク回避で見送り)。
