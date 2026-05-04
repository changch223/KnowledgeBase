# Feature Specification: 本文抽出 (Reader View)

**Feature Branch**: `003-extract-body` *(計画中。spec 001 / spec 002 commit 後に実ブランチを切る)*
**Created**: 2026-05-04
**Status**: Draft
**Input**: ユーザー説明: "spec 002 でキャッシュした raw HTML から、Readability 風のヒューリスティックで記事本文を抽出して `ArticleBody` エンティティに保存する。一覧の行をタップしたときの遷移先を、これまでの SFSafariViewController から「アプリ内 Reader View」に切り替える (本文抽出に成功しているとき)。失敗時は spec 001 / spec 002 と同じく SFSafariViewController にフォールバック。新規ネットワークアクセスは発生させない (rawHTML は spec 002 でキャッシュ済み)。"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - アプリ内 Reader View で本文を快適に読める (Priority: P1)

ユーザーが一覧から記事をタップすると、その記事の本文がアプリ内の Reader View に表示される。広告・ナビゲーション・サイドバー等は除去され、本文と段落だけが読みやすい行送り・余白で並ぶ。Dark Mode / Dynamic Type にも対応する。アプリから一度も離れずに記事を読み切れる。

**Why this priority**: spec 001 / spec 002 までは「保存して見返す」までの体験を作ったが、実際の「読む」体験はブラウザ任せだった。アプリ内 Reader を持つことで、片手操作・移動中・短時間での読書 (Constitution Principle V) を本格的に実現できる。本機能は KnowledgeTree が「単なるブックマークアプリ」と差別化される最大のポイント。

**Independent Test**: spec 002 で enrichment 成功済の記事を一覧でタップ → アプリ内 Reader View が立ち上がり、本文が読みやすい typography で表示される。広告・関連記事・ヘッダ等は含まれていない。スクロールして最後まで読める。「完了」または戻る操作で一覧に戻れる。

**Acceptance Scenarios**:

1. **Given** spec 002 で enrichment 成功し ArticleBody が抽出済の記事が一覧にある、**When** ユーザーがその行をタップする、**Then** アプリ内 Reader View が画面を覆い、抽出された本文が標準 Dynamic Type サイズで表示される。本文以外の boilerplate (広告、ナビ、サイドバー、コメント欄) は表示されない。
2. **Given** Reader View で記事を読んでいる、**When** ユーザーが「完了」または戻る gesture を行う、**Then** Reader View が閉じ、一覧画面に戻る。スクロール位置は次回開いたとき初期に戻る (本 spec ではセッション内位置記憶は持たない)。
3. **Given** Reader View で記事を読んでいる、**When** Dark Mode 切替や文字サイズ変更を OS 設定で行う、**Then** Reader View の表示が即座に追従する。
4. **Given** Reader View で記事を読んでいる、**When** ユーザーが「元記事を開く」アクション (toolbar ボタン) をタップする、**Then** SFSafariViewController が立ち上がり元 URL がロードされる (spec 001 / spec 002 と同じ挙動)。

---

### User Story 2 - 抽出失敗 / 未抽出時は SVC にフォールバック (Priority: P2)

本文抽出に失敗 (rawHTML がない、抽出ヒューリスティックが本文を見つけられない、抽出結果が短すぎる等) した場合、一覧の行タップは spec 001 / spec 002 と同じく SFSafariViewController を開く。Reader View に遷移して「読めません」の空状態を見せるのは Principle V (落ち着いた UX) に反するため、最初から SVC にフォールバックする。

**Why this priority**: 抽出失敗時の UX が壊れていると、Reader 機能全体への信頼を失う。Principle II (MVP first) と Principle V (落ち着いた UX) を両方守るためには、失敗時はサイレントに既存挙動 (SVC) に戻す設計が必須。

