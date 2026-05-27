# Feature Specification: UIUX Redesign V3.0 — 3-Tab Simplification

**Feature Branch**: `056-uiux-redesign-v3`
**Created**: 2026-05-24
**Status**: Draft
**Input**: User description: 9 ラウンドの対話で確定した「気になったものが、勝手に整理される」体験を中核に据えた全面 redesign。4 タブ → 3 タブ、Apple News / Photos の Today パターンに沿って引き算で再設計。

## 製品ビジョン (1 文)

**「気になったものが、勝手に整理される」**

ユーザーが共有 (read or 未 read 問わず) → AI が自動で整理 → 必要な時に開けば最新の自分が見える。週 1-2 回ライトユース前提、毎日 grind ではない。

## 設計原則 (Apple HIG ベース)

1. **Clarity (明瞭性)**: 開いて 3 秒で「ここは何の画面か」が分かる
2. **Deference (控えめ)**: コンテンツ (記事 / 概念 / 答え) が主役、UI は脇役
3. **Depth (奥行き)**: 必要なものだけを表に出し、優先度低いものは Layer 2 (もっと見る / 詳細遷移) に隠す
4. **Calm UX**: streak / バッジ / 通知 / 強い色 一切なし
5. **3 セクション・3 タブ ルール**: 1 画面に 4 つ以上の section を置かない、4 つ以上の root tab を置かない

## User Scenarios & Testing *(mandatory)*

### User Story 1 — 3 タブ構成で起動 default = 知識 Clip (Priority: P1)

ユーザーが iKnow を開くと、最初に **知識 Clip タブ**が表示される。下部に 3 つのタブ (`知識 Clip` / `ライブラリ` / `AI チャット`) のみが見え、旧 4 タブ目以降 (`学習` / `AI ブレイン` / `Settings`) は存在しない。

**Why this priority**: V3.0 の最大のメッセージは「画面が整理された」。これが達成されなければ他の改善も意味がない。ユーザーは「タブが減った」をまず認識する。

**Independent Test**: アプリ起動 → 3 タブのみ表示 → 起動 default = 知識 Clip 確認。1 シナリオで完結する独立確認。

**Acceptance Scenarios**:

1. **Given** 既存ユーザー (V2.5 までを使用済) が V3.0 アップデート、**When** アプリを起動、**Then** 下部タブバーに 3 つのタブのみ表示、選択中は知識 Clip
2. **Given** 新規ユーザーが V3.0 を初インストール、**When** アプリを起動、**Then** onboarding 後、起動 default = 知識 Clip
3. **Given** ユーザーがライブラリタブを開いてアプリを kill、**When** 再起動、**Then** 起動 default = 知識 Clip (前回タブ復元しない、新習慣を定着させる)

---

### User Story 2 — 知識 Clip 「最近の記事」で差分キャッチアップ (Priority: P1)

ユーザーが知識 Clip タブを開くと、最上部に **「最近の記事」**セクションが横スクロールで最大 3 件表示される。各カードは 1 記事の essence 要点 (40-50 字) + 引用記事タイトル + サイト名。「前回開いた時刻以降に新規共有された記事」が対象。

差分ゼロの場合 (新規共有なし) は、**前回見た 3 記事をそのまま維持**する (空表示せず、安定した見た目)。

**Why this priority**: 週 1-2 回ライトユーザーが「30 秒で何を見たいか」の答え。Apple News Today のメイン体験に相当。

**Independent Test**: 記事を 5 件保存 → アプリ kill → 再起動 → 知識 Clip タブ最上部に最新 3 件が essence 付きで表示。差分が無い状態で再起動 → 同じ 3 件が維持されることを確認。

**Acceptance Scenarios**:

1. **Given** 前回開いた時刻以降に 5 件新規共有、**When** 知識 Clip タブを開く、**Then** 最近の記事セクションに最新 3 件が横スクロール表示、「+2 件 もっと見る」リンクが下部に表示
2. **Given** 前回開いた時刻以降に新規共有ゼロ、**When** 知識 Clip タブを開く、**Then** 前回表示した 3 件が変化なくそのまま維持
3. **Given** 過去にも記事が一切無い (新規インストール直後)、**When** 知識 Clip タブを開く、**Then** 「最近の記事はまだありません ✨」 empty state を表示

