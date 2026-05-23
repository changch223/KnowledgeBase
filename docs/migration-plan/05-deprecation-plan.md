# 05 — Deprecation Plan (廃止計画)

## Status: 廃止対象は全 user 承認済 (2026-05-23)、撤去手順は Phase 3 で詳細化予定

## このファイルの目的

iKnow で **廃止する機能 / view / spec** の撤去手順を整理。
コード削減、テスト削除、user 影響緩和まで含む。

---

## 廃止対象 1: AI ブレインタブ + 関連 view

### 廃止する view (spec 011 関連)

| view | 元 spec | 削除 |
|---|---|---|
| `AIBrainView` | spec 011 | ❌ |
| `PowerGaugeCard` | spec 011 | ❌ |
| `KnowledgeMap` (force-directed Canvas) | spec 011 | ❌ |
| `RecentActivityCards` | spec 011 | ❌ (spec 035 RecentDigest と重複) |
| `AIInsightCard` | spec 011 | ❌ (知識 Clip に内容統合) |
| `KnowledgeCategoryRow` (AI ブレイン版) | spec 011 | ❌ |
| `KnowledgeMapBuilder` | spec 011 | ❌ |

### 削除する test

- `KnowledgeMapBuilderTests`
- `RecentActivitySnapshotBuilderTests`
- `AIBrainTabUITests`

### コード削減見込み

- ~500 行のコード削除
- ~150 行のテスト削除

### user 影響と対策

| user 影響 | 対策 |
|---|---|
| 「AI ブレインタブが消えた!」 | Onboarding overlay で 1 回説明: 「内容は知識 Clip タブに移動しました」 |
| KnowledgeMap (force-directed) ファン | static layout の CategoryGraphView (spec 041) で代替 |
| PowerGauge を気に入ってた人 | Widget で「あなたの AI パワー」表示可 (任意、spec 051 で検討) |

### 撤去タイミング

**spec 053 で撤去** (タブ再編と同時)。spec 049 (Understanding Chat) リリース後すぐ。

---

## 廃止対象 2: 起動 default の変更

| 項目 | 旧 | 新 |
|---|---|---|
| 起動時 default タブ | `.knowledgeClip` | `.learning` (新タブ) |
| code | `KnowledgeTreeApp.swift` | 同じファイル、enum 値変更 |

### user 影響と対策

- 「いつもと違うタブが開く」違和感
- Onboarding overlay 初回 1 回だけ: 「あなたへのカードが学習タブで surface されます」

---

## 廃止対象 3: spec 019 (Chrome 連携) 関連の残骸

spec 019 は既に撤回済 (`docs/concept-review/karpathy-llm-wiki/05-product-vision-consolidated.md` 等で言及)。
ただし関連コード (AppIntent / AppShortcutsProvider / ArticleSavingActor) は Safari Web Extension が依存しているので残す。

→ 撤去なし、現状維持。

---

## 廃止対象 4: 「Tag」を ConceptPage に統合する? (要確認)

- 現知積の `Tag` は Auto-Tag で自動付与
- iKnow の `ConceptPage` は entity 単位の概念
- 概念的には重複する部分あり

### 選択肢

| 案 | 中身 |
|---|---|
| A | Tag と ConceptPage を **並立** (役割が違うので両方残す) - 推奨 |
| B | Tag を ConceptPage に **吸収** (Tag.name = ConceptPage.name で同一視) |
| C | Tag を完全廃止 |

→ **A 推奨** (Tag = 軽量タグ付け、ConceptPage = 重い概念ページ、用途が違う)
→ ただし WikiLint で「同一視提案」を出すのは OK (spec 047)

---

## 廃止対象 5: 「UserTopic」と「EntityCommunity」の関係

- 現知積の `UserTopic` (spec 036) = K-means clustering で動的トピック検出
- iKnow の `EntityCommunity` (spec 048) = Graph ベースクラスタリング

### 選択肢

| 案 | 中身 |
|---|---|
| A | UserTopic を廃止、EntityCommunity に統合 (推奨) |
| B | 並立 (役割が違うので両方) |

→ **A 推奨** (実質同じ機能、二重管理避ける)
→ Migration: 既存 UserTopic から EntityCommunity に変換、UserTopic @Model 削除

---

## 撤去手順テンプレート

各廃止 spec で同じ手順を踏む:

1. 該当 view / @Model / Service を削除
2. 関連 test を削除
3. ServiceContainer / KnowledgeTreeApp bootstrap から参照削除
4. xcstrings から不要文言削除
5. CLAUDE.md の該当 spec entry を 「廃止」マーク
6. quickstart で動作確認 (撤去後の app が壊れていないこと)
7. commit + push

---

## 次のステップ

Phase 3 で詳細化:
- 各廃止項目の影響範囲精査
- user 通知方法 (Onboarding overlay 文言)
- 撤去スケジュール (どの spec で実施)
