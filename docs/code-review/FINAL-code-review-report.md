# iKnow (KnowledgeTree) Code Review FINAL Report

**作成日**: 2026-05-30
**対象**: `main` ブランチ (commit `c592654` 時点)
**対象規模**: アプリ本体 ~24,291 行 / 170 Swift + 拡張 3 ターゲット + Widget + テスト ~11,498 行 / 61 ファイル
**作成方法**: 3 つの独立 reviewer report (Claude / OpenAI / Google) を `final code_review_rubric.md` で採点し、評価者 3 名 (Claude / OpenAI / Gemini) の合議結果から「採用可」とされた指摘のみ統合。**P0 (5 件) と一部 P1/P2 は本評価で `rg` / Read による直接照合済**。✅ マーカー付きは直接 verified、🔍 マーカー付き (§8.3 一覧) は採用 reviewer のエージェント報告で **実装前に file:line 再確認が必要**

---

## 0. メタ情報

### 0.1 入力 reviewer の評価結果

| Reviewer | Claude 評価 | OpenAI 評価 | Gemini 評価 | 合議総合 | 採用方針 |
|---|---:|---:|---:|---|---|
| **Claude** | 91/100 Excellent | 84/100 Strong | 94/100 Excellent | **採用 (主)** | ベースライン採用。spec 系譜と calm UX 理解が最強、誤検出訂正セクションあり |
| **OpenAI** | 78/100 Useful | 80/100 Useful | 79/100 Useful | **条件付き採用 (補)** | P0-1 (Safari `application.id`) は Apple 仕様誤認のため除外、他は全採用。UI/UX Roadmap が秀逸 |
| **Google** | 42/100 Unreliable | 43/100 Unreliable | 40/100 Unreliable | **再検証キュー (4 件のみ抽出)** | Report 全体は採用不可。ただし他 reviewer が捉えていない 4 件は実コード確認で採用 |

### 0.2 採用ルール

- **P0**: 3 reviewer 中 2 名以上が同意、または 1 名指摘 + 実コードで confirm された出荷品質バグ
- **P1**: 同上、または 1 名指摘 + 実コード confirm された信頼性 / 保守性問題
- **P2**: 1 名以上が指摘 + 実コード confirm された設計 / 拡張性改善
- **棄却**: 実コード照合で誤検出、または既存設計判断 (spec / CLAUDE.md) と矛盾するもの

### 0.3 凡例

- ✅ **直接 verified** — 本評価で `rg` または Read で実コードを照合
- 🔍 **エージェント報告** — 採用 reviewer の subagent 報告、実装時に再確認推奨
- ⚠️ **訂正** — 当初指摘されたが検証で否定

---

## 1. エグゼクティブサマリー

**全体評価**: コード品質は高い水準。プロトコル指向 DI、`@Generable` AI 抽象化、Fallback 経路の徹底、CloudKit 互換スキーマ、堅牢なフェッチ防御 (timeout / size cap / crawl limit)、`TODO`/`FIXME` ゼロ、空 `catch` ゼロ、テスト ~11.5k 行 / 334 ケース。**致命的欠陥は無い**。

**改善は 4 テーマに集約**:

1. **V3 移行 (spec 056) の取りこぼし** — Onboarding / UI tests / Settings に旧タブ参照や placeholder が残置 (P0 大半)
2. **サイレント失敗の可視化** — ユーザー操作の `try?` が反応なしで成功表示、Safari/extension のエラー埋没、Chat 引用リンクが反応するのに遷移しない
3. **AI 自動操作の透明性とロールバック** — LintEngine が確認なしで ConceptPage を物理削除、stale 答えが reset 漏れで毎週反復再処理される (bounded、§2.2 参照)、token 上限 truncation 頼み
4. **機能追加で増えた重複・負債** — トピック系 @Model 5 分裂、deprecated トークン残留、ローカライズ 127 empty key、startup orchestration の God-object 化

**今ユーザーに見えている UX バグ**: 4 件 (アプリ名 placeholder / 学習タブ案内 / 重複 iCloud Section / Chat 引用リンク無反応)

---

## 2. 訂正事項 (採用しない指摘)

実装時の無駄を防ぐため、当初「問題」と疑われたが検証で否定された項目を記録する。

### ⚠️ 2.1 Safari 拡張の `"application.id"` は **バグではない** (OpenAI P0-1 棄却)

- **当初の疑い (OpenAI)**: `background.js:21,45,57` が `browser.runtime.sendNativeMessage("application.id", ...)` という汎用 placeholder を使っており、native handler へルーティングされず「manual save and auto-save can fail at the most important ingestion path」(P0)
- **検証結果 (✅ 直接 verified)**:
  - `KnowledgeTreeSafariExtension/Resources/background.js:21,45,57` で `"application.id"` を使用は事実
  - しかし `SafariWebExtensionHandler.swift:21-27` (`beginRequest`) が `request?.userInfo?[SFExtensionMessageKey]` (fallback `["message"]`) で正しく受信
  - **Safari Web Extension では Chrome と異なり、`sendNativeMessage` の第 1 引数 (application identifier) は無視され、containing app の `SafariWebExtensionHandler` へ自動ルーティングされる** ([Apple 公式ドキュメント](https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension))
  - CLAUDE.md にも「Apple template ベース」「Build SUCCEEDED」と記載、実機検証も spec 020 で部分済
- **結論**: **修正不要。この項目は対応しないこと**。OpenAI 版を改善計画に取り込む際は P0-1 を必ず削除する

### ⚠️ 2.2 LintEngine の SavedAnswer 再生成が「API コスト暴騰」は **誇張** (Google 2.3 棄却)

- **当初の疑い (Google)**: `LintEngine.stepRefreshStaleSavedAnswers` が `isStale` を reset しないため「次回 Lint で同じ回答が再判定 → AI API リクエストが無限に走り続け、利用コストが暴騰する危険性」
- **検証結果 (✅ 直接 verified)**:
  - `LintEngine.swift:323-360` で `maxRefreshPerRun = 3` の cap が掛かっている (週 1 BGTask × 3 件 = 週最大 3 件)
  - コメント `// 旧 SavedAnswer は isStale=true のまま archive (履歴保持)` で archive は意図的設計 (spec 058 Phase C)
  - 「再生成」は新 ChatSession 経由で `captureIfWorthyOrReplaceStale` を呼び、新 SavedAnswer が auto-save される (古は履歴保護で残る)
- **真の問題**: 同じ stale 答えが毎週 fetch 対象になり 3 件 cap 内で reprocess され続けることは事実だが「暴騰」ではない。**P2 で「LintEngine が refresh した SavedAnswer の isStale=false reset 漏れ」として再検討すべき** (本 report の 5.3 で扱う)

### ⚠️ 2.3 Article のリレーション cascade 欠落は **誤検出** (Google 2.2 棄却 + 初版 P2-1 撤回)

