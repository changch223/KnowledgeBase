# Migration Plan: 知積 → iKnow

## このフォルダの目的

現在の **知積 (KnowledgeTree、spec 001-044 実装済)** から、`docs/dream-product/` で定義した **理想形 iKnow (V1 ビッグバン)** へ進化させるためのロードマップ。

戦略: **Option C ハイブリッド** (現知積の bundle ID 継承 + 内部大改修 + メジャーバージョン跳ね上げ + リブランディング)。

---

## 読み順

```
00-README.md                    ← 今ここ
  ↓
01-current-vs-dream-diff.md    ★ 詳細 diff (ユーザー確認用)
02-feature-mapping.md           現 spec ↔ dream feature の対応
  ↓
03-data-migration.md            SwiftData migration 戦略
04-implementation-roadmap.md    spec 番号 + 順序 + 期間
05-deprecation-plan.md          廃止する機能 / view の撤去手順
  ↓
06-branding-migration.md        知積 → iKnow リブランディング
07-risk-register.md             リスク + mitigation
```

---

## 用語定義

| 用語 | 意味 |
|---|---|
| **現知積** | 現在の KnowledgeTree アプリ、spec 001-044 実装済、`/Users/changchiawei/Desktop/KnowledgeTree/` |
| **dream spec** | `docs/dream-product/` の 11 ファイル、zero-base 設計 |
| **iKnow** | dream を実装した先の新アプリ名 (旧 知積 を進化、bundle ID 継承) |
| **V1** | iKnow 最初の公開版、機能 30 個ビッグバンリリース |
| **V1.0** | (本 plan では使わない、V1 一気にリリース) |
| **継続活用** | 現知積の実装をそのまま使う |
| **改修** | 現知積の実装に拡張 / 修正を加える |
| **新規追加** | 現知積に無いものを新規実装 |
| **廃止** | 現知積にあるが iKnow では削除 |
| **統合** | 現知積の複数機能を 1 つにまとめる |

---

## 進め方 (5 phase)

| Phase | 内容 | 期間目安 |
|---|---|---|
| **Phase 0** (今) | skeleton 7 ファイル作成 | 1 セッション |
| **Phase 1** | 01 + 02 詳細化 | 1-2 セッション |
| **Phase 2** | 04 (実装ロードマップ) 詳細化 | 1 セッション |
| **Phase 3** | 03 + 05 + 06 詳細化 | 1 セッション |
| **Phase 4** | 07 + 全体レビュー | 1 セッション |
| **Phase 5** | VISION.md 更新案作成 | 1 セッション |
| **Phase 6** | spec 045 specify+plan 着手 | 別 plan で開始 |

---

## V1 機能スコープ (4-5 ヶ月想定)

10 個の新規 spec で V1 完成:

| spec | 内容 | 規模 |
|---|---|---|
| spec 045 | ConceptPage @Model + Service + UI | 大 |
| spec 046 | SavedAnswer + Chat filing | 小 |
| spec 047 | WikiLint 拡張 + 気づきの種 | 中 |
| spec 048 | EntityCommunity 検出 + UI | 中 |
| spec 049 | Understanding Chat (Main、新タブ) | **大 ★最大** |
| spec 050 | 写真 / AI 会話入力 (OCR + 構造判定) | 中 |
| spec 051 | Widget (ambient surface) | 中 |
| spec 052 | Export (zip + markdown) | 小 |
| spec 053 | タブ再編 + AI ブレイン廃止 | 中 |
| spec 054 | iKnow リブランディング (icon + xcstrings + App Store) | 小 |

---

## 重要原則

- **既存ユーザーのデータは絶対保持** (SwiftData lightweight migration)
- **bundle ID 継承** = App Store 評価 / TestFlight ベータ継続
- **段階的リリース禁止** (V1 ビッグバン、user 選択) → ただし TestFlight 内部 beta で先行確認
- **dream spec が source of truth**、実装は dream に向かって収束させる
- **「Karpathy 思想 + cortex pattern」を実装で reflect** (説明文 = embedding、Runbook、ハルシネーション位置、AI が書く前提)

---

## 次に読むファイル

- `01-current-vs-dream-diff.md` ← **ユーザー確認用、最重要**
- `02-feature-mapping.md` — 詳細マッピング