---

### User Story 3 — 「続きが気になるもの」で深掘り / Topic 振り返り (Priority: P1)

知識 Clip タブの 2 番目セクションに **「続きが気になるもの」** が表示される。**2 種類のカード**が混在表示:
- **ConceptPage 深掘り誘いカード** (旧 学習タブ): 「OpenAI の o3 model — 3 つの記事から、まだ整理中」「深掘りする →」
- **Topic Dashboard カード** (旧 KnowledgeDigest + UserTopic): 「テクノロジー分野で 5 件 — 最近 1 週間の動向」「まとめを読む →」

カードタップで対応する詳細画面 (深掘り chat / Topic 詳細) に遷移。

**Why this priority**: 「最近の記事」を見終わったユーザーが「次に何を見るか」の答え。学習タブ / KnowledgeDigest を 1 セクションに統合することで、redesign の核心 (引き算 + 統合) を実体化。

**Independent Test**: ConceptPage 3 件 + KnowledgeDigest 2 件存在する状態 → 知識 Clip タブ → 続きが気になるセクションに 5 件混在表示 → 1 件タップで対応詳細画面遷移。

**Acceptance Scenarios**:

1. **Given** ConceptPage 5 件 + Topic Digest 3 件存在、**When** 知識 Clip タブを開く、**Then** 続きが気になるセクションに上位 5 件 (混在) 表示、「もっと見る ›」リンク表示
2. **Given** ConceptPage 深掘りカードタップ、**When** カードタップ、**Then** DeepDiveChatView に遷移し家庭教師ループ開始 (既存 spec 044 動作維持)
3. **Given** Topic Dashboard カードタップ、**When** カードタップ、**Then** カテゴリ別ダイジェスト詳細画面に遷移 (既存 spec 018 動作維持)
4. **Given** ConceptPage 0 件 + Topic 0 件、**When** 知識 Clip タブを開く、**Then** 続きが気になるセクションは empty state を表示 (記事 5 件以上保存後の生成待ち hint)

---

### User Story 4 — 「追っている人物・モノ」 + 更新が必要 badge (Priority: P1)

知識 Clip タブの 3 番目セクションに **「追っている人物・モノ」** が表示される。
- ConceptPage で `isFollowing = true` のカード上位 5 件、理解度 ●●●○○ + 関連記事数表示
- サブヘッダ位置に `⚠️ 更新が必要 (N)` badge (件数 0 なら非表示)
- badge 経由で旧 FactConflicts + StaleSavedAnswers を統合表示

**Why this priority**: ユーザーが「能動的にフォローした概念」の最新状態と「対応待ち事項」を 1 ヶ所で把握。Apple News の Following + Apple Mail の VIP 風。

**Independent Test**: ConceptPage 3 件 isFollowing にし、1 件を isStale にする → 知識 Clip タブ → 追っているセクションに 3 件表示、⚠️ 更新が必要 (1) badge 表示。

**Acceptance Scenarios**:

1. **Given** isFollowing ConceptPage 5 件、ConflictProposal 1 件、isStale SavedAnswer 1 件、**When** 知識 Clip タブを開く、**Then** 追っているセクションに 5 件 + サブヘッダ「⚠️ 更新が必要 (2)」
2. **Given** isFollowing ConceptPage 3 件、Conflict 0 件、Stale 0 件、**When** 開く、**Then** 追っているセクションに 3 件 + badge 非表示
3. **Given** ⚠️ badge タップ、**When** タップ、**Then** 更新待ち一覧 (旧 FactConflictsSection + StaleSavedAnswersSection 統合 view) に遷移
4. **Given** isFollowing ConceptPage 0 件、**When** 開く、**Then** 「フォロー中の概念はまだありません」empty state + 知識 Clip 内の他カードから follow できる hint

---

