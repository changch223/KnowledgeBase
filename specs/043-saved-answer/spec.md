# Feature Specification: SavedAnswer (AI Chat 答えの永続化と概念ページへの紐付け)

**Feature Branch**: `043-saved-answer`
**Created**: 2026-05-23
**Status**: Draft
**Input**: SavedAnswer — iKnow V1 Phase A 第 2 弾、Karpathy LLM Wiki 思想の Compound Moment 条件 1 を実体化する。AI Chat の答えが引用 2 件以上含む時、それを SavedAnswer として永続化し、関連概念ページに紐付ける。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 答えの自動永続化 (Priority: P1)

ユーザーが AI チャットで質問をして、答えに引用記事が 2 件以上含まれていた場合、その質問と答えが自動的に「保存された答え」として永続化される。ユーザーには通知や進捗表示はされず、後から関連概念ページの詳細画面で見られる。

**Why this priority**: VISION.md v2.0 の Compound Moment 条件 1 (秘書 chat → 知識蓄積) の実体。これがないと AI Chat の答えは一過性のまま消えてしまい、「知識が compound する」という iKnow の核心価値が実現しない。

**Independent Test**: AI チャット画面で「Apple について教えて」と質問 → 答えに Apple 関連記事 2 件以上が引用される → DB 上に SavedAnswer が 1 件作成されることを確認できる。

**Acceptance Scenarios**:

1. **Given** AI Chat で質問送信、**When** 答えに citation 2 件以上 + 答え本文 50 字以上、**Then** SavedAnswer が自動生成され DB に永続化される (ユーザー通知なし)
2. **Given** AI Chat で質問、**When** 答えに citation 1 件以下、**Then** SavedAnswer は生成されない (graph ノードのみ既存ロジックで処理)
3. **Given** AI Chat で質問、**When** 答えが「分かりません」等で本文 50 字未満、**Then** SavedAnswer は生成されない
4. **Given** 同じ質問を 2 回連続送信、**When** 2 回目の答えが返ってくる、**Then** 既存 SavedAnswer の重複作成は防がれる

---

### User Story 2 - 概念ページに過去の質問と答えを表示 (Priority: P1)

ユーザーが概念ページ (例:「Apple」) の詳細画面を開いた時、その概念について過去に AI チャットで聞いた質問と答えが「この概念についての質問と答え (N)」セクションで一覧表示される。新しい順に最大 5 件、それ以上あれば「すべて見る」リンク。

**Why this priority**: 概念ページが「記事の統合」だけでなく「過去の問いと答えの蓄積」も含む包括的「読める単位」に成長する。Karpathy LLM Wiki の「Wiki が育つ」感覚を実体化。

**Independent Test**: SavedAnswer が DB に 3 件あり、それぞれ「Apple」概念ページに関連している状態で、Apple 詳細画面を開く → 3 件の質問プレビューが新しい順で表示されることを確認できる。

**Acceptance Scenarios**:

1. **Given** ConceptPage A に関連 SavedAnswer が 0 件、**When** A 詳細画面を開く、**Then** 「質問と答え」セクションは表示されない (空状態)
2. **Given** ConceptPage A に関連 SavedAnswer が 3 件、**When** A 詳細画面を開く、**Then** 3 件が新しい順で表示され、各行は質問の先頭 + 引用件数 + 保存日時を含む
3. **Given** ConceptPage A に関連 SavedAnswer が 10 件以上、**When** A 詳細画面を開く、**Then** 上位 5 件 + 「+N すべて見る」リンクが表示される
4. **Given** SavedAnswer 行をタップ、**When** タップ後、**Then** SavedAnswer 詳細画面に遷移する

---

### User Story 3 - 保存された答えの詳細閲覧 (Priority: P1)

ユーザーが SavedAnswer 詳細画面を開くと、質問、AI の答え本文、引用された記事 (タップで Article 詳細へ)、関連する概念ページ (タップで ConceptPage 詳細へ)、保存日時、自動保存か手動保存かを見られる。