- **当初の疑い (Google + 本 report 初版 P2-1)**: `Article.swift:64,68` の `conflictsAsNew` / `conflictsAsOld` が `@Relationship(inverse: ...)` のみで `.cascade` 未指定 → Article 削除時に ConflictProposal が孤児データとして残置、ストレージ圧迫
- **検証結果 (✅ 直接 verified)**:
  - `Models/ConflictProposal.swift:18,21` で既に `@Relationship(deleteRule: .nullify) var newArticle: Article?` / `var oldArticle: Article?` 完備
  - Article 削除時、ConflictProposal の newArticle/oldArticle は **nil 化されるだけで record 自体は保持** される
  - 同 `:79-81` のコメント `// spec 058: AI 自動採用 (両方残す、UI 通知なし、ArticleDetailView「過去の見解」で閲覧可能)` から、ConflictProposal の保持は **spec 037 + spec 058 の意図的な「過去の見解」履歴保存設計**
- **結論**: 「cascade 欠落バグ」ではない。「過去の見解」を残す前提なので nullify が正解。**修正不要**
- **将来検討余地** (P3 相当): ConflictProposal の超長期保持ポリシー (TTL or 上限件数) は別途 product decision として残す価値あり (本 report の主要 backlog からは除外)

---

## 3. P0: 出荷品質に直結するバグ (5 件)

### P0-1: ライブラリ空状態に placeholder「アプリ名」が表示される

| 項目 | 内容 |
|---|---|
| 出典 | Claude 2.1 (独自指摘) |
| 検証 | ✅ 直接 verified |
| ファイル | `KnowledgeTree/Views/EmptyStateView.swift:28` |
| コード | `Text("Safari で記事を開いて「共有」→ アプリ名 で保存できます")` |
| 影響 | 新規ユーザーが最初に見る空状態に置換漏れの placeholder が出現。第一印象を損なう |
| 提案 | `アプリ名` → `iKnow` に置換 (即時) + xcstrings 化 (中期、P1-4.3 と統合) |
| 検証案 | UI test で空状態 screenshot に「アプリ名」リテラルが含まれないことを assert |

### P0-2: Onboarding が「存在しない学習タブ」を案内

| 項目 | 内容 |
|---|---|
| 出典 | Claude 2.2 + OpenAI P0-5 (両者一致) |
| 検証 | ✅ 直接 verified |
| ファイル | `KnowledgeTree/Views/OnboardingView.swift:45` |
| コード | `body: "「学習タブ」では AI が次に深めるべきカードを 5 つ提案。…"` |
| 影響 | spec 056 (V3.0) で**学習タブは廃止され現在 3 タブ (知識 Clip / ライブラリ / AI チャット)**。初回起動最終ページで存在しないタブを案内し新規ユーザーが混乱 |
| 提案 | 4 ページ目を現行導線 (知識 Clip → 「続きが気になる」セクション → DeepDiveChatView) に書き換え |
| 検証案 | UI test で onboarding 全ページのコピーに `"学習タブ"` / `"AIブレイン"` 等の廃止タブ名が含まれないことを assert |

### P0-3: Settings に iCloud Section が 2 つ (矛盾)

| 項目 | 内容 |
|---|---|
| 出典 | OpenAI P0-3 (独自指摘) |
| 検証 | ✅ 直接 verified |
| ファイル | `KnowledgeTree/Views/SettingsView.swift:54` (動作する toggle) + `:198` (古い「近日対応」placeholder) |
| 影響 | ユーザーは上部で iCloud sync を有効化できるが、下部で「近日対応 — 複数の端末で同じ知識ベースを共有」「現在は全てこの端末内に保存されます。iCloud 同期は次のバージョンで予定しています」と相反する文言を見せられる。信頼を損ない、サポート問い合わせ誘発 |
| 提案 | 旧 placeholder Section (`:198-216`) を削除。spec 050 の遺物 (spec 051 で実装済) |
| 検証案 | UI test で `settings.icloud.placeholder` accessibility identifier が存在しないこと、 `settings.icloud.restartBanner` が条件付きで surface することを assert |

### P0-4: Chat 引用リンクが「反応するように見えて遷移しない」

| 項目 | 内容 |
|---|---|
| 出典 | OpenAI P0-2 (独自指摘) |
| 検証 | ✅ 直接 verified |
| ファイル | プロンプト: `Services/ChatService.swift:517` / ハンドラ: `Views/ChatMessageRow.swift:60-67` |
| コード | ```swift<br>.environment(\.openURL, OpenURLAction { url in<br>    if let id = Self.extractArticleID(from: url),<br>       let article = allArticles.first(where: { $0.id == id }) {<br>        _ = article  // ← discard!<br>        return .handled<br>    }<br>    return .systemAction<br>})<br>``` |
| 影響 | AI が prompt 指示通り `[title](article-id://UUID)` 形式で生成 → ユーザーは link が tappable に見える → tap しても何も起きない (`.handled` で systemAction を抑制、しかし navigation 未配線)。**期待違反は信頼に直結** |
| 提案 | OpenAI 案そのまま: `ChatTabView` 側で article lookup + navigation state を保持し、`onArticleLinkTap(UUID)` callback を `ChatMessageRow` に注入。`NavigationPath` 経由で `ArticleDetailView(article:embedNavigationStack:false)` を push |
| 検証案 | UI test で AI 答えに UUID link が含まれる ChatMessage を seed → link tap → `ArticleDetailView` 表示を assert |

### P0-5: UI tests が削除済タブを参照 (CI シグナル劣化)

| 項目 | 内容 |
|---|---|
| 出典 | OpenAI P0-4 (詳細) + Claude 9.2 (薄い言及) |
| 検証 | ✅ 直接 verified |
| ファイル | `KnowledgeTreeUITests/UnderstandingTabUITests.swift:25` で `tab.learning` を期待 / `KnowledgeTreeUITests/AIBrainTabUITests.swift:43` で `tab.aibrain` を期待 / 現行は `tab.knowledgeClip` (`KnowledgeTreeApp.swift:91`) / `tab.library` (`:98`) / `tab.chat` (`:105`) |
| 影響 | UI test は出荷製品を検証しない状態。**✅ 直接 verified**: `UnderstandingTabUITests.swift:55,79` に XCTSkip 2 件 (空状態 defensive guard)、さらに **`AIBrainTabUITests.swift` の 6 funcs と `UnderstandingTabUITests.swift` の 3 funcs が削除済タブ識別子 (`tab.aibrain` / `tab.learning`) を期待しており runtime fail する状態**。`SaveArticleUITests.swift` は 1 func のみで Claude reviewer から「pre-existing flaky」と言及 (XCTSkip は無し) |
| 提案 | OpenAI 案をベースに V3 UI test 一式へ刷新:<br>1. Knowledge Clip タブが load される<br>2. Add Article sheet が開く<br>3. Library タブが tag list へ navigate<br>4. Chat タブが sidebar を開き empty-state 表示<br>5. Settings が Avatar menu から開く |
| 検証案 | 旧 UI test ファイル削除 + 新 V3 UI test を CI green が前提に追加 |