**Independent Test**: rawHTML が nil の記事 (spec 002 で 2MB 超で破棄されたケース等) または ArticleBody.status が `failed` の記事をシードし、一覧でタップする → アプリ内 Reader View ではなく SFSafariViewController が直接開く (spec 001 / spec 002 と同じ挙動)。

**Acceptance Scenarios**:

1. **Given** ArticleBody が `failed` または `permanentlyFailed` または不在の記事が一覧にある、**When** ユーザーがその行をタップする、**Then** SFSafariViewController が立ち上がり元 URL がロードされる (Reader View には遷移しない)。
2. **Given** rawHTML から本文抽出を行ったが、結果が極端に短い (例: 100 文字未満) 場合、**When** 抽出ジョブが完了する、**Then** ArticleBody.status は `failed` として保存され、一覧でその行をタップしても SVC が開く (Reader 表示は試みない)。

---

### User Story 3 - Reader View 表示中も元記事に戻れる (Priority: P3)

Reader View で本文を読んでいるユーザーが「画像も見たい」「コメント欄を見たい」「動画があるはず」と思ったとき、toolbar の「元記事を開く」ボタン 1 つで SFSafariViewController に切り替えられる。Reader View ↔ 元記事 ブラウザは透過的に切り替わり、ユーザーが望む表示形態を選べる。

**Why this priority**: 抽出本文だけでは満足できないケース (画像中心、動画埋込、interactive content 等) のための逃げ道。MVP 中核ではないが、Reader 採用率を高めるユーザー控制。

**Independent Test**: Reader View 表示中に「元記事を開く」ボタンをタップ → SFSafariViewController が立ち上がる。SVC を閉じる → Reader View に戻る (Reader View が裏で立ち上がっていた場合) または一覧に戻る (Reader View が dismiss されていた場合)。

**Acceptance Scenarios**:

1. **Given** Reader View が表示されている、**When** toolbar の「元記事を開く」 (例: `safari` SF Symbol) をタップ、**Then** SFSafariViewController が Reader View の上に modal で重ねて表示される。
2. **Given** SVC が Reader View の上に重なっている、**When** SVC の「完了」を押す、**Then** SVC が閉じ、Reader View が再び見える。

---

### Edge Cases

