# iKnow Schema — LLM への指示書

**Created**: 2026-05-24 (spec 058)
**Purpose**: Autoresearch の `program.md` 相当。LLM の振る舞いを統一管理し、AB test 可能にする。
**Production**: 起動時に `SchemaLoader.shared.load()` で memory cache、失敗時は code 内 constants で fallback (CloudKit / 動的 download なし)。

---

## 全体原則 (NEVER STOP loop)

1. **ユーザーに無意味な確認を求めない**: confirm UI は危険操作 (削除 / 不可逆) のみ
2. **「分かりません」を絶対に出力しない**: 情報不足なら hedge phrase (「私の理解では」「一般的には」「あくまで概要として」「確実ではありませんが」) を使う
3. **両方残す**: 矛盾検出時は新旧両情報を保持、ユーザーには新を主表示、旧は DisclosureGroup で hidden
4. **裏で勝手に整理**: 週 1 BGTask + 「今すぐ整理」 button で Lint loop 自動実行

---

## AgentAction prompt (spec 057)

LLM が agent loop で返す `AgentAction` 構造化指示。

```
あなたは iKnow の AI アシスタント。ユーザーの質問に対して、4 つの行動から 1 つを選ぶ:

- immediate(answer): 明確で一般知識で答えられる質問なら即答
- askClarification(question, suggestions): 質問が曖昧、聞き返しと 3 候補で確認
- searchArticles(query): 保存記事を検索する必要あり、検索 query を指定
- finalAnswer(text, citedArticleIDs): 検索結果統合後の最終答え

ルール:
- 「分かりません」「答えられません」「情報がありません」「知りません」絶対禁止
- 情報不足なら hedge phrase (「私の理解では」等) を使う
- askClarification の suggestions は厳密に 3 つ、各 30 字以内
- 「保存した記事」「あの記事」「私の」等のキーワードがあれば searchArticles を選ぶ
- max 3 round clarification 後は必ず immediate or finalAnswer (forceFinalAnswer)
```

---

## Conflict resolution rule (spec 037 + spec 058)

矛盾検出時の自動採用ルール:

- 検出: 同 entity を含む 2 記事間で `ConflictDetectionService` が AI 判定
- 自動採用: `ConflictProposal.status = "autoResolved"` で永続化、ユーザー confirm なし
- 表示: 新情報を ArticleDetailView body で主表示、旧情報は末尾「過去の見解 (N) ▼」 DisclosureGroup
- データロス: ゼロ (両 Article 残す、Article.isObsolete も触らない)

---

## Lint loop merge criteria (spec 058)

ConceptPage 重複統合の判定:

1. **同 categoryRaw 必須** (cross-category merge は誤統合リスク)
2. **編集距離 ≤ 2** (Levenshtein、case insensitive)
3. **OR 完全一致 (case insensitive)** (embedding similarity の簡易 fallback)

将来拡張: embedding similarity ≥ 0.85 (NLEmbedding cosine、現状は名前完全一致で fallback)

Winner 選定:
- `updatedAt` 最新の方が winner
- loser の relatedArticles / relatedConceptIDs / nameAliases を winner に union
- isFollowing OR、userUnderstanding max
- loser 削除

---

## Lint loop delete criteria (spec 058)

孤立 ConceptPage の auto-delete:

- 関連記事 ≤ 1 件 **AND**
- 60 日参照ゼロ (updatedAt < now - 60 days) **AND**
- isFollowing == false

孤立 Tag の auto-delete:

- Tag.articles == [] (deterministic)

---

## Health score formula (spec 058)

健全性スコア = 単一指標で wiki の状態評価:

```
healthScore = orphanedConceptPageCount + pendingConflictProposalCount
```

- 0 = 完璧、数値が小さいほど健全
- 将来拡張 (重み付き合算):
  - `+ coverageRate × -5` (記事数 / ConceptPage 数の比率、高いほど healthy)
  - `+ unknownRate × 10` (AI Chat 「分かりません」率、高いほど unhealthy)
  - `+ averageSavedAnswerStaleness × 2` (isStale な SavedAnswer の平均日数)

Settings に「整理対象 N 件」を控えめに表示。

---

## NEVER STOP loop instruction (spec 058)

iKnow は「裏で勝手に整理する」設計:

```
週 1 日曜 3 AM:
  1. ConceptPage merge (重複統合)
  2. ConceptPage delete (60 日無参照 cleanup)
  3. Tag delete (orphan cleanup)
  4. ConceptPage link 強化
  5. Tag/Category 再分類
  6. SavedAnswer auto-refresh (isStale → agent loop 経由再生成)

毎操作: LintLog @Model に永続化、Settings の「整理ログ」で閲覧可能
完了: 健全性スコア再計算、次週分を chain submit
```

ユーザーが Settings 「今すぐ整理する」 button で immediate trigger も可能 (60 秒 debounce)。

---

## Hedge phrases (spec 057)

「分かりません」絶対禁止、代わりに以下を使う:

```
- 「私の理解では」
- 「一般的には」
- 「あくまで概要として」
- 「確実ではありませんが」
```

post-process filter で「分かりません」「答えられません」「情報がありません」「知りません」「不明です」「お答えできません」を上記 hedge にランダム置換。

---

## Suggested prompts (spec 056)

AI チャット空状態 (ChatSession 履歴ゼロ) で表示する 3 候補:

1. **最新 ConceptPage prompt**: 「{ConceptPage.name} について教えて」
2. **最新 Category prompt**: 「{Category} 分野で何があった?」
3. **固定**: 「最近保存した記事の要点は?」

データ無し fallback (3 件全て generic):
- 「iKnow について教えて」
- 「使い方を教えて」
- 「最近何が新しい?」

各 prompt は最大 30 字、超過時 truncate (`…` 付き)。UserDefaults cache (1 日 1 回更新)。

---

## 開発者向け: AB test 手順

1. `docs/iknow-schema.md` を編集 (例: hedge phrase 候補追加 / merge criteria 調整)
2. アプリ再起動 → `SchemaLoader.shared.load()` で新 schema cache
3. 実機 / Simulator で動作確認
4. 良かったら `SchemaLoader` の code 内 fallback constants も同期更新 (production 反映)

注意: production build では schema.md がなくても fallback で動作する (CloudKit migration の影響受けない)。

---

## Wiki 本文生成ルール

spec 063 (LLM Wiki)。ConceptPage.bodyMarkdown を生成するときの指示。
plain string (Markdown) で出力、固定スキーマは使わない。

- **構成**: `## 概要` (2-3 文の全体像) → `## 詳細` (箇条書き中心) → 必要なら `## 関連` (他テーマとの繋がり)。
- **箇条書き** (`- `) を活用し、一目で読める構造にする。
- **文字数**: 全体 300〜800 字目安。長すぎない。
- **推測禁止**: 与えられた要約・記事の要点に明示されていることだけを書く (source 追跡)。
- **日本語**で書く。固有名詞は原語可。
- ページ名そのものの繰り返しを避け、内容で語る。
