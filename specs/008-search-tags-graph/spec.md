# Feature Specification: 保存記事の振り返り支援 (検索 + タグ + エンティティ横断)

**Feature Branch**: `008-search-tags-graph`
**Created**: 2026-05-05
**Status**: Draft
**Input**: User description: "保存記事の振り返り支援。3 つの主要機能を 1 つの spec に統合する: (1) 全文検索、(2) タグ付け、(3) エンティティ横断 (knowledge graph)、(4) タグ自動提案。spec 005 / 006 / 007 で蓄積された知識データをフル活用。MVP 範囲では: 検索のソート (saved 日時降順固定), 検索履歴の永続化なし, タグの色やアイコン無し, グラフ可視化 UI 無し (テキストリストのみ)。検索パフォーマンスは 1000 記事までを想定。"

## User Scenarios & Testing

### User Story 1 - 過去に保存した記事を検索で見つける (Priority: P1)

ユーザーが数十〜数百件の記事を保存している状態で、特定のトピック (例: 「OAuth」「KFC」「気候変動」) について書かれた記事を素早く見つけたい。一覧画面の上部に検索バーを表示し、入力されたキーワードで title / canonicalTitle / summary / essence / keyFacts.statement / entity.name を横断検索する。case-insensitive で部分一致、結果はマッチ箇所ハイライト付きで表示。

**Why this priority**: 保存記事数が増えると一覧スクロールでの探索が破綻する (50 件以上で実用性低下)。振り返り体験の中核機能。spec 001-006 で生成された豊富な知識フィールド (essence / keyFacts / entities) を検索対象にすることで、記事タイトルにキーワードが無くても本文中の言及で見つけられる。

**Independent Test**: 数件の記事を保存して、それぞれの essence / entity に含まれる固有名詞で検索すると該当記事のみが返ることを確認できる。

**Acceptance Scenarios**:

1. **Given** ユーザーが 30 件の記事を保存し、うち 3 件の essence に「OAuth」が含まれる状態、**When** 検索バーに「oauth」と入力する、**Then** 3 件のみが結果として表示され、各行の essence に「OAuth」がハイライトされる (case-insensitive 一致)
2. **Given** 検索バーに何も入力されていない状態、**When** 一覧画面を見る、**Then** 全記事が saved 日時降順で表示される (現行と同じ動作)
3. **Given** 検索バーに「存在しないキーワード」を入力した状態、**When** 結果を見る、**Then** 「該当する記事がありません」という空状態メッセージが表示される
4. **Given** 検索バーに 1 文字「a」を入力した状態、**When** 結果を見る、**Then** 該当する記事 (1 文字でも部分一致するため大量の可能性) が saved 日時降順で表示される

---

### User Story 2 - 記事に手動でタグを付ける (Priority: P2)

ユーザーが Detail 画面で記事に対してタグを追加・削除できる。タグは小文字 trim で正規化され、同じ記事に同じタグを 2 回付けても重複しない。「タグ一覧」画面から既存タグをタップすると、そのタグが付いた記事一覧へ遷移する。

**Why this priority**: ユーザー独自の分類軸 (e.g., 「読み返したい」「実務で使う」「面白かった」) を作れる。AI 抽出 entity とは別の主観的なメタ情報を持つことで、検索だけでは届かない振り返り体験を提供する。spec 001-006 のデータにユーザー意図を上乗せするレイヤー。

**Independent Test**: 1 記事に手動で 2 タグを付け、タグ一覧でそれらのタグが表示され、タグをタップして記事一覧に戻ったときに対象記事が含まれることを確認できる。

**Acceptance Scenarios**:

1. **Given** ユーザーが Detail 画面を開いた状態、**When** タグ追加 UI で「読み返したい」と入力して確定、**Then** 記事に「読み返したい」タグが追加され、Detail 画面のタグ一覧にチップ表示される
2. **Given** 記事に「読み返したい」タグが付いている状態、**When** タグチップの×ボタンをタップ、**Then** タグが記事から削除される (タグ自体はマスタに残る場合とすべて削除される場合の挙動を統一: 該当記事 0 件になったタグはマスタから自動削除)
3. **Given** 「READ Later」と「read later」を別々の記事に追加しようとした状態、**When** 入力を確定、**Then** 両方とも「read later」(小文字 trim 済) という同一タグとして正規化される
4. **Given** 既に「読み返したい」タグを持つ記事に同じタグを再度追加しようとした状態、**When** 入力を確定、**Then** 重複追加されず無視される (no-op)
5. **Given** 「タグ一覧」画面を開いた状態、**When** 「読み返したい」をタップ、**Then** 「読み返したい」タグを持つ記事の一覧画面に遷移する (一覧画面と同じ row UI、検索バーには「tag:読み返したい」のような表示)

---

### User Story 3 - 関連記事をエンティティ経由で発見する (Priority: P2)

ユーザーが Detail 画面を見ているとき、その記事と共通の KnowledgeEntity を持つ他の記事を「関連記事」として下部に表示。共通 entity が多いほど上位、最大 5 件。同 entity を別の記事でも見ていることに気付くことで、知識のつながりを可視化する。entity チップ自体をタップすると、その entity を含む記事一覧へ遷移。

**Why this priority**: spec 004 で抽出した entity を活用する代表的な使い道。「あの本で読んだ概念、別の記事でも触れていた」気付きは知識管理アプリの価値を体現する。グラフ可視化 (D3.js のような) は MVP では UI 複雑度が大きすぎるためテキストリストで実装、将来 spec で可視化検討。

**Independent Test**: 同じ entity (例: 「Apple」) を持つ 2 件の記事を保存して、片方の Detail を開いたときにもう一方が関連記事として下部に出ることを確認できる。

**Acceptance Scenarios**:

1. **Given** ユーザーが「OpenAI」「ChatGPT」「Apple」を共通 entity として持つ記事 A と B、「Apple」のみ共通の記事 C を保存している状態、**When** 記事 A の Detail を開く、**Then** 関連記事セクションに B (共通 3 entity)、C (共通 1 entity) の順で表示される
2. **Given** 共通 entity を持つ記事が 7 件ある状態、**When** Detail を開く、**Then** 上位 5 件のみ表示され「他 2 件...」のような追加表示は MVP では出さない (上限切り)
3. **Given** ユーザーが entity チップ「Apple」をタップした状態、**When** 遷移先を見る、**Then** 「Apple」を含むすべての記事一覧画面へ遷移する (記事一覧画面の上部に「entity: Apple」の絞り込み状態が表示)
4. **Given** Detail 画面に共通 entity を持つ他記事が 0 件の状態、**When** 関連記事セクションを見る、**Then** セクション自体を非表示にする (Principle V: calm UX)
5. **Given** 記事 A の knowledge.status が `.failed` (entity 抽出されてない) 状態、**When** 関連記事を見る、**Then** セクション非表示

---

### User Story 4 - エンティティから自動タグ提案を採用する (Priority: P3)

ユーザーが Detail 画面で、その記事の知識サマリで salience 4 以上 (高重要度) の entity を「自動タグ候補」として 1 タップで採用できる。AI が抽出した entity を手動タグ付けの省力化に使う。

**Why this priority**: タグ付け (US2) のうち手動入力の手間を減らす補助機能。AI 出力を信用しすぎないための「ユーザー承認 1 タップ」モデル。MVP の中では P3 (P2 タグの拡張) として位置づけ。

**Independent Test**: 高重要度 entity を持つ記事を Detail 開き、提案チップをタップしたら手動タグと同じ扱いで保存され、再度 Detail を開くと提案チップから消えていることを確認。

**Acceptance Scenarios**:

1. **Given** 記事の knowledge.entities に salience 5 の「OAuth」、salience 3 の「PKCE」が含まれる状態、**When** Detail 画面のタグセクションを見る、**Then** 「OAuth」のみが「+ OAuth」のような提案チップで表示される (salience 4 以上のみ)
2. **Given** 提案チップ「+ OAuth」が表示されている状態、**When** チップをタップ、**Then** 「oauth」(正規化済) タグが手動タグと同じ扱いで保存され、提案チップは消えて手動タグチップ「oauth ×」に変わる
3. **Given** ユーザーが既に手動で「oauth」タグを付けている記事の状態、**When** Detail を再度開く、**Then** 「+ OAuth」提案チップは既に追加済として表示されない

---

### Edge Cases

- **検索文字列が極端に短い (1-2 文字)**: 部分一致なので大量ヒットの可能性。MVP ではそのまま実行、UI に上限 (例: 100 件) は設けない
- **検索文字列に正規表現メタ文字が含まれる**: 単純文字列検索 (literal contains)、正規表現として解釈しない
- **検索文字列が空白のみ**: 空入力扱い (全件表示)
- **記事に knowledge.status が `.failed` / `.skipped`**: essence / keyFacts / entities が未取得 → 検索対象は title / canonicalTitle / summary のみ。検索結果には含まれる可能性あり
- **検索バーにフォーカス中に新規記事が追加される**: 検索結果が live update で増減する (spec 005 の通知メカニズム継承)
- **同じタグが大文字小文字違いで重複入力**: 正規化で同一視 (e.g., 「OAuth」「oauth」「OAUTH」 → 「oauth」)
- **タグ名に絵文字 / 全角 / 半角混在**: 全部受理。trim と小文字化のみ実施 (絵文字の小文字化は無効)
- **タグ名に / や : などの特殊文字**: 受理 (検索クエリと衝突しない、ユーザーが望めば付けられる)
- **タグ削除で参照記事 0 件になった**: 自動削除 (タグマスタから消える)。ユーザー混乱の元になる「孤児タグ」を残さない
- **タグ一覧画面でタグが 0 件**: 空状態メッセージ「まだタグがありません」表示
- **関連記事セクションで記事 A 自身**: 共通 entity 計算時に自身を除外 (自分自身が最上位に出ない)
- **超多 entity 共通記事 (10 entity 以上共通)**: 共通数 sort で上位 5 件取れれば良い、特別処理なし
- **検索結果でハイライト対象が複数フィールドにある**: 各フィールドの最初のヒット箇所のみハイライト (UI 負荷軽減)
- **タグ自動提案で salience 4 以上が 10 件あった**: 上位 5 件のみ提案 (UI スペース制約)、残り 5 件は表示せず

## Requirements

### Functional Requirements

#### 全文検索 (US1)

- **FR-001**: 一覧画面の上部に **検索バー** (`.searchable` 標準 SwiftUI コンポーネント) を配置する
- **FR-002**: 検索クエリは **case-insensitive 部分一致** で以下のフィールドを横断: `Article.title`, `ArticleEnrichment.canonicalTitle`, `ArticleEnrichment.summary`, `ExtractedKnowledge.essence`, `ExtractedKnowledge.summary`, `KeyFact.statement`, `KnowledgeEntity.name`
- **FR-003**: 検索結果の **ソート順** は記事の `savedAt` 降順固定 (relevance score は MVP 未実装)
- **FR-004**: 検索結果の各記事行で、マッチした **フィールド名 + マッチ箇所周辺の文字列** を別途表示し、クエリ文字列を bold 等でハイライト
- **FR-005**: 検索クエリが **空文字列または whitespace のみ** の場合は全記事を返す (現行挙動)
- **FR-006**: 検索結果が **0 件** の場合は「該当する記事がありません」を表示
- **FR-007**: 検索結果は SwiftData `@Query` または `Predicate` で実装し、**1000 記事規模で 200ms 以内** に結果が出る

#### タグ付け (US2)

