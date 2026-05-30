# Feature Specification: News+ 風フィード (記事 + Wiki カード mix + 写真)

**Feature Branch**: `066-newsplus-feed`
**Created**: 2026-05-31
**Status**: Draft
**Input**: VISION v2 (LLM Wiki) タブ構成「フィード」。Plan エージェント設計 + ユーザー選択 (知識 Clip 進化 / フル scope / 写真あり / 退役は spec 067)

## 背景

VISION v2 (LLM Wiki) のタブ構成は「フィード / ライブラリ / AI チャット」。現状の「知識 Clip」タブ (KnowledgeClipView、3 セクション縦並び) を **Apple News+ 風の時系列 mix フィード**に進化させる。記事カードと Wiki カード (ConceptPage の更新) を 1 本のタイムラインに混ぜ、写真付きで「読み物」として開ける場にする。

spec 063-065 で WikiPage (ConceptPage) が Markdown 本文 + 相互リンクを持ち、AI 生成が軽くなった。その WikiPage を**記事と並べて見せる場所**がフィード。

**1 文の本質**: 「記事と Wiki ページを写真付きの時系列カードで混ぜ、開くだけで自分の知識の最新が流れてくる News+ 風フィードにする」

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 記事と Wiki が時系列で流れる (Priority: P1)

ユーザーが最初のタブ (フィード) を開くと、最近保存した記事と、最近更新された Wiki ページ (追っている人物・モノ・概念) が、新しい順に 1 本のタイムラインで混ざって表示される。それぞれカードで、写真があれば写真付き。

**Why this priority**: フィードの core。「開くだけで最新が見える」体験そのもの。

**Independent Test**: 記事と概念ページが複数ある状態でフィードを開き、両方が時系列で混在表示されることを確認。

**Acceptance Scenarios**:

1. **Given** 記事と更新済 Wiki ページがある, **When** フィードを開く, **Then** 両方が新しい順の単一タイムラインで表示される
2. **Given** 記事カード, **When** タップ, **Then** 記事詳細に遷移する
3. **Given** Wiki カード, **When** タップ, **Then** その概念ページ詳細に遷移する
4. **Given** データが空, **When** フィードを開く, **Then** 空状態が破綻なく表示される

---

### User Story 2 - 写真付きカード (Priority: P1)

記事カードは記事の OGP/サムネ画像を、Wiki カードは関連記事から借りた代表画像を表示する。画像が無いときは種別アイコン + カテゴリ色のフォールバックで、Apple News+ 風の見た目を保つ。

**Why this priority**: News+ 風の視覚的な「読み物」感。写真があると一覧が一気に魅力的になる。

**Independent Test**: 画像を持つ記事・概念ページでフィードを開き、写真が表示されること、画像なしでフォールバックが出ることを確認。

**Acceptance Scenarios**:

1. **Given** OGP 画像を持つ記事, **When** フィード表示, **Then** 記事カードに写真が出る
2. **Given** 関連記事に画像を持つ Wiki ページ, **When** フィード表示, **Then** Wiki カードにその画像が借用表示される
3. **Given** 画像が一切無いカード, **When** 表示, **Then** 種別アイコン + 色のフォールバックで崩れない

---

### User Story 3 - Wiki カードの 3 つの出方 (Priority: P2)

Wiki ページはフィードに 3 通りで現れる: (a) 更新通知 (最近 summary が更新された Wiki)、(b) 記事に紐づく関連 Wiki (記事カードに添えるチップ)、(c) 周期ダイジェスト (たまに「今週の振り返り」的なまとめカード)。情報過多を避けるため、更新通知は「直近 N 日 + 本文あり」のみ出す。

**Why this priority**: VISION の「3 タイミング」。フィードが記事だけにならず Wiki が自然に混ざる。ただし core (US1/US2) の後でよい。

**Independent Test**: 最近更新した Wiki が更新カードで出る / 記事カードに関連 Wiki チップが出る / 周期ダイジェストが出ることを確認。

**Acceptance Scenarios**:

1. **Given** 直近 N 日に更新され本文を持つ Wiki, **When** フィード表示, **Then** 更新カードが出る
2. **Given** 古い/本文の無い Wiki, **When** フィード表示, **Then** 更新カードは出ない (過多防止)
3. **Given** 関連 Wiki を持つ記事, **When** 記事カード表示, **Then** 関連 Wiki チップが添えられタップで遷移

---

### Edge Cases

