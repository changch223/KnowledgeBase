# Feature Specification: ConceptPage (概念ページ)

**Feature Branch**: `042-concept-page`
**Created**: 2026-05-23
**Status**: Draft
**Input**: ConceptPage — iKnow V1 第 1 弾、Phase A の中核 spec、Karpathy LLM Wiki 思想の「concept page」を SwiftData で実装する最重要 spec

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 概念ページの自動生成 (Priority: P1)

ユーザーが Apple について書かれた複数の記事 (例: 5 本) を Share Sheet で保存すると、「Apple」という概念ページがアプリ内に自動で出来上がる。記事を読まなくても、AI が複数記事を統合して「今 Apple について分かっていること」の要点と、「複数記事を並べて初めて見える横断的な知見」を文章で提示する。

**Why this priority**: dream-product/03-core-loops.md「秘書ループ」の核心。Karpathy LLM Wiki 思想の "compounding artifact" を実現する本体メカニズム。これがないと iKnow は単なる RAG アプリで終わる。

**Independent Test**: 同名 entity (例: "Apple") を含む 2 件以上の記事を保存 → 知識 Clip タブを開き、「あなたが追っている人物・モノ」セクションに「Apple」カードが表示され、タップで詳細画面に summary + crossSourceInsights が表示されることを確認できる。

**Acceptance Scenarios**:

1. **Given** "Apple" を含む記事を 1 件保存した状態, **When** 同じ "Apple" を含む 2 件目を保存, **Then** 「Apple」概念ページが自動生成され、2 件の要点を統合した summary (200-400 字) が表示される
2. **Given** "Apple" を含む記事が 1 件のみ, **When** その状態を確認, **Then** 「Apple」概念ページは未生成 (graph ノードのみ存在)
3. **Given** 既に「Apple」概念ページが存在, **When** "Apple" を含む 3 件目の記事を保存, **Then** 概念ページが `isStale = true` でマークされ、BGTask 実行後に summary が更新される
4. **Given** ConceptPage が生成された状態, **When** 詳細画面を開く, **Then** 4 セクション (今わかっていること / 横断的知見 / 関連記事 / つながる人物・モノ) が表示される

---

### User Story 2 - 知識 Clip タブで概念ページ一覧 (Priority: P1)

知識 Clip タブを開いたユーザーは、「あなたが追っている人物・モノ」セクションで、これまで保存した記事から AI が自動で発見した人物・モノ・テーマのカード一覧を見られる。カードには概念名 + 関連記事数 + 1 行要約 + 最終更新日が表示され、タップで詳細画面に遷移できる。

**Why this priority**: ConceptPage を user に surface する第一の場所。ConceptPage が自動生成されても、見えない場所にあると価値ゼロ。

**Independent Test**: 5 件の記事を保存して概念ページが 2-3 個生成された状態で、知識 Clip タブを開き、「あなたが追っている人物・モノ」セクションにカード一覧が表示されることを確認できる。

**Acceptance Scenarios**:

1. **Given** 概念ページが 0 個の状態, **When** 知識 Clip タブを開く, **Then** 「あなたが追っている人物・モノ」セクションは表示されない (空状態)
2. **Given** 概念ページが 3 個生成済, **When** 知識 Clip タブを開く, **Then** 3 個のカードが更新日 desc で表示される
3. **Given** 概念ページが 10 個以上ある, **When** セクションを表示, **Then** 上位 5 個 + 「+N すべて見る」リンク
4. **Given** カードをタップ, **When** タップ後, **Then** 該当 ConceptPage 詳細画面に遷移する

---

### User Story 3 - 概念ページ詳細画面 (Priority: P1)

ユーザーが概念ページカードをタップすると、その概念について「今わかっていること」(AI 合成要約)、「横断的知見」(複数記事を統合して見えた発見)、「関連記事」(原典への jump)、「つながる人物・モノ」(他概念へのリンク) の 4 セクションが見られる。

**Why this priority**: ConceptPage の中核 UI。詳細画面なしでは概念ページの価値が伝わらない。

**Independent Test**: 概念ページが生成された状態で詳細画面を開き、4 セクションが全て正しく表示されることを確認できる。

**Acceptance Scenarios**:

1. **Given** ConceptPage 詳細画面を開いた状態, **When** scroll, **Then** 「今わかっていること」「横断的知見」「関連記事」「つながる人物・モノ」の 4 セクションが順に表示される
2. **Given** 「関連記事」セクション, **When** いずれかの記事タップ, **Then** Article Detail 画面に遷移する (原文へ jump 可能)
3. **Given** 「つながる人物・モノ」セクション, **When** 他概念タップ, **Then** その概念の詳細画面に遷移する (探索可能)
4. **Given** AI 合成 summary が未完了 (新規生成中), **When** 詳細画面を開く, **Then** 「整理中…」プレースホルダー表示 (calm UX)

---

### User Story 4 - 概念ページの編集 (rename / merge / delete) (Priority: P2)

ユーザーが ConceptPage に誤って自動生成された概念名 (例: "Apple Inc." と "Apple" が別ページに) を見つけた時、rename / merge / delete で訂正できる。merge では 2 つの ConceptPage を統合し、関連記事 / 関連概念 を 1 つにまとめる。

**Why this priority**: AI 自動生成の精度限界をユーザーが補正できる仕組み。AI が間違えた時の "out" が無いと信頼性が落ちる。

**Independent Test**: 2 つの概念ページ ("Apple" と "アップル") を merge → 1 つに統合され、関連記事数が合算される。 rename で名前変更、delete で削除 (関連記事は残る)。

**Acceptance Scenarios**:

1. **Given** ConceptPage 詳細画面, **When** [編集] toolbar タップ → rename, **Then** 名前変更 sheet 開き、新名前入力 → 保存で name 更新
2. **Given** 2 ConceptPage ("Apple", "アップル") が並立, **When** "アップル" を選択して [統合] → "Apple" を統合先に, **Then** 1 つに統合、関連記事合算、片方削除
3. **Given** ConceptPage を delete, **When** 削除確認 alert → 削除, **Then** ConceptPage 削除、ただし関連 Article は残る (raw データ保護)
4. **Given** rename で空文字 / 30 字超を入力, **When** 保存試行, **Then** エラー表示で保存阻止

---

### User Story 5 - 概念ページのピン (フォロー) (Priority: P2)

ユーザーが特に追いたい概念をピン (フォロー) すると、後続 spec で実装される学習タブで優先 surface される。本 spec では isFollowing フィールドの永続化のみ実装、surface ロジックは別 spec。

**Why this priority**: ユーザー能動キュレーション機能。本 spec は仕込みのみで実体験は別 spec 完成後。

**Independent Test**: ConceptPage 詳細画面の [ピン] toggle で isFollowing 値が DB に反映され、再起動後も維持される。

**Acceptance Scenarios**:

1. **Given** ConceptPage 詳細画面, **When** [ピン] toggle を on, **Then** isFollowing = true で DB 永続化
2. **Given** ピン済 ConceptPage, **When** アプリ再起動, **Then** ピン状態が維持される

---

### User Story 6 - 検索で概念ページがヒット (Priority: P3)

ユーザーが既存検索バー (ライブラリタブ) で query を入力した時、保存記事だけでなく、関連する概念ページもヒットする。

**Why this priority**: 検索 UX 改善。記事タイトルでヒットしない時、概念ページが受け皿になる。

**Independent Test**: "Apple" 概念ページがある状態で "Apple" を検索 → 検索結果に Article + ConceptPage 両方が表示される。

**Acceptance Scenarios**:

1. **Given** ConceptPage "Apple" が存在, **When** "Apple" を検索, **Then** 検索結果に該当 ConceptPage がヒット
2. **Given** ConceptPage の summary に "M5" が含まれる, **When** "M5" を検索, **Then** ConceptPage が summary hit でヒット

---

### Edge Cases

- entity 名が極端に短い (1-2 文字) 場合: 短すぎる entity は ConceptPage 化を skip (例: "AI" 等は ambiguous)
- 概念ページが大量 (100+) になった場合: 知識 Clip 表示は上位 5 + 「すべて見る」、内部 fetch は paginated
- Foundation Models が利用不可: Fallback として essence を並べた簡易 summary 生成、AI 合成失敗を ActivityLog に記録
- 同 entity が異なる category で出現 (例: "Apple" が果物カテゴリーとテクノロジーカテゴリー): 各 category 別に ConceptPage 作成
- 記事が削除された時: 関連 ConceptPage の relatedArticles から除外、ConceptPage は残る (孤立 ConceptPage は WikiLint で別 spec で処理)
- 同名 entity の大文字小文字違い ("Apple" vs "apple"): 大文字小文字無視で同一視、ConceptPage 1 つに統合
- AI 合成 中に新記事が入った場合: 現行 synthesis 完了後に再度 isStale = true → 次の BGTask で再合成