---

## 4. P1: 信頼性 / 保守性問題 (10 件)

### P1-1: URL normalization が保存パスに未適用 (プライバシー + 重複)

| 項目 | 内容 |
|---|---|
| 出典 | OpenAI P1-1 (詳細) + Claude 6.1 (両者一致) |
| 検証 | ✅ 直接 verified |
| ファイル | normalizer: `Services/URLNormalization.swift:21,57-69` (utm_*/fbclid/gclid を**重複検出用のみ**除去) / save path: `Services/ArticleSavingService.swift:49` (raw `absoluteString`) / `AppIntents/ArticleSavingActor.swift:51` (raw trimmed) |
| 影響 | (1) **プライバシー漏れ**: 共有時に utm が残る、 (2) **重複検出漏れ**: tracking param / fragment / trailing slash / `www.` 違いで同記事を 2 件保存 |
| 提案 | `Article.normalizedURL` 追加 (lightweight migration) → `exists(url:)` / `save` で normalize 経由。元 URL は表示・open 用に保持。既存重複は lint step で backfill 解消 |
| 検証案 | `URLNormalizationTests` 拡張 (utm/fbclid 等 + fragment + trailing slash + www. + scheme casing)。ArticleSavingService.exists(url:) の重複判定が normalize 後で動くことを test |

### P1-2: Settings の iCloud toggle が「バウンスする」(UX 体感バグ)

| 項目 | 内容 |
|---|---|
| 出典 | Google 2.4 (独自指摘、他 reviewer 未検出) |
| 検証 | ✅ 直接 verified |
| ファイル | `KnowledgeTree/Views/SettingsView.swift:70-82` |
| コード | ```swift<br>Toggle(isOn: Binding(<br>    get: { iCloudSyncEnabled },<br>    set: { newValue in<br>        if newValue {<br>            showICloudEnableConfirm = true<br>        } else {<br>            showICloudDisableConfirm = true<br>        }<br>    }<br>)) { ... }<br>``` |
| 影響 | set closure 内で **`newValue` を保存せず alert だけ表示** → ユーザー tap 直後に switch が元位置に弾き戻る (バウンス) → confirm alert を OK → やっと値が反映される。「動作が壊れている」誤認の元 |
| 提案 | (a) Pending state を `@State var pendingICloudToggle: Bool?` で保持し、confirm alert OK で `iCloudSyncEnabled = pendingICloudToggle!` を apply。または (b) Toggle ではなく Button + chevron に変更し sheet で確定する Apple 設定アプリ風 UX |
| 検証案 | UI test で toggle tap → alert 表示 → cancel で元位置 / confirm で反転、それぞれ assert |

### P1-3: ユーザー操作の `try?` が無反応 (5 ファイル特定済み)

| 項目 | 内容 |
|---|---|
| 出典 | Claude 3.1 (詳細表) + OpenAI P1-2 (両者一致、対象が一部重複) |
| 検証 | ✅ 一部直接 verified (SettingsView:305 / ArticleDetailView:243,248) + 🔍 エージェント報告 (件数) |
| 内訳 | `try?` 全体 ~180 箇所、うち永続化 ~39。**ユーザー能動操作**だけ抜粋: |

| ファイル:行 | 操作 | 問題 |
|---|---|---|
| `Views/SettingsView.swift:305` | チャット履歴全削除 | alert 確定 → 失敗しても無反応、履歴復活 |
| `Views/ChatHistorySidebar.swift:99` | セッション個別削除 | swipe 削除が黙って失敗 |
| `Views/ArticleDetailView.swift:243,248` | タグ追加 / 削除 | UI 上は付いて見えるが保存されない |
| `Views/SavedAnswerDetailView.swift:40,106,126` | ピン / 既読 / 削除 | 成功表示のまま失敗 |
| `Views/ConceptPageDetailView.swift:53` | フォロー切替 | トグルは動くが保存されない |

| 影響 | 「成功した」認識と DB 状態の乖離。CloudKit sync 競合や migration エラーで実発生し得る |
| 提案 | (1) 軽量 `AppErrorReporter` (`Logger` ベース、OpenAI 案) を追加して全 silent fail で log、(2) **ユーザー操作**は失敗時に inline 失敗 state または quiet toast を surface、(3) **裏処理** (backfill / `regenerateAllStale`) は calm UX 原則として `try?` のまま OK |
| 検証案 | Mock store で save throws → 失敗 toast が表示されることを UI test で assert |

### P1-4: LintEngine の破壊操作に「取り消し」も「staging」も無い ★最重要

| 項目 | 内容 |
|---|---|
| 出典 | Claude 5.1 (独自指摘、3 つの代替案あり) |
| 検証 | 🔍 エージェント報告 (`Services/LintEngine.swift` を Claude が分析、行番号は実装時要再確認) |
| 詳細 | 週 1 BGTask (日曜 3 AM) で**ユーザー確認なし**に:<br>- ConceptPage を **Levenshtein 距離 ≤ 2 で自動マージ** → "Design Pattern" ↔ "Design Patterns" 誤マージの恐れ<br>- 60 日未参照 + 関連 ≤ 1 件 + 非 follow の ConceptPage を **物理削除** (`context.delete()`、ソフト削除なし)<br>- `LintLog` は 200 字までの before/after を残すのみ。**フルスナップショット無し = 復元不可** |
| 影響 | ユーザーが育てた `userUnderstanding` (理解度) や注釈ごと消える可能性。プロダクト哲学 (「AI が裏で勝手に整理」spec 058) の核心ゆえ、サイレントなデータ破壊が最大リスク |
| 提案 (いずれか / 段階導入) | (a) merge/削除を即実行せず `ConflictProposal(autoResolved=false)` にステージング → 知識 Clip の「確認が必要」セクションで事後レビュー (spec 058 既存パターン再利用)<br>(b) 30 日のソフト削除 (`isDeleted` フラグ) + 「最近削除した項目」UI<br>(c) マージ閾値を Levenshtein ≤ 1 に厳格化 or embedding 類似度併用 |
| 検証案 | `LintEngineTests` 拡張: (1) Levenshtein 距離別の merge 判定、 (2) ソフト削除フラグ、 (3) ConflictProposal staging path |

### P1-5: bootstrap God-object + ServiceContainer optional の袋

| 項目 | 内容 |
|---|---|
| 出典 | Claude 3.4 + OpenAI P1-3 (両者一致) |
| 検証 | ✅ 直接 verified |
| ファイル | `KnowledgeTreeApp.swift:153-428` (`bootstrap()` ~275 行で ~30 サービスを依存順に手動配線) + `Services/ServiceContainer.swift` (35 プロパティ全て optional) |
| 影響 | spec を 1 つ足すたびに optional 追加 → bootstrap 配線 → 全 consumer で `guard let services.X else { return }` のボイラープレートが View 側に 14+ 箇所。配線順が暗黙の依存になっており壊れやすい |
| 提案 | OpenAI 案: `ServiceGraphBuilder` + `StartupJobRunner` に分離。Claude 案: 確定済サービスは non-optional + lazy 化で View 側 guard を削減。非 critical な backfill は初回描画後に遅延。Idempotent + 独立 testable に |
| 検証案 | `ServiceGraphBuilderTests` で構築の冪等性 + 依存解決をテスト |

