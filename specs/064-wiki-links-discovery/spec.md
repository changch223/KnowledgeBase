# Feature Specification: Wiki ページ相互リンク + 関係発見

**Feature Branch**: `064-wiki-links-discovery`
**Created**: 2026-05-31
**Status**: Draft
**Input**: VISION v2 (LLM Wiki) 第 1 段階後半。Plan エージェント設計 (embedding Phase 1 + AI リンク Phase 2)

## 背景

VISION v2 (LLM Wiki) の核心「ページ間に相互リンクを張り、整理された状態を維持する」を実現する。spec 063 で ConceptPage が Markdown 本文 (bodyMarkdown) を持つ Wiki ページに進化した。本 spec はそのページ間に**関係 (リンク)** を作る。

関係発見には 3 つの仕組みがあり、本 spec で不足分を埋める:
1. **entity 共起** (同じ人物・モノが複数記事に出る) — 既存 (ConceptPage 生成のトリガ)
2. **embedding 類似** (意味が近いページ) — **本 spec で追加** (relatedConceptIDs がほぼ空のまま埋まっていない)
3. **AI の判断** (文脈的に関連) — **本 spec で追加** (AI が本文に相互リンクを書く)

これが完成すると、現在の GraphNode/GraphEdge (entity 関係を別管理する 7 分裂の 1 つ) の役割を WikiPage が引き継ぎ、spec 065 で graph 生成を安全に止められる。

**1 文の本質**: 「Wiki ページ間を embedding 類似で自動リンクし、AI が本文に相互リンクを書くことで、バラバラなページを繋がった知識ベースにする」

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 関連ページが自動で繋がる (Priority: P1)

ユーザーが概念ページ (Wiki ページ) の詳細を開くと、「つながる人物・モノ」セクションに、意味的に近い他のページが自動で表示される。これまでこのセクションはほぼ空だったが、AI が記事を取り込むたびに裏で関連ページが計算され、繋がりが見えるようになる。

**Why this priority**: Wiki の価値は「ページが孤立せず繋がっていること」。関連ページが見えることで、1 つの概念から芋づる式に知識を辿れる。

**Independent Test**: 複数の関連する概念ページがある状態で 1 つを開き、「つながる人物・モノ」に意味的に近いページが表示されることを確認。

**Acceptance Scenarios**:

1. **Given** 意味的に近い概念ページが複数ある, **When** 1 つの詳細を開く, **Then** 「つながる人物・モノ」に関連ページが表示される
2. **Given** 関連ページが 1 つも無い (孤立) 概念ページ, **When** 詳細を開く, **Then** セクションは空で破綻しない
3. **Given** AI が利用不可な端末, **When** 記事を取り込む, **Then** 関係発見はスキップされ既存の繋がりは保たれる (破綻しない)

---

### User Story 2 - 本文中のページ名がリンクになる (Priority: P1)

AI が書いた Wiki 本文の中で、他のページ (人物・概念) の名前が出てきたら、その名前がタップ可能なリンクになる。タップするとそのページの詳細に移動できる。Wikipedia のように、本文を読みながら関連概念へ自然に飛べる。

**Why this priority**: Karpathy LLM Wiki の核心「ページ間に相互リンクを張る」。本文リンクで「読みながら辿る」体験が生まれる。

**Independent Test**: 本文中に他ページ名を含む概念ページを開き、その名前がリンク表示され、タップで該当ページに移動することを確認。

**Acceptance Scenarios**:

1. **Given** 本文に他ページの名前を含む概念ページ, **When** 詳細を開く, **Then** その名前がリンク (色付き・下線) で表示される
2. **Given** 本文中のリンク, **When** タップ, **Then** 該当する概念ページの詳細に移動する
3. **Given** AI が存在しないページ名にリンクを書こうとした, **When** 表示, **Then** そのリンクはプレーンテキストになり、壊れたリンク (タップしても何も起きない) は表示されない

---

### User Story 3 - 関係発見が AI 呼び出しを増やさない (Priority: P1)

記事を取り込んで関係を発見する処理は、AI の呼び出し回数を増やさない (embedding の類似計算は数値演算でローカル完結、本文リンクは既存の本文生成 prompt を拡張するだけ)。VISION の「軽さ優先」を守る。

**Why this priority**: 関係発見のために AI 呼び出しが増えると「重い」が悪化する。VISION 原則に反するため、追加コストゼロが必須。

**Independent Test**: 記事取り込み時の AI 呼び出し回数が、関係発見の追加によって増えていないことを確認 (embedding は AI ではない、本文リンクは既存呼び出しの prompt 拡張のみ)。

**Acceptance Scenarios**:

1. **Given** 記事取り込み, **When** 関係発見 (embedding) が走る, **Then** AI (言語モデル) の呼び出しは発生しない
2. **Given** 本文生成, **When** リンク指示を含む prompt で生成, **Then** 本文生成の AI 呼び出し回数は従来と同じ (1 回)