### User Story 5 — 知識 Clip 右上アバターから Settings (Priority: P1)

知識 Clip タブの右上 toolbar に **アバター/プロフィール アイコン (👤)** が表示される。タップで SettingsView に遷移。

Settings root tab は削除。Settings 内のエントリ (Tag 管理 / iCloud sync / Chrome / Safari / AI チャット履歴削除 / 等) は **全て保持**、入口だけがアバター経由に統一される。

**Why this priority**: Apple News パターン (右上ユーザーアイコン → アカウント / 設定) に準拠。タブ削減のために必要。

**Independent Test**: 知識 Clip タブ右上アバタータップ → SettingsView 表示 → 既存全エントリ表示。

**Acceptance Scenarios**:

1. **Given** 知識 Clip タブ表示中、**When** 右上アバターをタップ、**Then** SettingsView が push or sheet 遷移で表示
2. **Given** SettingsView 表示中、**When** 既存エントリ (Tag 管理 / iCloud sync 等) をタップ、**Then** 既存 sub view に遷移、機能は V2.5 と同一
3. **Given** SettingsView から戻る、**When** 戻るボタン or swipe back、**Then** 知識 Clip タブに戻る

---

### User Story 6 — ライブラリタブが Apple Photos 風 日付別 grouping (Priority: P2)

ライブラリタブを開くと、保存済 Article が **日付別 grouping** (今日 / 昨日 / 今週 / 今月 / それ以前) で表示される。各 ArticleRow は thumbnail + title + サイト名 + 相対時刻。

上部に検索バー + 「分野で絞る」「タグで絞る」 filter pill が配置される。

**Why this priority**: 旧 ArticleListView は単純な savedAt desc list で、量が増えると見つけにくい。Apple Photos 風の日付 group + フィルター で「あの記事どこ?」を解決。

**Independent Test**: 異なる日付の記事 10 件保存 → ライブラリタブ → 5 つの date group に分類表示、各 group は閉じ折りたたみ可能。

**Acceptance Scenarios**:

1. **Given** 今日 3 件、昨日 2 件、今週 5 件保存、**When** ライブラリタブを開く、**Then** 3 group (今日 / 昨日 / 今週) で表示、各 group ヘッダ付き
2. **Given** 検索バーに「Apple」入力、**When** リアルタイム filter、**Then** 該当記事のみ表示、group は適切に縮小
3. **Given** 「分野で絞る」 pill タップ → 「テクノロジー」選択、**When** pill 選択、**Then** テクノロジー Category 内の記事のみ filter 表示

---

### User Story 7 — 知識 Clip / ライブラリ FAB で記事手動追加 (Priority: P2)

知識 Clip / ライブラリ タブの右下に **floating action button (⊕ 追加)** が表示される。タップで URL 入力 sheet が表示、URL 貼り付け or 入力 → 保存ボタンで Article 追加。

Share Extension / Safari Extension の既存経路は維持。

**Why this priority**: 現状は Share/Safari Extension しか保存経路がない。アプリ内から直接追加できれば「コピーした URL を貼り付けたい」需要に応えられる。

**Independent Test**: 知識 Clip タブ FAB タップ → URL 入力 sheet → 有効 URL 入力 → 保存 → ライブラリに記事追加確認。

**Acceptance Scenarios**:

1. **Given** 知識 Clip タブ表示中、**When** 右下 FAB タップ、**Then** URL 入力 sheet が下から出現、入力 field focus
2. **Given** 有効 URL 入力済、**When** 保存ボタンタップ、**Then** Article 保存処理開始、sheet dismiss、ライブラリに表示
3. **Given** 無効 URL 入力 (http: 無し等)、**When** 保存ボタンタップ、**Then** error alert 表示、sheet 維持
4. **Given** 重複 URL 入力、**When** 保存ボタンタップ、**Then** 「既に保存済です」alert + 既存記事へジャンプ

---

### User Story 8 — AI チャット 空状態 Suggested prompts (Priority: P2)