### P1-6: ModelContainer 失敗で fatalError → 復旧不能

| 項目 | 内容 |
|---|---|
| 出典 | OpenAI P1-4 (独自指摘) |
| 検証 | 🔍 エージェント報告 (`KnowledgeTreeApp.swift:76,79`) |
| 影響 | データ中心アプリで local store 作成失敗時に hard-crash → ユーザーは再インストール以外復旧手段なし (knowledge base 全消失リスク) |
| 提案 | release 時 `fatalError` を `StoreRecoveryView` に置換: (1) retry button、 (2) local-only fallback (CloudKit sync OFF)、 (3) support log export。debug 時のみ `assertionFailure` |
| 検証案 | inject mock failing ModelContainer → recovery view が表示されることを XCTest で assert |

### P1-7: 起動時 backfill が全て直列 await

| 項目 | 内容 |
|---|---|
| 出典 | Claude 3.3 (独自指摘) |
| 検証 | ✅ 直接 verified |
| ファイル | `KnowledgeTreeApp.swift:389-427` (bootstrap 末尾) |
| 詳細 | enrichment → body → knowledge → tag cleanup → auto-tag backfill → category backfill → digest → embedding → topic → concept backfill → resynthesize を直列 await (9+ 段)。互いに独立な backfill (embedding と topic clustering 等) も順番待ち |
| 影響 | cold start が長引く (ユーザー体感の「何も起きない」時間延長)。spec 011 PowerGauge 等の初期表示が遅延 |
| 提案 | (1) 依存 chain (enrichment → body → knowledge) は直列維持、 (2) 独立処理は `async let` / `TaskGroup` で並列化、 (3) 非 critical な backfill (concept resynthesize 等) は初回描画後に遅延 |
| 検証案 | Instruments で cold start TTI 測定、改善前後比較 |

### P1-8: K-means / vDSP がメインアクター上で同期実行

| 項目 | 内容 |
|---|---|
| 出典 | Claude 3.2 (独自指摘) |
| 検証 | ✅ 直接 verified |
| ファイル | `Services/EmbeddingService.swift:17` (`@MainActor`、内部 `vDSP_dotpr` / `vDSP_svesq` を同期実行 `:52,82,87`) + `Services/TopicClusteringService.swift:23` (`@MainActor`、`kmeans` `:197` で vDSP 同期反復) |
| 補足 (重要) | AI 呼び出し自体は `LanguageModelSessionProtocol.generateXXX(...) async` で suspend するため **メインスレッドを塞がない**。問題は **suspension point の無い同期処理** (K-means 反復計算等) |
| 影響 | 記事数 100 件超で起動時 clustering がメインスレッドを数百 ms〜秒単位ブロック。スクロール体感悪化 |
| 提案 | `kmeans` は純粋関数なので `nonisolated static` のまま `Task.detached(.utility)` または専用 `actor` で実行し、結果だけ `@MainActor` に戻す。**`BodyExtractionService` が既に `Task.detached(.utility)` でやっている良い前例あり** |
| 検証案 | TopicClusteringServiceTests で 1000 件 embedding の clustering が main thread を 100ms 超ブロックしないことを XCTest で assert (xctest performance metric) |

### P1-9: Row-level `@Query` in chat が scale poorly

| 項目 | 内容 |
|---|---|
| 出典 | OpenAI P1-6 (独自指摘) |
| 検証 | 🔍 エージェント報告 (`Views/ChatMessageRow.swift:23,191,241`) |
| 影響 | 各 message row が「全 Article / 全 ConceptPage」query を attach。Chat session が 100+ message に育つと O(n × m) のメモリ + invalidation コスト |
| 提案 | `ChatTabView` で article / concept dictionary を 1 度 fetch → 軽量 data か lookup closure を row へ pass。Row は render-only に |
| 検証案 | Instruments Allocations / SwiftUI re-evaluation count で改善検証 |

### P1-10: Foundation Models のトークン管理が truncation 頼み

| 項目 | 内容 |
|---|---|
| 出典 | Claude 5.2 (独自指摘) |
| 検証 | 🔍 エージェント報告 (`Services/ChatService.swift` `buildPrompt` ~`:509`) |
| 詳細 | system + multi-turn 5 件 + 記事 5 件 (essence + KeyFact) + 関連 entity を連結。各要素は個別文字数 cap されるが**合計トークン推定が無い**。Foundation Models ~4096 token 上限を multi-turn + 長文記事 5 件で超過の恐れ (`ConceptSynthesisService` 側にトークン超過の履歴コメントあり) |
| 影響 | 超過時は黙って truncate → 答え品質劣化、または `LanguageModelSession.GenerationError` 発生 |
| 提案 | `text.count / 3` 程度の概算で prompt 合計を見積もり、超過時は topK を 5→3 に動的縮小 |
| 良い点 | ハルシネーション対策は堅牢: retrieval 結果外の article ID を citation から filter、空 citation は「分かりません」に上書き、UUID 本文混入を `stripUUIDsFromBody` で除去、Agentic loop `maxClarificationRounds = 3` で発散防止 |
| 検証案 | ChatServiceTests に「max token boundary case」を追加 (mock LanguageModelSession で 4096 超過時の挙動を test) |

---

## 5. P2: 設計 / 保守性 / 拡張性改善 (15 件)

### ~~P2-1: Article のリレーションに cascade 削除欠落~~ → **§2.3 で棄却** (誤検出)

`ConflictProposal.swift:18,21` で既に `@Relationship(deleteRule: .nullify)` 完備、Article 削除時は nil 化される。「過去の見解」履歴保存は spec 037/058 の意図的設計のため修正不要。詳細は §2.3 を参照。

> 番号は付録 B の出典 reviewer 一覧と対応付け維持のため P2-1 マーカーを残置 (リナンバリングしない)。

### P2-2: ChatService のカテゴリ検索が `fetchLimit = 50` を filter 前に適用

| 項目 | 内容 |
|---|---|
| 出典 | Google 2.3 (独自指摘) + OpenAI P2-7 (薄い言及) |
| 検証 | ✅ 直接 verified |
| ファイル | `Services/ChatService.swift:305-313` (`fetchArticlesInCategory`) |
| コード | ```swift<br>var descriptor = FetchDescriptor<Article>(...)<br>descriptor.fetchLimit = 50  // ← filter 前に適用<br>let all = (try? context.fetch(descriptor)) ?? []<br>return all.filter { article in<br>    (article.tags ?? []).contains { ($0.categoryRaw ?? "") == categoryName }<br>}<br>``` |
| 影響 | 全体で最新 50 件の記事のみが検索対象 → カテゴリ「テクノロジー」記事が古い 51 件目以降に存在しても AI は完全に見落とす。**スケール問題** (200+ 記事ユーザーで顕在化) |
| 提案 | `#Predicate { article in article.tags?.contains { ($0.categoryRaw ?? "") == categoryName } ?? false }` で SQL レベル filter。または 2 段階 fetch (category 一致のみ取得 + 50 件 cap) |
| 検証案 | `ChatServiceTests` に「101 件記事 + カテゴリ X が 51-100 件目に分布」シナリオ追加 |

