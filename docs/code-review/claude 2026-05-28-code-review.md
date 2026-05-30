# iKnow (KnowledgeTree) コードレビュー報告書

- **対象**: `KnowledgeTree` iOS アプリ本体（アプリ ~24,291 行 / 170 Swift ファイル）+ 拡張機能 + Widget + テスト（~11,498 行 / 61 ファイル）
- **実施日**: 2026-05-28
- **ブランチ**: `main`（commit `c592654` 時点）
- **レビュー観点**: エラーハンドリング / 並行性 / SwiftData・CloudKit / View 層 / AI・Agentic 層 / 拡張機能 / ネットワーク取得層 / データモデル設計 / デザインシステム / テスト / アクセシビリティ / UI・UX

> **凡例（検証ステータス）**
> - ✅ **直接検証** = レビュー者が該当ファイルを読む or `rg` で実コードを確認済み
> - 🔍 **エージェント報告** = サブエージェント調査による報告（行番号は参考値、実装時に再確認推奨）
> - ⚠️ **訂正** = 当初「問題」とされたが検証の結果、問題でなかった項目

---

## 0. エグゼクティブサマリー

全体として **コードの質は高い**。プロトコル指向の DI、AI 呼び出しの `@Generable` 抽象化と Mock、Fallback 経路の徹底、CloudKit 互換のスキーマ設計、堅牢なフェッチ防御（タイムアウト / サイズ上限 / クロール上限）、`TODO`/`FIXME` ゼロ、空 `catch` ゼロ、テスト ~11.5k 行。**致命的欠陥は無い。**

改善余地は次の 3 テーマに集約される:

1. **サイレントな失敗・破壊操作の可視化** — ユーザー操作の保存失敗が無反応、LintEngine の自動マージ/削除が取り消し不能。
2. **"AI が裏でやる" 体験の透明性** — 自動整理が全てサイレントで、信頼の手がかりが散在。
3. **機能追加で増えた重複・負債の整理** — トピック系モデルの 5 分裂、deprecated トークン残留、ローカライズ不整合。

加えて、**今ユーザーに見えている UX バグが 2 件**（プレースホルダ文字列の表示、存在しないタブの案内）。

---

## 1. 訂正事項（誤検出だったもの）

実装時の誤判断を防ぐため、当初「問題」と疑われたが検証で否定された項目を記録する。

### ⚠️ 1.1 Safari 拡張の native messaging `"application.id"` は **バグではない**
- **当初の疑い**: `background.js` が `browser.runtime.sendNativeMessage("application.id", ...)` という汎用プレースホルダを使っており、ネイティブハンドラへルーティングされず「サイレント失敗」する（CRITICAL）。
- **検証結果（✅ 直接検証）**: 誤り。
  - `KnowledgeTreeSafariExtension/Resources/background.js:21,45,57` で `"application.id"` を使用。
  - しかし `SafariWebExtensionHandler.beginRequest`（`:21-27`）が `request?.userInfo?[SFExtensionMessageKey]`（fallback `["message"]`）で正しく受信している。
  - **Safari Web Extension では Chrome と異なり、`sendNativeMessage` の第 1 引数（application identifier）は無視され、containing app の `SafariWebExtensionHandler` へ自動ルーティングされる。** `"application.id"` は Apple 公式テンプレートそのままの正常な値。
  - CLAUDE.md にも「Apple template ベース」「Build SUCCEEDED」とあり整合。
- **結論**: 修正不要。**この項目は対応しないこと。**

---

## 2. 出荷品質に直結する UX バグ（P0）

### 2.1 ライブラリ空状態にプレースホルダ「アプリ名」がそのまま表示される
- **ファイル（✅ 直接検証）**: `KnowledgeTree/Views/EmptyStateView.swift:28`
  ```swift
  Text("Safari で記事を開いて「共有」→ アプリ名 で保存できます")
  ```
- **問題**: プレースホルダの「**アプリ名**」が `iKnow` に置換されないまま画面に表示される。新規ユーザーが最初に見る空状態でこれが出るため第一印象が悪い。
- **提案**: `iKnow` に修正。理想は xcstrings 化（後述 4.3）。