AI チャットタブを初めて開いた時 (session 0 / chat 履歴空)、**suggested prompts** 3 つが表示される:
- 「最近保存した記事の要点は?」
- 「{最新 ConceptPage 名} について教えて」
- 「{最新 Category 名} 分野で何があった?」

prompt はユーザーの実データに応じて動的生成、データが無い場合は generic fallback prompt 表示。タップで質問が送信される。

**Why this priority**: AI チャットの「何聞いていいか分からない」問題を解決。Apple Intelligence Writing Tools の suggested action 風。

**Independent Test**: 新規 ChatSession 状態 → AI チャットタブ → 3 つの suggested prompts 表示 → 1 つタップ → 自動送信 → AI 応答開始。

**Acceptance Scenarios**:

1. **Given** ChatSession 0 件、ConceptPage 5 件、Category 3 種類、**When** AI チャットタブを開く、**Then** 3 つの動的 suggested prompts 表示
2. **Given** suggested prompt タップ、**When** タップ、**Then** その prompt が user message として自動送信、AI 応答開始
3. **Given** ConceptPage 0 件 / Category 0 件 (新規 user)、**When** 開く、**Then** generic fallback prompts (「iKnow について教えて」等) を表示

---

### User Story 9 — AI チャット 📊 アイコンから Knowledge Graph 全体可視化 (Priority: P2)

AI チャットタブの右上 toolbar に **📊 Knowledge Graph アイコン** が配置される。タップで Knowledge Graph 全体可視化画面に遷移。Category 別 graph、node tap で ConceptPage 詳細遷移 (既存 spec 040/041 経路活用)。

**Why this priority**: 「AI が裏で何を理解しているか」を power user に見せる。AI を使っていることのアピール。AI ブレインタブ削除の代替動線。

**Independent Test**: AI チャットタブ → 右上 📊 タップ → Knowledge Graph 全体画面 → Category / node tap で詳細遷移。

**Acceptance Scenarios**:

1. **Given** GraphNode 20 件存在、**When** AI チャットタブ右上 📊 タップ、**Then** KnowledgeGraphFullScreenView が push 遷移、Category 別 graph 表示
2. **Given** Knowledge Graph 全体画面表示中、**When** node tap、**Then** GraphNodeDetailView に遷移 (既存 spec 041 動作維持)
3. **Given** GraphNode 0 件、**When** 📊 タップ、**Then** empty state「まだ知識グラフがありません」表示

---

### User Story 10 — 削除した機能の動線が機能継続 (Priority: P1)

旧 学習タブ / AI ブレインタブ / Settings タブ root 削除後も、それらの機能は完全に動作する:
- 学習タブの家庭教師ループ → 知識 Clip「続きが気になる」カード → DeepDiveChatView (spec 044)
- AI ブレインタブの Knowledge Map → AI チャット 📊 アイコン → KnowledgeGraphFullScreenView
- AI ブレインタブの統計 / PowerGauge / RecentActivity → Settings 内 sub view に格下げ
- Settings 全エントリ → 知識 Clip 右上アバター → SettingsView

**Why this priority**: 機能を「削除」しているのではなく「動線変更」しているだけ。既存ユーザーが触れる全機能が壊れない保証。

**Independent Test**: V2.5 で動作していた全機能 (家庭教師 / Knowledge Map / Tag 管理 / iCloud sync 等) を V3.0 で新動線経由で実行、全動作確認。

**Acceptance Scenarios**:

1. **Given** spec 044 家庭教師ループ動作 (V2.5)、**When** V3.0 で 知識 Clip「続きが気になる」→ ConceptPage カード → 深掘り、**Then** DeepDiveChatView 起動、3 ボタン (わかった / もっと / 興味ない) 全動作
2. **Given** spec 040 Knowledge Graph 動作 (V2.5)、**When** V3.0 で AI チャット 📊 → 全体画面、**Then** Category graph 表示、node tap で詳細
3. **Given** spec 051 iCloud sync toggle (V2.5)、**When** V3.0 で 知識 Clip 右上アバター → Settings → iCloud sync 項目、**Then** toggle 動作、確認 alert 表示
4. **Given** spec 024 Tag 編集 (V2.5)、**When** V3.0 で Settings → Tag 管理、**Then** Tag rename / merge / delete 動作