- **空状態**: 記事も Wiki も無い → 穏やかな空状態 (保存を促す)。
- **写真ロード失敗 / 無し**: フォールバック (種別アイコン + カテゴリ色)、レイアウト不変。
- **大量データ**: LazyVStack で遅延ロード、スクロール 60fps。
- **更新カード過多**: 「直近 N 日 + 本文あり」ガードで Wiki 更新カードを絞る。
- **削除済**: フィード表示中に削除/非表示になった項目はタップで安全に無視 (既存 reactive guard)。
- **pull-to-refresh**: 既存の更新動線を維持。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: フィードは記事と Wiki ページを 1 本の時系列タイムラインで混在表示しなければならない。
- **FR-002**: 記事カードはタップで記事詳細へ、Wiki カードはタップで概念ページ詳細へ遷移しなければならない。
- **FR-003**: 記事カードは記事の保存画像 (OGP/サムネ) を表示しなければならない (あれば)。
- **FR-004**: Wiki カードは関連記事から代表画像を借用して表示しなければならない (あれば)。
- **FR-005**: 画像が無いカードは種別アイコン + カテゴリ色のフォールバックで崩れず表示しなければならない。
- **FR-006**: Wiki 更新カードは情報過多を避けるため「直近 N 日に更新 + 本文あり」のみ表示しなければならない。
- **FR-007**: 記事カードは関連 Wiki ページをチップで添えられ、タップで遷移できなければならない。
- **FR-008**: 周期ダイジェストカード (まとめ) を時々表示できなければならない。
- **FR-009**: フィード構築は AI (言語モデル) を呼び出してはならない (SwiftData fetch + merge のみ)。
- **FR-010**: 永続化スキーマ (@Model) を変更してはならない (純 UI/transient)。
- **FR-011**: 空状態・削除済・画像失敗で破綻してはならない。
- **FR-012**: 既存のタブ遷移・pull-to-refresh・deep link を壊してはならない。

### Key Entities

- **FeedItem** (新 transient enum): `article(Article)` / `wikiUpdate(ConceptPage)` / `periodicDigest([ConceptPage])`。`sortDate` で時系列 merge。
- **Article / ConceptPage / ArticleEnrichment** (既存 @Model): フィードの素材。`ArticleEnrichment.ogImageURL` で写真、`ConceptPage.relatedArticles` で借用元・関連チップ。@Model 変更なし。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: フィードで記事と Wiki が時系列混在表示される。
- **SC-002**: 記事カード/Wiki カードのタップで各詳細に遷移する。
- **SC-003**: 画像のある記事/Wiki で写真が表示される。
- **SC-004**: 画像が無くてもフォールバックで崩れない。
- **SC-005**: Wiki 更新カードが「直近 N 日 + 本文あり」に絞られ過多にならない。
- **SC-006**: 記事カードに関連 Wiki チップが出てタップ遷移する。
- **SC-007**: フィード構築で AI 呼び出しが発生しない。
- **SC-008**: スクロール 60fps (LazyVStack + 遅延画像)。
- **SC-009**: クリーンビルド成功 + 全 unit test 回帰 PASS + FeedBuilder の新規テスト PASS。

## Assumptions

- 「知識 Clip」タブを「フィード」に進化させる (新タブは追加しない、VISION 3 タブ維持)。タブ名 label のみ変更 (key 維持)。
- フィード構築は新 transient `FeedItem` + 新 service `FeedBuilder` (純ロジック、AI なし) で行い、既存 `RecentArticlesService` / `FollowingPeopleSection` の fetch パターンを踏襲。
- 写真は `ArticleEnrichment.ogImageURL` (既存) を `ThumbnailView` 系で表示。Wiki カードは `conceptPage.relatedArticles` の最初の画像を借用 (`KnowledgeClipCard` の先例と同方式)。News+ 風の大判カードは新規カード View。
- 関連 Wiki チップは `Article.relatedConcepts` (既存 inverse) を読むだけで追加計算不要。
- 既存 `MixedSurfaceCard` (digest 依存、退役対象を含む) は流用しない。
- @Model 変更なし = CloudKit migration 不要。
- 旧モデル退役 (GraphNode/UserTopic/KnowledgeDigest) は spec 067 (本 spec では触らない)。

## Dependencies

- **spec 063/064** (WikiPage 本文 + 相互リンク) — Wiki カードの中身。
- **spec 042** (ConceptPage / relatedArticles) — 借用画像・関連チップ。
- **spec 018** (KnowledgeClipCard) — 写真借用の先例。
- **ArticleEnrichment.ogImageURL / ThumbnailView** — 既存画像基盤。

## Out of Scope

- 旧モデル退役 (GraphNode/UserTopic/KnowledgeDigest @Model 削除) — spec 067。
- 検索強化 — 後段。
- @Model 追加・変更。
- フィードのパーソナライズ/並び替え AI (VISION 軽さ優先、AI なし)。