### 2.2 オンボーディングが「存在しないタブ」を案内している
- **ファイル（✅ 直接検証）**: `KnowledgeTree/Views/OnboardingView.swift:42-47`
  ```swift
  body: "「学習タブ」では AI が次に深めるべきカードを 5 つ提案。…"
  ```
- **問題**: spec 056（V3.0）で**学習タブは廃止され、現在は 3 タブ（知識 Clip / ライブラリ / AI チャット）**。初回起動の最後で「探しても無いタブ」を案内しており、最初の体験で混乱を生む。
- **提案**: 4 ページ目を現行導線（知識 Clip の「続きが気になる」→ DeepDiveChatView）に書き換え。
- **遠因**: `OnboardingView` / `EmptyStateView` がハードコード日本語（xcstrings 未使用）。前回指摘のローカライズ不整合が実バグとして表出した例。

---

## 3. コード品質（P1）

### 3.1 ユーザー操作の保存失敗がサイレント（`try?` の濫用）
- **検証ステータス**: 🔍 エージェント報告（件数）+ ✅ 一部直接確認
- **概要**: アプリ全体で `try?` が約 180 箇所。うち約 39 が永続化（save/upsert）に対するもので、特に**ユーザーが「成功した」と認識する操作**が黙って失敗し得る。

| ファイル:行 | 操作 | 問題 |
|---|---|---|
| `Views/SettingsView.swift:305` | チャット履歴全削除 | alert で確定 → 失敗しても無反応、履歴が復活 |
| `Views/ChatHistorySidebar.swift:99` | セッション個別削除 | swipe 削除が黙って失敗 |
| `Views/ArticleDetailView.swift:243,248` | タグ追加 / 削除 | UI 上は付いて見えるが保存されない |
| `Views/SavedAnswerDetailView.swift:40,106,126` | ピン / 既読 / 削除 | 成功表示のまま失敗 |
| `Views/ConceptPageDetailView.swift:53` | フォロー切替 | トグルは動くが保存されない |

- **裏処理の `try?`**（backfill / `regenerateAllStale`）は "calm UX" 原則として合理的。問題は**ユーザーの能動操作**。
- **提案**: 能動操作はエラーを surface（最低限ログ、できれば失敗時 toast/alert）。

### 3.2 重い同期計算がメインアクター上で実行される
- **検証ステータス**: ✅ 直接検証（`rg`）
- **詳細**:
  - `Services/EmbeddingService.swift:17` が `@MainActor`、内部で `vDSP_dotpr` / `vDSP_svesq` 等を同期実行（`:52,82,87`）。
  - `Services/TopicClusteringService.swift:23` が `@MainActor`、`kmeans`（`:197`）が vDSP で同期反復計算。
- **補足（重要）**: AI 呼び出し自体は `LanguageModelSessionProtocol`（`:196` `Sendable`）の `async` メソッドで、`await` により suspend するため**メインスレッドを塞がない**。問題は **K-means の反復計算など suspension point の無い同期処理**で、記事数が増えると起動時クラスタリングでメインスレッドが数百 ms〜秒単位で固まり得る。
- **提案**: `kmeans` は純粋関数なので `nonisolated static` のまま `Task.detached` か専用 `actor` で実行し、結果だけ `@MainActor` に戻す。`BodyExtractionService` が既に `Task.detached(.utility)` でやっている良い前例あり。

### 3.3 起動時 backfill が全て直列 await
- **検証ステータス**: ✅ 直接検証
- **ファイル**: `KnowledgeTreeApp.swift:389-427`
- **詳細**: bootstrap 末尾で enrichment → body → knowledge → tag cleanup → auto-tag backfill → category backfill → digest → embedding → topic → concept backfill → resynthesize を**直列 await**（9+ 段）。互いに独立な backfill（embedding と topic clustering 等）も順番待ちになり cold start が長引く。
- **提案**: 依存 chain（enrichment→body→knowledge）は直列維持、独立処理は `async let` / `TaskGroup` で並列化。または非 critical な backfill を初回描画後に遅延。