## Requirements *(mandatory)*

### Functional Requirements

#### ConceptPage データ層

- **FR-001**: System MUST 同名 entity が 2+ Article に登場した時、ConceptPage を自動生成する
- **FR-002**: System MUST ConceptPage に name / nameAliases / categoryRaw / summary / crossSourceInsights / relatedArticles / relatedConceptIDs / userUnderstanding / isFollowing / isStale / embedding / createdAt / updatedAt フィールドを永続化する
- **FR-003**: System MUST 同名判定で大文字小文字を無視し、nameAliases も考慮する
- **FR-004**: System MUST 既存 ConceptPage がある entity の新記事登場時、isStale = true でマークする
- **FR-005**: System MUST BGTask で isStale = true の ConceptPage を順次再合成する (空き時間に少しずつ)
- **FR-006**: System MUST relatedArticles を SwiftData @Relationship で永続化する

#### 自動合成パイプライン (ConceptSynthesisService)

- **FR-007**: System MUST Foundation Models で複数記事の essence / KeyFact を統合し、summary (200-400 字日本語) を生成する
- **FR-008**: System MUST 複数記事を横断して見える知見を抽出し、crossSourceInsights として最大 7 件文字列リストで保存する
- **FR-009**: System MUST 関連記事が 5 件以上の場合、hierarchical + meta-summary パターンで context window 制約に対応する
- **FR-010**: System MUST Foundation Models 利用不可時、Fallback として essence を並べた簡易 summary を生成する
- **FR-011**: System MUST summary を embedding 化して検索インデックスに登録する
- **FR-012**: System MUST AI 合成は silent fire-and-forget で実行し、ユーザーに進捗表示しない (calm UX)
- **FR-013**: System MUST 既存記事から ConceptPage 群を初期 backfill する経路を提供する (V1 リリース後 1 回起動時実行)

#### 編集機能 (ConceptPageStore)

- **FR-014**: Users MUST be able to ConceptPage を rename できる (空文字 / 30 字超は拒否)
- **FR-015**: Users MUST be able to 2 つの ConceptPage を merge できる (関連記事 / 関連概念 統合、片方削除)
- **FR-016**: Users MUST be able to ConceptPage を delete できる (関連 Article は残る)
- **FR-017**: Users MUST be able to ConceptPage を pin (isFollowing toggle) できる
- **FR-018**: System MUST 編集操作後に RefreshTrigger.bump で UI 更新を通知する

#### 表示 UI

- **FR-019**: System MUST 知識 Clip タブに「あなたが追っている人物・モノ」セクションを追加し、ConceptPage カード一覧を表示する
- **FR-020**: System MUST セクション内では上位 5 件 + 「+N すべて見る」リンクを表示する (上位 = 更新日 desc + isFollowing 優先)
- **FR-021**: System MUST ConceptPage カードに 名前 / 関連記事数 / 最終更新 / 1 行 summary preview を表示する
- **FR-022**: System MUST ConceptPage 詳細画面に「今わかっていること (summary)」「横断的知見 (crossSourceInsights)」「関連記事 (relatedArticles)」「つながる人物・モノ (relatedConceptIDs)」の 4 セクションを表示する
- **FR-023**: System MUST 詳細画面の関連記事タップで Article Detail に遷移する
- **FR-024**: System MUST 詳細画面の他概念タップで該当 ConceptPage 詳細に遷移する (探索可能)
- **FR-025**: System MUST AI 合成未完了時に「整理中…」プレースホルダーを表示する
- **FR-026**: System MUST 詳細画面 toolbar に [編集] [ピン] アクションを表示する

#### 検索統合 (P3)

- **FR-027**: System MUST 既存検索 service が ConceptPage の name / summary をヒット対象に含める
- **FR-028**: System SHOULD 検索結果で Article と ConceptPage を識別可能に表示する (badge 等)