- **FR-008**: `Tag` (@Model) を新規導入: `id: UUID`, `name: String`(正規化済小文字 trim), `articles: [Article]` (多対多 relationship)
- **FR-009**: `Article` (@Model 既存) に `tags: [Tag]` 多対多 relationship を追加
- **FR-010**: タグの **正規化**: `name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()` で生成。空文字列タグは保存しない
- **FR-011**: Detail 画面に **タグセクション** を追加 (knowledge セクションと bodyOpen ボタンの間): 既存タグはチップ表示 (× で削除)、最後に「+ 追加」入力欄
- **FR-012**: 同 article への **重複タグは追加しない** (no-op)
- **FR-013**: タグ削除で **参照記事 0 件** になったタグは Tag マスタから自動削除
- **FR-014**: 「タグ一覧」画面 (新規) を NavigationStack のサブビューで実装。各タグ名 + 該当記事数を縦リスト表示、saved 日時降順 (記事の最新 saved 時刻)
- **FR-015**: タグをタップすると **タグ絞り込み済み記事一覧画面** に遷移。ここでは検索バーは表示せず、navigation title に「tag: <name>」を表示
- **FR-016**: 一覧画面 (top level) からタグ一覧画面へ遷移する **ナビゲーションボタン** を NavigationStack の trailing toolbar 等に配置

#### エンティティ横断 (US3)

- **FR-017**: Detail 画面の bodyOpen ボタンの **直前** に「関連記事」セクションを追加 (knowledge セクションのすぐ下)
- **FR-018**: 関連記事は **共通 KnowledgeEntity の name** で計算 (case-insensitive trim 一致): 自記事を除く Article のうち、本記事の entities と name が共通する entity 数を score とし、score 降順で上位 5 件を選出
- **FR-019**: 関連記事は **記事行のサブセット表示** (タイトル + 共通 entity 数のチップのみ、サムネ・summary は省略)
- **FR-020**: 関連記事の各行をタップ → 該当記事の **Detail 画面 sheet** が開く (現行のタップ動線と同じ)
- **FR-021**: 関連記事が **0 件**、または本記事の knowledge.status が `.failed`/`.skipped` の場合は **セクション自体を非表示**
- **FR-022**: Detail 画面の knowledge セクションの **entity チップ** をタップ → 「entity 絞り込み済み記事一覧画面」(新規) に遷移、navigation title に「entity: <name>」表示
- **FR-023**: entity 絞り込み画面では現行の record 行 UI を流用、記事は saved 日時降順

#### タグ自動提案 (US4)

- **FR-024**: Detail 画面のタグセクション内、既存手動タグの **下に「自動提案」サブセクション** を配置
- **FR-025**: 提案候補は本記事の `KnowledgeEntity` のうち **salience 4 以上 + 上位 5 件** (salience 降順、同 salience は order 昇順)
- **FR-026**: 提案候補のうち **既に手動タグとして登録済み** (正規化後 name 一致) のものは表示しない
- **FR-027**: 提案チップ (例: 「+ OAuth」) をタップ → 手動タグと同じ扱いで Tag を生成・関連付け、提案チップは即時消失 (手動タグ chip に状態移行)

### Key Entities

#### 新規

- **Tag (@Model)**: `id: UUID` (主キー), `name: String` (正規化済小文字 trim, 一意制約), `articles: [Article]` (多対多 inverse)
  - 一意制約: `name` (`@Attribute(.unique)`)
  - 削除ルール: 多対多のため Article 削除時に Tag は残る (relationship のみ解除)。Tag 側で全 article 0 件になったら手動で context.delete (FR-013)

#### 既存 (拡張)

- **Article (@Model)**: 既存に `tags: [Tag]` (多対多、inverse: `Tag.articles`) を追加
- **KnowledgeEntity (@Model)**: 既存のまま (検索対象 + 関連記事計算 + 自動タグ提案で読み取り使用)
- **ExtractedKnowledge (@Model)**: 既存のまま (essence / summary / keyFacts が検索対象)

#### Transient