---

### User Story 11 — Empty State の親切な表示 (Priority: P3)

各セクションが空 (データ 0 件) の時、適切な empty state を表示:
- 最近の記事 (新規インストール直後): 「最近の記事はまだありません ✨ — 記事を共有してみよう」+ Share Extension 案内
- 続きが気になる (記事 5 件未満): 「もう少し記事を保存すると、ここに整理されます」
- 追っている人物・モノ (isFollowing 0 件): 「気になる人物やモノをフォローすると、ここに集まります」+ ConceptPage 詳細から follow できる hint
- AI チャット suggested prompts (実データ無し): generic prompt fallback

**Why this priority**: 「使い始め」ユーザーの不安解消。空白を放置しない、何をすれば良いか示す。

**Independent Test**: 新規インストール状態 → 知識 Clip タブ → 3 セクション全て empty state 表示、各 state に次のアクション hint。

**Acceptance Scenarios**:

1. **Given** 新規インストール (記事 0 件)、**When** 知識 Clip タブを開く、**Then** 3 セクション全て empty state、各 state に次の行動 hint
2. **Given** 記事 3 件保存、ConceptPage 未生成、**When** 知識 Clip タブを開く、**Then** 最近の記事は 3 件表示、続きが気になるは「もう少し記事を保存すると整理されます」表示
3. **Given** AI チャット 空状態、ConceptPage 0 件 / Category 0 件、**When** AI チャットを開く、**Then** generic fallback prompts 3 つ表示

---

### Edge Cases

- **タブ表示直後の loading**: 知識 Clip タブを開いた瞬間、データ取得に 100ms 以上かかる場合、スケルトン UI or shimmer placeholder 表示 (空白 flash 防止)
- **大量データ時の性能**: ConceptPage 100+ 件 / Article 1000+ 件で各セクションが 60fps 維持できるか (要 LazyVStack + transient struct 利用)
- **Knowledge Graph 全体表示の重さ**: GraphNode 200+ 件で Canvas 描画が固まる場合、Category 単位の subgraph に分割表示
- **FAB と scroll 干渉**: scroll down で FAB を隠す / scroll up で出現 (Apple News パターン)、scroll 中 FAB タップは無効化
- **Avatar tap の sheet vs push 判断**: iPad では sheet、iPhone では push 遷移 (NavigationStack 内)
- **Suggested prompts のキャッシュ**: 起動毎に再生成すると重い → 1 日 1 回更新、UserDefaults キャッシュ
- **差分ゼロ時 cache 永続化**: 「前回見た 3 記事」を UserDefaults に Article ID 配列で永続化、起動後 SwiftData fetch で復元
- **iPad での 3 タブ表示**: NavigationSplitView (iPad) では sidebar + content + detail の 3 column、3 タブは sidebar のセクションとして配置
- **既存ユーザー V2.5 → V3.0 アップデート時の onboarding**: 初回起動時 1 回だけ「タブが新しくなりました ✨」tooltip 表示 (UserDefaults flag 1 つ)

## Requirements *(mandatory)*

### Functional Requirements

**3 タブ構成 (P1)**

- **FR-001**: System MUST display exactly 3 root tabs: 知識 Clip / ライブラリ / AI チャット (in this left-to-right order)
- **FR-002**: System MUST set 知識 Clip as default tab on every app launch (overriding any previous LastOpenedStore.lastTab value)
- **FR-003**: System MUST remove root-level tabs for: 学習 (Understanding) / AI ブレイン (AIBrain) / Settings
- **FR-004**: System MUST migrate existing user UserDefaults so V2.5 tab state does not cause crashes (one-time migration flag)

**知識 Clip タブ (P1)**

