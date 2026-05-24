# Feature Specification: Understanding Chat (家庭教師ループ + 学習タブ)

**Feature Branch**: `044-understanding-chat`
**Created**: 2026-05-23
**Status**: Draft
**Input**: Understanding Chat — iKnow V1 Phase A 最大 spec、Karpathy「You can outsource your thinking, but you cannot outsource your understanding」の家庭教師ループを実体化する。学習タブを新規追加、ConceptPage / SavedAnswer を「学習カード」として surface し、1 タップで深掘り chat 起動、「✓ わかった / 🤔 もっと / ✗ 違う」で理解度を蓄積。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 学習カードが自動で並ぶ (Priority: P1)

ユーザーが学習タブ (新タブ、起動 default) を開いた時、AI が「あなたが今深めるべき」と判断した 5 件のカード (人物・モノ・概念 = ConceptPage、または過去の質問と答え = SavedAnswer) が自動で並ぶ。新しい知識・古くなった答え・理解度の低い概念などが優先表示される。

**Why this priority**: 家庭教師ループの入口。ユーザーが「次に何を学ぼう」と考えなくても、AI が「いまあなたに必要なもの」を選んで surface する。これがないと学習タブは空っぽで、ユーザーは何も始められない。

**Independent Test**: ConceptPage 3 件 + SavedAnswer 2 件が DB に存在する状態で学習タブを開く → 5 件のカードが画面に並び、各カードに名前 + ラベル (「新しい知識」「更新が必要」等) が表示されることを確認できる。

**Acceptance Scenarios**:

1. **Given** ConceptPage / SavedAnswer ともに 0 件、**When** 学習タブを開く、**Then** 「まだ学ぶカードがありません。記事を保存したり AI チャットで質問してみましょう」placeholder 表示
2. **Given** 24 時間以内に作成された理解度ゼロの ConceptPage が 1 件、**When** 学習タブを開く、**Then** そのカードが「新しい知識」ラベルで最上位表示される
3. **Given** isStale な SavedAnswer が 2 件存在、**When** 学習タブを開く、**Then** これらが「更新が必要」ラベルで上位に並ぶ
4. **Given** ConceptPage 10+ 件 / SavedAnswer 8+ 件、**When** 学習タブを開く、**Then** 上位 5 件 + 「+N すべて見る」リンクが表示される

---

### User Story 2 - カードタップで AI と深掘り対話 (Priority: P1)

ユーザーがカードをタップすると、その概念 / 質問について **AI が「家庭教師」として** 対話を始める。質問に答えるだけでなく、ユーザーの理解度を確認する逆質問や、関連する保存記事への参照を促してくる。会話画面下部には「✓ わかった」「🤔 もっと」「✗ 違う」3 ボタンが常時表示される。

**Why this priority**: Karpathy「understanding は外部化できない」の実体化。AI から答えを取るだけでなく、AI に教えてもらうことで「自分のものにする」体験を提供する。

**Independent Test**: 「Apple Vision Pro」ConceptPage カードをタップ → 深掘り chat 画面が開き、AI が「Apple Vision Pro について、何が一番気になりますか?」のような家庭教師調の文で対話を始めることを確認できる。

**Acceptance Scenarios**:

1. **Given** 「Apple Vision Pro」カードを学習タブで表示中、**When** カードタップ、**Then** 深掘り chat 画面に遷移、AI が家庭教師調の初期質問を返す (3 秒以内)
2. **Given** 深掘り chat 画面、**When** ユーザーが追加質問送信、**Then** 既存 AI Chat と同様に答えが返り、引用記事も提示される
3. **Given** 深掘り chat 画面、**When** スクロール、**Then** 下部 3 ボタンは常時固定表示 (sticky)

---

### User Story 3 - 「✓ わかった」で理解度が育つ (Priority: P1)

ユーザーが対話で「腹落ちした」と感じたら「✓ わかった」ボタンをタップ。すると該当概念の理解度 (内部スコア 0-5) が +1 され、次回学習タブで該当カードは下位に下がる (もう surface されない傾向)。

**Why this priority**: 学習の「成果記録」と「重複防止」を両立。これがないと同じカードが何度も surface され続けてユーザーが疲弊する。