### 3.4 bootstrap が God-object 化 + ServiceContainer が optional の袋
- **検証ステータス**: ✅ 直接検証
- **ファイル**: `KnowledgeTreeApp.swift:154-428`（`bootstrap()` ~275 行で ~30 サービスを依存順に手動配線）、`Services/ServiceContainer.swift`（35 プロパティ全て optional）
- **問題**: spec を 1 つ足すたびに「optional 追加 → bootstrap で生成 → 全 consumer で `guard let`」が必要。配線順が暗黙の依存になっており壊れやすい。View 側に `guard let services.X else { return }` のボイラープレートが 14+ 箇所。
- **提案**: サービス生成を `ServiceContainer` 内の factory（または composition root 構造体）に移し、bootstrap を「生成」と「backfill 実行」に分離。確定済サービスは non-optional + lazy 化で View 側 guard を削減。

### 3.5 Widget ディープリンク解決にデッドコード
- **検証ステータス**: ✅ 直接検証
- **ファイル**: `KnowledgeTree/Views/KnowledgeClipView.swift:159-172`（`loadCardFromDeepLink`）
  ```swift
  if let modelContext = try? ModelContext(.init(for: ConceptPage.self)) {
      _ = modelContext  // can't easily access global context here
  }
  ```
- **問題**: 何もしない `ModelContext` 生成 +「アクセスできない」自認コメント。最終的に `surfaceAllCards()` の線形探索でしのいでおり、書きかけのまま放置された痕跡。
- **提案**: デッドコード削除 + Widget からの起動導線（`iknow://learning/card/{uuid}`）が意図通り動くか実機確認。

---

## 4. View 層 / ローカライズ（P2）

### 4.1 `@Query` で全件取得 → view body で in-memory filter
- **検証ステータス**: ✅ 一部直接検証 + 🔍 エージェント報告
- **代表例**:
  - `Views/InterestingNextSection.swift:26`（`categoryStats`）— 全記事 × 全 `CategorySeed` を**毎 body 評価で O(n×m) 再計算**、メモ化なし（✅ 直接検証）。
  - `Views/ChatTabView.swift` — 全 `ChatMessage` 取得 → session ID で in-memory filter。
  - `Views/AIBrainStatsRow.swift` — 記事 / entity / keyFact を 3 回フルスキャン + 毎回 Set 重複排除。
- **提案**: 重い集計は `@State` + `.onChange(of:)` でメモ化、またはサービス層へ。

### 4.2 アクセシビリティ（おおむね良好、2 点改善余地）
- **検証ステータス**: 🔍 エージェント報告
- **良い点**: `accessibilityIdentifier` 200 箇所、`accessibilityLabel` 31 箇所、Reduce Motion は `DS.Animation.ifMotionAllowed()` で全アニメをゲート（✅ `DesignSystem.swift:139` で直接確認）。Dynamic Type はセマンティックスタイル ~176 箇所で 97% 準拠。
- **改善 1（Reduce Transparency 未対応）**: `accessibilityReduceTransparency` のチェックが 0 件。`.regularMaterial` を多用（DeepDiveChat の入力バー / アクションバー / トースト等）しており、半透明オフ設定時に視認性低下。不透明背景へのフォールバックを。
- **改善 2（hero 固定フォント）**: `.font(.system(size: 96/48/32))` が 5 箇所（OnboardingView / EmptyStateView / CategoryGraphView / ChatInputField / RecentActivityCards）。装飾用途で致命的ではないが `AX5` での折返し確認推奨。

### 4.3 xcstrings キーとハードコード日本語の混在
- **検証ステータス**: 🔍 エージェント報告 + ✅ 一部直接確認
- **概要**: Japanese-first 方針だが 20 ファイルに 50+ のハードコード日本語リテラルがあり、xcstrings キーと混在（`SettingsView` / `RecentActivityCards` / `DeepDiveChatView` / `OnboardingView` / `EmptyStateView` 等）。英語展開時に取りこぼし、保守の一貫性も損なう。2.1 / 2.2 の実バグもこれが遠因。
- **提案**: 1 パスでキー化統一。