#### Article 連携 (P3)

- **FR-029**: System SHOULD Article 詳細画面に「この記事から派生した概念ページ」セクションを追加する (relatedArticles を含む ConceptPage 一覧)

#### ハルシネーション抑止

- **FR-030**: System MUST AI 合成 summary に元 Article ID を引用 / 参照可能な形で関連付ける (relatedArticles 経由)
- **FR-031**: System MUST AI が推測 / 一般知識から補強した内容は summary に含めない (prompt で明示)

### Key Entities

- **ConceptPage**: 複数の保存記事に登場する entity (人物 / モノ / 概念) を 1 つに統合したページ。AI が複数ソース横断で要約 (summary) と横断的知見 (crossSourceInsights) を合成。Article との N:N 関係 + 他 ConceptPage との 関連 (relatedConceptIDs)。ユーザーは閲覧 + 補正編集 (rename/merge/delete/pin) 可能。
- **Article (既存)**: ConceptPage の原典。ConceptPage.relatedArticles で参照。Article 側は変更不要 (既存 spec 001 で確立)。
- **KnowledgeEntity (既存)**: 1 記事内の entity 抽出結果。ConceptPage 生成のトリガーとして利用。ConceptPage は KnowledgeEntity を集約した上位概念。
- **GraphNode (既存)**: 同じ entity 名で graph 上のノード。ConceptPage と 1:1 or N:1 関係。ConceptPage = 「読める単位」、GraphNode = 「構造単位」で粒度が違う。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 同名 entity が 2 件の記事に登場してから 30 秒以内に ConceptPage が自動生成され、知識 Clip タブで確認できる
- **SC-002**: ConceptPage の summary は 200-400 字の日本語で、複数記事の要点を統合した文章として読める
- **SC-003**: crossSourceInsights は最大 7 件の bullet として表示され、「単一記事だけでは見えない知見」を含む
- **SC-004**: 新記事 ingest 完了から 5 分以内に関連 ConceptPage が isStale = true でマークされる
- **SC-005**: 5+ 関連記事を持つ ConceptPage の再合成が hierarchical + meta-summary パターンで Foundation Models context window 制約内に収まる
- **SC-006**: ConceptPage の rename / merge / delete 操作は 1 秒以内に DB 反映 + UI 更新される
- **SC-007**: 100 件以上の ConceptPage がある状態で、知識 Clip タブ scroll を 60fps で維持する
- **SC-008**: Foundation Models 不可時に Fallback summary が essence 並べで生成され、AI 合成失敗をユーザーに表示しない (silent degrade)
- **SC-009**: 既存記事 (50+ 件) から ConceptPage 初期 backfill が完了し、V1 リリース後 24 時間以内に主要概念が surface 可能になる
- **SC-010**: ConceptPage 詳細画面の「関連記事」タップで Article Detail に 1 秒以内に遷移し、原典が確認できる

## Assumptions

- ユーザーは Apple Intelligence (Foundation Models) を有効化済みの iOS 26+ iPhone を使用 (既存 知積 と同条件)
- 既存記事 (Article + ExtractedKnowledge + KnowledgeEntity) が前提として存在 (spec 001/004 実装済)
- 既存 GraphNode/GraphEdge (spec 040) が活用される (entity の graph 表現)
- 概念ページの自動生成は silent 、進捗表示なし (calm UX 原則)
- 「概念」の単位は entity (KnowledgeEntity) 名で決まる (新たな概念抽出ロジックは不要、既存 KnowledgeEntity 流用)
- 同 entity が複数 category に出現する場合は category 別に ConceptPage を作成 (例: 「Apple」が果物とテクノロジー両方に)
- ConceptPage はカテゴリー内で unique (同 categoryRaw + name は 1 つだけ)
- 完全 on-device 動作、クラウド API 一切使用しない (Constitution I)
- 通知 / バッジ / streak は使わない (Constitution V、calm UX)
- Foundation Models 失敗時は silent fallback、ユーザーに「AI 失敗」表示しない
- 既存 Tag / KnowledgeDigest / UserTopic との関係は本 spec 範囲外 (別 spec で並立検討、本 spec では並立前提)