**Independent Test**: ConceptPage A の userUnderstanding=0 状態で深掘り chat → 「✓ わかった」タップ → DB で A.userUnderstanding=1 を確認 → 学習タブをリフレッシュ → A は上位 5 件から外れる (or 表示順位下がる) ことを確認できる。

**Acceptance Scenarios**:

1. **Given** ConceptPage A の userUnderstanding=0、**When** 深掘り chat 画面で「✓ わかった」タップ、**Then** A.userUnderstanding=1 で DB 永続化 + 行動履歴 1 件記録
2. **Given** ConceptPage A の userUnderstanding=4、**When** 「✓ わかった」タップ、**Then** A.userUnderstanding=5 (max) で停止、行動履歴は記録
3. **Given** ConceptPage A が学習タブで surface 中、**When** 「✓ わかった」タップ → 学習タブ画面リフレッシュ、**Then** A の表示順位が下がる (or 別カードに置き換わる)

---

### User Story 4 - 「🤔 もっと」で対話継続 (Priority: P1)

ユーザーが「もっと聞きたい」と感じたら「🤔 もっと」ボタンをタップ。理解度は変化しないが、AI が「では、もう少し別の角度から見てみましょう」のように対話を継続するためのきっかけになる。

**Why this priority**: 「✓ わかった」と並ぶ 2 値選択。ユーザーが「まだ腹落ちしてない」明示シグナルを送れることで、学習タブから surface しなくならず、次回また現れる。

**Independent Test**: ConceptPage A の userUnderstanding=0 状態で深掘り chat → 「🤔 もっと」タップ → DB で A.userUnderstanding=0 のまま (変化なし)、行動履歴に 1 件記録されていることを確認できる。次回学習タブで A は引き続き surface される。

**Acceptance Scenarios**:

1. **Given** ConceptPage A の userUnderstanding=2、**When** 「🤔 もっと」タップ、**Then** A.userUnderstanding=2 のまま、行動履歴に "needMore" 1 件記録
2. **Given** 「🤔 もっと」タップ後、**When** 画面、**Then** chat 画面は閉じず、AI に「もう少し詳しく教えてください」等の継続メッセージ自動送信 (or ユーザーが続き手動入力可能)

---

### User Story 5 - 起動時 default タブが学習タブ (Priority: P1)

ユーザーがアプリを起動すると、最初に開くのは学習タブ。「いまあなたに必要なもの」が真っ先に目に入る UX。

**Why this priority**: 「読まないと忘れる」「貯まるだけ」既存サービスとの差別化。アプリを開いた瞬間に「学ぼう」になる導線。

**Independent Test**: アプリ完全終了 → 再起動 → 学習タブが選択されていることを確認できる。

**Acceptance Scenarios**:

1. **Given** アプリ未起動、**When** ユーザーがアプリを起動、**Then** 起動完了後の最初の画面が学習タブ
2. **Given** 学習タブ以外を選択した状態で background → foreground 復帰、**When** 復帰、**Then** 前回選択していたタブを維持 (default 強制復元はしない)

---

### User Story 6 - 全カード一覧 (+N すべて見る) (Priority: P2)

ユーザーが「他にも学べるものを見たい」と思った時、「+N すべて見る」リンクで全 UnderstandingCard 一覧画面に遷移できる。100+ 件でも 60fps で scroll 可能。

**Why this priority**: 上位 5 件で物足りない時の救済。ヘビーユーザー向け。

**Independent Test**: ConceptPage 20+ 件 + SavedAnswer 10+ 件存在する状態で「+25 すべて見る」タップ → 全 30 件が新しい順 (or 優先度順) で表示されることを確認。

**Acceptance Scenarios**:

1. **Given** 5 件超のカード候補がある、**When** 学習タブを開く、**Then** 「+N すべて見る」リンク表示
2. **Given** 「+N すべて見る」タップ、**When** 遷移後、**Then** 全 UnderstandingCard が paginated list (LazyVStack) で表示、60fps scroll

---

### User Story 7 - 「✗ 違う」で的外れカードを下位に (Priority: P2)

ユーザーが「このカード or AI の答えは今知りたいことじゃない」と感じた時、「✗ 違う」タップ。該当カードの surface 優先度を下げ、次回以降 surface されにくくする。

**Why this priority**: 学習体験の質を維持。ノイズが多いと学習タブが信頼されなくなる。