- **SearchResult**: 検索結果 1 件分。`article: Article`, `matches: [SearchMatch]`
- **SearchMatch**: 1 フィールドのマッチ情報。`fieldName: String` (e.g., "essence"), `excerpt: String` (マッチ周辺の 50-100 文字), `matchRange: Range<String.Index>` (ハイライト用)
- **RelatedArticle**: 関連記事 1 件分。`article: Article`, `commonEntityCount: Int`, `commonEntities: [String]` (上位 3 件まで chip で表示)

## Success Criteria

### Measurable Outcomes

- **SC-001**: 1000 記事の状態で検索クエリ入力から結果表示まで **200 ms 以内** (SC-007 互換確認)
- **SC-002**: 100 記事の状態でタグ追加 → タグ一覧画面更新まで **0.5 秒以内**
- **SC-003**: タグ追加後、タグ一覧画面で該当タグが表示され、タグをタップすると 0.5 秒以内に絞り込み画面が開く
- **SC-004**: 関連記事計算は Detail 画面表示から **1 秒以内** に下部に出る (sheet 開きと同期 or 後追い表示)
- **SC-005**: 自動タグ提案候補は Detail 画面表示から **0.5 秒以内** に表示される (knowledge.entities が既存データのため)
- **SC-006**: 検索結果のハイライトが **正しいフィールドの正しい文字列** を反映する (10 件のサンプルで確認)
- **SC-007**: タグ正規化 (大文字小文字違い、前後空白) が **全 10 ケース** で正しく同一視される
- **SC-008**: 削除済みタグが **タグ一覧画面に残らない** (FR-013 が機能している)

## Assumptions

- **検索の relevance score は MVP 未実装**: saved 日時降順固定。将来 spec で BM25 風スコアリング検討
- **検索インデックスは無し**: SwiftData Predicate での linear scan。1000 記事までは実用的、それ以上のスケールは将来 spec
- **タグの色 / アイコン / カテゴリ**: MVP 範囲外。シンプルなテキストチップのみ
- **タグの自動付与 (AI による完全自動)**: しない。ユーザー承認 1 タップ (US4) のみ。AI が勝手にタグを増やす挙動は信頼性を損なうため
- **関連記事の上限 5 件、共通 entity 数の同点**: 順位は entity の総 salience 合計が高い順 (二次キー)、それも同点なら savedAt 降順
- **検索クエリのパース**: 単語境界・AND/OR 検索なし。1 つの substring として扱う。将来 spec で「tag:foo」「entity:Apple」のような prefix syntax 追加検討
- **タグ画面の sort**: タグ一覧は articleCount 降順。同 count 内は最新 article の savedAt 降順
- **検索バーが表示されている状態の BottomStatusBar**: 引き続き表示 (spec 005 の挙動継承)
- **タグの最大文字数**: 50 文字 (UI / DB 制約)。超過時は trim
- **タグ名の禁則文字なし**: 何でも入れられる (絵文字・全角・記号)。filter は trim と lowercase のみ
- **検索結果のページネーション**: 無し。1000 件すべてスクロール可能 (LazyVStack)
- **検索とタグ絞り込みの併用**: タグ絞り込み画面では検索バー非表示 (シンプル化)。将来 spec で複合フィルタ検討
- **検索バーのキャンセル動作**: 標準 SwiftUI `.searchable` の挙動に従う (× ボタンで空文字列復帰)

## Dependencies

- **spec 001-004**: Article, ArticleEnrichment, ExtractedKnowledge, KeyFact, KnowledgeEntity の永続化済データを検索対象とする
- **spec 005**: Detail 画面の構造、ProcessingMonitor の進捗表示、live update メカニズムを継承
- **spec 006**: chunked summarization で生成された essence / keyFacts / entities もそのまま検索対象になる (新規 spec 008 では特別な拡張なし)
- **spec 007**: マルチページ追跡で取得された連結 HTML から抽出された body / knowledge も同様に検索対象