- **FR-005**: System MUST display 3 sections in 知識 Clip in this order: 最近の記事 / 続きが気になるもの / 追っている人物・モノ
- **FR-006**: System MUST display top 3 recent articles in 最近の記事 section, source = articles with savedAt >= LastOpenedStore.lastOpenedAt
- **FR-007**: System MUST display recent articles as horizontal scroll cards, each card showing essence (40-50 chars) + title + site name
- **FR-008**: System MUST show "+N もっと見る" link if 4+ new articles available, link navigates to filtered article list
- **FR-009**: System MUST maintain previous 3 articles unchanged when no new articles since LastOpenedStore.lastOpenedAt (no empty state during steady-state usage)
- **FR-010**: System MUST persist "previously displayed 3 article IDs" in UserDefaults so they survive app restart
- **FR-011**: System MUST display empty state "最近の記事はまだありません ✨" only when both differential is zero AND no prior cache exists (new install state)

**続きが気になるもの セクション (P1)**

- **FR-012**: System MUST display mixed card types in 続きが気になる section: ConceptPage cards (UnderstandingCardSurfaceService 経由) + Topic Dashboard cards (KnowledgeDigest)
- **FR-013**: System MUST show top 5 cards combined (by surface priority), with "もっと見る ›" link for remaining
- **FR-014**: System MUST navigate to DeepDiveChatView when ConceptPage card tapped (preserving spec 044 behavior)
- **FR-015**: System MUST navigate to CategoryKnowledgeDetailView when Topic Dashboard card tapped (preserving spec 018 behavior)
- **FR-016**: System MUST integrate UserTopic (spec 036) data into Topic Dashboard cards (no separate DynamicTopicsSection)

**追っている人物・モノ セクション (P1)**

- **FR-017**: System MUST display top 5 ConceptPage with isFollowing=true in 追っている section, sorted by updatedAt desc
- **FR-018**: System MUST show "⚠️ 更新が必要 (N)" badge subheader if N >= 1 (N = count of ConflictProposal undecided + isStale SavedAnswer)
- **FR-019**: System MUST hide "⚠️ 更新が必要" subheader when count is 0
- **FR-020**: System MUST navigate to unified review screen when ⚠️ badge tapped (merging old FactConflicts + StaleSavedAnswers views)
- **FR-021**: System MUST display ConceptPage cards with userUnderstanding 5-dot indicator (●●●○○) + related article count

**知識 Clip toolbar (P1)**

- **FR-022**: System MUST display avatar/profile icon in top-right toolbar of 知識 Clip tab
- **FR-023**: System MUST navigate to SettingsView when avatar icon tapped (sheet on iPad, push on iPhone)
- **FR-024**: System MUST preserve all existing Settings entries (Tag 管理 / iCloud sync / Chrome / Safari / Chat history delete / etc.)

**ライブラリタブ (P2)**

- **FR-025**: System MUST display articles grouped by date in ライブラリ tab: 今日 / 昨日 / 今週 / 今月 / それ以前
- **FR-026**: System MUST display search bar at top of ライブラリ tab, real-time filtering
- **FR-027**: System MUST display filter pills: 分野で絞る / タグで絞る (multi-select within each)
- **FR-028**: System MUST preserve existing swipe + contextMenu delete (spec 022/030)

**FAB 記事追加 (P2)**