- **rawHTML が nil (spec 002 で 2MB 超で破棄)**: ArticleBody は作成しない。一覧タップ時は spec 001 / spec 002 のフォールバックで SVC 直行。
- **本文抽出結果が極端に短い** (100 文字未満): `failed` 扱い。Reader 表示は試みず、SVC 直行。
- **本文抽出結果に大量の画像参照を含む** (例: 100 個超の `<img>`): MVP では画像は表示しない (テキスト only)。画像インライン表示は将来 spec で扱う。
- **JavaScript 必須サイト** (本文が JS で injected されるシングルページアプリ等): rawHTML には初期 HTML しか入っていないため抽出は事実上失敗する。SVC 直行。
- **Paywall サイト** (有料記事の途中で切れる HTML): 抽出した本文は途中まで。ユーザーには Reader 内に表示されるが、続きは SVC で見るしかない (US3 の「元記事を開く」が活きる)。
- **複数言語混在** (英語サイト + 日本語サイト): Reader View の typography は OS 既定 (Dynamic Type) のため自動対応。RTL 言語 (アラビア語等) は MVP では未検証 (将来 spec で対応)。
- **抽出ジョブ未完了状態でタップ**: `pending` / `extracting` 状態 → 一旦 SVC で開く (Reader が出て「準備中…」表示は Principle V に反するため)。次回タップ時には抽出完了していれば Reader が出る。
- **`Localizable.xcstrings` の Reader 文言**: 「元記事を開く」「完了」等の Reader UI 文言は新規キーで日本語登録 (Principle VII)。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: アプリは新規 `ArticleEnrichment.status == .succeeded` (rawHTML が保存されている) になった時点で、その Article の本文抽出ジョブをバックグラウンドキューに登録する。spec 002 のキューと並列ではなく後続として直列実行可能。
- **FR-002**: 本文抽出は **キャッシュ済 rawHTML のみを入力に取り、新規ネットワークアクセスを行わない** (Constitution Principle I 維持)。rawHTML が nil の場合は抽出を試みず、ArticleBody は作成しない。
- **FR-003**: 抽出結果は新規エンティティ `ArticleBody` として保存し、対応する `Article` への non-optional 参照を持つ (Constitution Principle III)。
- **FR-004**: 抽出は Foundation 標準 API のみで実装する (サードパーティ依存禁止 — Constitution Additional Constraints)。`<article>` / `<main>` / `<div role="main">` 等の意味的タグを優先し、見つからなければテキスト密度の高い `<div>` をスコアリングして選ぶ Readability 風ヒューリスティック。
- **FR-005**: 抽出結果が 100 文字未満なら `failed` ステータスで保存し、Reader View には遷移させない (US2 / Edge Case)。
- **FR-006**: 一覧画面の行タップ時の遷移先は: ArticleBody.status == .succeeded なら Reader View、それ以外 (なし / failed / permanentlyFailed / pending / extracting) なら SFSafariViewController (spec 001 / spec 002 の挙動を維持)。
- **FR-007**: Reader View は抽出された本文を SwiftUI の標準 Text コンポーネントで段落ごとに表示する。Dynamic Type / Dark Mode / VoiceOver にネイティブ対応。
- **FR-008**: Reader View の toolbar には「完了」(dismiss) と「元記事を開く」(SVC 起動) の 2 ボタンを置く (US3)。文言は `Localizable.xcstrings` から日本語で取得。
- **FR-009**: Reader View では画像 (`<img>`)、動画 (`<video>`)、interactive content (`<iframe>`、`<canvas>` 等) は **表示しない** (テキストのみ)。これらは将来 spec で扱う。
- **FR-010**: 抽出ジョブの進行状況 (`pending` / `extracting` / `succeeded` / `failed` / `permanentlyFailed`) は ArticleBody.status として永続化する。一覧画面ではこの状態を表示しない (Principle V — UI ノイズ回避)。
- **FR-011**: 同一 Article の rawHTML が更新された場合 (将来 spec 003+ で fetch 再実行時) は、対応する ArticleBody を invalidate して再抽出する。本 spec の MVP では rawHTML 更新経路がないため再抽出は発生しない。
- **FR-012**: Article 削除時、関連する ArticleBody は cascade delete される (Principle III の構造的整合性維持)。
- **FR-013**: Reader View / SVC 遷移先選択は同期的に行う (タップ → 遷移までの判定処理は ≤ 50 ms)。判定中の中間スピナーは表示しない (Principle V)。

### Key Entities *(include if feature involves data)*

- **ArticleBody**: 1 件の `Article` に紐づく抽出済本文。
  - 必須属性: 一意識別子、対応する `Article` への non-optional 参照 (Principle III)、抽出ステータス (`pending` / `extracting` / `succeeded` / `failed` / `permanentlyFailed`)。
  - オプション属性: extractedText (String?、本文の plain text)、extractionVersion (Int、ヒューリスティックバージョン管理)、lastExtractedAt (Date?)。
  - 関係: `Article` ↔ `ArticleBody` は 1-to-1 (cascade delete: Article 削除時に ArticleBody も削除)。`ArticleEnrichment.rawHTML` を入力に取るが、エンティティ間の direct relationship は持たない (それぞれが Article を経由)。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: enrichment (spec 002) 成功から ArticleBody が `succeeded` になるまで、典型的なニュース記事 (50-200 KB の HTML) に対して **median 1 秒以内** で完了する。
