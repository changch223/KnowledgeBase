# Phase 1 Data Model: spec 012 (タグ自動付与)

**Created**: 2026-05-05

## 概要

本 spec は **新 @Model / 新 schema migration / 新 transient struct すらゼロ**。既存 SwiftData モデルを **読み書き** する純粋関数モジュールのみ追加。

---

## Section A: 既存 @Model 利用 (改修なし)

| @Model | 利用方法 |
|---|---|
| `Article` | 読: `article.tags.count` (skip 判定) / `article.extractedKnowledge` (status + entities 取得) <br> 書: `article.tags` への Tag 追加 (TagStore 経由、本 spec では直接書き込みなし) |
| `Tag` | 既存 / 新規 Tag を `TagStore.addTag` 経由で追加 (内部で `Tag(name:)` insert または fetch して再利用) |
| `ExtractedKnowledge` | 読: `knowledge.statusRaw` / `knowledge.status` (computed) / `knowledge.entities` |
| `KnowledgeEntity` | 読: `entity.name` / `entity.salience` (SuggestedTagFinder 経由) |

すべて spec 008 / 011 で確立済の relationship を使う。新規 schema 改変ゼロ。

---

## Section B: Transient (永続化しない) struct

**なし**。

`AutoTagApplier` は副作用 (TagStore.addTag 呼び出し) のみで、中間状態 struct を持たない。`SuggestedTag` は spec 008 既存 transient struct を再利用 (本 spec で改変なし)。

---

## State Transitions

`Article.tags` の状態遷移:

| From | Event | To |
|---|---|---|
| `tags.isEmpty == true` + `knowledge.status == .succeeded/.partiallySucceeded` | `AutoTagApplier.apply` | `tags = [Tag x 5 (max)]` |
| `tags.isEmpty == false` (≥1 件) | `AutoTagApplier.apply` | **変化なし** (スキップ) |
| `knowledge.status == .failed/.pending/.skipped/.extracting` | `AutoTagApplier.apply` | **変化なし** (スキップ) |
| `tags = [auto-applied 5 件]` | ユーザー TagChip x ボタンタップ | `tags.count -= 1` (一部削除) |
| `tags.count == 0` (全削除後) | `AutoTagApplier.apply` (再抽出経由) | `tags = [Tag x 5 (max)]` (復活、US3) |

`ExtractedKnowledge.statusRaw` の状態遷移は spec 004 / 006 / 010 の既存パイプラインと同じ。本 spec で改変なし。

---

## Validation Rules

| Rule | 適用先 | 違反時の挙動 |
|---|---|---|
| `article.tags.isEmpty` | AutoTagApplier.apply 1st guard | 早期 return (no-op) |
| `knowledge != nil && status in {.succeeded, .partiallySucceeded}` | AutoTagApplier.apply 2nd guard | 早期 return (no-op) |
| TagNormalizer.normalize(rawName) が non-nil | TagStore.addTag 内 (既存) | 個別 candidate skip + log |
| Tag.name unique | SwiftData `@Attribute(.unique)` (既存) | TagStore.addTag が既存 Tag を fetch して再利用 |
| `article.tags` への重複追加防止 | TagStore.addTag 内 (既存) | `if !article.tags.contains(...) { append }` で no-op |
| `limit <= 5` (spec 012 確定値) | AutoTagApplier.apply 引数 default | 本 spec では固定、将来引数化 |

---

## 永続化なし宣言

本 spec で **新規 SwiftData @Model は追加しない**。`SharedSchema.all` の改修は不要。schema migration は **走らない**。既存 ModelContainer は spec 011 までと同じ構成で起動する。

新規 transient struct もゼロ。spec 008 既存の `SuggestedTag` のみ利用。

---

## 関係性ダイアグラム (本 spec 関連部分のみ)

```
Article ─────────── tags ──────────────→ [Tag, Tag, Tag, ...]
   │                                            ↑
   │                                            │ (auto-apply 経由で append)
   │                                            │
   ├──── extractedKnowledge ──→ ExtractedKnowledge
   │                                  │
   │                                  ├── statusRaw (.succeeded → trigger)
   │                                  └── entities ──→ [KnowledgeEntity (salience>=4 → SuggestedTag → Tag)]
   │
   └─── (auto-apply 後の状態) ────→ tags.count == 5 (max)
```

`AutoTagApplier` は ModelContext を直接触らず、**TagStore 経由**で書き込み (Constitution Principle VI のクリーン境界)。
