# Dream Product Spec — (仮称) "i knowledge base"

> **You can outsource your thinking, but you cannot outsource your understanding.**
> ― Andrej Karpathy

このフォルダは **zero-base で書かれた dream product の spec 集** です。現状の知積 (KnowledgeTree) アプリの実装やドキュメントは一切参照せず、「もし今から作るとしたら何を作るか」を白紙から設計します。

---

## このフォルダの目的

1. **理想形を言語化する**: 既存の制約・遺産・コードベースに引きずられず、「本当に作りたいもの」を 1 から書く
2. **議論の共通土台にする**: 名前・機能・UX・技術制約を別々のファイルに分けて、論点ごとに議論しやすくする
3. **migration plan (next step) の出発点にする**: zero-base spec が固まれば、「現知積から dream product へどう進化させるか」の migration plan に進める

---

## 読み順

```
00-README.md                    ← 今ここ (案内)
  ↓
01-vision-and-philosophy.md    ← 一文ビジョン + 中核哲学 + 設計原則
  ↓
02-target-users.md             ← 誰のために作るか (ペルソナ + シナリオ)
03-core-loops.md               ← 中核ループ (Outsource Thinking / Understanding / Compound)
04-features.md                 ← 機能一覧 (各機能がどのループに属するか + priority)
  ↓
05-information-architecture.md ← データ構造 (ノード / 関係 / lifecycle)
06-ux-flows.md                 ← 主要 UX フロー
07-tech-constraints.md         ← 技術前提 (完全 on-device / Foundation Models 等)
  ↓
08-non-goals.md                ← 「やらないこと」明示
09-naming-candidates.md        ← 名前候補 + 評価軸 + 議論ログ
10-open-questions.md           ← 未確定論点 (spec 作成中に残ったもの)
```

順に読めば **dream product 全体像** が見えます。

---

## ファイル要約 (1 行ずつ)

| # | ファイル | 1 行で |
|---|---|---|
| 00 | README | このフォルダの案内 (今ここ) |
| 01 | vision-and-philosophy | 「思考は委ねられても理解は委ねられない」を製品化する |
| 02 | target-users | 一般 iPhone ユーザー (年齢・職業問わず) のペルソナ 3 種 |
| 03 | core-loops | 2 つの中核ループと、それを繋ぐ compound moment |
| 04 | features | 機能の網羅 + 各機能の ループ 帰属 + priority |
| 05 | information-architecture | 知識の構造 (生 / 概念 / コミュニティ / 質問結果) |
| 06 | ux-flows | 「情報を入れる / 探す / 学ぶ」の主要フロー |
| 07 | tech-constraints | iOS / Foundation Models / 完全 on-device の前提 |
| 08 | non-goals | 「やらない」と決めたこと (cloud / 課金機能 / multi-user 等) |
| 09 | naming-candidates | 名前案 (候補 5+) + 評価軸 + ユーザー議論ログ |
| 10 | open-questions | spec 作成中に出た未確定論点の集約 |

---

## 命名・記述ルール

zero-base spec として一貫性を保つための取り決め:

| ルール | 中身 |
|---|---|
| **現知積の固有名を使わない** | `Article` `ConceptPage` `GraphNode` `spec 040` 等の固有名は使わず、一般語 (保存記事 / 概念ページ / entity 等) で記述 |
| **製品名は仮称** | 09 で名前候補を議論するまでは "(仮) i knowledge base" / "本アプリ" 表記で統一 |
| **iOS 制約は前提として OK** | Foundation Models / SwiftData / SwiftUI / Vision framework 等の Apple ネイティブ技術名は使用可 |
| **議論ポイントは複数案を並べる** | 「Understanding UX = カード案 / クイズ案 / ハイブリッド案」のように、決まっていないものは選択肢を併記する |
| **不明点は 10-open-questions に集約** | spec 作成中に出た「ユーザー判断待ち」は 10 に追記、解決したら該当 spec ファイルに反映 |
| **既存 docs/concept-review は参考に OK** | Karpathy / SAGE / Tableau AKG / cortex の設計原則は基礎知識として活用 |

---

## 進め方 (4 phase)

| Phase | ファイル | 状態 |
|---|---|---|
| 1 | 00, 01 | 🔄 作成中 |
| 2 | 02, 03, 04 | ⏳ 待機 |
| 3 | 05, 06, 07 | ⏳ 待機 |
| 4 | 08, 09, 10 | ⏳ 待機 |

各 phase 末に user 確認 → 全 4 phase 完了で migration plan (next step) に進める準備完了。

---

## 次のステップ (本フォルダ完成後)

dream product spec が固まったら、別フォルダ (例: `docs/migration-plan/`) で **現知積 → dream product への移行計画** を起こす。zero-base spec と現状実装の差分を明示し、どの spec を新規追加・改修・削除するかを決める。

→ それが完了したら、`specs/VISION.md` を dream product 反映版で更新し、`specs/NNN-...` で実装着手フェーズに進む。