- **FR-029**: System MUST display floating action button (⊕) at bottom-right of 知識 Clip and ライブラリ tabs
- **FR-030**: System MUST display URL input sheet when FAB tapped
- **FR-031**: System MUST validate URL on save (http:// or https:// scheme required) and reject invalid URLs
- **FR-032**: System MUST detect duplicate URL on save and show "既に保存済です" alert with jump-to-article option
- **FR-033**: System MUST preserve Share Extension and Safari Extension existing save paths

**AI チャットタブ (P2)**

- **FR-034**: System MUST display 3 suggested prompts in AI チャット tab when ChatSession history is empty
- **FR-035**: System MUST generate suggested prompts dynamically using user data (latest ConceptPage / Category) with generic fallback
- **FR-036**: System MUST auto-send prompt as user message when suggested prompt card tapped
- **FR-037**: System MUST display 📊 Knowledge Graph icon in AI チャット tab top-right toolbar
- **FR-038**: System MUST navigate to KnowledgeGraphFullScreenView when 📊 icon tapped

**Knowledge Graph 全体画面 (P2)**

- **FR-039**: System MUST display all Category-level Knowledge Graphs in KnowledgeGraphFullScreenView
- **FR-040**: System MUST navigate to GraphNodeDetailView when graph node tapped (preserving spec 041 behavior)
- **FR-041**: System MUST display empty state when GraphNode count is 0

**動線継続性 (P1)**

- **FR-042**: System MUST preserve spec 044 家庭教師ループ functionality via 知識 Clip 続きが気になる → DeepDiveChatView
- **FR-043**: System MUST preserve spec 040 Knowledge Graph functionality via AI チャット 📊 icon
- **FR-044**: System MUST preserve all spec 042/043/046/047 functionality (ConceptPage / SavedAnswer / Stale / Chips)
- **FR-045**: System MUST preserve all Settings sub-features (Tag 管理 / iCloud sync / Chrome / Safari)

**Empty States (P3)**

- **FR-046**: System MUST display contextually appropriate empty state for each section with next-action hint
- **FR-047**: System MUST display "もう少し記事を保存すると整理されます" in 続きが気になる when ConceptPage count < threshold
- **FR-048**: System MUST display "気になる人物やモノをフォローすると…" in 追っている when isFollowing count is 0
- **FR-049**: System MUST display "タブが新しくなりました ✨" one-time tooltip for V2.5 → V3.0 upgrade users (UserDefaults flag)

### Key Entities

- **RecentArticlesCache**: 「最近の記事」セクションの差分ゼロ時に維持する Article ID 配列。UserDefaults に永続化 (max 3 件)
- **SuggestedPrompt** (transient): AI チャット空状態で表示する prompt 文字列 + 動的生成元 (ConceptPage / Category / fallback) + sourceType enum
- **LibraryDateGroup** (transient): ライブラリの日付グループ enum (今日 / 昨日 / 今週 / 今月 / それ以前) + 含まれる Article 配列
- **MixedSurfaceCard** (transient): 「続きが気になる」セクションで表示する混在カード、UnderstandingCard or KnowledgeDigest を統合した display struct
- **ActionItemBadgeData** (transient): 「⚠️ 更新が必要」 badge の count + 内訳 (Conflict 数 / Stale SavedAnswer 数)
- **V3MigrationFlag**: UserDefaults flag `spec056_v3_migrated` で V2.5 → V3.0 初回起動 1 回だけの onboarding tooltip 表示判定

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 起動時 default tab = 知識 Clip 達成率 100% (毎回起動で確認、UserDefaults lastTab に関係なく)
- **SC-002**: タブバー表示数 = 3 (4 タブ以上が表示されたら fail)
- **SC-003**: 知識 Clip タブ表示後 1 秒以内に 3 セクション全表示 (LazyVStack + skeleton 利用)
- **SC-004**: 「最近の記事」セクションが差分ゼロ時に空にならない (前回 cache 維持) — 起動 → kill → 再起動を 3 回繰り返して empty にならない確認
- **SC-005**: 「続きが気になる」セクションで ConceptPage + Topic Dashboard カードが混在表示される (両方が surface 経路に乗ること)
- **SC-006**: 「⚠️ 更新が必要」 badge が件数 0 で非表示、1 以上で表示 (binary 確認)
- **SC-007**: 知識 Clip 右上アバタータップで Settings 遷移 100% 動作
- **SC-008**: 60fps 維持 (ConceptPage 100 件 + Article 1000 件 + GraphNode 200 件状態で各タブ scroll)
- **SC-009**: ライブラリタブが 5 つの date group で表示 (今日 / 昨日 / 今週 / 今月 / それ以前、データに応じて表示 group 数調整)
- **SC-010**: FAB タップ → URL 入力 sheet 表示 → 有効 URL 入力 → 保存成功までを 30 秒以内に完了
- **SC-011**: AI チャット空状態で 3 つの suggested prompts 表示、各 prompt は 30 字以内
- **SC-012**: AI チャット 📊 アイコンタップで Knowledge Graph 全体画面遷移 2 秒以内
- **SC-013**: V2.5 → V3.0 アップデート時、既存全機能 (家庭教師 / Knowledge Map / Tag 管理 / iCloud sync) が新動線経由で 100% 動作
- **SC-014**: 既存ユーザー初回起動で「タブが新しくなりました ✨」 tooltip 表示、2 回目以降は表示なし
- **SC-015**: 既存 unit test suite 全 PASS (regression なし、新規 + 既存テスト合算)
- **SC-016**: タブ削減により root view 数 5 → 3 に減少 (UnderstandingTabView + AIBrainTabView + SettingsTabView の 3 root view 削除)
- **SC-017**: ユーザーが iKnow を 1 文で説明できるレベルの体験簡素化 (測定: 招待 5 名に「何アプリ?」と聞いて 4 名以上が「読んだ記事を AI が整理するアプリ」相当の説明を返す)
- **SC-018**: 4 タブ → 3 タブで scroll / tap 操作回数を主要 user flow で 20% 削減 (例: 学習開始 = 旧 4 タップ → 新 3 タップ)

## Assumptions

- **対象ユーザー**: 週 1-2 回の light user。毎日アプリを開く power user は副次的対象
- **iOS バージョン**: iOS 26 以降。NavigationSplitView (iPad) と Floating Action Button SwiftUI native は iOS 26 で安定動作
- **データ規模**: 平均的 user は記事 100-500 件、ConceptPage 10-50 件、GraphNode 50-200 件と想定。1000+ 件規模は power user として LazyVStack で対応
- **migrate 戦略**: V2.5 → V3.0 は破壊的 UI 変更だが、データレイヤー (SwiftData @Model) は無変更。UserDefaults `lastTab` は無視して必ず知識 Clip default
- **既存機能の動線変更**: 既存機能を「削除」ではなく「動線変更」と位置づけ。家庭教師ループ / Knowledge Graph / Settings 全項目は完全保持
- **FAB の挙動**: scroll down で FAB を隠す Apple News パターンを採用 (scroll up / 静止時表示)
- **Suggested prompts のキャッシュ**: 起動毎再生成すると重いため UserDefaults に 1 日 1 回更新、起動時は cache 表示
- **差分ゼロ時 cache 永続化**: UserDefaults に Article ID 配列 (max 3) を JSON encode で保存、起動時 SwiftData fetch で復元
- **Knowledge Graph 全体画面の重さ**: GraphNode 200+ 件は Category 単位 subgraph 分割表示で対処
- **iPad UI**: NavigationSplitView 利用、3 タブを sidebar セクションとして配置。iPhone は標準 TabView
- **依存 spec**: spec 042 (ConceptPage) / spec 043 (SavedAnswer) / spec 044 (Understanding Chat) / spec 040 (Knowledge Graph) / spec 018 (KnowledgeDigest) / spec 035 (LastOpenedStore) / spec 036 (UserTopic) / spec 037 (ConflictProposal) / spec 046 (StaleSavedAnswers) / spec 051 (CloudKit) — 全て V2.5 で実装済 (本 spec はそれらの surface 経路を再編成)
- **release ターゲット**: V2.5 (CloudKit) と一括で V3.0 として release。V2.5 単独 release はスキップ
- **commit 単位**: Phase A (基盤 + KnowledgeClipView) → Phase B (Library) → Phase C (AI Chat) で段階 commit、最終 1 PR でマージ
- **テスト戦略**: 新規 service 3 つ (RecentArticlesService / SuggestedPromptGenerator / LibraryDateGrouper) は Mock + 純粋関数 unit test、UI は既存パターン (XCUIApplication + accessibilityIdentifier)
- **Apple HIG 準拠の判断基準**: 公開ドキュメント https://developer.apple.com/design/human-interface-guidelines/ 準拠、特に Navigation / Tab Bars / Layout / Empty States のガイドラインを参照
- **言語**: 日本語 first 維持、英語 / 多言語化は範囲外
