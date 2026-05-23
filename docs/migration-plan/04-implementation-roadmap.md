# 04 — Implementation Roadmap

## Status: Skeleton (Phase 2 で詳細化予定)

## このファイルの目的

iKnow V1 の **新規 10 spec (045-054)** を、依存関係 + 期間 + ブランチ戦略 で整理する。

---

## V1 spec 一覧 (10 個、4-5 ヶ月想定)

| spec | 内容 | 規模 | 推定週 | dependency |
|---|---|---|---|---|
| spec 045 | ConceptPage @Model + Service + UI | 大 | **3 週** | spec 040 (Graph) |
| spec 046 | SavedAnswer + Chat filing | 小 | **1 週** | spec 045 |
| spec 047 | WikiLint 拡張 + 気づきの種 | 中 | **2 週** | spec 045 / 040 / 037 |
| spec 048 | EntityCommunity 検出 + Catalog | 中 | **2 週** | spec 040 / 036 |
| spec 049 | Understanding Chat (Main、新タブ) | **大** | **4 週 ★最大** | spec 045 / 046 |
| spec 050 | 写真 / AI 会話入力 (OCR + 判定) | 中 | **2 週** | spec 001 既存 pipeline |
| spec 051 | Widget (3 サイズ) | 中 | **2 週** | spec 045 / 035 / 042 |
| spec 052 | Export (zip + markdown) | 小 | **1 週** | 全 @Model |
| spec 053 | タブ再編 + AI ブレイン廃止 | 中 | **2 週** | spec 049 |
| spec 054 | iKnow リブランディング (icon + xcstrings + App Store) | 小 | **1 週** | 全 spec |

**合計: ~20 週 = 約 5 ヶ月**

---

## 実装順序 (依存関係順、Phase A-D)

```
Phase A (基盤、3-4 週)
   ├── spec 045: ConceptPage ★ 最重要
   └── spec 050: 写真 / AI 会話入力 (並行可)

Phase B (compound + lint、2-3 週)
   ├── spec 046: SavedAnswer (045 必要)
   └── spec 047: WikiLint 拡張 (037 拡張)

Phase C (Community + Main UI、4-6 週)
   ├── spec 048: EntityCommunity
   └── spec 049: Understanding Chat (大、最重要新規 UX) ★

Phase D (Widget + Export + リブランディング、4 週)
   ├── spec 051: Widget
   ├── spec 052: Export
   ├── spec 053: タブ再編 + AI ブレイン廃止
   └── spec 054: iKnow リブランディング (最後、最後)

合計: 13-17 週 (V1 ビッグバン)
```

---

## ブランチ戦略

各 spec ごとに別ブランチ、main マージで段階リリース:

| ブランチ | spec |
|---|---|
| `045-concept-page` | spec 045 |
| `046-saved-answer` | spec 046 |
| `047-wiki-lint` | spec 047 |
| `048-entity-community` | spec 048 |
| `049-understanding-main` ★ | spec 049 (大型、長期) |
| `050-image-ai-input` | spec 050 |
| `051-widget` | spec 051 |
| `052-export` | spec 052 |
| `053-tab-restructure` | spec 053 |
| `054-iknow-rebranding` | spec 054 |

各 spec で:
1. `/speckit-specify` で spec.md 作成
2. `/speckit-plan` で plan.md 作成
3. `/speckit-tasks` で tasks.md 作成
4. `/speckit-implement` で実装
5. quickstart.md 作成 (実機検証)
6. commit + push + main マージ

---

## TestFlight ベータ戦略

| 段階 | 内容 | 期間 |
|---|---|---|
| 内部 dogfooding | 開発者 + 小数の信頼できる人 | spec 045-049 完了時 (Phase C 後) |
| 招待ベータ (50 名程度) | TestFlight 招待制 | spec 050-053 完了時 (Phase D 前半) |
| 公開ベータ (10,000 名上限) | TestFlight 公開 | spec 054 完了時 (Phase D 終了) |
| App Store 公開 | iKnow v2.0 リリース | ベータ 4-6 週間後 |

---

## マイルストーン

| マイルストーン | 時期 | 内容 |
|---|---|---|
| **M1**: ConceptPage 動く | 3 週目 | spec 045 完了、概念ページが見える |
| **M2**: Compound moment 動く | 6 週目 | spec 046 + 047 完了、wiki が育つ実感 |
| **M3**: Community 動く | 8 週目 | spec 048 完了、コミュニティが見える |
| **M4**: Understanding Chat 動く | 12 週目 | spec 049 完了、学習タブが動く ★ |
| **M5**: 新入力源動く | 14 週目 | spec 050 完了、写真 / AI 会話保存可 |
| **M6**: Widget + Export 動く | 16 週目 | spec 051 + 052 完了 |
| **M7**: タブ再編 + 廃止完了 | 18 週目 | spec 053 完了、AI ブレイン消滅 |
| **M8**: リブランディング完了 | 20 週目 | spec 054 完了、iKnow v2.0 ベータ準備完了 |

---

## 次のステップ

Phase 2 で詳細化:
- 各 spec の plan 概要 (どこをどう改修するか)
- パラレル実装可能性の精密化
- リスク (spec 049 大型、遅延リスク高)
- TestFlight 戦略の詳細