- **SC-002**: Reader View の表示までの所要時間 (一覧タップから本文が見えるまで) は **300 ms 以内**。
- **SC-003**: 典型的なニュースサイト 20 サイトのサンプルで、本文抽出成功率 (extractedText が ≥ 100 文字) が **70% 以上**。
- **SC-004**: 本文抽出ジョブ実行中もアプリ本体の UI 応答性は ≤ 100 ms (Constitution パフォーマンスゲート)。バックグラウンド処理がメインスレッドをブロックしない。
- **SC-005**: ネットワーク切断状態でも、Reader View 表示・一覧表示・既存全機能 (spec 001 + 抽出済の Reader 表示) は **100 % 利用可能**。本 spec 自体は新規ネットワーク非依存。
- **SC-006**: 100 件の記事一覧 (各々 ArticleBody を持つ) で 60 fps スクロール維持 (Constitution パフォーマンスゲート)。
- **SC-007**: Reader View 中の Dynamic Type 最大サイズ + Dark Mode + VoiceOver 全部 ON で layout 崩れ・読み上げ漏れ 0 件 (Quality Gate)。

## Assumptions

- **対象 OS / 端末**: spec 001 / 002 と同じ (iOS 26+ / iPadOS 26+、Apple Intelligence 対応端末)。本 spec も Foundation Models 不使用。
- **rawHTML への依存**: 本 spec は spec 002 の `ArticleEnrichment.rawHTML` をキャッシュとして使う。rawHTML が nil (spec 002 が 2MB 超で破棄したケース等) の Article は本 spec の対象外 (Reader 対応なし)。
- **抽出ヒューリスティックの品質**: Foundation 単独で達成できる抽出品質には限界がある (Mozilla Readability や Apple Reader Mode のような完成度には届かない可能性が高い)。MVP では 70% 成功率 (SC-003) を目標とし、不足ケースは将来 spec / 反復改善で対応。失敗時の UX (SVC フォールバック) を堅牢にすることで品質不足を緩和する。
- **画像・動画・interactive コンテンツ**: MVP では Reader View に表示しない (FR-009)。画像インライン表示は将来 spec。
- **Reader View 内のセッション位置記憶**: 本 spec ではセッション内のスクロール位置記憶を持たない (Reader View を再オープンすると先頭に戻る)。読書再開機能は将来 spec。
- **Reader View 内の typography 設定 UI** (フォントサイズ調整、テーマ切替等): MVP では持たない (OS の Dynamic Type / Dark Mode に従うのみ)。カスタマイズ UI は将来 spec。
- **schema migration**: spec 001 / 002 同様、production リリース前のため新エンティティ `ArticleBody` 追加は SwiftData lightweight migration で吸収できる想定。

## Out of Scope

本 spec では以下を **明示的に扱わない**。すべて将来 spec で扱う想定。

- **画像 / 動画 / iframe のインライン表示**: 本文 plain text のみ。画像インラインは「Reader View Phase 2」で扱う。
- **要約 (Apple Foundation Models)**: 次の spec で扱う。本 spec の `ArticleBody.extractedText` を入力に取る予定。
- **カテゴリ分類** (Apple Foundation Models): その次の spec で扱う。
- **Reader View 内の typography 設定** (フォントサイズ・テーマ・行送り): MVP では OS 既定のみ。将来 spec で典型的な reader-mode UI controls を追加。
- **読書位置記憶 / 続きから読む**: MVP では持たない。将来の「ハイライト & ノート」spec の前提として検討。
- **オフライン読書 (画像含む)**: 画像未対応のため automatic にオフラインだが、画像対応時にローカルキャッシュも追加する将来 spec で扱う。
- **rawHTML がない Article への再 fetch**: 本 spec では spec 002 のキャッシュに依存。再 fetch は spec 002 の手動再取得 (Out of Scope) に含まれる。
- **Mozilla Readability 移植 / サードパーティ Readability ライブラリ採用**: 禁止。Foundation 標準で実装。
- **Safari Reader Mode との統合**: 公開 API なし。検討対象外。
- **多言語 typography 最適化** (アラビア語 RTL 等): MVP は日本語 + 英語のみで動作確認。RTL は将来 spec。
- **TTS (text-to-speech) / オーディオ読み上げ**: 完全に別 spec。