**Why this priority**: 答えを再閲覧できないと永続化の意味がない。引用記事 / 関連概念ページへの jump で「答えの根拠を辿る」体験を提供。

**Independent Test**: 既存 SavedAnswer を 1 件用意 → 詳細画面を開く → 質問 / 答え / 引用記事 / 関連概念ページが全て表示され、引用記事タップで Article Detail に遷移できることを確認。

**Acceptance Scenarios**:

1. **Given** SavedAnswer 詳細画面、**When** 表示完了、**Then** question / answer / 引用記事 list / 関連概念ページ chip / 保存日時 / 自動 or 手動保存ラベルが表示される
2. **Given** 引用記事 row タップ、**When** タップ後、**Then** Article Detail に 1 秒以内に遷移する
3. **Given** 関連概念ページ chip タップ、**When** タップ後、**Then** ConceptPage 詳細画面に遷移する
4. **Given** 引用記事が後で削除された状態、**When** SavedAnswer 詳細画面を開く、**Then** 削除された記事は引用 list から除外されて表示される (relationship が nullify されたため、件数表示は減る)

---

### User Story 4 - 保存された答えの全履歴閲覧 (Priority: P2)

ユーザーが保存された答えの全履歴を見たい時、専用画面で最新順にリスト表示される。各行に質問プレビュー + 引用件数 + 保存日時。タップで詳細画面へ。

**Why this priority**: 概念ページに紐付かないか紐付きが弱い答え (汎用質問など) も見える化。SavedAnswer の存在を「ユーザー所有資産」として認識させる。

**Independent Test**: SavedAnswer 5 件保存済みの状態で履歴画面を開く → 5 件が新しい順に表示されることを確認できる。

**Acceptance Scenarios**:

1. **Given** SavedAnswer 5 件存在、**When** 履歴画面を開く、**Then** 5 件が savedAt desc で表示される
2. **Given** SavedAnswer 0 件、**When** 履歴画面を開く、**Then** 空状態メッセージが表示される
3. **Given** ピン済 SavedAnswer 2 件、その他 5 件、**When** 履歴画面を開く、**Then** ピン済が上位、その他が savedAt desc で並ぶ

---

### User Story 5 - 保存された答えのピン / 削除 (Priority: P2)

ユーザーが特に大事だと思った答えにピンを付けて上位表示できる。不要な答えは削除できる (引用記事は残る)。

**Why this priority**: ユーザー能動キュレーション機能。AI 自動保存だけだとノイズが蓄積するので、整理手段を提供。

**Independent Test**: SavedAnswer 詳細画面でピン toggle on → 履歴画面に戻ると上位表示。同じ画面で削除 → 履歴から消える、引用記事は Article 一覧に残ることを確認。

**Acceptance Scenarios**:

1. **Given** SavedAnswer 詳細画面、**When** [ピン] toggle を on、**Then** isPinned = true で永続化、再起動後も維持
2. **Given** SavedAnswer 詳細画面、**When** [削除] → 確認 alert → 削除、**Then** SavedAnswer 削除、引用記事は Article 一覧に残る (raw データ保護)
3. **Given** ピン済 SavedAnswer、**When** 履歴画面を開く、**Then** ピン済が一番上に表示される

---

### User Story 6 - 新記事 ingest による答えの古さマーク (Priority: P2)

ユーザーが新しい記事を保存して関連 ConceptPage が更新された時、その ConceptPage に紐付く SavedAnswer は「古い答え」としてマーク (isStale = true) される。本 spec では DB フラグ反映のみ、UI 表示は将来 spec (WikiLint 拡張) で扱う。

**Why this priority**: 将来の WikiLint 機能 (古い答えの検出 + 再生成提案) の仕込み。本 spec では DB 操作だけ実装してユーザー体験には現れない。

**Independent Test**: ConceptPage A に紐付く SavedAnswer 1 件存在 → A に新記事追加 → ConceptPage A が isStale 化 → 同 SavedAnswer も isStale=true になることを DB で確認。

**Acceptance Scenarios**:

1. **Given** ConceptPage A に紐付く SavedAnswer 1 件 (isStale=false)、**When** A に新記事追加で A が isStale=true 化、**Then** SavedAnswer も isStale=true に更新される (DB のみ、UI 影響なし)
2. **Given** SavedAnswer が ConceptPage に紐付かない (独立)、**When** 任意の新記事追加、**Then** SavedAnswer.isStale は変化しない

---

### User Story 7 - 保存された答えの検索 (Priority: P3)

ユーザーが履歴画面から query を入力して質問 / 答え / 引用記事タイトルに含まれる文字で検索できる。

**Why this priority**: SavedAnswer が 100 件超に成長した時に「あの答えどこだっけ?」を解決。MVP では nice-to-have。

**Independent Test**: SavedAnswer 5 件中 1 件に "Swift" を含む質問あり、検索 "Swift" → 該当 1 件のみ表示。

**Acceptance Scenarios**:

1. **Given** SavedAnswer 5 件、**When** 検索 "Swift" 入力、**Then** question / answer / 引用記事タイトルのいずれかに "Swift" を含む SavedAnswer のみ表示
2. **Given** 検索 query 空文字、**When** 履歴画面、**Then** 全件表示 (フィルター OFF)

---

### Edge Cases

- AI Chat 答えが「分かりません」等の fallback テキスト: 本文 50 字未満 + citation 0 件 → SavedAnswer 生成しない (US1 シナリオ 3)
- ChatSession 削除された SavedAnswer: chatSessionID は nullable、ChatSession 削除でも SavedAnswer は残る (履歴保護)
- 引用記事全削除: relatedConceptIDs に紐付け済の他 ConceptPage がまだ存在すれば概念ページ経由で見える、全部削除なら独立 SavedAnswer として履歴のみで見える
- 同じ質問の繰り返し: 既存 SavedAnswer の question が完全一致 (空白 trim 後) なら 2 件目作成スキップ (US1 シナリオ 4)
- ConceptPage merge による source 削除: relatedConceptIDs に source.id が含まれる SavedAnswer は target.id に置換 (graceful 移行)
- 同質問だが context が異なる場合: question が完全一致しないと別答えとして保存 (例: 「Apple とは?」と「Apple について教えて」は別扱い)
- 自動保存後の手動削除: ユーザーが「これいらない」と感じた answer は削除可能 (再質問しても auto-save 防止フラグは無い → 同 question で再保存される)

## Requirements *(mandatory)*

### Functional Requirements

#### SavedAnswer データ層

- **FR-001**: System MUST AI Chat 答えに引用 2 件以上 + 本文 50 字以上の時、SavedAnswer を自動生成する
- **FR-002**: System MUST SavedAnswer に question / answer / citedArticles / relatedConceptIDs / chatSessionID / isPinned / isStale / savedAt / updatedAt / savedAutomatically フィールドを永続化する
- **FR-003**: System MUST 引用記事を SwiftData @Relationship で nullify 削除規則で持つ (記事削除で SavedAnswer は残る)
- **FR-004**: System MUST 同 question (空白 trim 後完全一致) の既存 SavedAnswer がある場合は新規作成を skip する
- **FR-005**: System MUST SavedAnswer 自動保存は silent fire-and-forget で実行し、ユーザーに進捗表示しない

#### ConceptPage 紐付けロジック

- **FR-006**: System MUST 引用記事に関連する ConceptPage を fetch して relatedConceptIDs に最大 5 件 (mentionCount or 関連記事数の多い順) 保存する
- **FR-007**: System MUST 新記事 ingest で ConceptPage が isStale 化される時、その ConceptPage に紐付く SavedAnswer も isStale=true でマークする (DB フラグのみ、UI 影響なし)
- **FR-008**: System MUST ConceptPage が merge された時、source.id を含む SavedAnswer.relatedConceptIDs を target.id に置換する

#### 編集機能

- **FR-009**: Users MUST be able to SavedAnswer をピン (isPinned toggle) できる
- **FR-010**: Users MUST be able to SavedAnswer を削除できる (引用記事は残る)
- **FR-011**: System MUST 編集操作後に UI 更新通知を発行する