---

## 5. AI / Agentic 層（P1）

### 5.1 LintEngine の破壊的自動操作に「取り消し」も「ステージング」も無い ★最重要
- **検証ステータス**: 🔍 エージェント報告（行番号は要再確認）
- **ファイル**: `Services/LintEngine.swift`
- **詳細**: 週 1 BGTask で**ユーザー確認なし**に:
  - ConceptPage を **Levenshtein 距離 ≤ 2 で自動マージ**（`:148` 付近）→「Design Pattern」↔「Design Patterns」誤マージの恐れ。
  - 60 日未参照の ConceptPage を**物理削除**（`context.delete()`、ソフト削除なし）。
  - `LintLog` は 200 字までの before/after を残すのみ。**フルスナップショット無し = 復元不可。**
- **リスク**: ユーザーが育てた `userUnderstanding`（理解度）や注釈ごと消える可能性。プロダクト哲学（「AI が裏で勝手に整理」）の核心ゆえ、サイレントなデータ破壊が最大リスク。
- **提案**（いずれか）:
  - マージ / 削除を即実行せず `ConflictProposal`（`autoResolved=false`）にステージング → 知識 Clip の「確認が必要」セクションで事後レビュー（spec 058 に同種の仕組みあり）。
  - 30 日のソフト削除（`isDeleted` フラグ）+「最近削除した項目」。
  - マージ閾値を Levenshtein ≤ 1 に厳格化、または embedding 類似度併用。

### 5.2 Foundation Models のトークン管理が truncation 頼み
- **検証ステータス**: 🔍 エージェント報告
- **ファイル**: `Services/ChatService.swift`（`buildPrompt` ~`:509`）
- **詳細**: system + multi-turn 5 件 + 記事 5 件（essence + KeyFact）+ 関連エンティティを連結。各要素は個別に文字数 cap されるが**合計のランタイムトークン推定が無い**。Foundation Models の ~4096 トークン上限を multi-turn + 長文記事 5 件で超過する恐れ（`ConceptSynthesisService` 側にトークン超過の履歴コメントあり）。
- **提案**: `text.count / 3` 程度の概算でプロンプト合計を見積もり、超過時は topK を 5→3 に動的縮小。
- **良い点**: ハルシネーション対策は堅牢（retrieval 結果外の article ID を citation から filter、空 citation は「分かりません」に上書き、UUID 本文混入を `stripUUIDsFromBody` で除去）。Agentic loop も `maxClarificationRounds = 3` で発散防止。

---

## 6. セキュリティ / プライバシー（P2〜P3）

### 6.1 保存 URL からトラッキングパラメータが除去されていない
- **検証ステータス**: 🔍 エージェント報告
- **ファイル**: `Services/URLNormalization.swift:57-69`
- **詳細**: `utm_*` / `fbclid` / `gclid` を**重複検出用にだけ**除去。実保存される `article.url` には付いたまま。
- **影響**: (1) プライバシー漏れ（共有時に utm が残る）、(2) 重複検出漏れ（同記事を別経路で 2 件保存）。
- **提案**: 正規化を「保存時」にも適用 → プライバシーと重複排除を同時に改善。**費用対効果が高い。**

### 6.2 フェッチ時の private-IP / リダイレクト検証なし（SSRF 観点）
- **検証ステータス**: 🔍 エージェント報告
- **ファイル**: `Services/ArticleEnrichmentService.swift`, `Services/MultiPageCrawler.swift`
- **詳細**: リダイレクトを既定追従し、内部 IP（`127.0.0.1` / `192.168.*` / `169.254.169.254` 等）をブロックしない。個人利用 + ユーザー入力 URL ゆえ実リスクは低めだが、悪意ある共有リンクが内部 IP にリダイレクトする余地。
- **良い点**: タイムアウト 30s、レスポンス 5MB 上限、5 ページ cap、1 秒レート制限、4 段 charset fallback など**他の防御は優秀**。
- **提案**: private-IP ガード + リダイレクト上限（5）を追加。