**Independent Test**: ConceptPage A を 「✗ 違う」 → 学習タブをリフレッシュ → A は上位 5 件から外れる (or 大きく下位に) ことを確認。

**Acceptance Scenarios**:

1. **Given** ConceptPage A が学習タブで surface 中、**When** 深掘り chat で 「✗ 違う」タップ、**Then** A の優先度スコアが -10、次回 surface で大きく下位に
2. **Given** ConceptPage A が「✗ 違う」既往あり、**When** 学習タブを再表示、**Then** A は上位 5 件に出ない

---

### User Story 8 - AI チャット答え → 学習タブで深掘り推奨 (Priority: P2)

ユーザーが AI チャット (秘書ループ、spec 021) で質問 → 答えに引用 2+ 件あれば SavedAnswer 自動保存 (spec 043 既存)。本 spec で **その SavedAnswer が学習タブで「この概念について深掘り?」カードとして surface** される導線を追加。

**Why this priority**: 秘書ループ → 家庭教師ループの自然な接続。「答えを取った」が「自分のものにする」につながる。

**Independent Test**: AI チャットで質問 → SavedAnswer 自動生成 (spec 043) → 学習タブを開く → 該当 SavedAnswer が surface 候補に入っていることを確認。

**Acceptance Scenarios**:

1. **Given** AI チャットで質問 → SavedAnswer S が生成、**When** 学習タブを開く、**Then** S が surface 候補に入る (新しい SavedAnswer 優先)
2. **Given** S が surface された状態、**When** カードタップ → 深掘り chat、**Then** AI が「先ほどの「\(質問内容)」について、もっと深く理解したいですか?」等で開始

---

### User Story 9 - ConceptPage 詳細から学習する (Priority: P2)

ユーザーが知識 Clip タブ → ConceptPage 詳細を見ている時、「この概念を学習する」ボタンから直接深掘り chat に入れる。学習タブを経由しない最短導線。

**Why this priority**: 「読んでて気になった」瞬間に学習に入れる。発見的学習体験。

**Independent Test**: ConceptPage 詳細画面 → 「学習する」ボタンタップ → 深掘り chat 起動 (該当 ConceptPage を context に注入) を確認。

**Acceptance Scenarios**:

1. **Given** ConceptPage 詳細画面、**When** toolbar の「学習する」ボタンタップ、**Then** 深掘り chat 画面に遷移、AI が該当概念について家庭教師調で対話開始

---

### User Story 10 - 学習統計の軽量表示 (Priority: P3)

AI ブレインタブ (既存) の StatsRow に「今月「✓ わかった」N 件 / 最近 7 日で深掘りした概念 N」を追加表示。streak や日数バッジは絶対に出さない (calm UX)。

**Why this priority**: ユーザーが「自分の学習が積み上がっている」感覚を持てる軽い fact 表示。詳細 dashboard は将来 spec。

**Independent Test**: 「✓ わかった」を 3 件タップした状態で AI ブレインタブを開く → 「今月「✓ わかった」3 件」表示を確認。

**Acceptance Scenarios**:

1. **Given** 当月の「✓ わかった」が 5 件、**When** AI ブレインタブを開く、**Then** 「今月 5 件「わかった」」表示
2. **Given** 過去 7 日に深掘り chat した ConceptPage が 3 件、**When** AI ブレインタブを開く、**Then** 「最近深掘り 3 概念」表示
3. **Given** ユーザー操作 0 件、**When** AI ブレインタブを開く、**Then** 統計セクション自体非表示 (空状態あえて出さない、calm UX)

---

### Edge Cases

