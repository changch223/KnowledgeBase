# 概念ページが「広すぎる/平ら」問題 — 現状設計の分析と改善案

**作成**: 2026-06-07 / **対象**: `main + 072-category-fix` / **目的**: なぜ AI・Claude・Claude Code・Anthropic・OpenAI・データ分析・プロジェクトマネージャー が全部「同じ階層の広い概念ページ」になるのかを設計レベルで解明し、階層化の改善案をまとめる。

**注**: file:line は調査時点の目安。

---

## 1. 問題の症状（実機ログ）

```
concept page created: AI [テクノロジー] with 16 articles
concept page created: AI [その他]       with 10 articles   ← 同じ "AI" が2ページ
concept synthesis start for OpenAI [テクノロジー]: articles=5
concept synthesis start for Anthropic [テクノロジー]: articles=7
concept synthesis start for Claude Code [テクノロジー]: articles=9
concept synthesis start for CLAUDE [テクノロジー]: articles=9   ← Claude Code と別
concept synthesis start for AI [テクノロジー]: articles=16
concept page created: データ分析 [テクノロジー] with 3 articles
concept page created: Hacker News [その他] with 2 articles    ← サイト名が概念に
```

**ユーザーの指摘（正しい）**：
- `AI` / `データ分析` / `プロジェクトマネージャー` は **超広域**（分野レベル）
- `Anthropic` / `OpenAI` は **企業**
- `Claude` は **製品**、`Claude Code` / `Claude 3.7` は **その製品の一機能/バージョン**
- 本来こうした **階層**（分野 ⊃ 企業 ⊃ 製品 ⊃ 機能）があるはずなのに、**全部フラットに同列**で並んでいる。
- そして**広い概念ほど記事が集まって肥大化**（AI=16件）し、**具体的な概念はページにすらならない**。

---

## 2. 現状の設計（どうなっているか）

概念ページの中身は **3 つの段階**で決まる。①概念名の供給源（entity 抽出）→ ②ページの作られ方（entity 共起）→ ③階層・正規化（＝ほぼ無い）。

### 2-1. 概念名はどこから来るか = entity 抽出

`KnowledgeExtractor.buildPrompt`（`KnowledgeExtractor.swift:124`）は **entity 専用の指示を持たない**。本文を渡して「構造化された知識を抽出」と言うだけ：

```
以下の記事本文から構造化された知識を抽出してください。
# 抽出ルール (厳守)
- 元記事に明示されている内容のみを抽出してください
- 推測・補完・常識による補強は行わないでください
...
```

entity の形は `@Generable` スキーマだけで決まる（`LanguageModelSessionProtocol.swift`）：

```swift
struct KnowledgeEntityOutput {
    @Guide(description: "固有名詞 (30 字以内)")          let name: String
    @Guide(description: "種別")                          let type: EntityType   // person/organization/location/concept/product/work
    @Guide(description: "重要度 1〜5 (5 が最重要)")       let salience: Int
}
// ExtractedKnowledgeOutput.entities @Guide: "5-10 件、重要な固有名詞"
```

**ここが第一の根。** モデルへの指示は「重要な固有名詞を 5〜10 件」だけ。**抽象度（具体的か・広域か）という概念がどこにもない。** だから：
- `AI`（超広域）も `Claude Code`（具体）も同じ「固有名詞」として**並列に**抽出される
- `EntityType` に `concept`（概念・用語）はあるが、`field`（分野）と `specific entity`（具体物）を区別しない
- `salience`（重要度）はあるが、これは「記事内での目立ち度」であって「抽象度」ではない

### 2-2. 概念ページの作られ方 = entity 共起（出現回数だけ）

`ConceptSynthesisCommon.processNewArticle`（`ConceptSynthesisService.swift:650`）：

```
1. 記事の entities を 1 件ずつ見る (name 2 文字以上、minEntityNameLength=2)
2. キー = entity名(小文字) + categoryRaw  で既存ページを検索
3. あれば relatedArticles に追加 + isStale=true
4. なければ「同カテゴリの他記事に同名 entity があるか」を数え、
   - 1 件でもあれば（= 計 2 記事以上）→ ConceptPage 新規作成、ページ名 = entity 名そのまま
   - 無ければ作らない
```