### P2-3: LintEngine が refresh した SavedAnswer の isStale reset 漏れ

| 項目 | 内容 |
|---|---|
| 出典 | Google 2.3 (誇張部分は棄却、ただし**「reset 漏れ」自体は事実**) |
| 検証 | ✅ 直接 verified |
| ファイル | `Services/LintEngine.swift:323-360` (`stepRefreshStaleSavedAnswers`) |
| 詳細 | `maxRefreshPerRun = 3` で bounded ゆえ「API コスト暴騰」ではないが、archive された旧 SavedAnswer は `isStale=true` のまま永久残置 → 毎週 fetch 対象 → 毎週 3 件 reprocess。週 3 件 × 100 週 = 300 不要 LLM 呼び出し |
| 影響 | 中規模。週次バッチで Foundation Models へ無駄呼び出し。本来は「archive 印」を明示的に持つべき (`isArchived`) |
| 提案 | (a) refresh 後に `oldSavedAnswer.isArchived = true` 立て、`stepRefreshStaleSavedAnswers` の predicate を `isStale == true && isArchived == false` に。または (b) refresh 成功時に `isStale = false` reset し、archive 用に別フラグを設けない |
| 検証案 | `LintEngineTests` 拡張: refresh 後の旧 SavedAnswer が次回 fetch 対象にならないことを assert |

### P2-4: ChatTabView 擬似 streaming に `Task.isCancelled` チェック無し

| 項目 | 内容 |
|---|---|
| 出典 | Google 2.4 (独自指摘) |
| 検証 | ✅ 直接 verified |
| ファイル | `Views/ChatTabView.swift` `streamDisplayMessage` (15ms/文字 loop) |
| コード | ```swift<br>for char in fullText {<br>    streamingDisplayedText.append(char)<br>    try? await Task.sleep(nanoseconds: perCharDelayNs)<br>    // ← Task.isCancelled チェック無し<br>}<br>``` |
| 影響 | ユーザーが streaming 中に別 session に切替 / 別タブへ移動しても裏で loop 継続 → 新画面に予期せぬ文字混入の可能性。バッテリー無駄 |
| 提案 | loop 先頭に `if Task.isCancelled { return }` + session 切替時に `streamTask?.cancel()` |
| 検証案 | UI test で streaming 中 session 切替 → 新 session 画面に旧文字が混入しないこと assert |

### P2-5: Article detail の 1 秒 polling が過剰再描画

| 項目 | 内容 |
|---|---|
| 出典 | Google 2.4 + OpenAI P1-7 (両者一致) |
| 検証 | ✅ 直接 verified |
| ファイル | `Views/ArticleDetailView.swift:42` (`Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()`) |
| コメント | コード内 `/// 1秒 Timer ポーリング: 5 つの通知経路がすべて穴になる場合の最終保険。/// completion (knowledge succeeded + body succeeded) になったら止まる条件で /// CPU 影響を最小化する。` |
| 影響 | self-conscious コメントが示す通り「最終保険」として配置。それでも完了前は 1 秒ごと View 再構築でバッテリー消費 |
| 提案 | OpenAI 案: 明示的 progress / status publisher を store/service に追加して polling 排除。fallback は active processing state でのみ low-frequency 維持 |
| 検証案 | Instruments Energy Log で改善検証 |

### P2-6: @Query 全件取得 + in-memory filter (4 view)

| 項目 | 内容 |
|---|---|
| 出典 | Claude 4.1 + Google 2.1 (両者一致) |
| 検証 | ✅ 一部直接 verified |
| 代表例 | `Views/InterestingNextSection.swift:26` (`categoryStats` を全記事 × 全 CategorySeed で毎 body O(n×m) 再計算、メモ化なし) / `Views/ChatTabView.swift` (全 ChatMessage 取得 → session ID で in-memory filter) / `Views/AIBrainStatsRow.swift` (記事 / entity / keyFact を 3 回フルスキャン + 毎回 Set 重複排除) / `Services/ConceptSynthesisService.swift`, `Views/KnowledgeClipView.swift` (Google 報告) |
| 影響 | 数百〜数千記事規模でフリーズ / OOM リスク (Google 表現は誇張だが scale 問題は事実) |
| 提案 | 重い集計は `@State` + `.onChange(of:)` でメモ化、または service 層で precompute。`#Predicate` 利用可能箇所は SQL レベルへ |
| 検証案 | Instruments で 500 記事 seed → スクロール fps 計測 |

### P2-7: トピック / エンティティを表すモデルが 5 つに分裂

| 項目 | 内容 |
|---|---|
| 出典 | Claude 7.1 (独自指摘) |
| 検証 | 🔍 エージェント報告 |
| 詳細 | `Tag` / `ConceptPage` / `GraphNode` / `UserTopic` / `KnowledgeEntity` がいずれも「人物・モノ・概念」を別メカニズムで表現。**`categoryRaw` 文字列が 4 モデルに重複** (`Tag.categoryRaw` / `ConceptPage.categoryRaw` / `GraphNode.categoryRaw` / `GraphEdge.categoryRaw`)。`CategorySeed` のカテゴリ名変更時に 4 箇所をコードで手動同期、DB 整合性保証なし |
| 影響 | 知識グラフの断片化、merge 時の整合性 bug の温床 |
| 提案 | 軽量 `Category` @Model (name SSOT) に集約、または「4 モデルが同一 `CategorySeed` を使う」検証 unit test 追加。10 @Model 超え前が安全な導入時期 |

### P2-8: stringly-typed status (2 モデル)

| 項目 | 内容 |
|---|---|
| 出典 | Claude 7.2 (独自指摘) |
| 検証 | 🔍 エージェント報告 |
| 詳細 | 多くの `*Raw` は enum getter/setter 拡張で型安全化されているが、**`ChatMessage.role` (`ChatMessage.swift:20` 付近) と `GraphNode.entityType` (`GraphNode.swift:27` 付近) だけ素の String** で不正値が黙って永続化され得る |
| 提案 | 各 1 行の computed property (`var roleEnum: ChatMessageRole { .init(rawValue: role) ?? .user }` 等)。**Quick Win** |

### P2-9: VersionedSchema 不在 (20 @Model + CloudKit 本番)