- **ConceptPage / SavedAnswer 完全に 0 件**: 学習タブで空状態 placeholder「まだ学ぶカードがありません。記事を保存したり AI チャットで質問してみましょう」を表示、迷路化しない
- **userUnderstanding が全部 max (5)**: surface ロジックが「✓ 済」と判定しないように、5 件中 0 件しか出ない状態 → 「次の学びを待っています」placeholder と「30 日以上触れていない概念」セクション (US10 P3 と合流)
- **AI チャット (秘書) で短文 unknown 答え**: SavedAnswer 自動生成されない (spec 043 条件 = 引用 2+ + 50 字+)、学習タブも当然 surface しない
- **深掘り chat 開始時に Apple Intelligence 不可**: 既存 ChatService fallback (essence 並べ) で対話、家庭教師調プロンプトは無視される (graceful)
- **「✓ わかった」連打 (同 ConceptPage に何度もタップ)**: 各 +1 (max 5 で停止)、行動履歴は全て記録
- **ConceptPage が merge で消える / delete**: 学習タブの surface 候補から自動除外 (live @Query)、行動履歴は targetID で孤立残存 (削除 SavedAnswer / ConceptPage に紐づくログは UI には現れない)
- **同 ConceptPage を異なるカード経路で連続学習**: 新規 ChatSession を作る (会話を独立保持、過去会話は AI チャットタブのセッション一覧で見える)

## Requirements *(mandatory)*

### Functional Requirements

#### 学習タブ + Surface

- **FR-001**: System MUST 学習タブ (新タブ、起動 default 選択) を 4 タブ構成に追加する
- **FR-002**: System MUST 起動時の default 選択タブを「学習タブ」に変更する
- **FR-003**: System MUST 学習タブを開いた時、ConceptPage / SavedAnswer から **上位 5 件** を以下の優先順位で surface する:
  - (a) 新規 ConceptPage (作成 24 時間以内、userUnderstanding=0)「新しい知識」
  - (b) isStale な SavedAnswer (spec 043)「更新が必要」
  - (c) userUnderstanding 低 (0-1) + 関連記事最近保存「理解が浅い」
  - (d) isFollowing な ConceptPage で userUnderstanding 中 (2-3)「深掘り余地あり」
  - (e) 長く触れていない ConceptPage (lastInteractedAt 30+ 日)「復習」
- **FR-004**: System MUST 候補 0 件で空状態 placeholder 表示、迷路にしない
- **FR-005**: System MUST 候補 6+ 件で「+N すべて見る」リンク表示
- **FR-006**: System MUST 「+N すべて見る」遷移先で全 UnderstandingCard を paginated list で表示する

#### Deep dive chat 起動

- **FR-007**: Users MUST be able to カードタップで深掘り chat 画面を開ける
- **FR-008**: System MUST 深掘り chat 起動時に AI prompt に「あなたは家庭教師として、ユーザーが「\(概念名)」を腹落ちするまで助けてください」context を注入する
- **FR-009**: System MUST 深掘り chat の最初の AI 発話が「家庭教師調」(逆質問 / 概念確認 / 例示) になるよう prompt 制約する
- **FR-010**: System MUST 深掘り chat 用に専用 ChatSession を新規作成し、title をカード由来 (例:「Apple Vision Pro を深掘り」) で設定する
- **FR-011**: Users MUST be able to 深掘り chat 内で追加質問を送れる (既存 AI Chat と同 UI)
- **FR-012**: System MUST 深掘り chat 画面下部に「✓ わかった / 🤔 もっと / ✗ 違う」3 ボタンを常時 (sticky) 表示する

#### 理解度トラッキング

- **FR-013**: System MUST 「✓ わかった」タップで対象 ConceptPage の userUnderstanding を +1 (max 5) し永続化する
- **FR-014**: System MUST 「✓ わかった」タップ時に関連 ConceptPage (graph 1-hop neighbor) に +0.5 波及 (整数化して 0 or +1 とする、accumulate)
- **FR-015**: System MUST 「🤔 もっと」タップで userUnderstanding を変化させず、行動履歴のみ記録する
- **FR-016**: System MUST 「✗ 違う」タップで対象カードの surface 優先度スコアを -10 し、次回学習タブで下位にする
- **FR-017**: System MUST 各ボタンタップで UnderstandingInteraction レコード (action / targetKind / targetID / occurredAt) を 1 件保存する
- **FR-018**: System MUST userUnderstanding を 0-5 の整数で clamp する (-1 や 6 にならない)

#### 横断連携

- **FR-019**: System MUST AI チャット (秘書) で生成された SavedAnswer (spec 043) を学習タブの surface 候補に含める (新しい順優先)
- **FR-020**: Users MUST be able to ConceptPage 詳細画面の toolbar から「学習する」ボタンで深掘り chat を直接開始できる (学習タブを経由しない)
- **FR-021**: System SHOULD AI ブレインタブの StatsRow に「今月「✓」N 件」「最近 7 日で深掘り N 概念」(P3) を表示する。各 0 件なら非表示