### 6.3 Safari 拡張の権限が `*://*/*`（全サイト）
- **検証ステータス**: 🔍 エージェント報告 + ✅ manifest 確認
- **詳細**: content.js が銀行 / メール含む全サイトに注入。実害はローカル保存のみだが App Store 審査での説明要求 + プライバシー観点。native handler 失敗時に `null` 返却で「自動保存 OFF」誤認するフォールバックあり。
- **提案**: SettingsView にプライバシー方針明記 + 失敗時は保守的デフォルト（OFF）を明示返却。

### 6.4 PDF のサイズ / ロック検証
- **検証ステータス**: 🔍 エージェント報告
- **ファイル**: `Services/PDFFetcher.swift:30` 付近
- **詳細**: `PDFDocument(data:)` がサイズガード前にパース。`isLocked`（パスワード保護）チェックなし。nil 返却でグレースフルに失敗するため軽微。
- **提案**: init 前に `data.count` 上限チェック + `isLocked` 検出時はログ + fail-fast。

---

## 7. データモデル設計（P2）

### 7.1 「トピック / エンティティ」を表すモデルが 5 つに分裂
- **検証ステータス**: 🔍 エージェント報告
- **詳細**: `Tag` / `ConceptPage` / `GraphNode` / `UserTopic` / `KnowledgeEntity` がいずれも「人物・モノ・概念」を別メカニズムで表現。**`categoryRaw` 文字列が 4 モデルに重複**（`Tag.categoryRaw` / `ConceptPage.categoryRaw` / `GraphNode.categoryRaw` / `GraphEdge.categoryRaw`）。`CategorySeed` のカテゴリ名変更時に 4 箇所をコードで手動同期する必要があり、DB レベルの整合性保証なし。
- **提案**: 軽量 `Category` @Model（name を SSOT）に集約、または「4 モデルが同一 `CategorySeed` を使う」ことを検証する単体テスト追加。知識グラフが断片化する前に。

### 7.2 stringly-typed ステータスに enum アクセサが無いモデルが 2 つ
- **検証ステータス**: 🔍 エージェント報告
- **詳細**: 多くの `*Raw` は enum getter/setter 拡張で型安全化されているが、**`ChatMessage.role`（`ChatMessage.swift:20` 付近）と `GraphNode.entityType`（`GraphNode.swift:27` 付近）だけ素の String** で不正値が黙って永続化され得る。
- **提案**: 各 1 行の computed property（`var roleEnum: ChatMessageRole { .init(rawValue: role) ?? .user }` 等）を追加。

### 7.3 弱参照 `[UUID]` のダングリング
- **検証ステータス**: 🔍 エージェント報告
- **詳細**: `ConceptPage.relatedConceptIDs` / `SavedAnswer.relatedConceptIDs` / `ChatMessage.citedArticleIDs` などは参照整合性をバイパス。merge / delete 時に dangling し得る（merge hook は存在するが SavedAnswer 側の lifecycle テストは薄い）。意図的な設計（履歴保存）だが、View 側で「UUID 解決失敗時はグレースフルに非表示」を徹底すべき。
- **良い点**: 外部ストレージ（`@Attribute(.externalStorage)`）の使い分けは適切（embedding 系は external、短い文字列は inline）。deleteRule（cascade / nullify）もおおむね妥当。

### 7.4 マイグレーション戦略が無い（CloudKit 本番 + 20 @Model）
- **検証ステータス**: ✅ 直接検証（`SharedSchema.swift:22-44`）
- **詳細**: 20 @Model が登録され CloudKit 本番にユーザーデータが乗っているが、`VersionedSchema` / `SchemaMigrationPlan` が無く lightweight inferred migration 任せ。現在の追加フィールドは全て optional + default で安全だが、将来の型変更 / 非 optional 化 / リネームで起動時クラッシュ or データ消失の恐れ。
- **提案**: 現スキーマを `SchemaV1` として `VersionedSchema` 化し `SchemaMigrationPlan` の骨組みを今のうちに導入（中身は空でよい）。25 @Model を超える前が安全な導入タイミング。

