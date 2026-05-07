# Feature Specification: 時系列事実上書き提案 (機能 Z)

**Feature Branch**: `037-fact-overwrite` (実装時に作成)
**Created**: 2026-05-08
**Status**: Draft (specify+plan のみ)
**Vision**: [VISION.md](../VISION.md) 機能 Z

## なぜ (Why)

VISION.md コア価値「**読んだ知識を AI が時間軸で更新**」の核機能。

ユーザー要望 (2026-05-08):
- 例: **「去年『〇〇店 open』の情報があり、今日『〇〇店 潰れた』の情報があれば、それを更新する」**
- 判定方式: **AI が候補を提示 + ユーザー確認** (c)
  - 「この記事は X 月に保存した『〇〇』の更新では?」と提案
  - ユーザーが採用 / 却下

## ゴール

- 新記事保存時に **既存記事との entity 矛盾** を AI が検出
- 矛盾候補を「**事実更新の提案**」として知識 Clip タブに集約
- ユーザーが採用 → 古い記事に「旧情報」マーク、UserTopic / Category Digest 生成時に最新事実を優先採用

## 非ゴール

- AI 完全自動上書き (誤判定リスク高、ユーザー確認必須)
- 多段階 conflict resolution (3 件以上の矛盾チェイン) → 2 件比較のみ
- リアルタイム矛盾検出 (記事保存毎に同期処理) → batch 処理で
- 矛盾の自動 merge (両情報を AI 統合) → ユーザーが手動で「両方残す」選択肢を提供のみ
- 過去全記事を網羅的に矛盾チェック → 同 entity の最新 N 件のみ比較

## ユーザストーリー

### US1 (P1) — AI が事実矛盾を検出して提案

1. 新記事保存後、knowledge 抽出完了 (entity 抽出済) で trigger
2. 同 entity を持つ過去記事を fetch (上限 5 件、savedAt 降順)
3. AI が新記事 vs 各過去記事を比較 → 矛盾あり判定
4. 「事実更新の提案」セクションに新候補追加

### US2 (P1) — ユーザーが選択

1. 知識 Clip タブの「事実更新の提案」セクションを開く
2. 各候補 row:
   - 新記事 (タイトル + 該当事実 1 行)
   - 旧記事 (タイトル + 該当事実 1 行)
   - 矛盾の内容 (AI 生成、20 字以内)
3. ボタン: 「上書き」「両方残す」「却下」

### US3 (P1) — 採用後の挙動 (上書き)

1. 「上書き」採用
2. 古い記事に `isObsolete: true` フラグ
3. KnowledgeDigest / UserTopic 統合要約生成時、`isObsolete == true` を skip (or 「過去」セクションで併記)
4. ライブラリでの表示は維持 (ユーザーは見られる)、ただし archive 風 UI (薄く)

### US4 (P2) — 「両方残す」採用

1. 両方 isObsolete = false のまま
2. UserTopic / Digest 生成時、両方を「経緯」として併記
3. AI prompt に「これは時系列で進化した情報、両方の事実を併記してください」

### US5 (P2) — 「却下」

1. ConflictProposal.status = .dismissed
2. 同 (newArticle, oldArticle) ペアは再提案しない
3. 別 entity / 別記事の組合せで矛盾検出は継続

## 機能要件

### Conflict Detection (AI)

- **FR-001**: 新記事保存時、knowledge 抽出完了 (spec 004 succeeded) で trigger
- **FR-002**: 新記事の **top 3 entities** (salience 高い順) を抽出
- **FR-003**: 各 entity ごとに、同 entity を持つ過去記事を fetch (上限 5 件、savedAt 降順、自分は除外)
- **FR-004**: AI prompt: 「以下の 2 記事は同 entity 『〇〇』について書かれているが、事実 (open/閉店、就任/退任、リリース/廃止 等) に矛盾はあるか?」
- **FR-005**: `@Generable ConflictDetectionOutput { hasConflict: Bool, conflictDescription: String, newFact: String, oldFact: String }`
- **FR-006**: hasConflict == true で `ConflictProposal` を作成

### ConflictProposal @Model

- **FR-007**: 新 @Model `ConflictProposal`:
  - id: UUID @Attribute(.unique)
  - newArticle: @Relationship (deleteRule: .nullify)
  - oldArticle: @Relationship (deleteRule: .nullify)
  - entityName: String (矛盾検出のトリガ entity)
  - conflictDescription: String (AI 生成)
  - newFact: String (新記事の事実)
  - oldFact: String (旧記事の事実)
  - status: String ("pending" | "overwrite" | "keepBoth" | "dismissed")
  - createdAt: Date
  - resolvedAt: Date?