#### Calm UX 制約 (絶対遵守)

- **FR-022**: System MUST 連続学習日数 (streak) UI を表示しない
- **FR-023**: System MUST 「✓ わかった」タップ後に通知 / バッジ / 効果音を発しない (silent record)
- **FR-024**: System MUST 「学習しなさい」のような push 通知を一切送らない (アプリ内 banner も含む)

### Key Entities

- **UnderstandingCard (transient)**: 学習タブで surface される統一カード。元 entity (ConceptPage / SavedAnswer / Article) を kind enum で wrap、priorityScore で並び順、lastInteractedAt で表示ラベル決定。UI 用 transient struct で永続化なし。
- **UnderstandingInteraction (新 @Model)**: ユーザー操作の行動履歴。action ("understood" / "needMore" / "openedChat" / "dismissed") + targetKind ("conceptPage" / "savedAnswer" / "article") + targetID + occurredAt。集計 (FR-021) と surface 優先度に利用。
- **ConceptPage (既存、spec 042)**: surface 主対象。userUnderstanding (0-5) を本 spec で初活用、+1 波及 (graph 1-hop)。
- **SavedAnswer (既存、spec 043)**: surface 主対象 (isStale 優先)。
- **ChatSession (既存、spec 021)**: 深掘り chat 用に新規作成、title を「\(カード名) を深掘り」で設定。
- **Article (既存、spec 001)**: P2 で surface 候補に含める可能性 (本 spec MVP では ConceptPage + SavedAnswer のみ)。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 学習タブを開いてから上位 5 カードが表示されるまで **1 秒以内**
- **SC-002**: カードタップから深掘り chat 画面表示 + AI 初期発話までが **3 秒以内** (Apple Intelligence 利用可時)
- **SC-003**: 「✓ わかった」タップから DB 反映 + UI 更新が **1 秒以内**
- **SC-004**: 1-hop 波及で関連 ConceptPage の userUnderstanding 更新が **2 秒以内** (graph node 5-10 個想定)
- **SC-005**: 起動時の default タブが必ず「学習タブ」になる (100%)
- **SC-006**: 100+ 件 UnderstandingCard ある状態の「+N すべて見る」list で **60fps scroll 維持**
- **SC-007**: ConceptPage / SavedAnswer ともに 0 件で学習タブが空状態 placeholder を **1 秒以内に表示**
- **SC-008**: ユーザーが「✓ わかった」した ConceptPage が、**直後の学習タブ再表示** で上位 5 件から外れる (or 表示位置が下がる)
- **SC-009**: streak / バッジ / 通知 / 効果音 が **一切発生しない** (calm UX)
- **SC-010**: AI ブレインタブの「学習統計」(P3) が **0 件時に非表示** (空セクション出さない)

## Assumptions

- ユーザーは Apple Intelligence 有効化済の iOS 26+ iPhone を使用 (Foundation Models 経由の深掘り chat 必須)
- 既存 ConceptPage (spec 042) と SavedAnswer (spec 043) が稼働中、surface 対象として利用可能
- 既存 ChatService (spec 021) の createSession + send 経路を流用、深掘り chat 用に新 ChatSession を作る
- 深掘り chat の AI 初期発話は **AI 自動生成** (ユーザーが手動入力する必要なし、prompt context を投入後 AI に空 input で初期質問を生成させる)
- userUnderstanding は ConceptPage のみに集約 (SavedAnswer 単体には userUnderstanding を持たせない、関連 ConceptPage に波及)
- 起動 default タブ変更 (spec 035 の `.knowledgeClip` → `.learning`) は user setting で override 不可 (常に学習タブ)、ただし当該セッション内では選択タブ自由
- 連続学習日数 (streak) は **永久に non-goal** (Constitution V calm UX)
- 「正解 / 不正解」テスト UI は **永久に non-goal** (VISION 明示)
- 学習履歴の集計は基本のみ (FR-021)、詳細 dashboard は別 spec (V2 候補)
- 完全 on-device 動作、クラウド API 一切使用しない (Constitution I)
- 1-hop 波及の graph は spec 040 GraphNode/GraphEdge を流用、graph 不存在時は波及スキップ (silent degrade)