| 項目 | 内容 |
|---|---|
| 出典 | Claude 7.4 (独自指摘) |
| 検証 | ✅ 直接 verified (`SharedSchema.swift:22-44`) |
| 詳細 | 20 @Model が登録され CloudKit 本番にユーザーデータあり。`VersionedSchema` / `SchemaMigrationPlan` が無く lightweight inferred migration 任せ。現在の追加 field は全て optional + default で安全だが、将来の型変更 / 非 optional 化 / リネームで起動時クラッシュ or データ消失 |
| 提案 | 現スキーマを `SchemaV1` として `VersionedSchema` 化し `SchemaMigrationPlan` 骨組み導入 (中身は空でよい)。25 @Model 超過前が安全 |

### P2-10: Safari 拡張 / Widget / Settings に hardcoded 日本語、xcstrings に 127 empty key

| 項目 | 内容 |
|---|---|
| 出典 | OpenAI P1-9 + Claude 4.3 (両者一致) |
| 検証 | 🔍 エージェント報告 |
| 詳細 | xcstrings に **127 keys with empty localization dictionaries** (OpenAI 計測)。`SettingsView` / `RecentActivityCards` / `DeepDiveChatView` / `OnboardingView` / `EmptyStateView` / `GraphNodeEditSheet` / `GraphEdgeEditSheet` / Widget config に 50+ ハードコード日本語リテラル。P0-1 / P0-2 の実バグもこれが遠因 |
| 提案 | (a) 127 empty key を「extraction placeholder か意図的か」判定 → 整理、 (b) ハードコード日本語を 1 パスで key 化、 (c) CI で「`Text(` / `Button(` / `.navigationTitle(` 内の日本語リテラル」を検出する lint 追加 |

### P2-11: Legacy view / service が active target に残存

| 項目 | 内容 |
|---|---|
| 出典 | OpenAI P1-10 (独自指摘) |
| 検証 | 🔍 エージェント報告 |
| 詳細 | `Views/PowerGaugeCard.swift` / `KnowledgeMapView.swift` / `RecentActivityCards.swift` / `ReaderView.swift` / `Services/DeepDiveChatStarter.swift` / `DesignSystem.swift:64` (deprecated token) が「明示的に deprecated/legacy」とマーク or 役割消失。File-system-synchronized target membership で意図せず compile 維持 |
| 提案 | `Legacy/` フォルダへ移動 (ownership 明示) または削除。旧 localization key + 古い UI test も同時に処理 |

### P2-12: トラッキングパラメータ・SSRF・PDF サイズ検証 (セキュリティ小)

| 項目 | 内容 |
|---|---|
| 出典 | Claude 6.2 / 6.3 / 6.4 (独自指摘) |
| 検証 | 🔍 エージェント報告 |
| 詳細 | (a) `Services/ArticleEnrichmentService.swift`, `Services/MultiPageCrawler.swift` がリダイレクト既定追従 + 内部 IP (127.0.0.1 / 192.168.* / 169.254.169.254 等) ブロックなし、 (b) Safari 拡張 `*://*/*` 全サイト権限 (実害は local 保存のみだが App Store 審査で説明要求 + プライバシー観点)、 (c) `PDFFetcher.swift:30` 付近で size guard 前にパース、`isLocked` チェック無し (nil 返却でグレースフル失敗ゆえ軽微) |
| 良い点 | timeout 30s、5MB 上限、5 ページ cap、1 秒 rate limit、4 段 charset fallback など他の防御は優秀 |
| 提案 | (a) private-IP ガード + redirect 上限 5、 (b) SettingsView に Safari 拡張プライバシー方針明記、 (c) PDF init 前 `data.count` チェック + `isLocked` 検出 |

### P2-13: RAG trust boundary が一貫していない

| 項目 | 内容 |
|---|---|
| 出典 | OpenAI P1-5 (独自指摘) |
| 検証 | 🔍 エージェント報告 (`Services/ChatService.swift:514` (RAG prompt は一般知識禁止) + `:282` (zero-result fallback は一般知識を要求)) |
| 影響 | 「保存記事から回答」と「一般 assistant」が UI mode 無しに混在 → ユーザーは uncited 答えを保存記事ベースと誤認 |
| 提案 | 明示モードセレクタ:「保存記事から回答」「一般知識も使う」。Uncited 答えは badge で明示、cited と visual に区別 |

### P2-14: Safari 拡張の auto-save 設定が二重ソース

| 項目 | 内容 |
|---|---|
| 出典 | OpenAI P1-8 (独自指摘) |
| 検証 | 🔍 エージェント報告 (`SafariSetupView.swift:16` (`@AppStorage`) + `:214` (App Group へ手動 sync) + `SafariWebExtensionHandler.swift:67` (App Group 読み)) |
| 影響 | View は sync するが状態の真ソースが 2 つ → 初期値や将来の Settings UI で drift |
| 提案 | `SafariExtensionSettingsStore` 抽象を導入 → extension 可視設定は App Group suite のみ。`@AppStorage` は in-app UI state 専用に |

### P2-15: SwiftData store 層が未テスト (破壊操作含む)

| 項目 | 内容 |
|---|---|
| 出典 | Claude 9.1 (独自指摘) |
| 検証 | 🔍 エージェント報告 |
| 詳細 | 68 サービス中 23 が未テスト (カバー率 66%)。ロジック系 (LintEngine 10 / Clustering / Graph) は手厚いが、**`TagStore` / `ConceptPageStore` / `GraphNodeStore` / `ArticleStore` の CRUD・rename・merge・delete が未テスト**。P1-4 の破壊操作の実体がノーガード |
| 提案 | 最低限 merge / delete の unit test 追加。Swift Testing (`@Test`/`#expect`) 中心 ~474 test func の流儀に合わせる |

---

## 6. UI/UX 改善ロードマップ (9 領域)

OpenAI 案を主、Claude 案を補強した統合版。

### 6.1 First-run flow

| 問題 | 提案 |
|---|---|
| Onboarding が旧 navigation (学習タブ) を案内 | P0-2 で対応 |
| 空状態が next action を口頭で説明するだけ (CTA なし) | 空状態に CTA button: 「URL を追加」「Safari 連携を設定」「サンプルで試す」(optional demo mode) |
| 初回保存後に処理進捗が見えない | `ProcessingMonitor` の Phase を 知識 Clip に「AI が整理中… (N 件)」chip で接続 (Claude 案) |
| Settings 発見性 (Avatar menu のみ) | 空状態 / onboarding で一度だけ場所を示唆 (Claude 案) |

### 6.2 Ingestion UX

| 問題 | 提案 |
|---|---|
| Share / Safari / URL / App Intent パスが別メンタルモデル | 統一 `SaveStatus` モデル: `saved` / `duplicate` / `invalid_url` / `extension_unavailable` / `processing_queued`。Add Article / Share / Safari / App Intent で共通利用 |
| Safari 失敗が silent | P1-3 で対応 + 失敗時 toolbar badge |
| Duplicate alert が「既存記事を開く」導線なし | Add Article duplicate alert に「既存記事を開く」button 追加 |
| 保存成功 feedback が場面ごとに別 | 軽い haptic + 「保存しました」toast を全保存パスで統一 (現状 DeepDiveChatView / AnswerActionsMenu のみ haptic) |

