# Feature Specification: カテゴリ誤分類修正 (コア品質ブラッシュアップ 第2段階)

**Feature Branch**: `072-category-fix`
**Created**: 2026-06-06
**Status**: 実装完了 (実機検証残)
**Input**: 2 エージェント監査 + Plan 設計 + 実機ログ

## 背景

`AutoCategoryClassifier` がタグ名を 10 カテゴリ (テクノロジー/経済/健康/デザイン/学術/アート/ニュース/スポーツ/エンタメ/その他) に分類するが、実機ログで誤分類が多発:
- 「ハルシネーション」→健康、人名→スポーツ、「zenn」→デザイン
- 候補外カテゴリ生成 (「技術」「数学」「男性」「企業」「倫理的課題」→ fallback「その他」)

spec 068 で「分野」カードをフィードに出すようにしたため、この誤分類がユーザーに見える。token リスクはゼロ (出力 schema は文字列 1 個)。

**根本原因 (両エージェント一致)**:
1. **タグ名 1 語だけで分類、文脈ゼロ** (`classify(tagName: String)`)。記事の領域情報が失われ、「Apple」単体ではテク/ニュース/エンタメを判定不能
2. **prompt に各カテゴリの定義/例/反例がない** (旧 prompt は「候補から1つ完全一致で」だけ)。Foundation Models が日本語の同義語 (健康←ウェルネス/医学) を「完全一致」と誤認、候補外カテゴリも生成

**1 文の本質**: 「タグ名だけの分類に記事の文脈を足し、prompt に各カテゴリの定義+例+反例を埋めて、誤分類を減らす」

## User Scenarios & Testing *(mandatory)*

### User Story 1 - カテゴリが正しく分類される (Priority: P1)

記事を保存したとき、その記事のタグが内容に即した正しいカテゴリ (テク記事のタグ=テクノロジー) に分類される。AI 用語が健康に、人名がスポーツに誤分類されることが減る。

**Independent Test**: テク記事 (Claude/RAG/embedding のタグ) を保存し、テクノロジーに分類されることを実機ログで確認。

**Acceptance Scenarios**:
1. **Given** テク記事のタグ (ハルシネーション/RAG 等), **When** 分類, **Then** テクノロジーに分類される
2. **Given** 人名タグ (記事文脈なし), **When** 分類, **Then** スポーツ等に誤分類されず文脈優先か「その他」
3. **Given** 候補外を返しそうな曖昧タグ, **When** 分類, **Then** 10 候補のいずれか (or その他)、生成された候補外語が漏れない

### Edge Cases
- AI 不可端末: 「その他」fallback (既存)。
- 文脈なし: タグ名のみで分類 (degrade)。
- 候補外生成: 既存検証 (CategorySeed 一致しなければ「その他」) を維持。

## Requirements *(mandatory)*

- **FR-001**: 分類 prompt に各カテゴリの定義 + 代表例 + 反例を含めなければならない。
- **FR-002**: 分類入力にタグ名だけでなく記事の文脈 (タイトル/essence) を渡せなければならない。
- **FR-003**: prompt は「10 候補のいずれかに完全一致、候補外を作らない、迷う人名・一般語はその他」を明示しなければならない。
- **FR-004**: 出力が CategorySeed に一致しない場合「その他」fallback (既存維持)。
- **FR-005**: CategorySeed の 10 カテゴリ (name) を変更してはならない (CloudKit 安全)。
- **FR-006**: AI 呼び出し回数を増やしてはならない (1 タグ 1 回のまま)。
- **FR-007**: @Model を変更してはならない。

### Key Entities
- **AutoCategoryClassifier** (改修): prompt 刷新 + `classify(tagName:context:)` に文脈引数追加 (後方互換 extension で `classify(tagName:)` 維持)。
- **CategorySeed** (改修): `promptCandidatesWithDefinitions` 追加 (name 配列は不変)。

## Success Criteria *(mandatory)*

- **SC-001**: テク記事のタグがテクノロジーに分類される (実機)。
- **SC-002**: 実機ログで候補外カテゴリ生成・人名→スポーツ等の誤分類が減る。
- **SC-003**: AI 呼び出し回数が増えない (1 タグ 1 回)。
- **SC-004**: クリーンビルド成功 + AutoCategoryClassifierTests 回帰 PASS。

## Assumptions
- 記事文脈 = `article.title` + `ExtractedKnowledge.essence` (既存)。呼び出し元 (TagStore.addTag / AutoCategoryBackfillRunner / LintEngine) から渡す。
- prompt が長くなるが出力 schema は文字列 1 個なので token 影響は軽微 (context は 200 字 cap)。
- `InMemoryAutoCategoryClassifier` は引数追加に追従 (mapping ロジック不変)。

## Dependencies
- spec 015 (AutoCategoryClassifier 導入)、CategorySeed、ExtractedKnowledge.essence。

## Out of Scope
- カテゴリ数の増減 (10 個維持)。
- entity 抽出側の改善 (一般語が entity 化される問題は spec 074 = entity 正規化)。
- token 緩和 (spec 073)。