---

## 8. 拡張機能 / Widget（P2）

### 8.1 Share Extension は URL しか受け取れない
- **検証ステータス**: ✅ 直接検証
- **ファイル**: `KnowledgeTreeShareExtension/ShareViewController.swift:55,65`（`UTType.url` のみ）
- **詳細**: Files から PDF ファイルや選択テキストを共有すると無反応。spec 034 の PDF 対応は「PDF の URL」経由で、共有された PDF ファイル本体ではない。
- **提案**: `UTType.pdf` / `UTType.plainText` フォールバック追加（拡張はメモリ制約が厳しいので、ファイルは App Group に退避して本体アプリで処理）。
- **良い点**: Share Extension が本文抽出 / AI 抽出をプロセス内で行っていないことを確認済（jetsam クラッシュ耐性は良好）。SharedSchema / App Group は 4 ターゲットで一致。

### 8.2 Widget
- **検証ステータス**: 🔍 エージェント報告
- **詳細**: 読み取り専用コンテナ + defensive snapshot + 15 分リフレッシュで堅牢。AI を呼ばない。問題は 5.5 のディープリンク解決のデッドコード（→ 3.5）と整合確認のみ。

---

## 9. テスト / 品質（P2）

### 9.1 SwiftData store 層が未テスト（破壊的操作を含むのに）
- **検証ステータス**: 🔍 エージェント報告
- **詳細**: 68 サービス中 23 が未テスト（カバー率 66%）。ロジック系（LintEngine 10 件、Clustering、Graph）は手厚いが、**`TagStore` / `ConceptPageStore` / `GraphNodeStore` / `ArticleStore` の CRUD・rename・merge・delete が未テスト**。5.1 の破壊操作の実体がノーガード。
- **提案**: 最低限 merge / delete の単体テスト追加。
- **テスト框组**: Swift Testing（`@Test`/`#expect`）中心、~474 test func。

### 9.2 UI テストの flaky 放置
- **検証ステータス**: 🔍 エージェント報告 + ✅ XCTSkip 確認
- **詳細**: `AIBrainTabUITests`（5）+ `SaveArticleUITests`（1）が「pre-existing flaky」、`UnderstandingTabUITests` に空状態起因の `XCTSkip` 2 件。Simulator cold-launch timing 起因で CI シグナルを劣化させる。
- **提案**: 起動待機の安定化 or 明示 skip 条件の整理。

---

## 10. UI/UX 改善（バグ以外）

### 良い点（土台が強い）
- **single accent（Action Blue）+ parchment + adaptive Dark Mode**（`Color.adaptive`、`DesignSystem.swift:181`）、spacing / radius スケール、`ifMotionAllowed()` による Reduce Motion ゲート — デザインシステムの設計思想は一貫し質が高い。

### 改善提案