### 6.3 Library UX

| 提案 |
|---|
| Filter chips: all / processing / failed / obsolete / untagged / PDF / recently added |
| Delete undo (現状 swipe / contextMenu で即削除、spec 022/030 設計) |
| Retry failed processing batch action |
| Sort modes: saved date / last processed / title / category |

### 6.4 Article detail UX

| 提案 |
|---|
| Hidden polling (P2-5) を visible progress timeline に: saved → fetching → extracting body → generating knowledge → indexing graph/concepts |
| 失敗時に「retry」+ reason を明示 |
| Generated knowledge provenance を citation / source metadata 近くへ |

### 6.5 Chat UX

| 提案 |
|---|
| Citation link navigation 修正 (P0-4) を最優先 |
| Citation drawer: source snippet 表示 |
| Answer mode selector: 保存記事 vs 一般知識 (P2-13) |
| Stop / regenerate controls |
| Save answer feedback + pin state |

### 6.6 Knowledge Clip UX

| 提案 |
|---|
| 「why this card」を Interesting Next item で表示 |
| Stale / following / review を一貫した badge で区別 |
| 単一「Today」surface: New knowledge / Needs refresh / Keep following / Continue learning |

### 6.7 Graph UX

| 提案 |
|---|
| Legend (node size/color/edge confidence) |
| Filter: category / confidence / relation label / stale-uncertain |
| Uncertain AI edge の review queue |
| 「why connected」説明 (shared articles / key facts ベース) |

### 6.8 Settings UX

| 提案 |
|---|
| Section grouping: Health / Sync / Extensions / Data management / Display / Help-about |
| 危険操作は最下部 |
| 重複 iCloud placeholder 削除 (P0-3) |
| Toggle ではなく status (synced X minutes ago) を併記 |

### 6.9 Widget UX

| 提案 |
|---|
| Widget copy をローカライズ (P2-10) |
| 空状態に「open app to refresh」案内 + sync 状況表示 |
| Medium widget: 1 primary card + 「needs update」badge |

### 6.10 ★ 統合: 「AI が最近やったこと」フィード (Claude 独自、最重要)

| 問題 | 提案 |
|---|---|
| auto-tag / auto-category / conflict 自動解決 / lint 自動マージ / concept 合成 が全てサイレントで、信頼の手がかりが `LintLog` / `ConflictHistoryDisclosure` / 各画面に散在 | **「最近 AI がやったこと」タイムライン** (マージした / 削除した / タグ付けた) を 1 画面で。 「勝手にやる」安心感 × 透明性 × ロールバック導線 をプロダクト哲学 (spec 058) に最も沿った形で提供 |

`ProcessingMonitor` の Phase + `LintLog` 既存 + `ConflictProposal` 既存 を統合した read-only feed として実装可能。新規 schema 不要。

---

## 7. 推奨実装順 (最小工数 × 高効果)

### Sprint 1: 出荷ブロッカー (P0)

| # | 項目 | 該当節 | 工数 |
|---|---|---|---|
| 1 | アプリ名 placeholder → iKnow | P0-1 | 数行 |
| 2 | Onboarding の学習タブ案内書き換え | P0-2 | 数十行 |
| 3 | Settings 重複 iCloud Section 削除 | P0-3 | 数十行 |
| 4 | Chat citation link navigation 配線 | P0-4 | 50-100 行 |
| 5 | UI test V3 刷新 (学習/AIBrain → Knowledge Clip/Library/Chat) | P0-5 | 200-300 行 |

### Sprint 2: 信頼性 (P1 上位)

| # | 項目 | 該当節 | 工数 |
|---|---|---|---|
| 6 | URL normalization を保存パスへ + 重複 backfill | P1-1 | 中 |
| 7 | iCloud Toggle バウンス修正 | P1-2 | 小 |
| 8 | `try?` ユーザー操作 5 ファイルを surface + AppErrorReporter | P1-3 | 中 |
| 9 | LintEngine 破壊操作 staging 化 (ConflictProposal 経路再利用) | P1-4 | 中〜大 |
| 10 | ModelContainer fatalError → StoreRecoveryView | P1-6 | 小 |

### Sprint 3: 信頼性 (P1 後半) + 設計負債 (P2 上位)

| # | 項目 | 該当節 | 工数 |
|---|---|---|---|
| 11 | bootstrap → ServiceGraphBuilder + StartupJobRunner 分離 + backfill 並列化 | P1-5 + P1-7 | 大 |
| 12 | K-means / vDSP を Task.detached へ退避 | P1-8 | 中 |
| 13 | Row-level @Query in chat を dictionary lookup へ | P1-9 | 中 |
| 14 | Foundation Models token 推定 + 動的 topK | P1-10 | 中 |
| 15 | ChatService fetchLimit=50 を #Predicate へ | P2-2 | 小 |
| 16 | LintEngine refresh 後 isArchived 追加 (reset 漏れ) | P2-3 | 小 |
| 17 | streaming Task.isCancelled チェック | P2-4 | 小 |
| 18 | Article detail polling を progress publisher へ | P2-5 | 中 |
| 19 | enum accessor 2 件 (ChatMessage.role / GraphNode.entityType) | P2-8 | 小 (Quick Win) |
| 20 | SchemaV2 骨組み導入 (将来の型変更に備え) | P2-9 | 中 |

### Sprint 4: UX / 整理

| # | 項目 | 該当節 | 工数 |
|---|---|---|---|
| 21 | 「AI が最近やったこと」統合フィード ★ | 6.10 | 中〜大 (価値大) |
| 22 | xcstrings 127 empty key 整理 + ハードコード日本語 1 パス | P2-10 | 中 |
| 23 | Legacy view 削除 (PowerGaugeCard / KnowledgeMapView / 等) | P2-11 | 中 |
| 24 | SwiftData store 層テスト (TagStore / ConceptPageStore / 等 merge/delete) | P2-15 | 中 |
| 25 | UI/UX Roadmap 6.1-6.9 を順次 | 6 章 | 大 |

### 将来 (大型 / 中長期)

- Category @Model 集約 (P2-7)
- RAG trust boundary 明示モード (P2-13)
- Safari 拡張設定の二重ソース解消 (P2-14)
- private-IP ガード / PDF size guard (P2-12)
- Share Extension PDF・テキスト対応

---

## 8. 検証メモ / 未検証範囲

### 8.1 本評価で実行した検証

- `rg --files` でファイル数列挙
- `wc -l` でレポート規模測定
- `rg` で具体パターン検索 (アプリ名 / 学習タブ / application.id / iCloud / 等)
- `sed -n` + Read で 該当行コンテキスト精査
- 採用 reviewer の主要 file:line を本ブランチで cross-check

### 8.2 未実行 (本評価でも未検証)