- **FR-008**: SharedSchema.all に追加

### Article 改修

- **FR-009**: `Article.isObsolete: Bool` 追加 (default false)
- **FR-010**: KnowledgeDigest / UserTopic 統合 prompt で `isObsolete == true` を skip or 「過去」併記

### UI

- **FR-011**: 知識 Clip タブに `FactConflictsSection` 追加 (status == "pending" のみ表示)
- **FR-012**: 各候補 row:
  - 上部: 「⚠️ 事実が矛盾しているかも」(ヘッダ)
  - 中央: 新記事 title + newFact (太字)
  - 下: 旧記事 title (薄字) + oldFact (薄字)
  - 矛盾内容: conflictDescription (AI 生成、small caption)
  - ボタン横並び: 「上書き」(actionBlue) / 「両方残す」(neutral) / 「却下」(secondary)
- **FR-013**: 「上書き」「両方残す」「却下」 → ConflictProposal.status 更新 + Article.isObsolete 更新 + 候補リストから消える
- **FR-014**: 既存の「事実更新の提案」が 0 件 → セクション非表示

### 重複防止

- **FR-015**: 同 (newArticle.id, oldArticle.id) ペアは ConflictProposal に 1 件のみ (unique constraint or upsert ロジック)
- **FR-016**: status == "dismissed" で resolvedAt 過去 30 日以上 → 同ペア再検出を許可 (新事実が出てきた時の救済)

## 成功基準

- SC-001: 同 entity を持つ新記事保存 → 数十秒以内に「事実更新の提案」セクションに候補
- SC-002: 「上書き」 → 旧記事 isObsolete = true、Category Digest が新事実ベースで再生成
- SC-003: 「両方残す」 → 両 Article が Digest に併記される
- SC-004: 「却下」 → 候補消える、同ペアは 30 日再提案なし
- SC-005: 矛盾なしと AI が判定 → ConflictProposal 作らない、UI に何も出ない (silent)
- SC-006: 既存 KnowledgeDigest 生成に regression なし
- SC-007: AI 不可端末 → 機能スキップ (ConflictProposal 作らない、silent)

## アサンプション

- 同 entity を持つ過去記事 5 件以下なら全て比較
- AI 判定の False Positive (実は矛盾していない) は許容、ユーザーが「却下」で吸収
- True Negative (実は矛盾しているが AI が見逃した) は将来 spec で改善
- entity 名の正規化は spec 008 既存ロジック再利用

## 依存・前提

- **spec 004** (ExtractedKnowledge.entities 必須)
- **spec 008** (entity 正規化)
- **spec 015** (AvailabilityChecker)
- **spec 018** (KnowledgeDigest 統合 prompt 改修)

## 想定実装規模

- 新規 5 ファイル:
  - `Models/ConflictProposal.swift` (~60 行 @Model)
  - `Services/ConflictDetectionService.swift` (~200 行、entity 比較 + AI 判定 + ConflictProposal 作成)
  - `Views/FactConflictsSection.swift` (~100 行、候補リスト)
  - `Views/ConflictProposalRow.swift` (~150 行、3 ボタン UI)
- 改修 5 ファイル:
  - `Models/Article.swift` (~5 行、isObsolete 追加)
  - `Services/KnowledgeExtractionService.swift` (~10 行、knowledge 抽出後に conflict 検出 hook)
  - `Services/KnowledgeDigestService.swift` (~20 行、isObsolete を考慮)
  - `Services/LanguageModelSessionProtocol.swift` (~30 行、generateConflictDetection 追加)
  - `Views/KnowledgeClipView.swift` (~10 行、section 追加)
  - `SharedSchema.swift` (~3 行)
- 新規テスト 1 ファイル:
  - `ConflictDetectionServiceTests.swift` (~7 ケース)
- 合計 ~590 行、~12-15 タスク

## Constitution

- I (privacy): on-device 検出
- II (MVP): 2 件比較のみ、N 件チェイン / merge は将来 spec
- III (source 追跡): ConflictProposal が新旧 Article へ relationship、UI で両方表示
- IV (実現可能性): 既存 entity 抽出 + Foundation Models で判定可能
- V (calm UX): 矛盾なしの場合は silent、提案も控えめ表示
- VI (architecture): protocol + DI、spec 015 / 018 と同パターン
- VII (日本語): UI / prompt / 矛盾説明文 すべて日本語

## 状態

📝 specify+plan 完了 (2026-05-08)、`/speckit-tasks` + `/speckit-implement` は次セッションで。