#### 表示 UI

- **FR-012**: System MUST ConceptPage 詳細画面に「この概念についての質問と答え (N)」セクションを追加し、関連 SavedAnswer を最大 5 件 (新しい順 + ピン優先) 表示する
- **FR-013**: System MUST セクション内 5 件超は「+N すべて見る」リンクで全件遷移可能にする
- **FR-014**: System MUST SavedAnswer 行に質問プレビュー (40 字) + 引用件数 + 保存日時 (相対 / 絶対) を表示する
- **FR-015**: System MUST SavedAnswer 詳細画面に question / answer / 引用記事 list / 関連概念ページ chip / 保存日時 / 自動 or 手動保存ラベルを表示する
- **FR-016**: System MUST 引用記事タップで Article Detail に遷移する
- **FR-017**: System MUST 関連概念ページタップで該当 ConceptPage 詳細に遷移する
- **FR-018**: System MUST SavedAnswer 履歴画面 (専用画面) で全 SavedAnswer を savedAt desc + isPinned 優先で表示する

#### 検索 (P3)

- **FR-019**: System SHOULD SavedAnswer 履歴画面で question / answer / 引用記事 title に対する substring 検索を提供する

### Key Entities

- **SavedAnswer**: AI Chat の答えを永続化した entity。question / answer / citedArticles / relatedConceptIDs を持ち、ConceptPage と弱い紐付け (ID 配列) で関連付け。auto-save と手動 pin / delete で管理。
- **ChatAnswerOutput (transient、既存)**: ChatService の AI 答え output、citedArticleIDs が判定 source。本 spec で SavedAnswer に変換される。
- **Article (既存)**: 引用元、@Relationship.nullify で SavedAnswer と緩く結合。
- **ConceptPage (既存、spec 042)**: relatedConceptIDs で SavedAnswer と緩く結合、概念ページ詳細画面で SavedAnswer 一覧を表示する宿主。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: AI Chat 答えに引用 2+ 件あれば、答え表示から 5 秒以内に SavedAnswer として DB に永続化される
- **SC-002**: 同質問の連続送信で重複 SavedAnswer が生成されない (重複率 0%)
- **SC-003**: ConceptPage 詳細画面で関連 SavedAnswer が 1+ 件あれば「質問と答え」セクションが 1 秒以内に表示される
- **SC-004**: SavedAnswer 詳細画面の引用記事タップで Article Detail に 1 秒以内に遷移する
- **SC-005**: 100 件以上 SavedAnswer がある履歴画面で scroll を 60fps で維持する
- **SC-006**: SavedAnswer の ピン / 削除 操作は 1 秒以内に DB 反映 + UI 更新される
- **SC-007**: 新記事 ingest で関連 ConceptPage に紐付く SavedAnswer が 5 分以内に isStale=true でマークされる (DB 確認)
- **SC-008**: SavedAnswer 検索 (P3) で 100+ 件中の query 一致を 1 秒以内に表示する

## Assumptions

- ユーザーは AI チャット (spec 021) を有効化済の iOS 26+ iPhone を使用 (Foundation Models 動作必須)
- 既存 ChatService.ask() 経路が稼働中、ChatAnswerOutput.citedArticleIDs が信頼可能 (spec 021 / 033 で確立済)
- ConceptPage (spec 042) が稼働中、関連紐付けの宿主として利用可能
- 自動保存は silent、進捗 UI 一切なし (Constitution V calm UX)
- 通知 / バッジ / streak は使わない (Constitution V)
- ChatSession 削除時に SavedAnswer は残す (履歴保護)、chatSessionID は nullable
- AI 答え本文 50 字未満は SavedAnswer 保存価値なしと判定 (fallback「分かりません」等を除外)
- 同 question の重複判定は空白 trim 後の完全一致 (大文字小文字は区別する → ユーザー意図反映)
- 完全 on-device 動作、クラウド API 一切使用しない (Constitution I)
- 検索 (P3) は MVP に含むが、optional (リリース時無くても V1 出荷可)
