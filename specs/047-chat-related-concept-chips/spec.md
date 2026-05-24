# Feature Specification: AI Chat MessageRow に関連 ConceptPage chips 追加

**Feature Branch**: `047-chat-related-concept-chips` (実装は `044-understanding-chat` 内)
**Created**: 2026-05-24
**Status**: Draft

## なぜ

AI チャットタブで質問 → AI が答え + 引用記事を返す。引用記事は `CitedArticlesSection` で DisclosureGroup 表示されるが、**関連する ConceptPage (人物/モノ/概念) への jump は一切ない**。

ユーザーは:
- 「この答えは『Apple Vision Pro』について語っているっぽい、その概念ページを見たい」
- → 知識 Clip タブを開いて手動で探す必要がある

これは Karpathy「概念ページ = compound knowledge」原則の片輪欠落 (chat → concept page の橋がない)。

spec 043 SavedAnswer は `relatedConceptIDs` を持つが、これは「auto-save された時点」の固定。chat の各 message には relatedConceptIDs 相当を都度算出して chip で見せる方が自然。

## ゴール

- ChatMessageRow (assistant) の cited articles section の隣 (or 直下) に **関連 ConceptPage chips** を表示
- 上位 3 件、タップで `ConceptPageDetailDestination` 遷移 (既存)
- 0 件で非表示 (calm UX)
- 引用記事数 / 関連概念数の computed cost が高くないこと (LazyVStack 内、複数 message 同時 render)

## 非ゴール

- 関連概念の AI summary 表示 (chip に名前 + count badge のみ)
- フィルター / sort
- 過去 message の遡及 ConceptPage 紐付け永続化 (computed only)

## ユーザストーリー

### US1 (P1) — AI 答えに関連 ConceptPage chips 表示

1. AI チャットタブで質問 → AI 答え受信
2. 答えの下に「引用記事 (N)」DisclosureGroup + **「関連する概念 (M)」chips 行** (orange chevron なし、tap で navigation)
3. chip タップで該当 ConceptPage 詳細 (`ConceptPageDetailLoader`) 遷移
4. 関連 0 件なら chip 行非表示

## 機能要件

- **FR-001**: 新規 view `RelatedConceptsChips(articleIDs: [String])`、@Query で全 ConceptPage fetch、in-memory で各 ConceptPage の relatedArticles と articleIDs の overlap 数を計算、overlap > 0 を上位 3 件 (overlap desc) 表示
- **FR-002**: 各 chip は capsule + ConceptPage.name + tap で `NavigationLink(value: ConceptPageDetailDestination(id: page.id))`
- **FR-003**: 上位 3 件超は表示しない (UI 圧迫回避、必要なら DisclosureGroup 化検討)
- **FR-004**: 0 件で `EmptyView()` (calm UX)
- **FR-005**: ChatMessageRow assistant block の citedArticles 直下に配置
- **FR-006**: 重複 ConceptPage 排除 (overlap > 0 で 1 件しか出ない設計、自動)
- **FR-007**: accessibility: 各 chip に `accessibilityIdentifier("chat.message.relatedConcept.\(page.id.uuidString)")` + label「\(name) 概念」
- **FR-008**: chat タブには既に `navigationDestination(for: ConceptPageDetailDestination.self)` が **未配線** な可能性 → 必要なら ChatTabView に追加 (~3 行)

## 成功基準

- SC-001: 引用記事 2+ 件かつ関連 ConceptPage 1+ 件存在 → AI 答えに「関連する概念 (M)」chips 表示
- SC-002: chip タップで該当 ConceptPage 詳細遷移 (1 秒以内)
- SC-003: 関連 ConceptPage 0 件 → chip 行完全非表示
- SC-004: 4+ 件あっても 3 件まで (上位 overlap)
- SC-005: ConceptPage が merge/delete で消えた → 該当 chip が消える (@Query reactive)
- SC-006: 既存 chat 機能 (送信 / 履歴 / streaming) 無影響

## 依存

- spec 042 (ConceptPage @Model)
- spec 021 (ChatMessage + ChatMessageRow + CitedArticlesSection 同 view 構造)

## 規模

- 新規 1 sub-view (RelatedConceptsChips、~60 行、ChatMessageRow.swift 末尾に private struct 追加)
- 改修 1 line (ChatMessageRow body 内に挿入)
- ChatTabView に navigationDestination 1 行追加 (必要なら)
- 新規テストなし (純 UI + @Query、既存 ConceptPageStoreTests でカバー)
- 合計 ~65 行
