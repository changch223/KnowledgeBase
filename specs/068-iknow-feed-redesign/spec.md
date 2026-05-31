# Feature Specification: iKnow タブ — 自然 mix フィード + inline おすすめ carousel

**Feature Branch**: `068-iknow-feed-redesign`
**Created**: 2026-06-06
**Status**: Draft
**Input**: ユーザー対話で確定 (タブ名 iKnow / ラベル区切らず自然 mix / 横スクロール recommend 5 / AI 処理中の記事非表示 / 重複許容)

## 背景

spec 066 で「知識 Clip」タブを News+ 風の時系列 mix フィード (縦 1 列) に進化させた。本 spec はそれを **App Store Today 風** に再設計する。ユーザー要望:
- タブ名を「フィード」→「**iKnow**」に戻す (ブランド名)
- セクション見出し (「最近の記事」「あなたの Wiki」等) で**ガチガチに区切らず、自然に mix した UI**
- 縦フィードの**途中に横スクロール carousel** を挿入 (おすすめ 5 件、記事と Wiki 混在)
- **AI 処理中の記事は表示しない** (整理が終わったものだけ見せる = calm UX)
- recommend ロジック: Wiki は「関連記事が多い + 最近更新」を優先

**1 文の本質**: 「iKnow タブを、AI 整理済みの記事と Wiki が自然に時系列で流れ、途中におすすめ横棚が挿さる App Store Today 風フィードにする」

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 整理済みの知識だけが自然に流れる (Priority: P1)

ユーザーが iKnow タブ (起動 default) を開くと、AI 処理が完了した記事と更新された Wiki ページが、セクション見出しで区切られず、時系列で 1 つのフィードとして自然に流れる。まだ AI が整理中の記事は出てこない (整理が終わってから現れる)。

**Why this priority**: VISION「気になったものが、勝手に整理される」「calm UX」の中核。処理中のノイズを見せないことが体験の質を決める。

**Independent Test**: 記事を保存直後 (AI 処理中) はフィードに出ず、処理完了後に現れることを確認。Wiki も時系列で混ざる。

**Acceptance Scenarios**:

1. **Given** AI 処理が完了した記事と更新済 Wiki, **When** iKnow タブを開く, **Then** 両方が見出し無しで時系列 mix 表示される
2. **Given** 保存直後で AI 処理中の記事, **When** フィードを見る, **Then** その記事は表示されない
3. **Given** AI 処理が完了, **When** フィードを再描画, **Then** 完了した記事が時系列の正しい位置に現れる
4. **Given** カード, **When** タップ, **Then** 記事は記事詳細 / Wiki は概念詳細へ遷移

---

### User Story 2 - おすすめ横棚が途中に挿さる (Priority: P1)

縦フィードをスクロールすると、途中に横スクロールの「おすすめ」carousel が現れる。そこには「今あなたに関連が深い」記事と Wiki が 5 件、おすすめ順で並ぶ。Wiki は関連記事が多く最近更新されたものほど上位に来る。

**Why this priority**: 単調な時系列だけでなく「今おすすめ」を差し込むことで、埋もれた知識の再発見を促す (App Store Today パターン)。

**Independent Test**: フィード途中に横スクロール carousel が出て、5 件が recommend 順 (Wiki は記事数×更新で上位) に並ぶことを確認。

**Acceptance Scenarios**:

1. **Given** 記事と Wiki が複数ある, **When** フィードをスクロール, **Then** 途中に横スクロール carousel が現れる
2. **Given** carousel, **When** 横スクロール, **Then** おすすめ 5 件 (記事+Wiki 混在) が表示される
3. **Given** 関連記事が多く最近更新された Wiki, **When** carousel 表示, **Then** 上位に来る
4. **Given** carousel のカード, **When** タップ, **Then** 各詳細へ遷移する
5. **Given** carousel に出た項目, **When** 縦フィードにも同じ項目がある, **Then** 重複表示を許容する (App Store 同様、自然)

---

### User Story 3 - おすすめ計算が AI を使わない (Priority: P1)

おすすめ 5 件の選定も、時系列フィードの構築も、AI (言語モデル) を一切呼ばない (数値スコアリングと SwiftData fetch のみ)。VISION「軽さ優先」を守る。

**Why this priority**: フィード表示のたびに AI が走ると重くなる。表示は常にローカル計算で即時。

**Independent Test**: フィード表示・おすすめ計算で AI 呼び出しが発生しないことを確認。

**Acceptance Scenarios**:

1. **Given** iKnow タブ表示, **When** フィード + おすすめを構築, **Then** AI (言語モデル) 呼び出しゼロ
2. **Given** 記事保存 / Wiki 更新, **When** フィードが自動更新, **Then** reactive に反映 (AI なし)

---

### Edge Cases

- **AI 処理中のみ / データ空**: 表示できる項目が無いとき穏やかな空状態。
- **おすすめ候補不足**: 5 件に満たない場合はある分だけ表示 (carousel 自体を出さない閾値も検討)。
- **写真なし**: 種別アイコン + 色のフォールバック (既存)。
- **削除済**: 表示中に削除/非表示された項目はタップで安全に無視 (既存 reactive guard)。
- **処理中→完了の遷移**: AI 完了で `@Query` が再評価され、その記事が自然にフィードに現れる。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: タブ名を「iKnow」に変更しなければならない。
- **FR-002**: フィードはセクション見出しで区切らず、記事と Wiki を時系列 mix で表示しなければならない。
- **FR-003**: AI 処理が完了していない記事 (status が succeeded / partiallySucceeded 以外) をフィードに表示してはならない。
- **FR-004**: 縦フィードの途中に横スクロール「おすすめ」carousel を挿入しなければならない。
- **FR-005**: おすすめは記事と Wiki を混在させ、最大 5 件をおすすめ順で表示しなければならない。
- **FR-006**: Wiki のおすすめ順は「関連記事数が多い + 最近更新された」ものを優先しなければならない。
- **FR-007**: フィード構築・おすすめ計算は AI (言語モデル) を呼び出してはならない。
- **FR-008**: カードのタップで記事詳細 / 概念詳細へ遷移しなければならない。
- **FR-009**: carousel と縦フィードの項目重複を許容する (除外しない)。
- **FR-010**: 永続化スキーマ (@Model) を変更してはならない (純 UI/Service)。
- **FR-011**: 空状態・削除済・写真なしで破綻してはならない。
- **FR-012**: 既存のタブ遷移・FAB・deep link・pull-to-refresh を壊してはならない。

### Key Entities

- **FeedItem** (既存 transient enum): article / wikiUpdate / periodicDigest。本 spec で carousel 用途にも再利用。
- **Article / ConceptPage / ArticleEnrichment** (既存 @Model): フィード素材。`ExtractedKnowledge.status` で AI 処理完了判定。@Model 変更なし。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: iKnow タブで AI 処理済み記事と Wiki が見出し無しで時系列 mix 表示される。
- **SC-002**: AI 処理中の記事がフィードに出ない。完了後に現れる。
- **SC-003**: フィード途中に横スクロール carousel が出て、おすすめ 5 件 (記事+Wiki) が表示される。
- **SC-004**: 関連記事が多く最近更新された Wiki が carousel 上位に来る。
- **SC-005**: フィード/おすすめ構築で AI 呼び出しが発生しない。
- **SC-006**: カード tap で各詳細へ遷移する。
- **SC-007**: クリーンビルド成功 + 全 unit test 回帰 PASS + recommend ロジックの新規テスト PASS。

## Assumptions

- AI 処理完了判定は `article.extractedKnowledge?.status` が `.succeeded` または `.partiallySucceeded` (コードで確認済の enum)。
- recommend スコア: Wiki = 関連記事数 × 重み + 最近更新ボーナス、記事 = 新しさ。同一軸でソート上位 5。純関数 `FeedBuilder.recommend(...)` (AI なし、テスト可)。
- carousel の挿入位置は縦フィードの固定インデックス (例: 3 件目の後)。候補が少ない時は carousel 非表示。
- 横用コンパクトカード (写真上 + 名前下、~150pt) を新規。縦は既存 ArticleFeedCard/WikiFeedCard 流用。
- タブアイコンは当面 newspaper.fill 維持 (変更は容易、後で調整可)。
- @Model 変更なし = CloudKit migration 不要。

## Dependencies

- **spec 066** (FeedBuilder / FeedItem / ArticleFeedCard / WikiFeedCard) — 進化元。
- **spec 063/064** (WikiPage 本文 + relatedArticles) — Wiki カード中身・recommend スコア。
- **spec 004** (ExtractedKnowledge.status) — AI 処理完了判定。

## Out of Scope

- 旧 3 section view (RecentArticlesSection 等) の物理削除 (別途、未参照のまま残置)。
- 「続きが気になる (学習導線)」の復活 (本 spec では入れない、ユーザー判断で廃止)。
- AI を使ったパーソナライズ推薦 (VISION 軽さ優先、数値スコアのみ)。
- @Model 追加・変更。
- 旧モデル (GraphNode/KnowledgeDigest) 退役。