---

### Edge Cases

- **embedding なし**: AI 不可端末では embedding が無いので関係発見はスキップ、既存の繋がりは保持。
- **捏造リンク**: AI が候補に無い / 存在しない UUID のリンクを書いた場合、表示時にプレーンテキスト化し、壊れたリンクを出さない。
- **同名ページ**: ID 直書きで一意解決するため、同名 (分野違い) ページの誤リンクは起きない。
- **リンク先削除**: リンク先ページが削除/統合で消えていた場合、タップしてもクラッシュせず安全に無視 (既存の reactive guard 流用)。
- **token**: 本文生成 prompt に候補ページを足しても処理上限を超えない (候補は名前 + ID のみで軽い)。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 記事取り込み時、各 Wiki ページに意味的に近い他ページを自動で関連付けなければならない (embedding 類似)。
- **FR-002**: 関連付けの計算は言語モデル (AI) を呼び出してはならない (数値演算でローカル完結)。
- **FR-003**: Wiki ページ詳細の「つながる人物・モノ」セクションに、関連付けられたページを表示しなければならない。
- **FR-004**: AI が書く Wiki 本文の中で、他ページの名前を相互リンクにできなければならない。
- **FR-005**: 本文中のリンクをタップしたとき、該当する Wiki ページの詳細に移動しなければならない。
- **FR-006**: AI が候補に無い / 存在しないページへのリンクを書いた場合、そのリンクはプレーンテキスト化し、壊れたリンクを表示してはならない。
- **FR-007**: 本文リンク生成は、本文生成の AI 呼び出し回数を増やしてはならない (既存 prompt の拡張のみ)。
- **FR-008**: AI が利用不可な端末では関係発見をスキップし、既存の関連付けを保持しなければならない。
- **FR-009**: リンク先ページが削除/統合で消えていた場合、タップしてもクラッシュしてはならない。
- **FR-010**: 本変更は永続化スキーマ (@Model) を変更してはならない (relatedConceptIDs / embedding は既存)。

### Key Entities

- **Wiki ページ (ConceptPage)**: 関係発見の対象。`relatedConceptIDs` (関連ページ ID、既存) と `embedding` (意味ベクトル、既存) を使う。本 spec で @Model 変更なし。
- **記事 (Article)**: 関係発見の起点 (記事取り込みがトリガ)。参照のみ。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 意味的に近い概念ページがある状態で詳細を開くと「つながる人物・モノ」に関連ページが表示される。
- **SC-002**: 関係発見 (embedding) の処理で AI 呼び出しが発生しない。
- **SC-003**: 本文中の他ページ名がリンク表示され、タップで該当ページに移動する。
- **SC-004**: AI が書いた存在しないリンクがプレーンテキスト化され、壊れたリンクが表示されない。
- **SC-005**: 本文生成の AI 呼び出し回数が従来と同じ (関係発見で増えない)。
- **SC-006**: リンク先が削除されていてもタップでクラッシュしない。
- **SC-007**: クリーンビルド成功 + 既存 unit test 全 regression PASS + 関係発見の新規テスト PASS。

## Assumptions

- 関係発見の embedding 類似計算は、既存の意味ベクトル (ConceptPage.embedding、summary から生成済み) と cosine 類似度で行う。新規の AI 呼び出しは不要。
- 関連ページの上限は最大 8 件程度 (詳細画面の既存表示上限に合わせる)。類似度が低すぎるもの (閾値未満) は除外する。
- 本文リンクは `[ページ名](内部リンク識別子)` の形式で AI に書かせ、識別子には実在ページの ID を渡して一意解決する (同名ページの誤リンク回避)。
- 本文リンク表示・遷移は、既存の AI チャット引用リンク機構 (spec 033) を流用する。
- 本文生成 prompt に渡す関連候補は embedding 近傍を再利用し、token を圧迫しないよう件数・文字数を絞る。
- @Model は変更しない (relatedConceptIDs / embedding / bodyMarkdown はすべて既存)。CloudKit migration 影響ゼロ。

## Dependencies

- **spec 063** (WikiPage 土台、bodyMarkdown / generateWikiBody) — 進化元。
- **spec 042** (ConceptPage、relatedConceptIDs / embedding) — 既存フィールド。
- **spec 021** (EmbeddingService、cosineSimilarity) — 類似計算。
- **spec 033** (AI チャット inline 引用リンク) — リンク表示・遷移機構の流用元。
- **spec 058** (iknow-schema.md / SchemaLoader) — リンク記法ルールの追記先。

## Out of Scope

- News+ フィード (spec 066)。
- 旧モデル (GraphNode/UserTopic/KnowledgeDigest) の生成停止・退役 (spec 065)。
- 検索・カテゴライズ強化 (後段)。
- @Model の追加・変更 (relatedConceptIDs / embedding は既存で十分)。