| # | 項目 | 内容 |
|---|---|---|
| 1 | **「AI が最近やったこと」統合フィード** ★ | 本質は「AI が裏で勝手に整理」。だが auto-tag / auto-category / conflict 自動解決 / lint 自動マージ・削除 / concept 合成 が全部サイレントで、信頼の手がかりが `LintLog`・`ConflictHistoryDisclosure` 等に散在。**1 つの「最近 AI がやったこと」タイムライン**（マージした / 削除した / タグ付けた）を設けると、"勝手にやる" 安心感と透明性が両立。哲学に最も沿う UX 強化 |
| 2 | **初回 backfill 中の進捗表示** | 初回は大量 backfill 中に概念ページ / ダイジェストが空 → ユーザーが「何も起きない」と感じる。`ProcessingMonitor` の Phase を既に持つので、知識 Clip に「AI が整理中…（N 件）」chip を接続するだけ |
| 3 | **Reduce Transparency 対応** | `.regularMaterial` 多用箇所を `accessibilityReduceTransparency` で不透明背景フォールバック（→ 4.2） |
| 4 | **保存成功フィードバックの一貫性** | Share Extension / FAB / Safari 自動保存で「保存できた」体験を統一（軽い haptic + 「保存しました」）。haptics は現状 DeepDiveChatView / AnswerActionsMenu のみ |
| 5 | **空状態の充実度の差** | AI チャットは suggested prompts があり良い。ライブラリ / 知識 Clip 空状態は弱い → 「まず 1 本保存」CTA を |
| 6 | **DeepDiveChat ローディング 2 段問題** | 初期化「会話を準備しています…」と送信中「考えています…」が別表現。統一すると洗練 |
| 7 | **Settings 発見性** | アバタータップ（`AvatarMenu`）からの sheet のみ（Apple News パターン）。初見では気づきにくいので、空状態 / オンボーディングで一度だけ場所を示唆 |

---

## 11. 統合優先順位（全観点）

最小工数 × 高効果の順:

| 優先 | 項目 | 該当節 | 工数 |
|---|---|---|---|
| **1** | UX バグ A/B（「アプリ名」表示・存在しない学習タブ案内） | 2.1, 2.2 | 数行 |
| **2** | 保存 URL のトラッキングパラメータ除去（プライバシー + 重複排除） | 6.1 | 小 |
| **3** | ユーザー操作の `try?` をエラー surface に（削除 / タグ / ピン） | 3.1 | 小〜中 |
| **4** | enum アクセサ 2 件追加（ChatMessage.role / GraphNode.entityType） | 7.2 | 小 |
| **5** | LintEngine 破壊操作のステージング化 or ソフト削除 | 5.1 | 中 |
| **6** | K-means / embedding をメインスレッドから退避 | 3.2 | 中 |
| **7** | store 層テスト追加（merge / delete） | 9.1 | 中 |
| **8** | 「AI が最近やったこと」統合フィード | 10-1 | 中〜大（価値大） |
| **9** | ローカライズ統一（xcstrings 化 1 パス） | 4.3 | 中 |
| 将来 | Category @Model 集約 / VersionedSchema 骨組み / private-IP ガード / 起動 backfill 並列化 / Share Extension PDF・テキスト対応 | 7.1, 7.4, 6.2, 3.3, 8.1 | 大 |

---

## 付録 A. 検証に使った主な直接確認

| 対象 | 方法 |
|---|---|
| `KnowledgeTreeApp.swift`（bootstrap 全体） | Read |
| `Services/ServiceContainer.swift` | Read |
| `SharedSchema.swift` | Read |
| `Views/KnowledgeClipView.swift` | Read |
| `Views/OnboardingView.swift` | Read |
| `Views/DeepDiveChatView.swift` | Read |
| `Views/EmptyStateView.swift` | Read |
| `DesignSystem.swift` | Read |
| `DESIGN.md`（先頭 90 行） | Read |
| EmbeddingService / TopicClusteringService の `@MainActor` + vDSP | `rg` |
| InterestingNextSection の O(n×m) | `rg` |
| Safari `background.js` + `SafariWebExtensionHandler`（誤検出訂正） | `rg` |
| ShareViewController の UTType | `rg` |
| 「アプリ名」リテラル / 学習タブ参照 | `rg` |

## 付録 B. 規模メトリクス

- アプリ本体: 24,291 行 / 170 Swift ファイル（Views 76 / Services 68 / Models 20 / その他 6）
- テスト: 11,498 行 / 61 ファイル（~474 test func、Swift Testing 中心）
- 最大ファイル: `ChatService.swift`（718）/ `ConceptSynthesisService.swift`（550）/ `ArticleDetailView.swift`（534）/ `KnowledgeExtractionService.swift`（484）

---

*このレビューは静的解析（コード読解 + ripgrep）に基づく。実機での動作検証・パフォーマンス計測（Instruments）は別途必要。行番号は記載時点のもので、実装時に再確認すること。*