**ここが第二の根。** ページ生成の唯一の条件は「**同じ entity 名が同カテゴリの 2 記事以上に出る**」。つまり：
- **出現頻度だけ**で作る。`salience` は**使われていない**（重要度 1 の端役 mention でもカウント）
- **広い語ほど多くの記事に出る → 真っ先に閾値を超える → 広い概念が優遇される**（TF はあるが IDF が無い検索エンジンと同じ病）
- ページ名は entity 名の生コピー。`Claude Code` と `CLAUDE` が別 entity なら別ページ

### 2-3. 階層・正規化の有無 = ほぼ無い

`ConceptPage` @Model（`ConceptPage.swift`）のフィールド：

| フィールド | 役割 | 階層に使えるか |
|---|---|---|
| `name` / `nameAliases` | 名前と別名 | 別名は**手動 merge 時のみ**設定。自動正規化なし |
| `categoryRaw` | 10 カテゴリのどれか | **キーの一部** → 同じ概念がカテゴリ違いで分裂 |
| `relatedConceptIDs: [UUID]` | 関連ページ | **フラットな兄弟リンクのみ**（embedding cosine ≥0.5 top8）。親子の区別なし |
| `kindRaw` | person/concept/project | 3 種だけ。分野/企業/製品/機能の階層ではない |

**ここが第三の根。`ConceptPage` に `parentConceptID` のような階層フィールドが存在しない。** `relatedConceptIDs` は「似ている度」で繋ぐ平らなグラフで、`AI → Anthropic → Claude → Claude Code` という**包含関係を表現できない**。`searchableNames` は大文字小文字を無視するだけ（`CLAUDE`==`claude`）で、`Claude`/`クロード`/`Claude 3.7` は別物のまま。

---

## 3. なぜこうなったのか（設計の経緯と構造的理由）

| 理由 | 中身 |
|---|---|
| **MVP の単純定義** | spec 042 で「**entity が 2 記事に共起 = 概念**」と最小定義した。抽象度や階層を扱う仕組みは「軽さ優先・複雑さ回避」のため意図的に入れなかった |
| **TF only / IDF 無し** | 出現回数だけでページ化する設計が、構造的に**広域語を優遇**する。これは「広い概念が肥大化、具体概念が埋もれる」の直接原因 |
| **category キーの名残** | spec 016 のカテゴリ別整理の流れで `entity名 + categoryRaw` をキーにした。結果、同一概念がカテゴリ違いで割れる（AI[テク]/AI[その他]） |
| **正規化の後回し** | alias 統合は手動 merge のみ実装（spec 024）。自動正規化は spec 074 に先送り |
| **抽出が「固有名詞」止まり** | entity 抽出に「具体性」という軸を持たせなかったので、分野語と具体物が同列に出る |

→ 総じて **「平らな entity バッグ」設計**。記事が少ないうちは破綻しないが、増えると広域語に飲み込まれ、ユーザーの言う「大まかすぎる」状態になる。**これは prompt の文言ではなく、データモデルと生成ルールの構造問題**である。

---

## 4. 改善できるのか（できる。方向は 5 つ、組合せる）

### 案 A：抽出側に「抽象度」を持たせる【上流の根治・効果大】
- entity 抽出 prompt に「**具体的な固有名詞を優先。`AI`/`技術`/`データ分析` のような分野・総称は scope=field として区別**」を明示
- `KnowledgeEntityOutput` に `scope`（`specific` / `field`）を 1 つ追加（@Generable enum）
- 効果：分野語を「ページ化しない or 親候補にする」判断が下流でできる
- 注意：@Generable に列追加 = 出力 token 微増（§ token 設計と要バランス）

### 案 B：概念ページに階層（親子）を持たせる【本丸】
- `ConceptPage` に `parentConceptID: UUID?` を追加（default nil = **CloudKit lightweight migration 安全**）
- 親子の自動推定（AI 呼び出しを増やさず）：
  - **名前包含**：`Claude Code` は `Claude` を含む → 子候補
  - **embedding 包含**：子は親の意味空間に内包されやすい（既存 embedding 流用）
  - **scope（案 A）**：field 語を親、specific 語を子に寄せる