- `xcodebuild test` 実行 (OpenAI も同様、sandbox/CoreSimulator permission 警告で skip)
- Instruments による fps / TTI / Energy 計測 (P1-7 / P1-8 / P2-5 / P2-6 の影響評価)
- 実機での UI flow 検証 (P0-1〜P0-5 の体感確認、quickstart シナリオ消化)
- CloudKit Dashboard での schema deploy 状況確認
- Safari 拡張 / Share Extension / Widget の実機動作確認

### 8.3 エージェント報告 (実装時要再確認)

以下の指摘は採用 reviewer の subagent 報告に依存しており、実装着手時に file:line を再確認すること:

- P1-4 LintEngine (Claude 5.1) — `Services/LintEngine.swift` の Levenshtein / 60 日削除条件 / context.delete()
- P1-6 ModelContainer (OpenAI P1-4) — `KnowledgeTreeApp.swift:76,79`
- P1-9 Row-level @Query (OpenAI P1-6) — `Views/ChatMessageRow.swift:23,191,241`
- P1-10 Foundation Models token (Claude 5.2) — `Services/ChatService.swift` `buildPrompt` ~`:509`
- P2-7 トピックモデル 5 分裂 (Claude 7.1)
- P2-8 stringly status (Claude 7.2) — `Models/ChatMessage.swift:20` / `Models/GraphNode.swift:27`
- P2-10 xcstrings 127 empty key (OpenAI P1-9)
- P2-11 Legacy view (OpenAI P1-10)
- P2-12 SSRF / PDF (Claude 6.2-6.4)
- P2-13 RAG trust (OpenAI P1-5) — `Services/ChatService.swift:514,282`
- P2-14 Safari 設定二重 (OpenAI P1-8) — `Views/SafariSetupView.swift:16,214` / `SafariWebExtensionHandler.swift:67`
- P2-15 Store 層テスト不足 (Claude 9.1)

### 8.4 取り上げなかった (Google 棄却分)

- 「OOM を確実に引き起こします」断定 → scale 問題は事実だが「確実」は誇張、P2-6 として残置
- 「LintEngine 無限ループで API コスト暴騰」→ `maxRefreshPerRun = 3` で bounded、P2-3 として正確な形で残置
- 行番号なし指摘の大半 → 採用 reviewer の同類指摘で代替

---

## 付録 A. コードベース統計 (3 reviewer の数値統合)

| 項目 | 数値 | 出典 |
|---|---:|---|
| Swift ファイル総数 | 170 (アプリ本体) + 拡張 / Widget | Claude |
| Swift ファイル総数 (全 target) | 248 | Google |
| 全 source/config 行数 (アプリ本体) | 24,291 | Claude |
| 全 source/config 行数 (全 target) | 37,414 | OpenAI |
| 全 source/config 行数 (空行含む) | 73,816 | Google |
| テストファイル数 | 61 (Claude) / 66 (Google) | 両者 |
| テストケース数 | ~474 test func (Swift Testing) / 334 `func test` (XCTest) / 487 total declarations | 3 者統合 |
| Localization | `KnowledgeTree/Localization/Localizable.xcstrings` 一元 (127 empty key あり) | Google + OpenAI |
| Entitlements ターゲット | 4 (本体 + Share + Safari + Widget) | Google |
| TODO/FIXME | 0 | Claude |
| 空 `catch` | 0 | Claude |
| 最大ファイル | ChatService.swift (718) / ConceptSynthesisService.swift (550) / ArticleDetailView.swift (534) / KnowledgeExtractionService.swift (484) | Claude |

## 付録 B. 出典 reviewer 一覧

| 採用指摘 | 出典 reviewer |
|---|---|
| P0-1 (アプリ名) | Claude 独自 |
| P0-2 (学習タブ) | Claude + OpenAI |
| P0-3 (重複 iCloud) | OpenAI 独自 |
| P0-4 (Chat citation) | OpenAI 独自 |
| P0-5 (UI test stale) | OpenAI + Claude |
| P1-1 (URL norm) | OpenAI + Claude |
| P1-2 (Toggle bounce) | **Google 独自** |
| P1-3 (try? silent) | Claude + OpenAI |
| P1-4 (LintEngine) | Claude 独自 |
| P1-5 (bootstrap) | Claude + OpenAI |
| P1-6 (ModelContainer crash) | OpenAI 独自 |
| P1-7 (直列 backfill) | Claude 独自 |
| P1-8 (vDSP main-actor) | Claude 独自 |
| P1-9 (Row @Query) | OpenAI 独自 |
| P1-10 (Token mgmt) | Claude 独自 |
| ~~P2-1 (Article cascade)~~ | **棄却** — §2.3 参照 (ConflictProposal は既に `.nullify` 完備) |
| P2-2 (fetchLimit=50) | **Google 独自** + OpenAI (軽) |
| P2-3 (LintEngine reset) | Google 部分採用 (誇張除去) |
| P2-4 (streaming cancel) | **Google 独自** |
| P2-5 (polling) | Google + OpenAI |
| P2-6 (@Query in body) | Claude + Google |
| P2-7 (model 5 分裂) | Claude 独自 |
| P2-8 (enum accessor) | Claude 独自 |
| P2-9 (VersionedSchema) | Claude 独自 |
| P2-10 (xcstrings) | OpenAI + Claude |
| P2-11 (Legacy view) | OpenAI 独自 |
| P2-12 (SSRF/PDF) | Claude 独自 |
| P2-13 (RAG trust) | OpenAI 独自 |
| P2-14 (Safari 設定二重) | OpenAI 独自 |
| P2-15 (Store 層テスト) | Claude 独自 |
| 6.10 (AI フィード) | Claude 独自 |
| UI/UX 6.1-6.9 | OpenAI 主 + Claude 補 |

### 棄却した指摘

- ⚠️ 2.1 Safari `application.id` (OpenAI P0-1) — Apple Safari Web Extension で第 1 引数無視仕様
- ⚠️ 2.2 LintEngine「API コスト暴騰」(Google 2.3 誇張部分) — `maxRefreshPerRun = 3` で bounded。reset 漏れ自体は P2-3 で正確な形に修正採用
- ⚠️ 2.3 Article cascade 欠落 (Google 2.2 + 初版 P2-1) — `ConflictProposal.swift:18,21` で既に `.nullify` 完備、Article 削除で nil 化される。「過去の見解」履歴保存は spec 037/058 の意図的設計

---

*本 report は静的解析 (3 reviewer report + 本評価での `rg` / Read による cross-check) に基づく。実機での動作検証・Instruments 計測は別途必要。行番号は記載時点のもので、実装時に再確認すること。*

*作成方法: `final code_review_rubric.md` v1.0 の比較レビューモード (§9) に従い、3 reviewer report を個別採点 → P0/P1 一覧化 → 重複 / 矛盾 / 片方だけの指摘を分離 → 矛盾は file:line で再検証 → 両方指摘は優先度上げ → 片方だけは証拠強度とコンテキスト適合で採否決定。*