- UI：親ページに「関連する詳細トピック（子）」セクション、子に「上位概念」リンク
- 効果：`AI ⊃ Anthropic ⊃ Claude ⊃ Claude Code` のドリルダウンが実現

### 案 C：広域語のページ化を抑制（IDF / salience / stoplist）【即効・低リスク】
- **IDF**：全記事の N%（例 40%）超に出る語は「広すぎ」→ 単独ページにせず**ナビ用カテゴリ扱い**（or 親のみ）
- **salience 閾値**：低重要 mention（salience ≤ 2）はページ生成に数えない（現状は無視されている）
- **stoplist**：`男性`/`ユーザー`/`企業`/`彼女は`/地名 等の一般語・代名詞を除外（spec 074 と共通）
- 効果：肥大化した無意味ページの発生を止める。token も節約

### 案 D：category キーを廃止して分裂解消【spec 074】
- ページのキーを `entity名 + category` から **canonical entity 名のみ**に変更
- `AI[テク]` + `AI[その他]` を 1 ページに統合（category はタグ/ファセットとして保持）

### 案 E：entity 正規化（alias 自動統合）【spec 074】
- `Claude`/`クロード`/`CLAUDE` → `Claude` に正規化（nameAliases 自動投入）
- ただし `Claude Code` / `Claude 3.7` は**別物として保持**（案 B の子にする）。= 正規化と階層化はセット

---

## 5. 推奨ロードマップ

現行の「コア品質ブラッシュアップ」（memory `project_core_quality_brushup`）に階層化を組み込む：

| 順 | 内容 | 規模 | リスク |
|---|---|---|---|
| 1 | **案 C（IDF + salience + stoplist）** で広域語/ゴミの暴発を止める | 小（生成ルールのみ、@Model 不変） | 低 |
| 2 | **案 D + E（spec 074：canonical キー + alias 正規化）** で分裂を畳む | 中（照合ロジック、migration 検討） | 中 |
| 3 | **案 A（抽出に scope）** で具体/分野を分ける | 中（prompt + @Generable 1 列、token 注意） | 中 |
| 4 | **案 B（parentConceptID で階層）** でドリルダウン UI | 大（@Model 1 列 + 推定 + UI） | 中 |

**最初の一手は案 C**（@Model を触らず、生成ルールに IDF/salience/stoplist を足すだけ）。一番安全で、肥大化の即時抑制になる。階層 UI（案 B）は土台（C/D/E）が整ってから。

---

## 6. リスク・制約（必ず守る）

- **CloudKit 安全則**：`ConceptPage` への列追加は **default 付き必須**（`parentConceptID: UUID? = nil` 等）。@Model の削除・rename は禁止（型名 `ConceptPage` は永久に維持）
- **AI 呼び出しを増やさない**：階層・正規化の推定は **embedding + 名前ルール**で行い、新たな LLM 呼び出しを足さない（VISION 軽さ優先）
- **token 設計と両立**：案 A の @Generable 列追加は出力予約を増やす。`docs/ARCHITECTURE.md` §12（出力スキーマ圧縮）と整合させる
- **既存データの再分類コスト**：canonical 化・階層付与は backfill が要る。BGTask で段階適用（一括は重い）
- **過剰マージの誤り**：`Claude` と `Claude Code` を同一視しない。正規化（同一物の表記揺れ）と階層化（別物の包含）を**混同しない**のが肝

---

## 付録：関連ファイル早見

- entity 抽出 prompt → `KnowledgeExtractor.swift:124` `buildPrompt`
- entity スキーマ（name/type/salience）→ `LanguageModelSessionProtocol.swift`（`KnowledgeEntityOutput` / `EntityType`）
- 概念ページ生成（共起ルール）→ `ConceptSynthesisService.swift:650` `processNewArticle`
- category 解決 → `ConceptSynthesisService.swift:725` `resolveCategoryRaw`
- 概念モデル（階層フィールド不在）→ `ConceptPage.swift`
- 全体像・token 所見 → `docs/ARCHITECTURE.md` §5・§12
- コア品質計画 → memory `project_core_quality_brushup` / `project_category_classify_accuracy`
